"""
Tests for Persistence and Cost Optimization:
1. MongoDB indexes and startup initialization.
2. Semantic LLM cache for notes and quizzes (normalized hash, version key invalidation, cache hits).
3. Image scan deduplication by content hash per user.
4. Graceful DB degradation and /readyz observability.
5. Pagination for history endpoints and GDPR 'Delete-My-Data' endpoint.
6. Daily per-user usage counter bounding LLM cost.
"""

import hashlib
import io
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image

from core.usage_limiter import (
    DAILY_LLM_QUOTA,
    check_and_increment_daily_usage,
    delete_user_usage_records,
)
from database.indexes import init_db_indexes
from main import app
from services.llm.cache import (
    compute_notes_cache_key,
    compute_quiz_cache_key,
    set_cached_notes,
    set_cached_quiz,
)
from services.llm.text import generate_notes, generate_quiz


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


# ==============================================================================
# 1. MONGODB INDEXES & STARTUP ROUTINE
# ==============================================================================


@pytest.mark.asyncio
async def test_init_db_indexes_graceful_when_db_none():
    """
    Startup index routine must not raise an unhandled exception when DB is None.
    """
    success = await init_db_indexes(database=None)
    assert success is False


@pytest.mark.asyncio
async def test_init_db_indexes_mock_collection():
    """
    Verifies that init_db_indexes attempts to create the required composite and TTL indexes.
    """
    created_indexes = {}

    class MockCollection:
        def __init__(self, name):
            self.name = name

        async def create_index(self, keys, **kwargs):
            created_indexes.setdefault(self.name, []).append((keys, kwargs))
            return kwargs.get("name", "mock_idx")

    class MockDatabase:
        def __getitem__(self, name):
            return MockCollection(name)

    mock_db = MockDatabase()
    res = await init_db_indexes(database=mock_db)
    assert res is True

    # Verify required indexes exist
    assert "scans" in created_indexes
    assert any("idx_scans_user_timestamp" == kw.get("name") for _, kw in created_indexes["scans"])
    assert any("idx_scans_user_content_hash" == kw.get("name") for _, kw in created_indexes["scans"])

    assert "notes" in created_indexes
    assert any("idx_notes_user_topic" == kw.get("name") for _, kw in created_indexes["notes"])

    assert "llm_cache" in created_indexes
    assert any("idx_llm_cache_ttl" == kw.get("name") for _, kw in created_indexes["llm_cache"])

    assert "usage_counters" in created_indexes
    assert any("idx_usage_user_date" == kw.get("name") for _, kw in created_indexes["usage_counters"])


# ==============================================================================
# 2. CACHING GENERATED NOTES AND QUIZZES
# ==============================================================================


def test_cache_key_normalization():
    """
    Topic casing/whitespace and variable order must produce identical cache keys.
    """
    key1 = compute_notes_cache_key("Kinematics", ["v", "t", "a"])
    key2 = compute_notes_cache_key("  kinematics  ", ["t", "a", "v"])
    assert key1 == key2

    quiz_key1 = compute_quiz_cache_key("Newton's Laws", 5)
    quiz_key2 = compute_quiz_cache_key("  newton's laws  ", 5)
    assert quiz_key1 == quiz_key2


def test_cache_version_invalidation():
    """
    Changing cache version must invalidate previously cached content.
    """
    key_current = compute_notes_cache_key("Optics", ["f"])
    raw_v2 = "notes:v2:optics:f"
    key_v2 = hashlib.sha256(raw_v2.encode("utf-8")).hexdigest()
    assert key_current != key_v2


@pytest.mark.asyncio
async def test_notes_caching_skips_llm():
    """
    Subsequent calls with identical topic and variables must return from cache without invoking LLM.
    """
    topic = "Thermal Expansion"
    vars_list = ["delta_l", "alpha", "l0", "delta_t"]

    test_notes = {
        "explanation": "Cached explanation of thermal expansion.",
        "variable_breakdown": {"alpha": "Coefficient"},
        "formulas": ["ΔL = α L0 ΔT"],
        "example": "Railway track expansion",
        "mistakes": [],
        "practice_questions": [],
        "summary": ["Heat expands metals"],
        "resources": [],
        "degraded": False,
    }

    # Populate cache
    await set_cached_notes(topic, vars_list, test_notes)

    # Fetch via generate_notes
    result = await generate_notes(topic=topic, variables=vars_list, ocr_text=None)
    assert result.explanation == "Cached explanation of thermal expansion."
    assert result.degraded is False


