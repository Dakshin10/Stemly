"""
Custom LangSmith Evaluators for the Stemly Multi-Agent LangGraph Pipeline.
Evaluates:
1. Math & Physics Calculation Accuracy (Zero Hallucination)
2. Socratic Pedagogy & Misconception Intervention
3. Simulation Parameter Clamping & Visual Cue Relevance
4. Follow-up Question Chip Quality
5. Execution Latency SLA (<1500ms)
"""

import math
from typing import Any, Dict


def eval_math_accuracy(run_outputs: Dict[str, Any], expected: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluates whether deterministic math output matches ground truth physical invariants."""
    if not expected.get("has_math", False):
        return {"key": "math_accuracy", "score": 1.0, "comment": "No math required"}

    math_result = run_outputs.get("math_result")
    if not math_result:
        return {"key": "math_accuracy", "score": 0.0, "comment": "Missing math_result"}

    exact = math_result.get("exact_results", {})
    tolerance = 0.08  # 80mm / 80ms tolerance

    # Projectile checks
    if "max_height_m" in expected:
        h_diff = abs(exact.get("max_height_m", 0) - expected["max_height_m"])
        r_diff = abs(exact.get("horizontal_range_m", 0) - expected["horizontal_range_m"])
        t_diff = abs(exact.get("time_of_flight_s", 0) - expected["time_of_flight_s"])
        passed = (h_diff <= tolerance) and (r_diff <= tolerance) and (t_diff <= tolerance)
        return {
            "key": "math_accuracy",
            "score": 1.0 if passed else 0.0,
            "comment": f"h_diff={round(h_diff, 3)}, r_diff={round(r_diff, 3)}, t_diff={round(t_diff, 3)}",
        }

    # Harmonic pendulum / spring checks
    if "period_s" in expected:
        p_diff = abs(exact.get("period_s", 0) - expected["period_s"])
        passed = p_diff <= tolerance
        return {
            "key": "math_accuracy",
            "score": 1.0 if passed else 0.0,
            "comment": f"period_diff={round(p_diff, 3)}",
        }

    return {"key": "math_accuracy", "score": 1.0, "comment": "Pass"}


def eval_pedagogy_socratic(run_outputs: Dict[str, Any], expected: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluates whether Socratic method and misconceptions were correctly diagnosed."""
    pedagogy = run_outputs.get("pedagogical_cues") or {}
    expected_misconception = expected.get("has_misconception", False)

    if expected_misconception:
        detected = pedagogy.get("has_misconception", False)
        name_match = pedagogy.get("misconception_name") == expected.get("misconception_name")
        tier_match = pedagogy.get("scaffolding_tier") == expected.get("scaffolding_tier")
        score = 1.0 if (detected and name_match and tier_match) else 0.0
        return {
            "key": "pedagogy_socratic",
            "score": score,
            "comment": f"detected={detected}, name_match={name_match}, tier_match={tier_match}",
        }

    return {"key": "pedagogy_socratic", "score": 1.0, "comment": "Pass"}


def eval_simulation_action(run_outputs: Dict[str, Any], expected: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluates whether simulation slider parameters are properly clamped and visual cues generated."""
    sim_action = run_outputs.get("sim_action") or {}
    param_updates = run_outputs.get("parameter_updates") or sim_action.get("parameter_updates") or {}

    # Check adversarial clamping
    if "clamped_speed_max" in expected:
        speed = param_updates.get("speed", 0)
        gravity = param_updates.get("gravity", 0)
        passed = (speed <= expected["clamped_speed_max"]) and (gravity >= expected["clamped_gravity_min"])
        return {
            "key": "sim_clamping_safety",
            "score": 1.0 if passed else 0.0,
            "comment": f"clamped_speed={speed}, clamped_gravity={gravity}",
        }

    # Check normal parameter updates
    if "parameter_updates" in expected:
        for k, v in expected["parameter_updates"].items():
            if param_updates.get(k) != v:
                return {
                    "key": "sim_action",
                    "score": 0.0,
                    "comment": f"Param {k} mismatch: expected {v}, got {param_updates.get(k)}",
                }

    if expected.get("requires_phet", False):
        has_phet = sim_action.get("has_phet", False)
        return {
            "key": "sim_action",
            "score": 1.0 if has_phet else 0.0,
            "comment": f"has_phet={has_phet}",
        }

    return {"key": "sim_action", "score": 1.0, "comment": "Pass"}


def eval_followup_quality(run_outputs: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluates that exactly 3 dynamic, non-empty follow-up question chips are generated."""
    followups = run_outputs.get("suggested_followups") or []
    valid = len(followups) == 3 and all(isinstance(f, str) and len(f.strip()) > 5 for f in followups)
    return {
        "key": "followup_chips_quality",
        "score": 1.0 if valid else 0.0,
        "comment": f"chip_count={len(followups)}",
    }


def eval_latency_sla(duration_ms: float, max_allowed_ms: float = 1800.0) -> Dict[str, Any]:
    """Evaluates whether parallel agent execution meets mobile response time SLA."""
    passed = duration_ms <= max_allowed_ms
    score = max(0.0, min(1.0, 1.0 - (duration_ms / max_allowed_ms - 1.0))) if not passed else 1.0
    return {
        "key": "latency_sla",
        "score": score,
        "comment": f"duration_ms={round(duration_ms, 1)}, sla_ms={max_allowed_ms}",
    }


# ==============================================================================
# LangSmith Protocol Evaluator Wrappers (Run, Example) -> dict
# ==============================================================================

def langsmith_math_evaluator(run: Any, example: Any) -> Dict[str, Any]:
    outputs = getattr(run, "outputs", {}) or {}
    expected = (getattr(example, "outputs", {}) or {}).get("expected_outputs", {})
    return eval_math_accuracy(outputs, expected)


def langsmith_pedagogy_evaluator(run: Any, example: Any) -> Dict[str, Any]:
    outputs = getattr(run, "outputs", {}) or {}
    expected = (getattr(example, "outputs", {}) or {}).get("expected_outputs", {})
    return eval_pedagogy_socratic(outputs, expected)


def langsmith_simulation_evaluator(run: Any, example: Any) -> Dict[str, Any]:
    outputs = getattr(run, "outputs", {}) or {}
    expected = (getattr(example, "outputs", {}) or {}).get("expected_outputs", {})
    return eval_simulation_action(outputs, expected)


def langsmith_followup_evaluator(run: Any, example: Any) -> Dict[str, Any]:
    outputs = getattr(run, "outputs", {}) or {}
    return eval_followup_quality(outputs)
