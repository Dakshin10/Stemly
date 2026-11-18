from typing import Annotated, Any, Dict, List, Optional, TypedDict
from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages


class StemlyParallelState(TypedDict):
    """
    Shared state container for the parallel LangGraph multi-agent pipeline.
    Workers write to isolated keys to guarantee zero merge conflicts during concurrent fan-out.
    """
    # 1. Inputs & Multi-turn Conversation
    messages: Annotated[List[AnyMessage], add_messages]
    raw_query: str
    topic: str
    student_id: str
    template_id: Optional[str]
    current_params: Dict[str, Any]
    variables: List[str]

    # 2. Parallel Worker Isolated Outputs
    math_result: Optional[Dict[str, Any]]         # From Math Engine (exact values, equations)
    sim_action: Optional[Dict[str, Any]]          # From Sim Controller (sliders, PhET url, visual cue)
    pedagogical_cues: Optional[Dict[str, Any]]    # From Misconception Assessor (scaffolding tier, hints)

    # 3. Fan-In Synthesizer Outputs
    final_response: str
    parameter_updates: Dict[str, Any]
    suggested_followups: List[str]
    degraded: bool
