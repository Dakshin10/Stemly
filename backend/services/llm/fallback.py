"""
Local deterministic fallback engine for STEM topic classification and emergency fallbacks.
Preserves the existing regex/keyword matching logic to guarantee system resilience.
"""

import re
from typing import Dict, List, Tuple

# Keyword mapping dictionary for rule-based topic detection
TOPIC_KEYWORDS: Dict[str, List[str]] = {
    "Optics": [
        "optic",
        "lens",
        "mirror",
        "refraction",
        "reflection",
        "light",
        "ray",
        "focal",
        "prism",
        "convex",
        "concave",
    ],
    "Kinematics": ["velocity", "acceleration", "motion", "displacement", "kinematic", "speed", "trajectory", "time"],
    "Electricity": [
        "current",
        "voltage",
        "resistance",
        "ohm",
        "circuit",
        "capacitor",
        "electric",
        "resistor",
        "battery",
    ],
    "Magnetism": ["magnetic", "magnet", "field", "solenoid", "electromagnet", "lorentz"],
    "Thermodynamics": ["heat", "temperature", "entropy", "thermal", "thermodynamic", "gas law", "pressure"],
    "Waves": ["wave", "frequency", "wavelength", "amplitude", "oscillation", "sound", "doppler"],
    "Mechanics": ["force", "newton", "momentum", "torque", "equilibrium", "friction", "gravity", "mass"],
    "Calculus": ["derivative", "integral", "differentiation", "integration", "limit", "dx", "dy"],
    "Algebra": ["equation", "polynomial", "quadratic", "linear", "variable", "solve for x"],
    "Geometry": ["triangle", "circle", "angle", "polygon", "theorem", "euclidean"],
    "Chemistry": ["reaction", "element", "compound", "molecule", "bond", "acid", "base", "ph", "atom"],
    "Biology": ["cell", "organism", "gene", "dna", "protein", "photosynthesis", "mitochondria"],
    "Projectile Motion": ["projectile", "cannon", "parabola", "range", "trajectory", "2d motion", "launch angle"],
}

# Static curated emergency quiz dataset for zero-connectivity situations
SAMPLE_QUIZZES = {
    "Projectile Motion": {
        "topic": "Projectile Motion",
        "difficulty": "mixed",
        "questions": [
            {
                "question": "At what launch angle (neglecting air resistance) is the horizontal range of a projectile maximized?",
                "options": ["30°", "45°", "60°", "90°"],
                "correct_index": 1,
                "explanation": "Range R = (v^2 * sin(2*theta)) / g. The term sin(2*theta) attains its maximum value of 1 when 2*theta = 90°, so theta = 45°.",
                "takeaway": "45° yields maximum range in vacuum.",
            },
            {
                "question": "At the peak of a projectile's trajectory, what is its vertical velocity?",
                "options": ["Zero", "Equal to initial velocity", "Maximum", "Depends on mass"],
                "correct_index": 0,
                "explanation": "At the apex of the parabolic trajectory, the vertical component of velocity (v_y) reverses direction, momentarily becoming 0.",
                "takeaway": "Vertical velocity is zero at maximum height.",
            },
            {
                "question": "Which acceleration component remains constant throughout ideal projectile motion?",
                "options": [
                    "Horizontal acceleration",
                    "Vertical acceleration (-g)",
                    "Radial acceleration",
                    "Both horizontal (0) and vertical (-g)",
                ],
                "correct_index": 3,
                "explanation": "Horizontal acceleration is zero (constant velocity), and vertical acceleration is constant downward (-9.8 m/s²).",
                "takeaway": "a_x = 0 and a_y = -g are constant.",
            },
        ],
    },
    "Optics": {
        "topic": "Optics",
        "difficulty": "mixed",
        "questions": [
            {
                "question": "Which phenomenon causes a pencil dipped in a glass of water to appear bent?",
                "options": ["Reflection", "Refraction", "Diffraction", "Polarization"],
                "correct_index": 1,
                "explanation": "Refraction is the bending of light as it passes between media of different optical densities due to changes in light speed.",
                "takeaway": "Refraction bends light between media.",
            },
            {
                "question": "A convex lens always produces which type of image when the object is beyond 2F?",
                "options": [
                    "Virtual and erect",
                    "Real, inverted, and diminished",
                    "Real, inverted, and magnified",
                    "Virtual and magnified",
                ],
                "correct_index": 1,
                "explanation": "For an object placed beyond 2F of a convex lens, the image formed is real, inverted, and smaller than the object.",
                "takeaway": "Beyond 2F produces real, inverted, diminished images.",
            },
        ],
    },
    "Mechanics": {
        "topic": "Mechanics",
        "difficulty": "mixed",
        "questions": [
            {
                "question": "A 10 kg object accelerates at 2 m/s². What is the net force acting on it?",
                "options": ["5 N", "10 N", "15 N", "20 N"],
                "correct_index": 3,
                "explanation": "According to Newton's Second Law, F = m * a = 10 kg * 2 m/s² = 20 N.",
                "takeaway": "F = m * a",
            },
            {
                "question": "Which of Newton's laws explains why recoil occurs when firing a weapon?",
                "options": ["First Law", "Second Law", "Third Law", "Law of Gravitation"],
                "correct_index": 2,
                "explanation": "Newton's Third Law states that every action produces an equal and opposite reaction.",
                "takeaway": "Equal and opposite reaction.",
            },
        ],
    },
    "General": {
        "topic": "General Science",
        "difficulty": "mixed",
        "questions": [
            {
                "question": "What is the primary gas found in Earth's atmosphere?",
                "options": ["Oxygen", "Carbon Dioxide", "Nitrogen", "Argon"],
                "correct_index": 2,
                "explanation": "Nitrogen makes up approximately 78% of Earth's atmosphere by volume.",
                "takeaway": "Nitrogen comprises ~78% of air.",
            },
            {
                "question": "According to the first law of thermodynamics, energy cannot be:",
                "options": ["Transformed", "Created or destroyed", "Stored", "Measured"],
                "correct_index": 1,
                "explanation": "Energy is conserved; it can only change form.",
                "takeaway": "Energy is conserved.",
            },
        ],
    },
}


