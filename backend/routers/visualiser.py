from typing import Optional

from fastapi import APIRouter, Depends, Header, Query, Request
from pydantic import BaseModel, Field

from auth.auth_middleware import require_firebase_user
from core.parameter_sanitizer import sanitize_simulation_parameters
from core.rate_limiter import LIMIT_CHAT, LIMIT_STANDARD, limiter
from core.usage_limiter import check_and_increment_daily_usage
from database.visualiser_model import (
    get_visualiser_entries_paginated,
    save_visualiser_entry,
)
from models.visualiser_models import (
    VisualiserChatRequest,
    VisualiserChatResponse,
    VisualiserSaveRequest,
    VisualiserStateResponse,
    VisualiserStatesListResponse,
)
from services.llm import process_visualiser_chat_llm

router = APIRouter(
    prefix="/visualiser",
    tags=["Visualiser"],
    dependencies=[Depends(require_firebase_user)],
)


class ImageGenRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=500, description="Image generation prompt")


class ImageGenResponse(BaseModel):
    image_url: Optional[str] = None
    status: str = Field(default="Diagram generation is currently disabled.")


@router.post("/states", response_model=VisualiserStateResponse)
@limiter.limit(LIMIT_STANDARD)
async def save_visualiser_state(request: Request, payload: VisualiserSaveRequest):
    user_id = request.state.user["uid"]
    clamped_params = sanitize_simulation_parameters(payload.parameters)
    entry_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=payload.template_id,
        parameters=clamped_params,
    )
    return VisualiserStateResponse(id=entry_id)


@router.get("/states", response_model=VisualiserStatesListResponse)
@limiter.limit(LIMIT_STANDARD)
async def list_visualiser_states(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    skip: int = Query(0, ge=0),
):
    user_id = request.state.user["uid"]
    entries, total = await get_visualiser_entries_paginated(user_id, limit=limit, skip=skip)
    has_more = total > (skip + len(entries))
    return VisualiserStatesListResponse(
        items=entries,
        history=entries,
        total=total,
        limit=limit,
        skip=skip,
        has_more=has_more,
    )


@router.post("/generate-image", response_model=ImageGenResponse)
@limiter.limit(LIMIT_STANDARD)
async def create_visualisation_image(request: Request, payload: ImageGenRequest):
    """
    Educational diagram generation endpoint placeholder.
    """
    return ImageGenResponse(image_url=None, status="Diagram generation is currently disabled.")


@router.post("/chat", response_model=VisualiserChatResponse)
@limiter.limit(LIMIT_CHAT)
async def visualiser_chat(
    request: Request,
    payload: VisualiserChatRequest,
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    """
    AI Chat for the visualiser.
    Supports both visualization parameter changes and concept explanations.
    """
    user_id = request.state.user["uid"]
    await check_and_increment_daily_usage(user_id=user_id)

    history = [{"text": m.text, "isUser": m.isUser} for m in (payload.history or [])]

    result = await process_visualiser_chat_llm(
        user_message=payload.message,
        topic=payload.topic,
        parameters=payload.parameters,
        chat_history=history,
    )

    # Server-side parameter clamping for stability
    sanitized_updates = {}
    if result.parameter_updates:
        sanitized_updates = sanitize_simulation_parameters(result.parameter_updates)

    return VisualiserChatResponse(
        response=result.response,
        parameter_updates=sanitized_updates,
        update_type=result.update_type,
        degraded=result.degraded,
    )
