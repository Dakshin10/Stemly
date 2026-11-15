"""
Standardized Event Envelope and Data Models for Streaming Protocol v2.
Contract: {v: 1, id: str, seq: int, type: str, data: dict}
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class MetaEventData(BaseModel):
    request_id: str
    session_id: str
    model: str
    created_at: int


class TokenEventData(BaseModel):
    delta: str


class ParametersEventData(BaseModel):
    updates: Dict[str, Any]


class FollowupsEventData(BaseModel):
    suggestions: List[str]


class ErrorEventData(BaseModel):
    code: str
    message: str
    retryable: bool


class UsageEventData(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    latency_ms: float
    ttft_ms: float


class DoneEventData(BaseModel):
    finish_reason: str


class StreamEventEnvelope(BaseModel):
    v: int = Field(default=1, description="Protocol version")
    id: str = Field(..., description="Unique message or frame identifier")
    seq: int = Field(..., ge=0, description="Monotonically increasing sequence index")
    type: str = Field(..., description="Event type: meta|token|parameters|followups|error|usage|done")
    data: Dict[str, Any] = Field(default_factory=dict, description="Typed payload")

    def to_sse(self) -> str:
        """Serializes envelope to SSE data frame format."""
        import json
        payload = self.model_dump()
        # Backward-compatible convenience aliases at root
        if self.type == "token":
            payload["content"] = self.data.get("delta", "")
        elif self.type == "parameters":
            payload["updates"] = self.data.get("updates", {})
        elif self.type == "followups":
            payload["suggestions"] = self.data.get("suggestions", [])
        return f"data: {json.dumps(payload)}\n\n"
