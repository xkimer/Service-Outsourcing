from datetime import date
from typing import Optional, List

import os
import shutil

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Query, Request
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..ml_service import infer_image
from ..database import get_db
from ..utils import (
    generate_filename,
    load_config,
    save_config
)

router = APIRouter()

UPLOAD_DIR = "static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


# =========================
# 工具函数：前端字段适配
# =========================
def build_image_url(request: Request, image_path: str) -> str:
    if not image_path:
        return ""

    if image_path.startswith("http://") or image_path.startswith("https://"):
        return image_path

    base_url = str(request.base_url).rstrip("/")
    return f"{base_url}/{image_path.lstrip('/')}"


def pick_preset_model(record) -> str:
    return record.batch_id or record.device_id or "能效标签"


def format_current_record(record, request: Request):
    return {
        "status": record.status,
        "ocrText": record.class_name,
        "presetModel": pick_preset_model(record),
        "isMatch": record.status == "OK",
        "defectType": record.defect_type,
        "positionStatus": record.position_status,
        "positionX": record.position_x,
        "positionY": record.position_y,
        "timestamp": record.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        "imageUrl": build_image_url(request, record.image_path),
    }


def format_recent_record(record):
    model = pick_preset_model(record)
    return {
        "timestamp": record.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        "presetModel": model,
        "productModel": model,
        "ocrText": record.class_name,
        "status": record.status,
        "defectType": record.defect_type,
        "positionStatus": record.position_status,
    }


def format_history_record(record, request: Request):
    model = pick_preset_model(record)
    return {
        "timestamp": record.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        "presetModel": model,
        "productModel": model,
        "ocrText": record.class_name,
        "status": record.status,
        "defectType": record.defect_type,
        "positionStatus": record.position_status,
        "imageUrl": build_image_url(request, record.image_path),
    }


def format_statistics_record(record):
    return {
        "timestamp": record.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        "presetModel": pick_preset_model(record),
        "status": record.status,
        "hasDefect": record.has_defect,
        "defectType": record.defect_type if record.has_defect else "",
        "positionStatus": record.position_status,
    }


# =========================
# 文件上传接口（保留）
# =========================
@router.post("/api/v1/detect/upload_image")
async def upload_image(file: UploadFile = File(...)):
    allowed_ext = {".jpg", ".jpeg", ".png"}
    ext = os.path.splitext(file.filename)[1].lower()

    if ext not in allowed_ext:
        raise HTTPException(status_code=400, detail=f"Invalid image format: {ext}")

    filename = generate_filename(file.filename)
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return {
        "image_name": filename,
        "image_url": f"/static/uploads/{filename}"
    }


# =========================
# 手动写记录接口（改成新版真实字段）
# =========================
@router.post("/api/v1/detect/record", response_model=schemas.DetectionRecordOut)
def create_record(record: schemas.DetectionRecordCreate, db: Session = Depends(get_db)):
    return crud.create_detection_record(db, record)


# =========================
# 旧历史接口（保留）
# =========================
@router.get("/api/v1/detect/history", response_model=schemas.HistoryResponse)
def get_legacy_history(
    page: int = 1,
    size: int = 10,
    device_id: str = None,
    batch_id: str = None,
    db: Session = Depends(get_db)
):
    skip = (page - 1) * size
    return crud.get_history_with_stats(db, skip, size, device_id, batch_id)


# =========================
# 前端新要求接口
# =========================

# 1. 获取当前检测结果
@router.get("/api/current", response_model=schemas.CurrentResultResponse)
def get_current(request: Request, db: Session = Depends(get_db)):
    record = crud.get_latest_record(db)
    if not record:
        return {
            "status": "NG",
            "ocrText": "",
            "presetModel": "",
            "isMatch": False,
            "defectType": "无",
            "positionStatus": "正常",
            "positionX": 0,
            "positionY": 0,
            "timestamp": "",
            "imageUrl": "",
        }
    return format_current_record(record, request)


# 2. 获取最近10条记录
@router.get("/api/recent", response_model=List[schemas.RecentRecordResponse])
def get_recent(
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db)
):
    records = crud.get_recent_records(db, limit=limit)
    return [format_recent_record(r) for r in records]


# 3. 历史分页
@router.get("/api/history", response_model=schemas.FrontendHistoryResponse)
def get_history(
    request: Request,
    page: int = Query(1, ge=1),
    pageSize: int = Query(25, ge=1, le=100),
    startDate: Optional[date] = Query(None),
    endDate: Optional[date] = Query(None),
    statusFilter: str = Query("ALL"),
    db: Session = Depends(get_db)
):
    total, records = crud.get_frontend_history(
        db=db,
        page=page,
        page_size=pageSize,
        start_date=startDate,
        end_date=endDate,
        status_filter=statusFilter
    )

    return {
        "total": total,
        "records": [format_history_record(r, request) for r in records]
    }


# 4. 获取配置
@router.get("/api/config", response_model=schemas.ConfigResponse)
def get_config():
    return load_config()


# 5. 保存配置
@router.post("/api/config", response_model=schemas.SaveConfigResponse)
def post_config(config: schemas.ConfigResponse):
    save_config(config.model_dump())
    return {
        "success": True,
        "message": "配置保存成功"
    }


# 6. 获取统计数据
@router.get("/api/statistics", response_model=List[schemas.StatisticsItemResponse])
@router.get("/api/statistic", response_model=List[schemas.StatisticsItemResponse])
def get_statistics(
    startDate: Optional[date] = Query(None),
    endDate: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    records = crud.get_statistics_records(
        db=db,
        start_date=startDate,
        end_date=endDate
    )
    return [format_statistics_record(r) for r in records]


# 7. 上传图片 + 推理 + 自动入库
@router.post("/api/v1/detect/analyze_image", response_model=schemas.MlAnalyzeResponse)
async def analyze_image(
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    allowed_ext = {".jpg", ".jpeg", ".png"}
    ext = os.path.splitext(file.filename)[1].lower()

    if ext not in allowed_ext:
        raise HTTPException(status_code=400, detail=f"Invalid image format: {ext}")

    filename = generate_filename(file.filename)
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    config = load_config()
    position_tolerance = config.get("positionTolerance", 10)

    result = infer_image(
        image_path=file_path,
        position_tolerance=position_tolerance
    )

    db_record = crud.save_analyze_result(
        db=db,
        image_path=f"/static/uploads/{filename}",
        analyze_result=result
    )

    result["imageUrl"] = build_image_url(request, db_record.image_path)
    return result