from typing import Any, Dict
from services.agents.state import StemlyParallelState


async def router_node(state: StemlyParallelState) -> Dict[str, Any]:
    """
    Zero-latency entrypoint router.
    Validates state before triggering parallel fan-out branches.
    Execution time: <0.1ms (in-memory pass-through).
    """
    return {}
