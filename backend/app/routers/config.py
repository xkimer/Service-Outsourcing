from copy import deepcopy
from typing import Any, Dict

from fastapi import APIRouter, Query

router = APIRouter(
    prefix="/api/v1/config",
    tags=["config"]
)

# 默认运行时配置
# 先把 sensitivity 写成 medium，别写“中”
# 因为你队友脚本后面会把它放进 X-Sensitivity 请求头里，
# 中文很容易触发 latin-1 编码问题
DEFAULT_RUNTIME_CONFIG: Dict[str, Any] = {
    "models": [],
    "positionTolerance": 10,
    "sensitivity": "medium",
    "lightCompensation": 0,
    "camera": {
        "exposure": 0,
        "resolution": "1280x720"
    }
}

# 简单的内存级设备配置表
# 现在先够用，后面再接数据库也行
DEVICE_CONFIGS: Dict[str, Dict[str, Any]] = {
    "board01": deepcopy(DEFAULT_RUNTIME_CONFIG)
}


@router.get("/current")
def get_current_config(device_id: str = Query(..., description="设备ID")):
    config = deepcopy(DEVICE_CONFIGS.get(device_id, DEFAULT_RUNTIME_CONFIG))
    config["device_id"] = device_id

    return {
        "code": 0,
        "message": "success",
        "data": config
    }