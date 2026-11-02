"""
Groq LLM Unified Layer for Stemly.
Exposes vision and text APIs, models, client lifecycles, and fallback mechanisms.
"""

from .client import get_text_client, get_vision_client, llm_clients
from .text import (
    NotesResponse,
    ParameterUpdateResponse,
    QuizQuestion,
    QuizResponse,
    TutorChatResponse,
    VisualiserChatResponse,
    follow_up_notes,
    generate_notes,
    generate_quiz,
    parse_param_update,
    process_visualiser_chat_llm,
    tutor_chat,
)
from .vision import TopicAnalysis, analyze_image

__all__ = [
    "llm_clients",
    "get_vision_client",
    "get_text_client",
    "analyze_image",
    "TopicAnalysis",
    "generate_notes",
    "follow_up_notes",
    "generate_quiz",
    "parse_param_update",
    "tutor_chat",
    "process_visualiser_chat_llm",
    "NotesResponse",
    "QuizResponse",
    "QuizQuestion",
    "ParameterUpdateResponse",
    "TutorChatResponse",
    "VisualiserChatResponse",
]
