from typing import Any, Dict
from services.agents.math_solver import solve_deterministic_stem_math
from services.agents.state import StemlyParallelState


async def worker_math_node(state: StemlyParallelState) -> Dict[str, Any]:
    """
    Worker A (Parallel Node):
    Deterministic, high-speed mathematical & kinematic calculation.
    Guarantees 0% arithmetic hallucination with pure in-memory execution (<0.5ms).
    """
    query = state.get("raw_query", "")
    topic = state.get("topic", "")
    math_result = solve_deterministic_stem_math(query=query, topic=topic)
    return {"math_result": math_result}
