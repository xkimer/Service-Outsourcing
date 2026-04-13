import base64
import logging
import os
import subprocess
import threading
import time
from dataclasses import dataclass
from typing import Dict, Any, List, Optional, Tuple

import cv2
import requests


# =========================
# 配置区
# =========================
@dataclass
class Config:
    # hdc
    HDC_EXE: str = r"C:\Users\zhangyuhan\AppData\Local\OpenHarmony\Sdk\10\toolchains\hdc.exe"
    HDC_TARGET: str = "7001005458323933328a01bce01b3800"

    # GPIO
    SENSOR_GPIO: int = 29
    GREEN_LED_GPIO: int = 105
    RED_LED_GPIO: int = 114

    # 摄像头（插在电脑上）
    # 先尝试 1，再尝试 0、2、3，通常外接 USB 摄像头常见是 1
    CAMERA_INDEXES: Tuple[int, ...] = (1, 0, 2, 3)
    FRAME_WIDTH: int = 1280
    FRAME_HEIGHT: int = 720
    JPEG_QUALITY: int = 85

    # 时序
    POLL_INTERVAL_MS: int = 50
    TRIGGER_COOLDOWN_MS: int = 600
    CAPTURE_DELAY_MS: int = 150
    RESULT_HOLD_MS: int = 800

    # 后端
    BACKEND_BASE: str = "http://192.168.3.34:8000"
    DEVICE_ID: str = "board01"
    BATCH_ID: str = "line001"
    ENABLE_DISPLAY_SYNC: bool = True

    # 本地调试目录，可选
    LOCAL_DEBUG_DIR: str = r"D:\bridge_debug"
    SAVE_DEBUG_IMAGE: bool = False


CFG = Config()


# =========================
# 日志
# =========================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)
logger = logging.getLogger("bridge_pc_opencv")


# =========================
# HDC
# =========================
class HdcClient:
    def __init__(self, hdc_exe: str, target: str = ""):
        self.hdc_exe = hdc_exe
        self.target = target.strip()
        self.lock = threading.Lock()

        rc, out = self.shell("echo hdc_ready", timeout=5.0, check=False)
        if rc != 0:
            raise RuntimeError(f"HDC 不可用，输出：\n{out}")

        logger.info("HDC 已就绪")

    def _base_cmd(self) -> List[str]:
        cmd = [self.hdc_exe]
        if self.target:
            cmd += ["-t", self.target]
        return cmd

    def _run(self, args: List[str], timeout: float = 5.0) -> Tuple[int, str]:
        try:
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                timeout=timeout
            )
        except subprocess.TimeoutExpired:
            raise TimeoutError("命令执行超时: " + " ".join(args))

        stdout = (result.stdout or "").strip()
        stderr = (result.stderr or "").strip()
        output = "\n".join([x for x in [stdout, stderr] if x]).strip()
        return result.returncode, output

    def shell(self, cmd: str, timeout: float = 5.0, check: bool = True) -> Tuple[int, str]:
        with self.lock:
            rc, out = self._run(self._base_cmd() + ["shell", cmd], timeout=timeout)

        if check and rc != 0:
            raise RuntimeError(
                f"HDC shell 执行失败\n"
                f"cmd: {cmd}\n"
                f"returncode: {rc}\n"
                f"output:\n{out or '<无输出>'}"
            )
        return rc, out


# =========================
# GPIO
# =========================
class BoardGPIO:
    def __init__(self, hdc: HdcClient, sensor_pin: int, green_pin: int, red_pin: int):
        self.hdc = hdc
        self.sensor_pin = sensor_pin
        self.green_pin = green_pin
        self.red_pin = red_pin

    def init(self):
        cmds = [
            f"echo {self.sensor_pin} > /sys/class/gpio/export 2>/dev/null || true",
            f"echo in > /sys/class/gpio/gpio{self.sensor_pin}/direction",

            f"echo {self.green_pin} > /sys/class/gpio/export 2>/dev/null || true",
            f"echo out > /sys/class/gpio/gpio{self.green_pin}/direction",

            f"echo {self.red_pin} > /sys/class/gpio/export 2>/dev/null || true",
            f"echo out > /sys/class/gpio/gpio{self.red_pin}/direction",

            f"echo 0 > /sys/class/gpio/gpio{self.green_pin}/value",
            f"echo 0 > /sys/class/gpio/gpio{self.red_pin}/value",
        ]

        for cmd in cmds:
            self.hdc.shell(cmd, timeout=5.0)

        logger.info("GPIO 初始化完成")

    def read_sensor(self) -> int:
        _, out = self.hdc.shell(
            f"cat /sys/class/gpio/gpio{self.sensor_pin}/value",
            timeout=2.0
        )
        out = (out or "").strip()
        return int(out) if out in ("0", "1") else 1

    def set_idle(self):
        self.hdc.shell(f"echo 0 > /sys/class/gpio/gpio{self.green_pin}/value", timeout=2.0)
        self.hdc.shell(f"echo 0 > /sys/class/gpio/gpio{self.red_pin}/value", timeout=2.0)

    def set_ok(self):
        self.hdc.shell(f"echo 1 > /sys/class/gpio/gpio{self.green_pin}/value", timeout=2.0)
        self.hdc.shell(f"echo 0 > /sys/class/gpio/gpio{self.red_pin}/value", timeout=2.0)

    def set_ng(self):
        self.hdc.shell(f"echo 0 > /sys/class/gpio/gpio{self.green_pin}/value", timeout=2.0)
        self.hdc.shell(f"echo 1 > /sys/class/gpio/gpio{self.red_pin}/value", timeout=2.0)


