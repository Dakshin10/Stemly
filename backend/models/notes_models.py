from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from services.llm.text import NotesResponse


class NotesGenerateRequest(BaseModel):
    topic: str = Field(..., min_length=1, max_length=150, description="STEM topic name")
    variables: List[str] = Field(default_factory=list, max_length=50, description="List of variable symbols")
    image_path: Optional[str] = Field(default=None, max_length=500)
    ocr_text: Optional[str] = Field(default=None, max_length=5000)


class NotesFollowUpRequest(BaseModel):
    topic: str = Field(..., min_length=1, max_length=150)
    previous_notes: Dict[str, Any] = Field(default_factory=dict)
    user_prompt: str = Field(..., min_length=1, max_length=2000, description="Follow-up question")


class NotesEnvelopeResponse(BaseModel):
    notes: NotesResponse
