from copy import deepcopy
from threading import Lock
from typing import Any, Dict

from fastapi import APIRouter, Body, Query

router = APIRouter(
    prefix="/api/v1/display",
    tags=["display"]
)

display_lock = Lock()

# 按 device_id 保存每台设备的最新显示状态
LATEST_DISPLAY_STATE: Dict[str, Dict[str, Any]] = {}


@router.post("/update")
async def update_display(payload: Dict[str, Any] = Body(default={})):
    print("收到 display/update 请求：", payload)

    backend_payload = payload.get("backend_payload", {}) or {}
    device_id = (
        payload.get("device_id")
        or backend_payload.get("device_id")
        or "board01"
    )

    with display_lock:
        LATEST_DISPLAY_STATE[device_id] = deepcopy(payload)

    return {
        "code": 0,
        "message": "display update success",
        "device_id": device_id
    }


@router.get("/latest")
def get_latest_display(device_id: str = Query(..., description="设备ID")):
    with display_lock:
        data = deepcopy(LATEST_DISPLAY_STATE.get(device_id))

    if not data:
        return {
            "code": 0,
            "message": "no display data yet",
            "data": {
                "device_id": device_id,
                "result": "idle",
                "image_url": "",
                "image_name": "",
                "image_b64": "",
                "ts": 0
            }
        }

    return {
        "code": 0,
        "message": "success",
        "data": data
    }