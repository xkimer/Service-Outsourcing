from datetime import datetime, date, time, timedelta
from sqlalchemy.orm import Session

from . import models, schemas


def create_detection_record(db: Session, record: schemas.DetectionRecordCreate):
    db_record = models.DetectionRecord(
        device_id=record.device_id,
        batch_id=record.batch_id,
        image_path=record.image_path,

        class_name=record.class_name,
        defect_type=record.defect_type,
        confidence=record.confidence,
        status=record.status,

        position_status=record.position_status,
        position_x=record.position_x,
        position_y=record.position_y,

        bbox_x1=record.bbox_x1,
        bbox_y1=record.bbox_y1,
        bbox_x2=record.bbox_x2,
        bbox_y2=record.bbox_y2,

        has_defect=record.has_defect,
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record


def save_analyze_result(
    db: Session,
    image_path: str,
    analyze_result: dict,
    device_id: str = "",
    batch_id: str = "",
):
    bbox = analyze_result.get("bbox", [0, 0, 0, 0])
    if len(bbox) != 4:
        bbox = [0, 0, 0, 0]

    record = schemas.DetectionRecordCreate(
        device_id=device_id,
        batch_id=batch_id,
        image_path=image_path,

        class_name=analyze_result.get("className", "unknown"),
        defect_type=analyze_result.get("defectType", "未知"),
        confidence=float(analyze_result.get("confidence", 0.0)),
        status=analyze_result.get("status", "NG"),

        position_status=analyze_result.get("positionStatus", "未知"),
        position_x=int(analyze_result.get("positionX", 0)),
        position_y=int(analyze_result.get("positionY", 0)),

        bbox_x1=float(bbox[0]),
        bbox_y1=float(bbox[1]),
        bbox_x2=float(bbox[2]),
        bbox_y2=float(bbox[3]),

        has_defect=bool(analyze_result.get("hasDefect", True)),
    )

    return create_detection_record(db, record)


# =========================
# 历史 + 统计
# =========================
def get_history_with_stats(db: Session, skip=0, limit=100, device_id=None, batch_id=None):
    query = db.query(models.DetectionRecord)

    if device_id:
        query = query.filter(models.DetectionRecord.device_id == device_id)
    if batch_id:
        query = query.filter(models.DetectionRecord.batch_id == batch_id)

    total = query.count()
    items = query.order_by(models.DetectionRecord.created_at.desc()).offset(skip).limit(limit).all()

    all_items = query.all()
    total_scanned = len(all_items)
    pass_count = sum(1 for item in all_items if item.status == "OK")
    fail_count = total_scanned - pass_count
    pass_rate = round(pass_count / total_scanned, 3) if total_scanned else 0.0

    return {
        "stats": {
            "total_scanned": total_scanned,
            "fail_count": fail_count,
            "pass_count": pass_count,
            "pass_rate": pass_rate
        },
        "records": items,
        "total": total
    }


# =========================
# 前端兼容接口：查询函数
# =========================
def get_latest_record(db: Session):
    return db.query(models.DetectionRecord).order_by(models.DetectionRecord.created_at.desc()).first()


def get_recent_records(db: Session, limit: int = 10):
    return (
        db.query(models.DetectionRecord)
        .order_by(models.DetectionRecord.created_at.desc())
        .limit(limit)
        .all()
    )


def build_filtered_query(
    db: Session,
    start_date: date | None = None,
    end_date: date | None = None,
    status_filter: str = "ALL"
):
    query = db.query(models.DetectionRecord)

    if start_date:
        start_dt = datetime.combine(start_date, time.min)
        query = query.filter(models.DetectionRecord.created_at >= start_dt)

    if end_date:
        end_dt = datetime.combine(end_date + timedelta(days=1), time.min)
        query = query.filter(models.DetectionRecord.created_at < end_dt)

    status_filter = (status_filter or "ALL").upper()

    if status_filter == "OK":
        query = query.filter(models.DetectionRecord.status == "OK")
    elif status_filter == "NG":
        query = query.filter(models.DetectionRecord.status == "NG")

    return query


def get_frontend_history(
    db: Session,
    page: int = 1,
    page_size: int = 25,
    start_date: date | None = None,
    end_date: date | None = None,
    status_filter: str = "ALL"
):
    query = build_filtered_query(db, start_date, end_date, status_filter)

    total = query.count()
    records = (
        query.order_by(models.DetectionRecord.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return total, records


def get_statistics_records(
    db: Session,
    start_date: date | None = None,
    end_date: date | None = None
):
    query = build_filtered_query(db, start_date, end_date, "ALL")

    return (
        query.order_by(models.DetectionRecord.created_at.asc())
        .all()
    )