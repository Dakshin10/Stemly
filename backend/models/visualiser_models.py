from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class VisualiserSaveRequest(BaseModel):
    template_id: str = Field(..., min_length=1, max_length=100, description="ID of the visualiser template to save")
    parameters: Dict[str, Any] = Field(
        default_factory=dict,
        description="User-customised parameters for the template",
    )


class VisualiserStateResponse(BaseModel):
    id: str = Field(description="Saved entry ID")


class VisualiserStatesListResponse(BaseModel):
    items: List[Dict[str, Any]] = Field(default_factory=list)
    history: List[Dict[str, Any]] = Field(default_factory=list)
    total: int = Field(default=0, description="Total records count")
    limit: int = Field(default=20, description="Page size limit")
    skip: int = Field(default=0, description="Number of skipped records")
    has_more: bool = Field(default=False, description="True if more records exist")


class VisualiserGenerateRequest(BaseModel):
    topic: str = Field(..., min_length=1, max_length=150, description="Topic or concept to visualize")
    variables: Optional[List[str]] = Field(default_factory=list, max_length=50)
    user_id: Optional[str] = Field(default=None, max_length=128)


class VisualiserGenerateResponse(BaseModel):
    status: str = Field(default="success")
    template: Dict[str, Any] = Field(default_factory=dict)
    history_id: str = Field(default="")


class VisualiserUpdateRequest(BaseModel):
    template_id: str = Field(..., min_length=1, max_length=100)
    parameters: Dict[str, Any] = Field(default_factory=dict)
    user_prompt: Optional[str] = Field(default=None, max_length=2000)
    user_id: Optional[str] = Field(default=None, max_length=128)
    history_id: Optional[str] = Field(default=None, max_length=100)


class VisualiserUpdateResponse(BaseModel):
    template_id: str
    history_id: str
    parameters: Dict[str, Any]
    ai_updates: Dict[str, Any] = Field(default_factory=dict)
    ai_response: str = ""


class ChatMessageItem(BaseModel):
    text: str = Field(..., max_length=2000)
    isUser: bool


class VisualiserChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    topic: str = Field(..., min_length=1, max_length=150)
    parameters: Dict[str, Any] = Field(default_factory=dict)
    history: Optional[List[ChatMessageItem]] = Field(default_factory=list, max_length=50)


class VisualiserChatResponse(BaseModel):
    response: str
    parameter_updates: Dict[str, Any] = Field(default_factory=dict)
    update_type: str = "none"
    degraded: bool = False
