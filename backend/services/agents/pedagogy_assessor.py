import re
from typing import Any, Dict


COMMON_MISCONCEPTIONS = [
    {
        "pattern": r"(?:heavy|heavier|mass|weight|\d+\s*kg|\d+\s*g\b).*?(?:fall|drop|accelerat).*?(?:fast|first|quick)",
        "name": "Free Fall Mass Independence",
        "misconception": "Belief that heavier objects accelerate faster under gravity.",
        "socratic_strategy": "Ask the student to recall Galileo's leaning tower thought experiment or consider the equation a = F/m = (mg)/m = g.",
    },
    {
        "pattern": r"(?:accel|acceleration).*?(?:0|zero).*?(?:peak|top|apex|height|throw)|(?:accel|acceleration).*?(?:peak|top|apex|height|throw).*?(?:0|zero)|(?:peak|top|apex|height|throw).*?(?:accel|acceleration).*?(?:0|zero)",
        "name": "Kinematics Peak Acceleration",
        "misconception": "Confusing zero instantaneous vertical velocity with zero acceleration.",
        "socratic_strategy": "Ask what would happen if gravity turned off at the apex: would the projectile stay floating?",
    },
    {
        "pattern": r"(?:force).*?(?:keep|maintain|sustain|continue|needed to).*?(?:mov|speed|motion|velocity)|(?:without\s+force).*?(?:stop|slow)",
        "name": "Newton's First Law / Inertia",
        "misconception": "Aristotelian view that a continuous net force is needed to sustain constant motion.",
        "socratic_strategy": "Guide the student with Newton's 1st law: In a frictionless vacuum, does an object slow down?",
    },
    {
        "pattern": r"centrifugal.*?(?:push|force|real|outward|outside)",
        "name": "Centripetal vs Centrifugal",
        "misconception": "Treating centrifugal force as an actual Newtonian interaction force in inertial frames.",
        "socratic_strategy": "Ask what physical object is applying that outward push, and contrast with centripetal inward tension.",
    },
]


def assess_student_pedagogy(query: str, topic: str = "") -> Dict[str, Any]:
    """
    Analyzes student query for known STEM conceptual pitfalls and selects targeted Socratic scaffolding.
    """
    cleaned = query.lower()

    detected_misconception = None
    strategy = "Use step-by-step guided questions. Do not give the raw numeric solution immediately."

    for item in COMMON_MISCONCEPTIONS:
        if re.search(item["pattern"], cleaned):
            detected_misconception = item
            strategy = item["socratic_strategy"]
            break

    # Determine scaffolding tier
    if detected_misconception:
        tier = "misconception_intervention"
    elif any(w in cleaned for w in ["what is", "explain", "why", "how does"]):
        tier = "conceptual_intuition"
    elif any(w in cleaned for w in ["calculate", "find", "solve", "what would be"]):
        tier = "guided_problem_solving"
    else:
        tier = "exploratory_dialogue"

    return {
        "scaffolding_tier": tier,
        "has_misconception": detected_misconception is not None,
        "misconception_name": detected_misconception["name"] if detected_misconception else None,
        "socratic_strategy": strategy,
        "directive": (
            f"Pedagogical Scaffolding Tier: {tier.upper()}.\n"
            f"Strategy: {strategy}\n"
            "Enforce Socratic method: Ask one thought-provoking leading question to prompt the student to verify their intuition."
        ),
    }