def detect_topic_from_keywords(text: str) -> Tuple[str, List[str]]:
    """
    Deterministic rule-based fallback topic detector using whole-word regex matching.
    Returns (topic_name, variables_list).
    """
    if not text:
        return "General Science", []

    text_lower = text.lower()

    # Priority check for specific multi-word topics to prevent misclassification
    priority_topics = ["Projectile Motion"]
    for topic in priority_topics:
        if topic in TOPIC_KEYWORDS:
            for kw in TOPIC_KEYWORDS[topic]:
                if re.search(r"\b" + re.escape(kw) + r"\b", text_lower):
                    return topic, ["v0", "theta", "g", "range"]

    # General keywords search
    best_topic = "General Science"
    max_matches = 0
    detected_vars: List[str] = []

    for topic, keywords in TOPIC_KEYWORDS.items():
        matches = 0
        for kw in keywords:
            if re.search(r"\b" + re.escape(kw) + r"\b", text_lower):
                matches += 1
        if matches > max_matches:
            max_matches = matches
            best_topic = topic

    if best_topic == "Optics":
        detected_vars = ["f", "do", "di", "m"]
    elif best_topic in ["Kinematics", "Mechanics"]:
        detected_vars = ["v", "a", "t", "m", "F"]
    elif best_topic == "Electricity":
        detected_vars = ["V", "I", "R", "P"]

    return best_topic, detected_vars


def get_fallback_quiz(topic: str, count: int = 5) -> dict:
    """Return static emergency quiz questions for a topic."""
    normalized_topic = topic.strip()
    quiz = SAMPLE_QUIZZES.get(normalized_topic)

    if not quiz:
        # Search by keyword match
        topic_lower = normalized_topic.lower()
        for k, v in SAMPLE_QUIZZES.items():
            if k.lower() in topic_lower or topic_lower in k.lower():
                quiz = v
                break

    if not quiz:
        quiz = SAMPLE_QUIZZES["General"]

    questions = quiz["questions"][:count]
    return {
        "topic": quiz["topic"],
        "difficulty": quiz["difficulty"],
        "questions": questions,
        "degraded": True,
    }
