"""
Simulation Parameter Sanitization and Clamping.
Guarantees numeric safety by clamping physics parameters (gravity, angle, mass, velocity)
server-side, preventing numerical overflow, negative mass, or physics engine instability.
"""

import math
from typing import Any, Dict

# Range definitions: (min_value, max_value)
PARAMETER_BOUNDS: Dict[str, tuple[float, float]] = {
    # Mechanics / Kinematics
    "g": (0.1, 50.0),
    "gravity": (0.1, 50.0),
    "v": (0.0, 500.0),
    "v0": (0.0, 500.0),
    "velocity": (0.0, 500.0),
    "speed": (0.0, 500.0),
    "angle": (-360.0, 360.0),
    "theta": (-360.0, 360.0),
    "launch_angle": (0.0, 90.0),
    "mass": (0.001, 10000.0),
    "m": (0.001, 10000.0),
    "friction": (0.0, 5.0),
    "mu": (0.0, 5.0),
    "air_resistance": (0.0, 5.0),
    "height": (0.0, 2000.0),
    "h": (0.0, 2000.0),
    "y0": (0.0, 2000.0),
    "x0": (-2000.0, 2000.0),
    "time": (0.0, 3600.0),
    "t": (0.0, 3600.0),
    "time_step": (0.001, 1.0),
    "dt": (0.001, 1.0),
    # Springs / SHM
    "k": (0.1, 5000.0),
    "spring_constant": (0.1, 5000.0),
    "amplitude": (0.01, 500.0),
    "damping": (0.0, 10.0),
    # Optics
    "f": (-1000.0, 1000.0),
    "focal_length": (-1000.0, 1000.0),
    "do": (0.1, 1000.0),
    "di": (-1000.0, 1000.0),
    "ho": (0.1, 500.0),
    "hi": (-500.0, 500.0),
    # Electricity & Magnetism
    "r": (0.01, 1_000_000.0),
    "resistance": (0.01, 1_000_000.0),
    "voltage": (-1000.0, 1000.0),
    "v_source": (-1000.0, 1000.0),
    "current": (-100.0, 100.0),
    "i": (-100.0, 100.0),
    "charge": (-100.0, 100.0),
    "q": (-100.0, 100.0),
    # Plotter
    "min_x": (-10000.0, 0.0),
    "max_x": (0.0, 10000.0),
    "min_y": (-10000.0, 0.0),
    "max_y": (0.0, 10000.0),
    "a": (-1000.0, 1000.0),
    "b": (-1000.0, 1000.0),
    "c": (-1000.0, 1000.0),
    "u": (-500.0, 500.0),
    "t_max": (0.1, 100.0),
    "h_o": (0.1, 500.0),
    # Chemistry / Atom
    "protons": (1.0, 118.0),
    "neutrons": (0.0, 180.0),
}


def clamp_parameter(param_name: str, value: Any) -> Any:
    """
    Clamps a single numeric parameter according to its physical constraints.
    Rejects NaN or Infinite values.
    """
    if not isinstance(value, (int, float)):
        return value

    # Prevent NaN and Inf
    if math.isnan(value) or math.isinf(value):
        return 0.0

    clean_key = param_name.strip().lower()

    if clean_key in PARAMETER_BOUNDS:
        min_v, max_v = PARAMETER_BOUNDS[clean_key]
        return max(min_v, min(float(value), max_v))

    # Generic numeric sanity cap
    return max(-1_000_000.0, min(float(value), 1_000_000.0))


def sanitize_simulation_parameters(parameters: Dict[str, Any]) -> Dict[str, Any]:
    """
    Recursively validates and clamps all parameters in a simulation parameters dict.
    """
    if not isinstance(parameters, dict):
        return {}

    sanitized: Dict[str, Any] = {}
    for key, val in parameters.items():
        if isinstance(val, dict):
            # Might be structured like {"value": 20, "min": 0, "max": 100}
            if "value" in val and isinstance(val["value"], (int, float)):
                clamped_val = clamp_parameter(key, val["value"])
                val_copy = dict(val)
                val_copy["value"] = clamped_val
                sanitized[key] = val_copy
            else:
                sanitized[key] = sanitize_simulation_parameters(val)
        elif isinstance(val, (int, float)):
            sanitized[key] = clamp_parameter(key, val)
        else:
            sanitized[key] = val

    return sanitized
