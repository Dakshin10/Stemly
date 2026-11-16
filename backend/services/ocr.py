"""
Local OCR extraction service for STEM problem diagrams and textbook images.
Supports Windows native WinRT OCR via winocr, falling back gracefully to pytesseract or empty string.
"""

import io
import logging
from typing import Optional
from PIL import Image

logger = logging.getLogger("stemly.services.ocr")


async def extract_text_from_image_bytes(image_bytes: bytes, lang: str = "en") -> str:
    """
    Extract text from raw image bytes using local OCR.
    Prioritizes winocr (fast, native Windows API), then pytesseract.
    Returns stripped extracted text or empty string on failure.
    """
    if not image_bytes:
        return ""

    # Strategy 1: Windows Native OCR (winocr)
    try:
        import winocr

        with Image.open(io.BytesIO(image_bytes)) as pil_img:
            result = await winocr.recognize_pil(pil_img, lang)
            if result and result.text and result.text.strip():
                extracted = result.text.strip()
                logger.info("winocr successfully extracted %d characters from image.", len(extracted))
                return extracted
    except ImportError:
        logger.debug("winocr is not installed or not supported on this platform.")
    except Exception as exc:
        logger.warning("winocr extraction encountered an error: %s", exc)

    # Strategy 2: pytesseract (cross-platform fallback)
    try:
        import pytesseract

        with Image.open(io.BytesIO(image_bytes)) as pil_img:
            extracted = pytesseract.image_to_string(pil_img)
            if extracted and extracted.strip():
                logger.info("pytesseract extracted %d characters from image.", len(extracted.strip()))
                return extracted.strip()
    except ImportError:
        logger.debug("pytesseract is not installed.")
    except Exception as exc:
        logger.warning("pytesseract extraction encountered an error: %s", exc)

    logger.info("No local OCR engine succeeded; proceeding without extracted text.")
    return ""