# =========================
# PC 摄像头
# =========================
class CameraWorker:
    def __init__(self, index_candidates: Tuple[int, ...], width: int, height: int):
        self.index_candidates = index_candidates
        self.width = width
        self.height = height

        self.cap: Optional[cv2.VideoCapture] = None
        self.camera_index_in_use: Optional[int] = None
        self.frame_lock = threading.Lock()
        self.latest_frame = None
        self.running = False
        self.thread: Optional[threading.Thread] = None

    def start(self):
        selected_cap: Optional[cv2.VideoCapture] = None
        selected_idx: Optional[int] = None

        for idx in self.index_candidates:
            if os.name == "nt":
                cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
            else:
                cap = cv2.VideoCapture(idx)

            if cap and cap.isOpened():
                try:
                    cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
                except Exception:
                    pass

                cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)

                selected_cap = cap
                selected_idx = idx
                break

            if cap:
                cap.release()

        if selected_cap is None or selected_idx is None:
            raise RuntimeError(f"摄像头打开失败，尝试过索引: {self.index_candidates}")

        self.cap = selected_cap
        self.camera_index_in_use = selected_idx

        self.running = True
        self.thread = threading.Thread(target=self._reader_loop, daemon=True)
        self.thread.start()

        logger.info("PC 摄像头已启动，index=%s", self.camera_index_in_use)
        time.sleep(1.0)  # 预热

    def _reader_loop(self):
        while self.running and self.cap:
            ret, frame = self.cap.read()
            if ret and frame is not None:
                with self.frame_lock:
                    self.latest_frame = frame.copy()
            else:
                time.sleep(0.02)

    def get_latest_frame(self, timeout: float = 2.0):
        start = time.time()
        while time.time() - start < timeout:
            with self.frame_lock:
                if self.latest_frame is not None:
                    return self.latest_frame.copy()
            time.sleep(0.01)
        raise TimeoutError("获取摄像头帧超时")

    def stop(self):
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=1.0)
        if self.cap:
            self.cap.release()
            self.cap = None
        logger.info("PC 摄像头已停止")


# =========================
# 后端
# =========================
class BackendClient:
    def __init__(self, base_url: str, device_id: str, batch_id: str, enable_display_sync: bool):
        self.base_url = base_url.rstrip("/")
        self.device_id = device_id
        self.batch_id = batch_id
        self.enable_display_sync = enable_display_sync

        self.session = requests.Session()
        self.upload_url = (
            f"{self.base_url}/api/v1/detect/upload_bytes"
            f"?device_id={self.device_id}&batch_id={self.batch_id}&ext=jpg"
        )
        self.display_update_url = f"{self.base_url}/api/v1/display/update"

    def upload_jpg(self, jpg_bytes: bytes) -> Dict[str, Any]:
        resp = self.session.post(
            self.upload_url,
            data=jpg_bytes,
            headers={"Content-Type": "application/octet-stream"},
            timeout=10
        )
        resp.raise_for_status()

        ctype = resp.headers.get("Content-Type", "")
        if "application/json" in ctype:
            return resp.json()

        text = resp.text.strip()
        return {"raw_text": text}

    def parse_result(self, payload: Dict[str, Any]) -> str:
        for key in ("result", "status", "decision"):
            if key in payload:
                value = str(payload[key]).strip().upper()
                if "OK" in value:
                    return "OK"
                if "NG" in value:
                    return "NG"

        for key in ("is_qualified", "qualified", "pass"):
            if key in payload and isinstance(payload[key], bool):
                return "OK" if payload[key] else "NG"

        raw = str(payload.get("raw_text", "")).strip().upper()
        if "OK" in raw:
            return "OK"
        if "NG" in raw:
            return "NG"

        return "NG"

    def push_display_state(self, result: str, backend_payload: Dict[str, Any], jpg_bytes: bytes):
        if not self.enable_display_sync:
            return

        image_url = backend_payload.get("image_url", "")
        image_name = backend_payload.get("image_name", "")
        image_b64 = ""

        # 没有 image_url 时，用 base64 兜底给前端显示
        if not image_url and jpg_bytes:
            image_b64 = base64.b64encode(jpg_bytes).decode("utf-8")

        payload = {
            "result": result,
            "image_url": image_url,
            "image_name": image_name,
            "image_b64": image_b64,
            "backend_payload": backend_payload,
            "ts": time.time()
        }

        try:
            self.session.post(self.display_update_url, json=payload, timeout=3)
        except Exception as e:
            logger.warning("同步显示结果给后端失败: %s", e)


