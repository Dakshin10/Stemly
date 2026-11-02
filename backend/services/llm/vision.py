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
from typing import List

from PIL import Image
from pydantic import BaseModel, Field

from config import settings
from prompts.vision_prompts import VISION_TOPIC_DETECTION_PROMPT_V1

from .client import get_vision_client
from .engine import call_groq_structured
from .fallback import detect_topic_from_keywords

logger = logging.getLogger("stemly.llm.vision")

# Groq Vision limits: safe dimensions <= 1024, max compressed bytes <= 3.5MB
MAX_IMAGE_DIMENSION = 1024
MAX_IMAGE_BYTES = 3 * 1024 * 1024  # 3 MB


class TopicAnalysis(BaseModel):
    topic: str = Field(description="Canonical STEM topic name")
    variables: List[str] = Field(default_factory=list, description="Variables detected in the image/text")
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    degraded: bool = Field(default=False, description="True if local fallback engine was used")


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
        return TopicAnalysis(
            topic=fallback_topic,
            variables=fallback_vars,
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
            max_tokens=500,
        )

        if result:
            result.degraded = False
            return result

    except Exception as exc:
        logger.error("Groq vision analysis failed: %s. Falling back to local engine.", exc)

    # Local fallback
    fallback_topic, fallback_vars = detect_topic_from_keywords(ocr_text)
    return TopicAnalysis(
        topic=fallback_topic,
        variables=fallback_vars,
        confidence=0.4,
        degraded=True,
    )
