"""
Groq Vision Service for STEM Topic and Variable Analysis.
Features:
- Image compression and dimension safety checks via Pillow.
- Base64 data URL encoding respecting Groq payload constraints.
- Groq primary analysis -> automatic repair retry -> local keyword fallback with degraded=true.
"""

import base64
import io
import logging
from typing import List, Optional

from PIL import Image
from pydantic import BaseModel, Field, model_validator

from config import settings
from prompts.vision_prompts import VISION_TOPIC_DETECTION_PROMPT_V1

from .client import get_vision_client
from .engine import call_groq_structured
from .fallback import detect_topic_from_keywords

logger = logging.getLogger("stemly.llm.vision")

# Groq Vision limits: safe dimensions <= 1024, max compressed bytes <= 3.5MB
MAX_IMAGE_DIMENSION = 1024
MAX_IMAGE_BYTES = 3 * 1024 * 1024  # 3 MB


class PhysicsVariable(BaseModel):
    name: str = Field(default="", description="Descriptive name (e.g. Initial Velocity, Launch Angle, Mass)")
    symbol: str = Field(default="", description="Standard mathematical symbol (e.g. u, v, theta, g, m, F)")
    value: Optional[float] = Field(default=None, description="Numeric magnitude if given, null if target unknown")
    unit: str = Field(default="", description="SI or specified unit (e.g. m/s, deg, m/s^2, kg, N, J)")
    is_target: bool = Field(default=False, description="True if problem specifically asks to solve for this variable")


class TopicAnalysis(BaseModel):
    topic: str = Field(description="Canonical STEM topic name")
    variables: List[str] = Field(default_factory=list, description="Variables detected in simple string format")
    structured_variables: List[PhysicsVariable] = Field(
        default_factory=list, description="Detailed physical variables with typed values, units, and targets"
    )
    target_question: Optional[str] = Field(
        default=None, description="The primary question or unknown to solve, e.g. 'Find maximum height reached'"
    )
    latex_formula: Optional[str] = Field(
        default=None, description="Primary governing equation formatted in LaTeX"
    )
    extracted_text: Optional[str] = Field(
        default="", description="Transcribed problem statement or equation text from image"
    )
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    degraded: bool = Field(default=False, description="True if local fallback engine was used")

    @model_validator(mode="after")
    def sync_variables_and_structured(self):
        # If variables list is empty but structured_variables exists, sync
        if not self.variables and self.structured_variables:
            self.variables = [
                f"{v.symbol}={v.value}{v.unit}" if v.value is not None else v.symbol
                for v in self.structured_variables
            ]
        # If structured_variables is empty but simple variables exist, create basic entries
        elif not self.structured_variables and self.variables:
            extracted = []
            for v_str in self.variables:
                parts = v_str.split("=")
                sym = parts[0].strip()
                val = None
                if len(parts) > 1:
                    try:
                        # Extract leading numeric part
                        import re

                        num_match = re.search(r"[-+]?\d*\.?\d+", parts[1])
                        if num_match:
                            val = float(num_match.group())
                    except Exception:
                        pass
                extracted.append(PhysicsVariable(name=sym, symbol=sym, value=val, unit="", is_target=False))
            self.structured_variables = extracted
        return self


