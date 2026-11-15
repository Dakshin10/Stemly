import json
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from auth.auth_middleware import require_firebase_user
from core.idempotency import acquire_idempotency_key, complete_idempotency_key
from core.parameter_sanitizer import sanitize_simulation_parameters
from core.rate_limiter import LIMIT_CHAT, limiter
from core.usage_limiter import check_and_increment_daily_usage
from services.llm import stream_tutor_chat, tutor_chat

logger = logging.getLogger("stemly.routers.chat")

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    dependencies=[Depends(require_firebase_user)],
)


class ChatMessage(BaseModel):
    role: str = Field(default="user", description="'user' or 'assistant'")
    content: str = Field(..., description="Message text content")


class ChatRequest(BaseModel):
    user_prompt: str = Field(..., min_length=1, max_length=2000, description="User question or instruction")
    topic: str = Field(..., min_length=1, max_length=150, description="STEM topic")
    variables: List[str] = Field(default_factory=list, max_length=50, description="Variable symbols")
    image_path: Optional[str] = Field(default=None, max_length=500)
    current_params: Optional[Dict[str, Any]] = None
    template_id: Optional[str] = Field(default=None, max_length=100)
    history: List[ChatMessage] = Field(
        default_factory=list,
        max_length=20,
        description="Multi-turn conversation history for context memory",
    )


class ChatResponse(BaseModel):
    response: str = Field(description="AI explanation or tutor response")
    parameter_updates: Dict[str, Any] = Field(
        default_factory=dict, description="Sanitized simulation parameter updates"
    )
    update_type: str = Field(default="none", description="Simulation control type")
    suggested_followups: List[str] = Field(
        default_factory=list, description="3 dynamic one-tap follow-up question chips"
    )
    degraded: bool = Field(default=False)


@router.post("/ask", response_model=ChatResponse)
@limiter.limit(LIMIT_CHAT)
async def chat_ask(
    request: Request,
    req: ChatRequest,
    x_ai_api_key: Optional[str] = Header(None, alias="X-AI-API-Key"),
):
    """
    Synchronous full-turn AI STEM tutor response with simulation controls and follow-up chips.
    """
    await check_and_increment_daily_usage(user_id=request.state.user["uid"])

    # Convert Pydantic ChatMessages to dicts for multi-turn history
    history_dicts = [m.model_dump() for m in req.history]

    result = await tutor_chat(
        message=req.user_prompt,
        topic=req.topic,
        variables=req.variables,
        current_params=req.current_params,
        template_id=req.template_id,
        history=history_dicts,
    )

    # Server-side clamp any parameter updates for simulation stability
    sanitized_updates = {}
    if result.parameter_updates:
        sanitized_updates = sanitize_simulation_parameters(result.parameter_updates)

    return ChatResponse(
        response=result.response,
        parameter_updates=sanitized_updates,
        update_type=result.update_type,
        suggested_followups=result.suggested_followups,
        degraded=result.degraded,
    )


@router.post("/stream")
@limiter.limit(LIMIT_CHAT)
async def chat_stream(
    request: Request,
    req: ChatRequest,
    x_ai_api_key: Optional[str] = Header(None, alias="X-AI-API-Key"),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    x_session_id: Optional[str] = Header(None, alias="X-Session-ID"),
):
    """
    ChatGPT/Claude-grade Server-Sent Events (SSE) token-by-token streaming endpoint.
    Streaming Protocol v2 Envelope:
      {v: 1, id: str, seq: int, type: str, data: dict}
    Headers:
      Cache-Control: no-cache, Connection: keep-alive, X-Accel-Buffering: no, Content-Encoding: identity
    """
    user_id = request.state.user.get("uid", "anonymous")
    effective_idemp = idempotency_key or x_idempotency_key

    # Check and acquire idempotency reservation to prevent duplicate stream processing
    is_new, idemp_status, _ = acquire_idempotency_key(effective_idemp, user_id=user_id)
    if not is_new:
        if idemp_status == "in_flight":
            raise HTTPException(
                status_code=409,
                detail="A stream request with this Idempotency-Key is currently in flight.",
            )
        if idemp_status == "completed":
            raise HTTPException(
                status_code=409,
                detail="A stream request with this Idempotency-Key has already completed.",
            )

    await check_and_increment_daily_usage(user_id=user_id)

    history_dicts = [m.model_dump() for m in req.history]

    async def sse_event_generator():
        completed_cleanly = False
        try:
            async for envelope in stream_tutor_chat(
                message=req.user_prompt,
                topic=req.topic,
                variables=req.variables,
                current_params=req.current_params,
                template_id=req.template_id,
                history=history_dicts,
                session_id=x_session_id,
                is_disconnected_fn=request.is_disconnected,
            ):
                if await request.is_disconnected():
                    logger.info("Client disconnected from /chat/stream; aborting generator.")
                    break

                # Sanitize simulation parameters on the fly
                if envelope.type == "parameters" and "updates" in envelope.data:
                    envelope.data["updates"] = sanitize_simulation_parameters(envelope.data["updates"])

                if envelope.type == "done":
                    completed_cleanly = True

                yield envelope.to_sse()
        finally:
            if effective_idemp and completed_cleanly:
                complete_idempotency_key(
                    effective_idemp,
                    user_id=user_id,
                    payload={"status": "completed"},
                )

    return StreamingResponse(
        sse_event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
            "Content-Encoding": "identity",
        },
    )
