"""
Main Multi-Agent Orchestration Engine for Stemly.
Manages the parallel fan-out / fan-in StateGraph execution pipeline,
ensuring minimum latency, zero cold starts, and real-time SSE streaming.
"""

import json
import logging
from typing import Any, AsyncGenerator, Dict, Optional, cast

from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, StateGraph

from services.agents.nodes import (
    router_node,
    socratic_synthesizer_node,
    worker_math_node,
    worker_pedagogy_node,
    worker_sim_node,
)
from services.agents.state import StemlyParallelState

logger = logging.getLogger("stemly.agents.orchestration")

_ORCHESTRATOR_GRAPH = None


def build_orchestrator():
    """
    Constructs the high-throughput parallel StateGraph orchestrator.
    Parallel Fan-Out:
      router -> (worker_math, worker_sim, worker_pedagogy) concurrently.
    Fan-In Join:
      (worker_math, worker_sim, worker_pedagogy) -> synthesizer.
    """
    builder = StateGraph(cast(Any, StemlyParallelState))

    # 1. Register individual nodes
    builder.add_node("router", router_node)
    builder.add_node("worker_math", worker_math_node)
    builder.add_node("worker_sim", worker_sim_node)
    builder.add_node("worker_pedagogy", worker_pedagogy_node)
    builder.add_node("synthesizer", socratic_synthesizer_node)

    # 2. Set root entrypoint
    builder.set_entry_point("router")

    # 3. Parallel Fan-Out: Concurrent asynchronous execution
    builder.add_edge("router", "worker_math")
    builder.add_edge("router", "worker_sim")
    builder.add_edge("router", "worker_pedagogy")

    # 4. Fan-In Barrier: Synchronize all worker outputs before synthesis
    builder.add_edge("worker_math", "synthesizer")
    builder.add_edge("worker_sim", "synthesizer")
    builder.add_edge("worker_pedagogy", "synthesizer")

    # 5. Graph termination
    builder.add_edge("synthesizer", END)

    # Thread-safe memory checkpointer
    checkpointer = MemorySaver()
    return builder.compile(checkpointer=checkpointer)


def get_orchestrator():
    """
    Singleton getter for the compiled orchestrator graph.
    Compiles once at container startup to eliminate cold-start latency.
    """
    global _ORCHESTRATOR_GRAPH
    if _ORCHESTRATOR_GRAPH is None:
        _ORCHESTRATOR_GRAPH = build_orchestrator()
    return _ORCHESTRATOR_GRAPH


async def run_orchestrated_tutor(
    query: str,
    topic: str,
    student_id: str,
    template_id: Optional[str] = None,
    current_params: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Executes the full parallel agent pipeline asynchronously and returns structured outputs.
    """
    orchestrator = get_orchestrator()
    initial_state = {
        "raw_query": query,
        "topic": topic,
        "student_id": student_id,
        "template_id": template_id,
        "current_params": current_params or {},
        "messages": [{"role": "user", "content": query}],
        "variables": [],
    }

    config = {"configurable": {"thread_id": f"student_{student_id}"}}
    result = await orchestrator.ainvoke(initial_state, config=config)
    return result


async def stream_orchestrated_tutor(
    query: str,
    topic: str,
    student_id: str,
    template_id: Optional[str] = None,
    current_params: Optional[Dict[str, Any]] = None,
) -> AsyncGenerator[str, None]:
    """
    High-efficiency Server-Sent Events (SSE) streaming pipeline.
    Optimized to push simulation adjustments immediately upon worker resolution,
    then stream synthesizer tokens with zero buffering delay.
    """
    orchestrator = get_orchestrator()
    initial_state = {
        "raw_query": query,
        "topic": topic,
        "student_id": student_id,
        "template_id": template_id,
        "current_params": current_params or {},
        "messages": [{"role": "user", "content": query}],
        "variables": [],
    }

    config = {"configurable": {"thread_id": f"student_{student_id}"}}

    try:
        async for output in orchestrator.astream(initial_state, config=config, stream_mode="updates"):
            for node_name, node_state in output.items():
                # 1. Early push of simulation parameters
                if node_name == "worker_sim":
                    sim_action = node_state.get("sim_action", {})
                    if sim_action.get("parameter_updates") or sim_action.get("phet"):
                        yield f"data: {json.dumps({'type': 'sim_update', 'payload': sim_action})}\n\n"

                # 2. Push synthesized Socratic token chunk & followups
                elif node_name == "synthesizer":
                    final_text = node_state.get("final_response", "")
                    followups = node_state.get("suggested_followups", [])
                    degraded = node_state.get("degraded", False)

                    yield f"data: {json.dumps({'type': 'token', 'content': final_text})}\n\n"

                    meta_payload = {
                        "type": "meta",
                        "suggested_followups": followups,
                        "degraded": degraded,
                    }
                    yield f"data: {json.dumps(meta_payload)}\n\n"

        yield "data: [DONE]\n\n"

    except Exception as exc:
        logger.exception("Orchestration streaming exception: %s", exc)
        yield f"data: {json.dumps({'type': 'error', 'detail': str(exc)})}\n\n"
        yield "data: [DONE]\n\n"
