from typing import Any, Dict
from services.agents.sim_controller import resolve_simulation_action
from services.agents.state import StemlyParallelState


async def worker_sim_node(state: StemlyParallelState) -> Dict[str, Any]:
    """
    Worker B (Parallel Node):
    In-memory simulation catalog lookup and slider parameter bound clamping.
    Executes concurrently with Math and Pedagogy workers in <0.5ms.
    """
    query = state.get("raw_query", "")
    topic = state.get("topic", "")
    current_params = state.get("current_params", {})
    template_id = state.get("template_id")

    sim_action = resolve_simulation_action(
        query=query,
        topic=topic,
        current_params=current_params,
        template_id=template_id,
    )
    return {"sim_action": sim_action}
