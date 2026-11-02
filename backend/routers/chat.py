from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, Request
from pydantic import BaseModel, Field

from auth.auth_middleware import require_firebase_user
from core.parameter_sanitizer import sanitize_simulation_parameters
from core.rate_limiter import LIMIT_CHAT, limiter
from core.usage_limiter import check_and_increment_daily_usage
from services.llm import tutor_chat

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    dependencies=[Depends(require_firebase_user)],
)


class ChatRequest(BaseModel):
    user_prompt: str = Field(..., min_length=1, max_length=2000, description="User question or instruction")
    topic: str = Field(..., min_length=1, max_length=150, description="STEM topic")
    variables: List[str] = Field(default_factory=list, max_length=50, description="Variable symbols")
    image_path: Optional[str] = Field(default=None, max_length=500)
    current_params: Optional[Dict[str, Any]] = None
    template_id: Optional[str] = Field(default=None, max_length=100)


class ChatResponse(BaseModel):
    response: str = Field(description="AI explanation or tutor response")
    parameter_updates: Dict[str, Any] = Field(
        default_factory=dict, description="Sanitized simulation parameter updates"
    )
    update_type: str = Field(default="none", description="Simulation control type")
    degraded: bool = Field(default=False)


@router.post("/ask", response_model=ChatResponse)
@limiter.limit(LIMIT_CHAT)
async def chat_ask(
    request: Request,
    req: ChatRequest,
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    await check_and_increment_daily_usage(user_id=request.state.user["uid"])
    result = await tutor_chat(
        message=req.user_prompt,
        topic=req.topic,
        variables=req.variables,
        current_params=req.current_params,
        template_id=req.template_id,
    )

    # Server-side clamp any parameter updates for simulation stability
    sanitized_updates = {}
    if result.parameter_updates:
        sanitized_updates = sanitize_simulation_parameters(result.parameter_updates)

    return ChatResponse(
        response=result.response,
        parameter_updates=sanitized_updates,
        update_type=result.update_type,
        degraded=result.degraded,
    )
