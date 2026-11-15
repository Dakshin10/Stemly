from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, File, Form, Header, Query, Request, UploadFile
from pydantic import BaseModel, Field

from auth.auth_middleware import require_firebase_user
from core.rate_limiter import LIMIT_STANDARD, LIMIT_VISION, limiter
from core.usage_limiter import check_and_increment_daily_usage
from database.history_model import (
    get_scan_by_content_hash,
    get_user_history_paginated,
    save_scan_history,
)
from services.llm import analyze_image
from services.storage import save_scan_image

router = APIRouter(
    dependencies=[Depends(require_firebase_user)],
    tags=["Scan"],
)


class ScanUploadResponse(BaseModel):
    status: str = Field(description="Upload status")
    topic: str = Field(description="Detected STEM topic")
    variables: List[str] = Field(default_factory=list, description="Variables extracted from scan")
    structured_variables: List[Dict[str, Any]] = Field(
        default_factory=list, description="Strongly typed physics variables"
    )
    target_question: Optional[str] = Field(default=None, description="Primary unknown or question to solve")
    latex_formula: Optional[str] = Field(default=None, description="Governing LaTeX equation")
    image_path: str = Field(description="Relative path to stored image")
    history_id: str = Field(description="Database record identifier")
    degraded: bool = Field(default=False, description="True if local fallback engine was used")
    deduped: bool = Field(default=False, description="True if previous identical scan was reused")


class ScanHistoryResponse(BaseModel):
    history: List[Dict[str, Any]] = Field(default_factory=list, description="List of scan history items")
    total: int = Field(default=0, description="Total number of scan records")
    limit: int = Field(default=20, description="Page limit")
    skip: int = Field(default=0, description="Number of skipped items")
    has_more: bool = Field(default=False, description="True if more items are available")


class ScanPingResponse(BaseModel):
    message: str


@router.post("/upload", response_model=ScanUploadResponse)
@limiter.limit(LIMIT_VISION)
async def upload_scan(
    request: Request,
    file: UploadFile = File(...),
    ocr_text: str = Form("", max_length=5000),
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    user_id = request.state.user["uid"]

    # 1. Validate file (magic bytes, 5MB limit, 4096px bounds, decompression bomb, strip EXIF, compute hash)
    saved_path, clean_bytes, content_hash = await save_scan_image(file)

    # 2. Deduplication check: Has this user already scanned an identical image?
    existing_scan = await get_scan_by_content_hash(user_id=user_id, content_hash=content_hash)
    if existing_scan:
        return ScanUploadResponse(
            status="success",
            topic=existing_scan["topic"],
            variables=existing_scan.get("variables", []),
            structured_variables=existing_scan.get("structured_variables", []),
            target_question=existing_scan.get("target_question"),
            latex_formula=existing_scan.get("latex_formula"),
            image_path=existing_scan["image_path"],
            history_id=existing_scan["_id"],
            degraded=False,
            deduped=True,
        )

    # 3. Check and increment daily LLM usage counter before calling Groq Vision
    await check_and_increment_daily_usage(user_id=user_id)

    # 4. Analyze image using Groq Vision (prompt-injection safe: ocr_text kept in user role)
    analysis = await analyze_image(image_bytes=clean_bytes, ocr_text=ocr_text)

    # Convert Pydantic structured variables to dicts
    structured_vars_dicts = [
        v.model_dump() if hasattr(v, "model_dump") else v for v in analysis.structured_variables
    ]

    # 5. Save History with content_hash for future deduplication
    try:
        record_id = await save_scan_history(
            user_id=user_id,
            image_path=saved_path,
            topic=analysis.topic,
            variables=analysis.variables,
            content_hash=content_hash,
            structured_variables=structured_vars_dicts,
            target_question=analysis.target_question,
            latex_formula=analysis.latex_formula,
        )
    except Exception:
        record_id = "error-saving-history"

    return ScanUploadResponse(
        status="success",
        topic=analysis.topic,
        variables=analysis.variables,
        structured_variables=structured_vars_dicts,
        target_question=analysis.target_question,
        latex_formula=analysis.latex_formula,
        image_path=saved_path,
        history_id=record_id,
        degraded=analysis.degraded,
        deduped=False,
    )


@router.get("/history", response_model=ScanHistoryResponse)
@limiter.limit(LIMIT_STANDARD)
async def history(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    skip: int = Query(0, ge=0),
):
    user_id = request.state.user["uid"]
    history_items, total = await get_user_history_paginated(user_id, limit=limit, skip=skip)
    has_more = total > (skip + len(history_items))

    return ScanHistoryResponse(
        history=history_items,
        total=total,
        limit=limit,
        skip=skip,
        has_more=has_more,
    )


@router.get("/ping", response_model=ScanPingResponse)
@limiter.limit(LIMIT_STANDARD)
def ping(request: Request):
    return ScanPingResponse(message="Backend Connected Successfully!")
