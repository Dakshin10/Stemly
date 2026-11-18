"""
Stemly Unified AI & Multi-Agent Architecture.
Single source of truth for:
1. Parallel LangGraph Agent Orchestration (orchestration.py)
2. Specialized Engine Nodes (nodes/)
3. Foundation Vision, Generation, Caching, and Connection Pooling (client.py, text.py, vision.py)
"""

from .audio import transcribe_audio
from .client import get_text_client, get_vision_client, llm_clients
from .math_solver import solve_deterministic_stem_math
from .orchestration import (
    build_orchestrator,
    get_orchestrator,
    run_orchestrated_tutor,
    stream_orchestrated_tutor,
)
from .pedagogy_assessor import assess_student_pedagogy
from .sim_controller import resolve_simulation_action
from .state import StemlyParallelState
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

# Backward compatibility aliases
get_stemly_tutor_graph = get_orchestrator
create_stemly_tutor_graph = build_orchestrator
run_agent_tutor = run_orchestrated_tutor
stream_agent_tutor = stream_orchestrated_tutor

__all__ = [
    # Orchestrator
    "build_orchestrator",
    "get_orchestrator",
    "run_orchestrated_tutor",
    "stream_orchestrated_tutor",
    "get_stemly_tutor_graph",
    "create_stemly_tutor_graph",
    "run_agent_tutor",
    "stream_agent_tutor",
    "StemlyParallelState",
    # Specialized Engines
    "solve_deterministic_stem_math",
    "resolve_simulation_action",
    "assess_student_pedagogy",
    # Foundation
    "llm_clients",
    "get_text_client",
    "get_vision_client",
    "analyze_image",
    "TopicAnalysis",
    "transcribe_audio",
    "generate_notes",
    "follow_up_notes",
    "generate_quiz",
    "detect_or_resolve_equation_plotter",
    "generate_sandbox_simulation",
    "clean_raw_equation",
    "quick_detect_equation",
    "parse_param_update",
    "tutor_chat",
    "stream_tutor_chat",
    "process_visualiser_chat_llm",
    "make_equation_plotter_template",
    "EquationDetectionResponse",
    "SandboxGenerationResponse",
    "QuizResponse",
    "QuizQuestion",
    "NotesResponse",
    "ParameterUpdateResponse",
    "TutorChatResponse",
    "VisualiserChatResponse",
]
