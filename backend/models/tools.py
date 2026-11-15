"""
Pydantic Schemas and Tool Definitions for Groq Function Calling.
Covers:
- update_simulation: Mutates interactive canvas parameters with explanation and visual cue.
- suggest_followups: Generates exactly 3 context-aware student follow-up questions.
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator


class UpdateSimulationArgs(BaseModel):
    """Arguments for the update_simulation tool."""
    parameters: Dict[str, Any] = Field(
        ...,
        description="Key-value pairs of simulation parameter updates (e.g. speed, angle, gravity)",
    )
    explanation: Optional[str] = Field(
        default="",
        description="Pedagogical explanation for why these parameters are being adjusted",
    )
    visual_cue: Optional[str] = Field(
        default="",
        description="Visual cue for the interactive canvas (e.g. 'watch the apex', 'observe deceleration')",
    )

    @field_validator("parameters")
    @classmethod
    def validate_parameters(cls, v: Any) -> Dict[str, Any]:
        if not isinstance(v, dict):
            raise ValueError("parameters must be a dictionary of key-value pairs")
        return v


class SuggestFollowupsArgs(BaseModel):
    """Arguments for the suggest_followups tool."""
    questions: List[str] = Field(
        ...,
        min_length=1,
        max_length=5,
        description="List of concise, pedagogical one-tap follow-up questions",
    )

    @field_validator("questions")
    @classmethod
    def clean_questions(cls, v: List[str]) -> List[str]:
        cleaned = [q.strip() for q in v if isinstance(q, str) and q.strip()]
        if not cleaned:
            raise ValueError("questions must contain at least one valid question string")
        return cleaned[:3]  # Clamp to top 3 questions


# ------------------------------------------------------------------------------
# Groq / OpenAI Compatible Tool Definitions
# ------------------------------------------------------------------------------

TUTOR_TOOLS: List[Dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "update_simulation",
            "description": (
                "Update the interactive STEM canvas simulation parameters and visual cues based on user discussion."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "parameters": {
                        "type": "object",
                        "description": "Key-value pairs of numeric parameters to change (e.g. {'speed': 25.0, 'angle': 45.0})",
                    },
                    "explanation": {
                        "type": "string",
                        "description": "Brief explanation of why the simulation values are adjusted",
                    },
                    "visual_cue": {
                        "type": "string",
                        "description": "Visual focus cue for the user (e.g. 'watch peak height', 'observe velocity')",
                    },
                },
                "required": ["parameters"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "suggest_followups",
            "description": "Suggest exactly 3 context-aware, educational follow-up questions for the student.",
            "parameters": {
                "type": "object",
                "properties": {
                    "questions": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of 3 concise follow-up question chips",
                    },
                },
                "required": ["questions"],
            },
        },
    },
]
