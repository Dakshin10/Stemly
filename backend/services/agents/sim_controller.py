import re
from typing import Any, Dict, Optional
from urllib.parse import urlparse
from core.parameter_sanitizer import sanitize_simulation_parameters
from services.phet_service import phet_service

RE_PARAM_SPEED = re.compile(r"(?:speed|velocity|v0?)\s*(?:to|is|at|=|:)?\s*([+-]?[0-9]+(?:\.[0-9]+)?)")
RE_PARAM_ANGLE = re.compile(r"(?:angle|theta)\s*(?:to|is|at|=|:)?\s*([+-]?[0-9]+(?:\.[0-9]+)?)")
RE_PARAM_GRAVITY = re.compile(r"(?:gravity|g\b)\s*(?:to|is|at|=|:)?\s*([+-]?[0-9]+(?:\.[0-9]+)?)")
RE_PARAM_MASS = re.compile(r"(?:mass|m\b)\s*(?:to|is|at|=|:)?\s*([+-]?[0-9]+(?:\.[0-9]+)?)")


def is_allowed_phet_url(url: Optional[str]) -> bool:
    """Validates that a URL is a secure, official PhET interactive simulation."""
    if not url or not isinstance(url, str):
        return False
    try:
        parsed = urlparse(url)
        return (
            parsed.scheme == "https"
            and parsed.netloc == "phet.colorado.edu"
            and parsed.path.startswith("/sims/html/")
        )
    except Exception:
        return False


# Backward compatibility alias
_is_allowed_phet_url = is_allowed_phet_url


def resolve_simulation_action(
    query: str,
    topic: str,
    current_params: Optional[Dict[str, Any]] = None,
    template_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Evaluates simulation state, searches PhET official catalog, extracts slider parameter changes,
    and returns sanitized parameter updates and visual cues.
    """
    current_params = current_params or {}
    lower_query = query.lower()

    # 1. Parameter extraction from user text (supports signed floats)
    extracted_params: Dict[str, Any] = {}

    speed_match = RE_PARAM_SPEED.search(lower_query)
    if speed_match:
        extracted_params["speed"] = float(speed_match.group(1))

    angle_match = RE_PARAM_ANGLE.search(lower_query)
    if angle_match:
        extracted_params["angle"] = float(angle_match.group(1))

    gravity_match = RE_PARAM_GRAVITY.search(lower_query)
    if gravity_match:
        extracted_params["gravity"] = float(gravity_match.group(1))

    mass_match = RE_PARAM_MASS.search(lower_query)
    if mass_match:
        extracted_params["mass"] = float(mass_match.group(1))

    # Sanitize and clamp values using Stemly's security and bounds engine
    sanitized_updates = sanitize_simulation_parameters(extracted_params)

    # 2. PhET Catalog lookup
    phet_match = phet_service.find_simulation(topic)
    valid_phet = None
    if phet_match and is_allowed_phet_url(phet_match.get("url", "")):
        valid_phet = {
            "title": phet_match["title"],
            "url": phet_match["url"],
            "slug": phet_match["slug"],
            "subject": phet_match.get("subject", "physics"),
        }

    # 3. Generate visual cue for student
    visual_cue = None
    if sanitized_updates:
        keys_changed = ", ".join(sanitized_updates.keys())
        visual_cue = f"Notice how updating {keys_changed} transforms the trajectory and key turning points on the simulation."
    elif valid_phet:
        visual_cue = f"Interact with the '{valid_phet['title']}' simulation sliders to explore this effect live."

    return {
        "has_phet": valid_phet is not None,
        "phet": valid_phet,
        "parameter_updates": sanitized_updates,
        "visual_cue": visual_cue,
        "template_id": template_id or (valid_phet["slug"] if valid_phet else "declarative_physics"),
    }
