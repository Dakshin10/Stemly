"""
Google Gemini Flash Fallback Client for High Concurrency Resiliency.
Automatically handles failovers when Groq hits 429 rate limits or upstream 5xx outages.
Uses standard asynchronous httpx client without requiring heavy SDK overhead.
"""

import base64
import json
import logging
from typing import Optional

import httpx

from config import settings
from prompts.vision_prompts import VISION_TOPIC_DETECTION_PROMPT_V1

logger = logging.getLogger("stemly.llm.gemini")

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


async def call_gemini_vision(image_bytes: bytes, ocr_text: str = "") -> Optional[dict]:
    """
    Call Gemini Flash Vision endpoint as a secondary fallback.
    Returns parsed dictionary payload or None on failure.
    """
    api_key = getattr(settings, "GEMINI_API_KEY", None)
    if not api_key or not api_key.strip():
        return None

    model = getattr(settings, "GEMINI_VISION_MODEL", "gemini-1.5-flash")
    url = f"{GEMINI_BASE_URL}/{model}:generateContent?key={api_key}"

    # Prepare base64 image data
    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    prompt = VISION_TOPIC_DETECTION_PROMPT_V1
    if ocr_text and ocr_text.strip():
        prompt += f"\n\nSupplementary OCR text:\n{ocr_text[:800]}"

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": b64_image,
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.1,
            "maxOutputTokens": 1024,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=settings.LLM_TIMEOUT_SECONDS) as client:
            resp = await client.post(url, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                candidates = data.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    if parts and "text" in parts[0]:
                        raw_text = parts[0]["text"]
                        return json.loads(raw_text)
            else:
                logger.warning(
                    "Gemini Vision API returned status %d: %s",
                    resp.status_code,
                    resp.text[:200],
                )
    except Exception as exc:
        logger.warning("Gemini Vision failover encountered an error: %s", exc)

    return None