def get_fallback_structured_data(topic: str) -> tuple[List[PhysicsVariable], Optional[str], Optional[str]]:
    """Returns curated fallback structured variables, target question, and latex formula."""
    topic_clean = topic.strip().lower()

    if "projectile" in topic_clean:
        return (
            [
                PhysicsVariable(name="Initial Velocity", symbol="u", value=20.0, unit="m/s", is_target=False),
                PhysicsVariable(name="Launch Angle", symbol="theta", value=45.0, unit="deg", is_target=False),
                PhysicsVariable(name="Gravity", symbol="g", value=9.8, unit="m/s^2", is_target=False),
                PhysicsVariable(name="Maximum Height", symbol="H_max", value=None, unit="m", is_target=True),
            ],
            "Calculate maximum height and horizontal range.",
            r"R = \frac{u^2 \sin(2\theta)}{g}, \quad H = \frac{u^2 \sin^2\theta}{2g}",
        )
    elif "optic" in topic_clean or "lens" in topic_clean:
        return (
            [
                PhysicsVariable(name="Focal Length", symbol="f", value=15.0, unit="cm", is_target=False),
                PhysicsVariable(name="Object Distance", symbol="u", value=-30.0, unit="cm", is_target=False),
                PhysicsVariable(name="Image Distance", symbol="v", value=None, unit="cm", is_target=True),
            ],
            "Determine the position and nature of the image formed.",
            r"\frac{1}{f} = \frac{1}{v} - \frac{1}{u}",
        )
    elif "kinematic" in topic_clean:
        return (
            [
                PhysicsVariable(name="Initial Velocity", symbol="u", value=0.0, unit="m/s", is_target=False),
                PhysicsVariable(name="Acceleration", symbol="a", value=2.0, unit="m/s^2", is_target=False),
                PhysicsVariable(name="Time", symbol="t", value=5.0, unit="s", is_target=False),
                PhysicsVariable(name="Displacement", symbol="s", value=None, unit="m", is_target=True),
            ],
            "Find the distance traveled and final velocity.",
            r"v = u + at, \quad s = ut + \frac{1}{2}at^2",
        )
    elif "mechanic" in topic_clean or "incline" in topic_clean:
        return (
            [
                PhysicsVariable(name="Mass", symbol="m", value=5.0, unit="kg", is_target=False),
                PhysicsVariable(name="Incline Angle", symbol="theta", value=30.0, unit="deg", is_target=False),
                PhysicsVariable(name="Friction Coefficient", symbol="mu", value=0.15, unit="", is_target=False),
                PhysicsVariable(name="Acceleration", symbol="a", value=None, unit="m/s^2", is_target=True),
            ],
            "Calculate the acceleration of the mass sliding down the incline.",
            r"a = g(\sin\theta - \mu\cos\theta), \quad F_{\text{net}} = m \cdot a",
        )
    elif "electric" in topic_clean:
        return (
            [
                PhysicsVariable(name="Voltage", symbol="V", value=12.0, unit="V", is_target=False),
                PhysicsVariable(name="Resistance", symbol="R", value=4.0, unit="Ω", is_target=False),
                PhysicsVariable(name="Current", symbol="I", value=None, unit="A", is_target=True),
            ],
            "Find the current and total power consumed.",
            r"V = I \cdot R, \quad P = V \cdot I",
        )

    return ([], None, None)


