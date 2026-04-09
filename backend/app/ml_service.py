import os
from functools import lru_cache
from typing import Dict, Any

from PIL import Image
from ultralytics import YOLO


# ===== 这里改成你的模型路径 =====
MODEL_PATH = os.getenv(
    "YOLO_MODEL_PATH",
    r"D:\EnergyLabel-Detection-System\yolo-distiller\runs\student\yolo11n_dpfd_energy_label\weights\best.pt"
)

CONF_THRES = float(os.getenv("YOLO_CONF", "0.25"))


CLASS_MAP = {
    "label_normal": {
        "status": "OK",
        "defectType": "无",
        "hasDefect": False,
    },
    "label_offset": {
        "status": "NG",
        "defectType": "偏移",
        "hasDefect": True,
    },
    "label_scratch": {
        "status": "NG",
        "defectType": "划痕",
        "hasDefect": True,
    },
    "label_stain": {
        "status": "NG",
        "defectType": "污渍",
        "hasDefect": True,
    },
    "label_wrinkle": {
        "status": "NG",
        "defectType": "褶皱",
        "hasDefect": True,
    },
}


@lru_cache
def get_model():
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"模型文件不存在: {MODEL_PATH}")
    return YOLO(MODEL_PATH)


def calc_position_status(
    cx: float,
    cy: float,
    image_w: int,
    image_h: int,
    tolerance_percent: int = 10
) -> str:
    """
    增强版位置判断：
    1. 先比较标签中心和图像中心
    2. 超出容忍范围时，返回偏左 / 偏右 / 偏上 / 偏下
    3. 如果模型已经判定为 offset，但中心点又刚好比较接近中心，
       那就用“偏差更大的那个方向”作为兜底结果
    """
    center_x = image_w / 2.0
    center_y = image_h / 2.0

    dx = cx - center_x
    dy = cy - center_y

    tol_x = image_w * tolerance_percent / 100.0
    tol_y = image_h * tolerance_percent / 100.0

    # 是否超出容忍范围
    out_x = abs(dx) > tol_x
    out_y = abs(dy) > tol_y

    # 归一化偏差，避免宽高不同导致比较不公平
    nx = dx / max(image_w, 1)
    ny = dy / max(image_h, 1)

    # 情况1：已经明显偏出中心区域
    if out_x or out_y:
        if abs(nx) >= abs(ny):
            return "偏右" if dx > 0 else "偏左"
        else:
            return "偏下" if dy > 0 else "偏上"

    # 情况2：模型说它是 offset，但中心点又没有明显超界
    # 这时仍然给一个“最可能方向”，避免只返回“偏移”
    if abs(dx) < 1 and abs(dy) < 1:
        return "偏移"

    if abs(nx) >= abs(ny):
        return "偏右" if dx > 0 else "偏左"
    else:
        return "偏下" if dy > 0 else "偏上"


def infer_image(image_path: str, position_tolerance: int = 10) -> Dict[str, Any]:
    model = get_model()

    results = model.predict(
        source=image_path,
        conf=CONF_THRES,
        save=False,
        verbose=False
    )

    with Image.open(image_path) as img:
        image_w, image_h = img.size

    if not results or results[0].boxes is None or len(results[0].boxes) == 0:
        return {
            "status": "NG",
            "className": "no_detection",
            "defectType": "未检测到标签",
            "confidence": 0.0,
            "positionStatus": "未知",
            "positionX": 0,
            "positionY": 0,
            "bbox": [0, 0, 0, 0],
            "hasDefect": True,
        }

    boxes = results[0].boxes

    # 取置信度最高的那个框
    best_i = max(range(len(boxes)), key=lambda i: float(boxes.conf[i].item()))

    cls_id = int(boxes.cls[best_i].item())
    confidence = float(boxes.conf[best_i].item())
    x1, y1, x2, y2 = boxes.xyxy[best_i].tolist()

    # 兼容 model.names 是 dict 或 list 的情况
    if isinstance(model.names, dict):
        class_name = model.names.get(cls_id, str(cls_id))
    elif isinstance(model.names, list):
        class_name = model.names[cls_id] if 0 <= cls_id < len(model.names) else str(cls_id)
    else:
        class_name = str(cls_id)

    cx = (x1 + x2) / 2.0
    cy = (y1 + y2) / 2.0

    mapped = CLASS_MAP.get(
        class_name,
        {
            "status": "NG",
            "defectType": class_name,
            "hasDefect": True,
        }
    )

    # 位置状态：
    # 只有 offset 类更强调“偏移方向”
    # 其他缺陷默认仍视为“正常位置”
    if class_name == "label_offset":
        position_status = calc_position_status(
            cx=cx,
            cy=cy,
            image_w=image_w,
            image_h=image_h,
            tolerance_percent=position_tolerance
        )
    else:
        position_status = "正常"

    return {
        "status": mapped["status"],
        "className": class_name,
        "defectType": mapped["defectType"],
        "confidence": round(confidence, 4),
        "positionStatus": position_status,
        "positionX": int(round(cx)),
        "positionY": int(round(cy)),
        "bbox": [round(x1, 2), round(y1, 2), round(x2, 2), round(y2, 2)],
        "hasDefect": mapped["hasDefect"],
    }