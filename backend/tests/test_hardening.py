"""
Production Hardening Verification Suite for Stemly Backend.
Validates:
1. Authentication: 401 on every non-public route without valid Bearer token.
2. Validation: Strict Pydantic v2 schemas and parameter clamping.
3. Uploads: Magic byte checks, 5MB file size limit, dimension limits, decompression bomb, EXIF stripping.
4. Error Handling: Standardized error envelopes {"error": {"code", "message", "request_id"}} without stack traces.
5. Observability: Request IDs, security headers, /healthz, and /readyz probes.
6. Rate Limiting: 429 Too Many Requests enforcement.
"""

import io

import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image

from core.parameter_sanitizer import clamp_parameter, sanitize_simulation_parameters
from main import app
from services.storage import (
    MAX_SCAN_BYTES,
    _process_and_save_image_sync,
)


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


# ==============================================================================
# 1. AUTHENTICATION HARDENING TESTS
# ==============================================================================

PROTECTED_ROUTES = [
    ("POST", "/scan/upload", {}),
    ("GET", "/scan/history", None),
    ("GET", "/scan/ping", None),
    ("POST", "/notes/generate", {"topic": "Kinematics"}),
    ("POST", "/notes/ask", {"topic": "Kinematics", "user_prompt": "Explain v=u+at"}),
    ("GET", "/quiz/questions/1", None),
    ("GET", "/quiz/generate?topic=Forces", None),
    ("POST", "/quiz/submit", {"answers": [{"question_id": 101, "selected_index": 0}]}),
    ("POST", "/chat/ask", {"topic": "Kinematics", "user_prompt": "Hello"}),
    ("POST", "/visualiser/states", {"template_id": "projectile_motion", "parameters": {}}),
    ("GET", "/visualiser/states", None),
    ("POST", "/visualiser/generate", {"topic": "projectile motion"}),
    ("POST", "/visualiser/update", {"template_id": "projectile_motion", "parameters": {}}),
    ("GET", "/visualiser/history", None),
    ("POST", "/visualiser/chat", {"topic": "projectile motion", "message": "Faster", "parameters": {}}),
    ("GET", "/auth/me", None),
]


@pytest.mark.asyncio
@pytest.mark.parametrize("method,path,payload", PROTECTED_ROUTES)
async def test_protected_routes_return_401_without_token(method: str, path: str, payload):
    """
    Verifies that every non-public route strictly requires authentication
    and rejects unauthenticated requests with HTTP 401 and standard error payload.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        if method == "GET":
            response = await client.get(path)
        elif method == "POST":
            response = await client.post(path, json=payload or {})
        else:
            pytest.fail(f"Unsupported HTTP method: {method}")

        assert response.status_code == 401, f"Route {method} {path} returned {response.status_code} instead of 401"
        data = response.json()
        assert "error" in data
        assert data["error"]["code"] == "UNAUTHORIZED"
        assert "request_id" in data["error"]
        assert "message" in data["error"]


@pytest.mark.asyncio
async def test_public_routes_accessible_without_token():
    """
    Verifies that public routes (/, /healthz, /readyz) succeed without an Authorization token.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Root route
        res_root = await client.get("/")
        assert res_root.status_code == 200
        assert res_root.json() == {"message": "Stemly Backend API is running"}

        # Healthz
        res_health = await client.get("/healthz")
        assert res_health.status_code == 200
        health_data = res_health.json()
        assert health_data["status"] == "ok"
        assert health_data["service"] == "stemly-backend"
        assert "timestamp" in health_data

        # Readyz
        res_ready = await client.get("/readyz")
        assert res_ready.status_code == 200
        ready_data = res_ready.json()
        assert ready_data["status"] == "ready"
        assert "config" in ready_data
        assert "database" in ready_data


# ==============================================================================
# 2. GLOBAL ERROR HANDLING & OBSERVABILITY TESTS
# ==============================================================================


@pytest.mark.asyncio
async def test_global_404_error_format():
    """
    Ensures 404 errors return uniform {error: {code, message, request_id}}.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/non_existent_route_404")
        assert res.status_code == 404
        data = res.json()
        assert data["error"]["code"] == "NOT_FOUND"
        assert data["error"]["request_id"]
        assert res.headers.get("X-Request-ID") == data["error"]["request_id"]


@pytest.mark.asyncio
async def test_global_422_validation_error_format(auth_headers):
    """
    Ensures Pydantic schema validation failures return 422 with structured details.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Notes generate requires a topic
        res = await client.post("/notes/generate", json={}, headers=auth_headers)
        assert res.status_code == 422
        data = res.json()
        assert data["error"]["code"] == "VALIDATION_ERROR"
        assert "request_id" in data["error"]
        assert "topic" in data["error"]["message"].lower()