# =========================
# 工具
# =========================
def encode_jpg(frame, quality: int) -> bytes:
    ok, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        raise RuntimeError("JPG 编码失败")
    return buf.tobytes()


def save_debug_image(jpg_bytes: bytes):
    if not CFG.SAVE_DEBUG_IMAGE:
        return

    os.makedirs(CFG.LOCAL_DEBUG_DIR, exist_ok=True)
    filename = os.path.join(CFG.LOCAL_DEBUG_DIR, f"capture_{int(time.time() * 1000)}.jpg")
    with open(filename, "wb") as f:
        f.write(jpg_bytes)
    logger.info("已保存本地调试图片: %s", filename)


# =========================
# 主流程
# =========================
def main():
    print("bridge_pc_opencv.py starting...")
    logger.info("开始初始化 HDC / GPIO / PC Camera")

    hdc = HdcClient(CFG.HDC_EXE, CFG.HDC_TARGET)
    gpio = BoardGPIO(hdc, CFG.SENSOR_GPIO, CFG.GREEN_LED_GPIO, CFG.RED_LED_GPIO)
    camera = CameraWorker(CFG.CAMERA_INDEXES, CFG.FRAME_WIDTH, CFG.FRAME_HEIGHT)
    backend = BackendClient(CFG.BACKEND_BASE, CFG.DEVICE_ID, CFG.BATCH_ID, CFG.ENABLE_DISPLAY_SYNC)

    try:
        gpio.init()
        gpio.set_idle()
        camera.start()

        logger.info("系统已启动，等待产品经过传感器...")

        last_sensor = gpio.read_sensor()
        cooldown_until = 0.0
        busy = False
        led_reset_at = 0.0

        while True:
            now = time.time()

            # 灯保持一段时间后自动熄灭
            if led_reset_at > 0 and now >= led_reset_at and not busy:
                try:
                    gpio.set_idle()
                    led_reset_at = 0.0
                except Exception as e:
                    logger.warning("重置 LED 失败: %s", e)

            try:
                sensor_value = gpio.read_sensor()
            except Exception as e:
                logger.exception("读取传感器失败: %s", e)
                time.sleep(CFG.POLL_INTERVAL_MS / 1000.0)
                continue

            triggered = (
                last_sensor == 1 and
                sensor_value == 0 and
                now >= cooldown_until and
                not busy
            )

            if triggered:
                busy = True
                cooldown_until = now + CFG.TRIGGER_COOLDOWN_MS / 1000.0
                logger.info("检测到产品经过，准备拍照")
                gpio.set_idle()

                try:
                    # 稍微等一下，让产品到镜头中心
                    time.sleep(CFG.CAPTURE_DELAY_MS / 1000.0)

                    frame = camera.get_latest_frame(timeout=2.0)
                    jpg_bytes = encode_jpg(frame, CFG.JPEG_QUALITY)
                    save_debug_image(jpg_bytes)

                    backend_payload = backend.upload_jpg(jpg_bytes)
                    result = backend.parse_result(backend_payload)

                    logger.info("后端返回结果：%s | payload=%s", result, backend_payload)

                    if result == "OK":
                        gpio.set_ok()
                    else:
                        gpio.set_ng()

                    led_reset_at = time.time() + CFG.RESULT_HOLD_MS / 1000.0
                    backend.push_display_state(result, backend_payload, jpg_bytes)

                except Exception as e:
                    logger.exception("本次处理失败: %s", e)
                    try:
                        gpio.set_ng()
                        led_reset_at = time.time() + CFG.RESULT_HOLD_MS / 1000.0
                        backend.push_display_state("NG", {"error": str(e)}, b"")
                    except Exception:
                        pass

                finally:
                    busy = False

            last_sensor = sensor_value
            time.sleep(CFG.POLL_INTERVAL_MS / 1000.0)

    finally:
        try:
            gpio.set_idle()
        except Exception:
            pass
        try:
            camera.stop()
        except Exception:
            pass


if __name__ == "__main__":
    main()
