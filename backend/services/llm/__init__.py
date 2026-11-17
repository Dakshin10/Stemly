"""
Groq LLM Unified Layer for Stemly.
Exposes vision and text APIs, models, client lifecycles, and fallback mechanisms.
"""

from .client import get_text_client, get_vision_client, llm_clients
from .text import (
    EquationDetectionResponse,
    NotesResponse,
    ParameterUpdateResponse,
    QuizQuestion,
    QuizResponse,
    SandboxGenerationResponse,
    TutorChatResponse,
    VisualiserChatResponse,
    clean_raw_equation,
    detect_or_resolve_equation_plotter,
    follow_up_notes,
    generate_notes,
    generate_quiz,
    generate_sandbox_simulation,
    make_equation_plotter_template,
    parse_param_update,
    process_visualiser_chat_llm,
    quick_detect_equation,
    stream_tutor_chat,
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
    "stream_tutor_chat",
    "process_visualiser_chat_llm",
    "detect_or_resolve_equation_plotter",
    "generate_sandbox_simulation",
    "clean_raw_equation",
    "quick_detect_equation",
    "make_equation_plotter_template",
    "EquationDetectionResponse",
    "SandboxGenerationResponse",
    "NotesResponse",
    "QuizResponse",
    "QuizQuestion",
    "ParameterUpdateResponse",
    "TutorChatResponse",
    "VisualiserChatResponse",
]