@pytest.mark.asyncio
async def test_security_headers_present():
    """
    Verifies that security headers are injected by middleware on all responses.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/healthz")
        assert res.headers.get("X-Content-Type-Options") == "nosniff"
        assert res.headers.get("X-Frame-Options") == "DENY"
        assert "max-age=31536000" in res.headers.get("Strict-Transport-Security", "")
        assert "default-src 'none'" in res.headers.get("Content-Security-Policy", "")
        assert "X-Request-ID" in res.headers


# ==============================================================================
# 3. PARAMETER SANITIZATION & SIMULATION CLAMPING TESTS
# ==============================================================================


def test_parameter_clamping_gravity():
    assert clamp_parameter("g", 9.8) == 9.8
    assert clamp_parameter("g", -10.0) == 0.1  # Clamped to min 0.1
    assert clamp_parameter("g", 100.0) == 50.0  # Clamped to max 50.0


def test_parameter_clamping_angle():
    assert clamp_parameter("angle", 45.0) == 45.0
    assert clamp_parameter("theta", 500.0) == 360.0
    assert clamp_parameter("launch_angle", -20.0) == 0.0


def test_parameter_clamping_mass():
    assert clamp_parameter("mass", -5.0) == 0.001
    assert clamp_parameter("m", 50000.0) == 10000.0


def test_parameter_clamping_velocity():
    assert clamp_parameter("v", -10.0) == 0.0
    assert clamp_parameter("velocity", 9999.0) == 500.0


def test_parameter_clamping_nan_inf_safety():
    assert clamp_parameter("g", float("nan")) == 0.0
    assert clamp_parameter("velocity", float("inf")) == 0.0
    assert clamp_parameter("angle", float("-inf")) == 0.0


def test_nested_simulation_parameters_sanitization():
    raw_params = {
        "g": {"value": -5.0, "min": 1, "max": 20},
        "theta": {"value": 850.0, "min": 0, "max": 90},
        "mass": 0.0,
        "velocity": float("nan"),
    }
    sanitized = sanitize_simulation_parameters(raw_params)
    assert sanitized["g"]["value"] == 0.1
    assert sanitized["theta"]["value"] == 360.0
    assert sanitized["mass"] == 0.001
    assert sanitized["velocity"] == 0.0


# ==============================================================================
# 4. UPLOADS & FILE SECURITY TESTS
# ==============================================================================


def test_storage_rejects_non_image_magic_bytes():
    """
    Plain text file disguised as JPEG must be rejected by magic bytes check.
    """
    fake_bytes = b"Hello, this is just plain text, not a real image."
    with pytest.raises(Exception) as exc_info:
        _process_and_save_image_sync(fake_bytes, "test.jpg")
    assert "Invalid image format" in str(exc_info.value.detail)


def test_storage_rejects_oversized_pixel_dimensions():
    """
    Image exceeding 4096px in dimension must be rejected.
    """
    huge_img = Image.new("RGB", (4097, 100), color=(255, 0, 0))
    buf = io.BytesIO()
    huge_img.save(buf, format="JPEG")
    huge_bytes = buf.getvalue()

    with pytest.raises(Exception) as exc_info:
        _process_and_save_image_sync(huge_bytes, "huge.jpg")
    assert "exceed maximum allowed limit" in str(exc_info.value.detail)


def test_storage_strips_exif_metadata():
    """
    Images with EXIF metadata must have EXIF stripped before saving.
    """
    # Create test image with fake EXIF
    img = Image.new("RGB", (200, 200), color=(0, 128, 255))
    buf = io.BytesIO()
    # Save with minimal EXIF data
    exif = img.getexif()
    exif[0x010E] = "Secret User Camera Info"  # ImageDescription tag
    img.save(buf, format="JPEG", exif=exif)
    raw_with_exif = buf.getvalue()

    saved_path, clean_bytes, content_hash = _process_and_save_image_sync(raw_with_exif, "clean_test.jpg")

    # Read back saved bytes and verify EXIF is absent or empty of user metadata
    with Image.open(io.BytesIO(clean_bytes)) as clean_img:
        clean_exif = clean_img.getexif()
        assert 0x010E not in clean_exif


@pytest.mark.asyncio
async def test_upload_scan_exceeding_max_file_size(auth_headers):
    """
    Files larger than 5 MB must trigger 413 Payload Too Large.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Create 5.5 MB payload of fake bytes
        oversized_data = b"\xff\xd8\xff" + (b"0" * (MAX_SCAN_BYTES + 1024))
        files = {"file": ("oversized.jpg", io.BytesIO(oversized_data), "image/jpeg")}

        res = await client.post("/scan/upload", files=files, headers=auth_headers)
        assert res.status_code == 413
        data = res.json()
        assert "exceeds maximum allowed size" in data["error"]["message"].lower()


# ==============================================================================
# 5. RATE LIMITING TESTS
# ==============================================================================


@pytest.mark.asyncio
async def test_rate_limit_exceeded_returns_429():
    """
    Rapid requests exceeding limits trigger 429 Too Many Requests.
    """
    from unittest.mock import AsyncMock, patch

    from services.llm.text import QuizQuestion, QuizResponse

    mock_quiz = QuizResponse(
        topic="Force",
        difficulty="mixed",
        questions=[
            QuizQuestion(
                question="What is force?",
                options=["A", "B", "C", "D"],
                correct_index=0,
                explanation="F=ma",
            )
        ],
        degraded=False,
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        with patch("routers.quiz_router.generate_quiz", AsyncMock(return_value=mock_quiz)):
            hit_429 = False
            for _ in range(15):
                res = await client.get("/quiz/generate?topic=Force", headers={"Authorization": "Bearer test-token"})
                if res.status_code == 429:
                    hit_429 = True
                    assert res.json()["error"]["code"] == "RATE_LIMIT_EXCEEDED"
                    assert "Retry-After" in res.headers
                    break

            assert hit_429, "Rate limiter did not trigger 429 after 15 rapid requests"
