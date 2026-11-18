import logging
from typing import Any, Dict

from config import settings
from prompts.tutor_prompts import TUTOR_STREAM_SYSTEM_PROMPT
from services.agents.client import get_text_client
from services.agents.state import StemlyParallelState

logger = logging.getLogger("stemly.agents.nodes.synthesizer")


async def socratic_synthesizer_node(state: StemlyParallelState) -> Dict[str, Any]:
    """
    Fan-In Join Node:
    Synthesizes outputs from the 3 parallel workers into a cohesive Socratic tutor response.
    Optimized for minimum TTFT (Time-To-First-Token) by compressing context payloads.
    """
    query = state.get("raw_query", "")
    topic = state.get("topic", "")
    math_res = state.get("math_result")
    sim_action = state.get("sim_action") or {}
    pedagogy = state.get("pedagogical_cues") or {}

    param_updates = sim_action.get("parameter_updates", {})
    visual_cue = sim_action.get("visual_cue")

    # Build concise ground truth context to minimize input tokens
    ground_truth_blocks = []
    if math_res:
        ground_truth_blocks.append(
            f"VERIFIED PHYSICAL TRUTH: Formula $${math_res.get('formula_latex')}$$, Values: {math_res.get('exact_results')}"
        )
    if visual_cue:
        ground_truth_blocks.append(f"SIMULATION VISUAL CUE: {visual_cue}")

    pedagogy_directive = pedagogy.get("directive", "Guide step-by-step using the Socratic method.")

    system_instruction = (
        f"{TUTOR_STREAM_SYSTEM_PROMPT}\n"
        f"Topic: {topic}\n"
        f"Scaffolding: {pedagogy_directive}\n"
        + ("\n".join(ground_truth_blocks) + "\n" if ground_truth_blocks else "")
    )

    messages_payload = [
        {"role": "system", "content": system_instruction},
        {"role": "user", "content": query},
    ]

    response_text = ""
    degraded = False

    try:
        client = get_text_client()
        resp = await client.post(
            "/chat/completions",
            json={
                "model": settings.GROQ_TEXT_MODEL,
                "messages": messages_payload,
                "temperature": 0.4,
                "max_tokens": 800,
            },
        )
        if resp.status_code == 200:
            data = resp.json()
            response_text = data["choices"][0]["message"]["content"]
        else:
            logger.warning("Groq API returned %s; engaging grounded fallback", resp.status_code)
            degraded = True
    except Exception as exc:
        logger.warning("Synthesizer network exception: %s; engaging grounded fallback", exc)
        degraded = True

    # Immediate deterministic fallback if network is offline
    if not response_text:
        degraded = True
        if math_res:
            response_text = (
                f"Let's break down this calculation using physical principles.\n\n"
                f"For this motion, the governing relationship is given by:\n"
                f"$${math_res.get('formula_latex')}$$\n\n"
                f"From your input parameters: {math_res.get('verified_truth')}\n\n"
                f"{visual_cue or 'Observe the simulation canvas to see the trajectory.'}\n\n"
                f"What do you predict will happen if we change the launch angle?"
            )
        else:
            response_text = (
                f"That's a great question about **{topic}**! "
                f"Let's think about the governing forces at play. "
                f"{visual_cue or 'Test your intuition with the simulation sliders.'} "
                f"Which variable do you think has the greatest impact here?"
            )

    suggested_followups = [
        f"How does changing angle affect {topic}?",
        "Show me the step-by-step derivation",
        "What happens in zero gravity?",
    ]

    return {
        "final_response": response_text,
        "parameter_updates": param_updates,
        "suggested_followups": suggested_followups,
        "degraded": degraded,
    }
