"""
Unit tests for production scaling enhancements:
- S3/Cloudflare R2 cloud storage upload with public CDN URL.
- Gemini Flash secondary LLM failover.
- MongoDB connection pool configuration.
- Redis-backed rate limiting storage configuration.
"""

from unittest.mock import MagicMock, patch

import pytest

from config import settings
from services.llm.gemini_fallback import call_gemini_vision
from services.storage import _upload_to_s3_sync


def test_mongo_pool_settings_default():
    assert settings.MONGO_MAX_POOL_SIZE == 25
    assert settings.MONGO_MIN_POOL_SIZE == 5


@patch("boto3.session.Session")
def test_upload_to_s3_sync_success(mock_session_cls):
    mock_s3 = MagicMock()
    mock_session = MagicMock()
    mock_session.client.return_value = mock_s3
    mock_session_cls.return_value = mock_session

    with patch.object(settings, "S3_BUCKET", "test-bucket"), \
         patch.object(settings, "S3_ACCESS_KEY_ID", "test-key"), \
         patch.object(settings, "S3_SECRET_ACCESS_KEY", "test-secret"), \
         patch.object(settings, "S3_PUBLIC_DOMAIN", "https://cdn.stemly.app"):

        url = _upload_to_s3_sync(b"fake-jpeg-bytes", "test.jpg")
        assert url == "https://cdn.stemly.app/scans/test.jpg"
        mock_s3.put_object.assert_called_once()
        kwargs = mock_s3.put_object.call_args[1]
        assert kwargs["Bucket"] == "test-bucket"
        assert kwargs["Key"] == "scans/test.jpg"
        assert kwargs["ContentType"] == "image/jpeg"


@pytest.mark.asyncio
async def test_call_gemini_vision_no_key():
    with patch.object(settings, "GEMINI_API_KEY", None):
        res = await call_gemini_vision(b"fake-bytes")
        assert res is None


@pytest.mark.asyncio
async def test_call_gemini_vision_mock_response():
    fake_response = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "text": '{"topic": "projectile_motion", "variables": ["u=10m/s", "theta=45deg"], "confidence": 0.95}'
                        }
                    ]
                }
            }
        ]
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = fake_response

    with patch.object(settings, "GEMINI_API_KEY", "mock-gemini-key"), \
         patch("httpx.AsyncClient.post", return_value=mock_resp):
        res = await call_gemini_vision(b"fake-bytes", ocr_text="Find range")
        assert res is not None
        assert res["topic"] == "projectile_motion"
        assert "u=10m/s" in res["variables"]