def prepare_image_data_url(image_bytes: bytes) -> str:
    """
    Validates, resizes, and compresses image bytes to safe dimensions and format for Groq.
    Returns a standard base64 data URL: data:image/jpeg;base64,...
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as raw_img:
            # Convert color mode to RGB for consistent JPEG encoding
            if raw_img.mode in ("RGBA", "LA", "P"):
                # Create white background for transparent images
                background = Image.new("RGB", raw_img.size, (255, 255, 255))
                conv_img = raw_img.convert("RGBA") if raw_img.mode == "P" else raw_img
                background.paste(conv_img, mask=conv_img.split()[-1] if "A" in conv_img.mode else None)
                img: Image.Image = background
            elif raw_img.mode != "RGB":
                img = raw_img.convert("RGB")
            else:
                img = raw_img

            # Downsample if dimensions exceed safe boundaries
            width, height = img.size
            if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
                img.thumbnail((MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION), Image.Resampling.LANCZOS)

            # Compress to JPEG
            output = io.BytesIO()
            img.save(output, format="JPEG", quality=85, optimize=True)
            compressed_bytes = output.getvalue()

            # If still over limit, downscale more aggressively
            if len(compressed_bytes) > MAX_IMAGE_BYTES:
                output = io.BytesIO()
                img.thumbnail((768, 768), Image.Resampling.LANCZOS)
                img.save(output, format="JPEG", quality=75, optimize=True)
                compressed_bytes = output.getvalue()

            b64_encoded = base64.b64encode(compressed_bytes).decode("utf-8")
            return f"data:image/jpeg;base64,{b64_encoded}"

    except Exception as exc:
        logger.warning("Pillow failed to optimize image: %s. Using raw base64 fallback.", exc)
        b64_raw = base64.b64encode(image_bytes).decode("utf-8")
        return f"data:image/jpeg;base64,{b64_raw}"


async def analyze_image(image_bytes: bytes, ocr_text: str = "") -> TopicAnalysis:
    """
    Analyze scanned STEM image using Groq Vision model.
    Falls back gracefully to local regex engine if Groq fails or keys are unavailable.
    """
    client = get_vision_client()

    # If vision key is not set or empty, jump straight to local fallback
    if not settings.GROQ_VISION_API_KEY:
        logger.warning("GROQ_VISION_API_KEY missing. Using local keyword fallback.")
        fallback_topic, fallback_vars = detect_topic_from_keywords(ocr_text)
        struct_vars, target_q, latex = get_fallback_structured_data(fallback_topic)
        return TopicAnalysis(
            topic=fallback_topic,
            variables=fallback_vars,
            structured_variables=struct_vars,
            target_question=target_q,
            latex_formula=latex,
            confidence=0.4,
            degraded=True,
        )

    try:
        data_url = prepare_image_data_url(image_bytes)

        user_content = [
            {"type": "text", "text": VISION_TOPIC_DETECTION_PROMPT_V1},
            {"type": "image_url", "image_url": {"url": data_url}},
        ]

        if ocr_text and ocr_text.strip():
            user_content.append(
                {
                    "type": "text",
                    "text": f"Supplementary OCR text detected from scan:\n<untrusted_ocr_text>\n{ocr_text[:800]}\n</untrusted_ocr_text>",
                }
            )

        messages = [{"role": "user", "content": user_content}]

        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_VISION_MODEL,
            messages=messages,
            schema=TopicAnalysis,
            temperature=0.1,
            max_tokens=1000,
        )

        if result:
            result.degraded = False
            return result

    except Exception as exc:
        logger.warning("Groq vision analysis failed: %s. Attempting Gemini Flash failover...", exc)

    # Secondary Cloud Fallback: Google Gemini Flash
    try:
        from .gemini_fallback import call_gemini_vision

        gemini_data = await call_gemini_vision(image_bytes=image_bytes, ocr_text=ocr_text)
        if gemini_data and isinstance(gemini_data, dict) and gemini_data.get("topic"):
            raw_struct_vars = gemini_data.get("structured_variables", [])
            parsed_struct_vars = []
            for item in raw_struct_vars:
                if isinstance(item, dict):
                    parsed_struct_vars.append(PhysicsVariable(**item))
                elif isinstance(item, PhysicsVariable):
                    parsed_struct_vars.append(item)

            logger.info("Successfully recovered scan analysis using Gemini Flash Vision.")
            return TopicAnalysis(
                topic=str(gemini_data.get("topic", "general_physics")).strip().lower(),
                variables=gemini_data.get("variables", []),
                structured_variables=parsed_struct_vars,
                target_question=gemini_data.get("target_question"),
                latex_formula=gemini_data.get("latex_formula"),
                extracted_text=gemini_data.get("extracted_text", ""),
                confidence=float(gemini_data.get("confidence", 0.85)),
                degraded=False,
            )
    except Exception as gemini_exc:
        logger.warning("Gemini Flash fallback also failed: %s. Reverting to local heuristic fallback.", gemini_exc)

    # Tertiary Fallback: Local Regex Keyword Engine
    fallback_topic, fallback_vars = detect_topic_from_keywords(ocr_text)
    struct_vars, target_q, latex = get_fallback_structured_data(fallback_topic)
    return TopicAnalysis(
        topic=fallback_topic,
        variables=fallback_vars,
        structured_variables=struct_vars,
        target_question=target_q,
        latex_formula=latex,
        confidence=0.4,
        degraded=True,
    )
