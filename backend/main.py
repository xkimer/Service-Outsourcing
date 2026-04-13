import os
from threading import Lock

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from fastapi.staticfiles import StaticFiles

from app.database import engine, Base
from app.routers import detection, display

app = FastAPI(
    title="Detection Backend",
    version="1.0",
    description="Industrial Detection Backend Service"
)

# 确保静态目录存在
os.makedirs("static/uploads", exist_ok=True)

# 初始化数据库
Base.metadata.create_all(bind=engine)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")

# 路由
app.include_router(detection.router)
app.include_router(display.router)

# =========================
# GPIO <-> App 桥接状态
# =========================
bridge_lock = Lock()
bridge_state = {
    "pending": False,   # shell 是否检测到一次新的传感器触发
    "result": "idle"    # idle / busy / ok / ng
}

@app.get("/")
def root():
    return {"message": "Detection backend is running"}

# =========================
# 桥接接口：给板子 shell 用
# =========================

@app.post("/bridge/trigger", response_class=PlainTextResponse)
def bridge_trigger():
    """
    shell 检测到传感器触发后调用
    """
    with bridge_lock:
        bridge_state["pending"] = True
        bridge_state["result"] = "busy"
    return "ok"

@app.get("/bridge/next_trigger", response_class=PlainTextResponse)
def bridge_next_trigger():
    """
    App 轮询这个接口：
    - 有新触发 -> 返回 "1"，并清掉 pending
    - 没有新触发 -> 返回 "0"
    """
    with bridge_lock:
        if bridge_state["pending"]:
            bridge_state["pending"] = False
            return "1"
        return "0"

@app.post("/bridge/result", response_class=PlainTextResponse)
def bridge_result(value: str = Query(...)):
    """
    App 检测完成后回传结果：
    value = ok / ng / busy / idle
    """
    value = value.strip().lower()
    if value not in ("ok", "ng", "busy", "idle"):
        return "invalid"

    with bridge_lock:
        bridge_state["result"] = value
    return "ok"

@app.get("/bridge/result", response_class=PlainTextResponse)
def bridge_get_result():
    """
    shell 轮询这个接口，根据结果控制 LED
    """
    with bridge_lock:
        return bridge_state["result"]

@app.post("/bridge/reset", response_class=PlainTextResponse)
def bridge_reset():
    """
    手动复位桥接状态，调试时很有用
    """
    with bridge_lock:
        bridge_state["pending"] = False
        bridge_state["result"] = "idle"
    return "ok"