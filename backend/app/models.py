from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from datetime import datetime
from .database import Base
from zoneinfo import ZoneInfo
from datetime import datetime


class DetectionRecord(Base):
    __tablename__ = "detection_records"

    id = Column(Integer, primary_key=True, index=True)

    # 先保留，方便兼容前端展示/后续扩展
    device_id = Column(String(64), nullable=True, default="", index=True)
    batch_id = Column(String(64), nullable=True, default="", index=True)

    image_path = Column(String(255), nullable=False)

    # 真实 ML 输出字段
    class_name = Column(String(64), nullable=False, index=True)
    defect_type = Column(String(64), nullable=False)
    confidence = Column(Float, nullable=False)
    status = Column(String(16), nullable=False, index=True)  # OK / NG

    position_status = Column(String(32), nullable=False, default="正常")
    position_x = Column(Integer, nullable=False, default=0)
    position_y = Column(Integer, nullable=False, default=0)

    bbox_x1 = Column(Float, nullable=False, default=0.0)
    bbox_y1 = Column(Float, nullable=False, default=0.0)
    bbox_x2 = Column(Float, nullable=False, default=0.0)
    bbox_y2 = Column(Float, nullable=False, default=0.0)

    has_defect = Column(Boolean, nullable=False, default=False)

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(ZoneInfo("Asia/Shanghai")).replace(tzinfo=None),
        nullable=False,
        index=True
    )