@pytest.mark.asyncio
async def test_quiz_caching_skips_llm():
    """
    Subsequent calls for quiz on identical topic return from cache.
    """
    topic = "Coulomb's Law"
    test_quiz = {
        "topic": topic,
        "difficulty": "medium",
        "questions": [
            {
                "question": "What happens if distance doubles?",
                "options": ["Quartered", "Halved", "Doubled", "Quadrupled"],
                "correct_index": 0,
                "explanation": "Inverse square law",
                "takeaway": "F proportional to 1/r^2",
            }
        ],
        "degraded": False,
    }

    await set_cached_quiz(topic, 5, test_quiz)

    result = await generate_quiz(topic=topic, num_questions=5)
    assert result.topic == topic
    assert result.questions[0].correct_index == 0


# ==============================================================================
# 3. DEDUPLICATION OF IDENTICAL IMAGE SCANS
# ==============================================================================


@pytest.mark.asyncio
async def test_scan_deduplication_reuses_previous_analysis(auth_headers):
    """
    Uploading the exact same image twice for the same user skips Groq Vision
    and returns deduped=True with the previous analysis and path.
    """
    img = Image.new("RGB", (100, 100), color=(12, 34, 56))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    from services.llm.vision import TopicAnalysis

    mock_analysis = TopicAnalysis(topic="Kinematics", variables=["v", "t"], confidence=0.9, degraded=False)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        with patch("routers.scan.analyze_image", AsyncMock(return_value=mock_analysis)):
            # First upload
            files1 = {"file": ("scan1.jpg", io.BytesIO(img_bytes), "image/jpeg")}
            res1 = await client.post("/scan/upload", files=files1, headers=auth_headers)
            assert res1.status_code == 200
            data1 = res1.json()
            assert data1["status"] == "success"
            assert data1["deduped"] is False

            # Second upload with identical bytes
            files2 = {"file": ("scan2.jpg", io.BytesIO(img_bytes), "image/jpeg")}
            res2 = await client.post("/scan/upload", files=files2, headers=auth_headers)
            assert res2.status_code == 200
            data2 = res2.json()
            assert data2["status"] == "success"
            assert data2["deduped"] is True
            assert data2["topic"] == data1["topic"]
            assert data2["image_path"] == data1["image_path"]


# ==============================================================================
# 4. DAILY USAGE COUNTER (COST BOUNDING)
# ==============================================================================


@pytest.mark.asyncio
async def test_daily_usage_counter_enforces_quota():
    """
    Verifies that check_and_increment_daily_usage tracks calls and raises 429 when quota is exceeded.
    """
    test_user = "user_cost_test_999"

    # Reset any existing counts
    await delete_user_usage_records(test_user)

    # Consume quota up to limit
    for _ in range(DAILY_LLM_QUOTA):
        allowed, count, limit = await check_and_increment_daily_usage(test_user)
        assert allowed is True

    # Next call exceeds quota
    with pytest.raises(Exception) as exc_info:
        await check_and_increment_daily_usage(test_user)
    assert exc_info.value.status_code == 429
    assert "Daily AI generation quota exceeded" in exc_info.value.detail


# ==============================================================================
# 5. PAGINATION & DELETE-MY-DATA
# ==============================================================================


@pytest.mark.asyncio
async def test_scan_history_pagination(auth_headers):
    """
    GET /scan/history returns total, limit, skip, and has_more.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/scan/history?limit=5&skip=0", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert "history" in data
        assert "total" in data
        assert data["limit"] == 5
        assert data["skip"] == 0
        assert "has_more" in data


@pytest.mark.asyncio
async def test_visualiser_history_pagination(auth_headers):
    """
    GET /visualiser/history returns pagination structure.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/visualiser/history?limit=10&skip=0", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert "items" in data
        assert "total" in data
        assert data["limit"] == 10
        assert "has_more" in data


@pytest.mark.asyncio
async def test_delete_my_data_endpoint(auth_headers):
    """
    DELETE /auth/me/data deletes all user data across scans, notes, visualiser, and usage records.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.delete("/auth/me/data", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "deleted_counts" in data
        assert "scans" in data["deleted_counts"]
        assert "notes" in data["deleted_counts"]
        assert "visualiser_entries" in data["deleted_counts"]
        assert "usage_records" in data["deleted_counts"]
