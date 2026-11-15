"""
Hardened Storage Service for Scanned STEM Images.
Features:
- Magic-byte validation (PNG and JPEG).
- Max file size enforcement (5 MB limit).
- Pixel dimension limits (max 4096 x 4096 px).
- Decompression bomb protection (Image.MAX_IMAGE_PIXELS = 10,000,000).
- Automatic EXIF metadata stripping.
- Non-blocking execution offloaded to worker threadpool.
"""

import hashlib
import io
import logging
import os
import uuid
from typing import Tuple

from fastapi import HTTPException, UploadFile, status
from fastapi.concurrency import run_in_threadpool
from PIL import Image

from config import settings

logger = logging.getLogger("stemly.storage")

# Operational limits
MAX_SCAN_BYTES = 5 * 1024 * 1024  # 5 MB
MAX_IMAGE_DIMENSION = 4096  # 4096 x 4096 px max
SCANS_DIR = "static/scans"

# Pillow decompression bomb protection
Image.MAX_IMAGE_PIXELS = 10_000_000  # 10 Megapixels

# Magic byte signatures
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
JPEG_MAGIC = b"\xff\xd8\xff"


def _upload_to_s3_sync(clean_bytes: bytes, filename: str) -> str:
    """
    Uploads processed scan JPEG to S3 or Cloudflare R2 bucket.
    Returns persistent CDN / public URL.
    """
    try:
        import boto3
        from botocore.config import Config

        session = boto3.session.Session()
        s3 = session.client(
            "s3",
            endpoint_url=settings.S3_ENDPOINT_URL,
            aws_access_key_id=settings.S3_ACCESS_KEY_ID,
            aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY,
            region_name=settings.S3_REGION_NAME,
            config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
        )
        key = f"scans/{filename}"
        s3.put_object(
            Bucket=settings.S3_BUCKET,
            Key=key,
            Body=clean_bytes,
            ContentType="image/jpeg",
            CacheControl="public, max-age=31536000, immutable",
        )
        if settings.S3_PUBLIC_DOMAIN:
            return f"{settings.S3_PUBLIC_DOMAIN.rstrip('/')}/{key}"
        if settings.S3_ENDPOINT_URL:
            return f"{settings.S3_ENDPOINT_URL.rstrip('/')}/{settings.S3_BUCKET}/{key}"
        return f"https://{settings.S3_BUCKET}.s3.amazonaws.com/{key}"
    except Exception as exc:
        logger.error("Cloud storage upload to S3/R2 failed: %s. Falling back to local disk.", exc)
        return ""


def _process_and_save_image_sync(raw_bytes: bytes, filename: str) -> Tuple[str, bytes, str]:
    """
    Synchronous image processing: validates magic bytes, checks dimensions,
    strips EXIF, and saves clean JPEG to disk or cloud object storage.
    Executed in threadpool to prevent blocking the async event loop.
    """
    # 1. Magic bytes validation
    is_png = raw_bytes.startswith(PNG_MAGIC)
    is_jpeg = raw_bytes.startswith(JPEG_MAGIC)
    if not (is_png or is_jpeg):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Only JPEG and PNG files are allowed.",
        )

    # 2. Open and inspect image using Pillow
    try:
        with Image.open(io.BytesIO(raw_bytes)) as raw_img:
            width, height = raw_img.size
            if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Image dimensions ({width}x{height}) exceed maximum allowed limit of {MAX_IMAGE_DIMENSION}x{MAX_IMAGE_DIMENSION} pixels.",
                )

            # 3. Strip EXIF metadata by copying pixel data into a new clean RGB surface
            if raw_img.mode in ("RGBA", "LA", "P"):
                background = Image.new("RGB", raw_img.size, (255, 255, 255))
                conv_img = raw_img.convert("RGBA") if raw_img.mode == "P" else raw_img
                background.paste(conv_img, mask=conv_img.split()[-1] if "A" in conv_img.mode else None)
                clean_img = background
            elif raw_img.mode != "RGB":
                clean_img = raw_img.convert("RGB")
            else:
                clean_img = Image.new("RGB", raw_img.size)
                clean_img.paste(raw_img)

            # 4. Save clean image without EXIF
            output_buffer = io.BytesIO()
            clean_img.save(output_buffer, format="JPEG", quality=85, optimize=True)
            clean_bytes = output_buffer.getvalue()
            content_hash = hashlib.sha256(clean_bytes).hexdigest()

            # Upload to Cloudflare R2 / AWS S3 if configured
            image_url = ""
            if settings.S3_BUCKET and settings.S3_ACCESS_KEY_ID:
                image_url = _upload_to_s3_sync(clean_bytes, filename)

            # Local disk fallback or local development storage
            if not image_url:
                os.makedirs(SCANS_DIR, exist_ok=True)
                file_path = os.path.join(SCANS_DIR, filename)
                with open(file_path, "wb") as f:
                    f.write(clean_bytes)
                image_url = f"static/scans/{filename}"

            return image_url, clean_bytes, content_hash

    except (Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Decompression bomb detected. Image rejected for security.",
        ) from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Corrupted or invalid image data.",
        ) from exc


async def save_scan_image(file: UploadFile) -> Tuple[str, bytes, str]:
    """
    Asynchronously reads file stream enforcing a hard 5MB cap,
    then processes and saves the image via threadpool.
    Returns: (saved_relative_path, cleaned_image_bytes, content_hash)
    """
    total_bytes = 0
    contents = bytearray()

    while True:
        chunk = await file.read(1024 * 512)  # 512 KB chunks
        if not chunk:
            break
        total_bytes += len(chunk)
        if total_bytes > MAX_SCAN_BYTES:
            raise HTTPException(
                status_code=getattr(status, "HTTP_413_CONTENT_TOO_LARGE", 413),
                detail=f"File exceeds maximum allowed size of {MAX_SCAN_BYTES // (1024 * 1024)} MB.",
            )
        contents.extend(chunk)

    if total_bytes == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    filename = f"{uuid.uuid4().hex}.jpg"
    raw_data = bytes(contents)

    # Offload image verification, EXIF stripping, and disk write to threadpool
    saved_path, clean_bytes, content_hash = await run_in_threadpool(_process_and_save_image_sync, raw_data, filename)
    return saved_path, clean_bytes, content_hash
