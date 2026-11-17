import copy
import json
import os
import re
from typing import Any, Dict, List, Optional

TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), "..", "templates", "visualiser")

TOPIC_TO_TEMPLATE = {
    "projectile motion": "projectile_motion.json",
    "projectile_motion": "projectile_motion.json",
    "projectile": "projectile_motion.json",
    "free fall": "free_fall.json",
    "free_fall": "free_fall.json",
    "shm": "shm.json",
    "simple harmonic motion": "shm.json",
    "harmonic": "shm.json",
    "optics": "optics.json",
    "optic": "optics.json",
    "lens": "optics.json",
    "mirror": "optics.json",
    "kinematics": "kinematics.json",
    "kinematics_1d": "kinematics.json",
    "motion in 1d": "kinematics.json",
    "atom": "atom.json",
    "atom_bohr": "atom.json",
    "bohr atom": "atom.json",
    "chemistry": "atom.json",
    "graph": "graphs.json",
    "graph_quadratic": "graphs.json",
    "quadratic": "graphs.json",
    "equation": "equation_plotter.json",
    "equation_plotter": "equation_plotter.json",
    "plot": "equation_plotter.json",
    "mechanics": "mechanics_2d.json",
    "mechanics_2d": "mechanics_2d.json",
    "force": "mechanics_2d.json",
    "forces": "mechanics_2d.json",
    "friction": "mechanics_2d.json",
    "newton": "mechanics_2d.json",
    "incline": "inclined_plane.json",
    "inclined plane": "inclined_plane.json",
    "inclined_plane": "inclined_plane.json",
    "ramp": "inclined_plane.json",
    "pulley": "pulley.json",
    "atwood": "pulley.json",
    "atwood machine": "pulley.json",
    "collision": "collision.json",
    "collisions": "collision.json",
    "momentum": "collision.json",
    "declarative_physics": "mechanics_2d.json",
}

# In-memory template cache to eliminate blocking disk I/O in async request handlers
_TEMPLATE_CACHE: Dict[str, Dict[str, Any]] = {}


def _load_template_cached(filename: str) -> Optional[Dict[str, Any]]:
    if filename in _TEMPLATE_CACHE:
        return copy.deepcopy(_TEMPLATE_CACHE[filename])

    path = os.path.join(TEMPLATES_DIR, filename)
    if not os.path.exists(path):
        return None

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            _TEMPLATE_CACHE[filename] = data
            return copy.deepcopy(data)
    except Exception:
        return None


async def get_template_by_topic(topic: str) -> Optional[Dict[str, Any]]:
    if not topic:
        return None

    key = topic.strip().lower()
    filename = TOPIC_TO_TEMPLATE.get(key)
    if not filename:
        return None

    return _load_template_cached(filename)


def fill_template_defaults(template: Dict[str, Any], variables: Optional[List[str]] = None) -> Dict[str, Any]:
    filled = copy.deepcopy(template)
    if not variables:
        return filled

    parameters = filled.get("parameters", {})
    metadata = filled.setdefault("metadata", {})

    for var in variables:
        if not isinstance(var, str) or "=" not in var:
            continue
        parts = var.split("=", 1)
        raw_key = parts[0].strip().lower()
        raw_val = parts[1].strip()

        # Handle equation / formula parameter
        if raw_key in {"equation", "formula", "eq", "fn", "y"} and filled.get("template_id") == "equation_plotter":
            from services.llm.text import clean_raw_equation
            metadata["equation"] = clean_raw_equation(raw_val)
            continue

        # Try to parse numerical variable value
        num_match = re.search(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", raw_val)
        if not num_match:
            continue

        val_num = float(num_match.group(0))

        # Match against template parameters (case-insensitive)
        for p_name, p_dict in parameters.items():
            if p_name.lower() == raw_key and isinstance(p_dict, dict):
                p_min = p_dict.get("min", -1e9)
                p_max = p_dict.get("max", 1e9)
                p_dict["value"] = max(p_min, min(p_max, val_num))
                break

    return filled
