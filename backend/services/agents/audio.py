import io
import logging
from typing import Any, Dict, Optional

from groq import AsyncGroq

from config import settings

logger = logging.getLogger("stemly.agents.audio")


async def transcribe_audio(
    file_bytes: bytes,
    filename: str = "recording.m4a",
    language: Optional[str] = "en",
    prompt: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Transcribes audio using Groq Whisper Large V3 Turbo model ($0.04/hour, 400 RPM).
    Optimized for low-latency student voice input on STEM equations and questions.
    """
    if not settings.GROQ_TEXT_API_KEY:
        logger.warning("GROQ_TEXT_API_KEY not configured for Whisper transcription")
        return {
            "text": "",
            "degraded": True,
            "error": "Transcription service credentials not configured",
        }

    try:
        client = AsyncGroq(api_key=settings.GROQ_TEXT_API_KEY)
        audio_file = io.BytesIO(file_bytes)
        audio_file.name = filename

        transcription = await client.audio.transcriptions.create(
            file=(filename, audio_file),
            model=settings.GROQ_AUDIO_MODEL,
            language=language or "en",
            prompt=prompt or "Physics, Mathematics, Kinematics, Calculus, STEM equations.",
            response_format="verbose_json",
        )

        text_content = getattr(transcription, "text", "") or ""
        duration = getattr(transcription, "duration", None)
        lang = getattr(transcription, "language", language)

        return {
            "text": text_content.strip(),
            "duration": duration,
            "language": lang,
            "degraded": False,
        }
    except Exception as exc:
        logger.exception("Error transcribing audio with Groq Whisper: %s", exc)
        return {
            "text": "",
            "degraded": True,
            "error": str(exc),
        }
