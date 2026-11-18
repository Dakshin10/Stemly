from typing import Any, Dict
from services.agents.pedagogy_assessor import assess_student_pedagogy
from services.agents.state import StemlyParallelState


async def worker_pedagogy_node(state: StemlyParallelState) -> Dict[str, Any]:
    """
    Worker C (Parallel Node):
    Analyzes student input against pre-compiled STEM misconception patterns.
    Selects optimal Socratic scaffolding tier in <0.2ms.
    """
    query = state.get("raw_query", "")
    topic = state.get("topic", "")
    pedagogy = assess_student_pedagogy(query=query, topic=topic)
    return {"pedagogical_cues": pedagogy}
