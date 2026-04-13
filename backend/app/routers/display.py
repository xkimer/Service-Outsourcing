from fastapi import APIRouter, Body
from typing import Any, Dict
from datetime import datetime

router = APIRouter(
    prefix="/api/v1/display",
    tags=["display"]
)

@router.post("/update")
async def update_display(payload: Dict[str, Any] = Body(default={})):
    print("收到 display/update 请求：", payload)

    return {
        "code": 0,
        "message": "display update success",
        "data": payload,
        "time": datetime.now().isoformat()
    }