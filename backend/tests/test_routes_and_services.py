"""
Comprehensive Route Integration & Services Test Suite.
Validates:
1. Every route via httpx.AsyncClient with mock Firebase authentication.
2. Groq LLM scenarios via respx:
   - Happy path with structured Pydantic response
   - Invalid JSON from model with 1 automatic repair retry & fallback
   - 429 Rate Limit with Retry-After header
   - Request Timeout with retry / fallback
   - Complete downstream model failure with graceful degraded response
3. Full unit tests for all backend services (phet, quiz, history, visualiser_loader, llm client/cache/fallback).
"""

import io
import json

import httpx
import pytest
import respx
from httpx import ASGITransport, AsyncClient
from PIL import Image

from config import settings
from core.rate_limiter import limiter
from main import app
from models.quiz import QuizAnswerRequest, QuizSubmission
from services.history_service import add_history, get_user_history
from services.llm.cache import (
    compute_notes_cache_key,
    compute_quiz_cache_key,
    get_cached_notes,
    get_cached_quiz,
    normalize_topic,
    set_cached_notes,
    set_cached_quiz,
)
from services.llm.client import LLMClientManager
from services.llm.fallback import (
    detect_topic_from_keywords,
    get_fallback_quiz,
)
from services.llm.text import (
    _fallback_notes,
    follow_up_notes,
    process_visualiser_chat_llm,
)
from services.llm.vision import (
    analyze_image,
    prepare_image_data_url,
)
from services.phet_service import PhetService
from services.quiz_service import QuizService
from services.visualiser_loader import _load_template_cached, fill_template_defaults


@pytest.fixture(autouse=True)
def reset_limiter_state():
    try:
        limiter._storage.reset()
    except Exception:
        pass
    yield
    try:
        limiter._storage.reset()
    except Exception:
        pass


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


def create_dummy_jpeg(color=(100, 150, 200)) -> bytes:
    img = Image.new("RGB", (100, 100), color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# ==============================================================================
# 1. ROUTE TESTS: OBSERVABILITY & SYSTEM PROBES
# ==============================================================================


@pytest.mark.asyncio
async def test_healthz_and_readyz():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Liveness probe
        res_health = await client.get("/healthz")
        assert res_health.status_code == 200
        data_health = res_health.json()
        assert data_health["status"] == "ok"
        assert "timestamp" in data_health

        # Readiness probe
        res_ready = await client.get("/readyz")
        assert res_ready.status_code in [200, 503]
        data_ready = res_ready.json()
        if res_ready.status_code == 200:
            assert data_ready["status"] == "ready"
            assert "database" in data_ready
            assert "config" in data_ready


# ==============================================================================
# 2. ROUTE TESTS: SCAN & VISION
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_route_scan_upload_happy_path(auth_headers):
    # Mock Groq Vision endpoint
    vision_mock = respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "topic": "Projectile Motion",
                                    "confidence": 0.95,
                                    "summary": "Parabolic motion of a launched body",
                                    "variables": ["v", "theta", "g"],
                                    "domain": "physics",
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    jpeg_bytes = create_dummy_jpeg()
    files = {"file": ("test.jpg", jpeg_bytes, "image/jpeg")}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/scan/upload", headers=auth_headers, files=files)
        assert res.status_code == 200
        body = res.json()
        assert body["topic"] == "Projectile Motion"
        assert "variables" in body
        assert vision_mock.called


@pytest.mark.asyncio
@respx.mock
async def test_route_scan_upload_groq_timeout_fallback(auth_headers):
    # Mock Groq Vision timing out
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        side_effect=httpx.ConnectTimeout("Groq API connection timed out")
    )

    jpeg_bytes = create_dummy_jpeg(color=(250, 40, 10))
    files = {"file": ("test_fresh.jpg", jpeg_bytes, "image/jpeg")}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/scan/upload", headers=auth_headers, files=files)
        assert res.status_code == 200
        body = res.json()
        # Fallback response is gracefully returned
        assert "topic" in body
        assert body["degraded"] is True


# ==============================================================================
# 3. ROUTE TESTS: NOTES GENERATION
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_route_notes_generate_happy_path(auth_headers):
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "explanation": "Force equals mass times acceleration",
                                    "summary": [
                                        "Laws of motion governing classical dynamics",
                                        "Second law specifies F = ma",
                                    ],
                                    "formulas": ["F = ma"],
                                    "variable_breakdown": {"F": "Force", "m": "mass", "a": "acceleration"},
                                    "example": "Pushing a stalled vehicle",
                                    "mistakes": ["Confusing mass and weight"],
                                    "practice_questions": [
                                        "What is the force required to accelerate a 5kg mass at 2m/s^2?"
                                    ],
                                    "resources": ["OpenStax Physics 4.3"],
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/notes/generate",
            headers=auth_headers,
            json={"topic": "Newton's Laws", "variables": ["F", "m", "a"]},
        )
        assert res.status_code == 200
        body = res.json()
        assert "notes" in body
        assert "Force equals mass times acceleration" in body["notes"]["explanation"]
        assert body["notes"]["degraded"] is False


@pytest.mark.asyncio
@respx.mock
async def test_route_notes_generate_429_retry_after(auth_headers):
    # First response returns 429 with Retry-After, second succeeds
    route = respx.post("https://api.groq.com/openai/v1/chat/completions")
    route.side_effect = [
        httpx.Response(429, headers={"Retry-After": "1"}, json={"error": "Rate limit exceeded"}),
        httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "explanation": "Linear velocity relation",
                                    "summary": ["Motion in 1D", "Velocity increases with constant acceleration"],
                                    "formulas": ["v = u + at"],
                                    "variable_breakdown": {"v": "final velocity", "u": "initial velocity"},
                                    "example": "Train departing station",
                                    "mistakes": ["Assuming constant acceleration always"],
                                    "practice_questions": ["Calculate v when u=0, a=2, t=5."],
                                    "resources": ["Kinematics Guide"],
                                }
                            )
                        }
                    }
                ]
            },
        ),
    ]

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/notes/generate",
            headers=auth_headers,
            json={"topic": "Kinematics"},
        )
        assert res.status_code == 200
        body = res.json()
        assert "notes" in body
        assert "Linear velocity relation" in body["notes"]["explanation"]


@pytest.mark.asyncio
@respx.mock
async def test_route_notes_generate_invalid_json_fallback(auth_headers):
    # Returns corrupted unrepairable text repeatedly
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(200, text="Sorry, I am unable to format as valid JSON.")
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/notes/generate",
            headers=auth_headers,
            json={"topic": "Free Fall"},
        )
        assert res.status_code == 200
        body = res.json()
        # Gracefully returns deterministic fallback
        assert "notes" in body
        assert body["notes"]["degraded"] is True
        assert "Free Fall" in body["notes"]["explanation"]


# ==============================================================================
# 4. ROUTE TESTS: QUIZ & TUTOR CHAT
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_route_quiz_generate_and_submit(auth_headers):
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "topic": "Optics",
                                    "questions": [
                                        {
                                            "id": 1,
                                            "question": "What is the focal length of a flat mirror?",
                                            "options": ["0", "Infinity", "1 m", "-1 m"],
                                            "correct_answer": "Infinity",
                                            "correct_index": 1,
                                            "explanation": "Parallel rays reflect without convergence.",
                                        }
                                    ],
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Generate quiz
        res_gen = await client.get("/quiz/generate?topic=Optics", headers=auth_headers)
        assert res_gen.status_code == 200
        quiz_data = res_gen.json()
        assert len(quiz_data["questions"]) >= 1

        # Submit quiz
        res_sub = await client.post(
            "/quiz/submit",
            headers=auth_headers,
            json={"answers": [{"question_id": 101, "selected_index": 3}]},
        )
        assert res_sub.status_code == 200
        sub_data = res_sub.json()
        assert "score" in sub_data


@pytest.mark.asyncio
@respx.mock
async def test_route_tutor_chat_happy_path(auth_headers):
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "response": "Velocity is the rate of change of displacement.",
                                    "parameter_updates": {},
                                    "update_type": "explanation",
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/chat/ask",
            headers=auth_headers,
            json={"topic": "Kinematics", "user_prompt": "What is velocity?"},
        )
        assert res.status_code == 200
        body = res.json()
        assert "response" in body
        assert "displacement" in body["response"]
        assert body["degraded"] is False


# ==============================================================================
# 5. ROUTE TESTS: VISUALISER ENGINE
# ==============================================================================


@pytest.mark.asyncio
async def test_route_visualiser_generate_whitelisted_and_phet(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Internal whitelisted template
        res_internal = await client.post(
            "/visualiser/generate",
            headers=auth_headers,
            json={"topic": "projectile motion"},
        )
        assert res_internal.status_code == 200
        data_int = res_internal.json()
        assert data_int["template"]["template_id"] == "projectile_motion"

        # Unknown topic with PhET match
        res_phet = await client.post(
            "/visualiser/generate",
            headers=auth_headers,
            json={"topic": "forces and motion"},
        )
        assert res_phet.status_code == 200
        data_phet = res_phet.json()
        assert data_phet["template"]["template_id"] in ["phet-webview", "default-empty"]


@pytest.mark.asyncio
async def test_route_visualiser_states_crud(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Save state
        res_save = await client.post(
            "/visualiser/states",
            headers=auth_headers,
            json={
                "template_id": "projectile_motion",
                "parameters": {"U": 25.0, "theta": 45.0, "g": 9.8},
            },
        )
        assert res_save.status_code == 200
        assert "id" in res_save.json()

        # List states
        res_list = await client.get("/visualiser/states", headers=auth_headers)
        assert res_list.status_code == 200
        assert "items" in res_list.json()


# ==============================================================================
# 6. ROUTE TESTS: USER DATA & GDPR DELETION
# ==============================================================================


@pytest.mark.asyncio
async def test_route_delete_my_data(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.delete("/auth/me/data", headers=auth_headers)
        assert res.status_code == 200
        body = res.json()
        assert body["status"] == "success"


# ==============================================================================
# 7. SERVICE UNIT TESTS (TARGET 80%+ COVERAGE)
# ==============================================================================


def test_phet_service_search_and_format():
    svc = PhetService()
    # Direct match
    sim1 = svc.find_simulation("Projectile Motion")
    assert sim1 is not None
    assert "phet.colorado.edu" in sim1["url"]

    # Keyword match
    sim2 = svc.find_simulation("gravity and cannon trajectory")
    assert sim2 is not None

    # Empty query
    assert svc.find_simulation("") is None

    # No match threshold
    assert svc.find_simulation("unrelated completely unknown query xyz123") is None


def test_visualiser_loader_service():
    # Cache hit & file load
    tmpl1 = _load_template_cached("projectile_motion.json")
    assert tmpl1 is not None
    assert tmpl1["template_id"] == "projectile_motion"

    # Inexistent file
    assert _load_template_cached("nonexistent_file_9999.json") is None

    # Defaults filler
    filled = fill_template_defaults(tmpl1, ["U", "theta"])
    assert filled["template_id"] == "projectile_motion"


def test_quiz_service_methods():
    qs = QuizService()
    topics = qs.get_topics()
    assert len(topics) >= 1

    questions = qs.get_questions(1, limit=2)
    assert len(questions) <= 2

    # Evaluation
    sub = QuizSubmission(
        answers=[
            QuizAnswerRequest(question_id=101, selected_index=3),  # Correct
            QuizAnswerRequest(question_id=102, selected_index=0),  # Incorrect
        ]
    )
    result = qs.evaluate(sub)
    assert result.score == 1
    assert result.total == 2
    assert 101 in result.correct_questions


def test_history_service_methods():
    user = "test_uid_service_123"
    rec_id = add_history(user, "/path/img.jpg", "Newtonian Gravity", ["G", "m1", "m2"])
    assert rec_id is not None

    hist = get_user_history(user)
    assert len(hist) >= 1
    assert hist[0]["topic"] == "Newtonian Gravity"


@pytest.mark.asyncio
async def test_llm_cache_system():
    # Topic normalization
    assert normalize_topic("  Projectile Motion  ") == "projectile motion"

    # Compute key
    k1 = compute_notes_cache_key("Optics", ["f", "u"])
    k2 = compute_notes_cache_key("optics", ["u", "f"])
    assert k1 == k2  # Sorted & normalized match

    q_key = compute_quiz_cache_key("Optics", 3)
    assert q_key is not None

    # Set and Get notes cache
    await set_cached_notes("Optics", ["f", "u"], {"summary": "Cached notes content"})
    cached = await get_cached_notes("Optics", ["f", "u"])
    assert cached is not None
    assert cached["summary"] == "Cached notes content"

    # Set and Get quiz cache
    await set_cached_quiz("Optics", 3, {"questions": []})
    cached_q = await get_cached_quiz("Optics", 3)
    assert cached_q is not None


def test_llm_fallback_generation():
    # Fallback notes
    notes = _fallback_notes("Kinematics", ["v", "a", "t"])
    assert "Kinematics" in notes.explanation
    assert notes.degraded is True
    assert len(notes.variable_breakdown) >= 1

    # Fallback quiz
    quiz = get_fallback_quiz("Optics", count=2)
    assert quiz["topic"] == "Optics"
    assert quiz["degraded"] is True
    assert len(quiz["questions"]) == 2

    # Keyword detection
    detected, vars_found = detect_topic_from_keywords("The cannon fired the ball at 45 degrees angle")
    assert detected == "Projectile Motion"
    assert "range" in vars_found or "theta" in vars_found or "v0" in vars_found

    # General detection
    gen_topic, _ = detect_topic_from_keywords("")
    assert gen_topic == "General Science"


@pytest.mark.asyncio
async def test_llm_client_manager():
    mgr = LLMClientManager()
    await mgr.start()
    assert mgr.vision_client is not None
    assert mgr.text_client is not None
    await mgr.close()
    assert mgr._vision_client is None
    assert mgr._text_client is None


def test_vision_prepare_image_modes():
    # 1. RGBA mode
    rgba_img = Image.new("RGBA", (200, 200), (255, 0, 0, 128))
    buf = io.BytesIO()
    rgba_img.save(buf, format="PNG")
    url_rgba = prepare_image_data_url(buf.getvalue())
    assert url_rgba.startswith("data:image/jpeg;base64,")

    # 2. Oversized image thumbnail downsampling
    large_img = Image.new("RGB", (1500, 1200), (0, 255, 0))
    buf_large = io.BytesIO()
    large_img.save(buf_large, format="JPEG")
    url_large = prepare_image_data_url(buf_large.getvalue())
    assert url_large.startswith("data:image/jpeg;base64,")


@pytest.mark.asyncio
@respx.mock
async def test_vision_analyze_image_mocked():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "topic": "Optics",
                                    "variables": ["f", "do", "di"],
                                    "confidence": 0.95,
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    jpeg_bytes = create_dummy_jpeg()
    result = await analyze_image(jpeg_bytes, ocr_text="Concave lens focal distance")
    assert result.topic == "Optics"
    assert "f" in result.variables
    assert result.degraded is False


@pytest.mark.asyncio
async def test_vision_analyze_image_offline_fallback():
    # Temporarily clear key
    orig_key = settings.GROQ_VISION_API_KEY
    settings.GROQ_VISION_API_KEY = ""
    try:
        result = await analyze_image(b"fake", ocr_text="calculate current and voltage in ohm resistor")
        assert result.topic == "Electricity"
        assert result.degraded is True
    finally:
        settings.GROQ_VISION_API_KEY = orig_key


@pytest.mark.asyncio
@respx.mock
async def test_text_followup_and_chat_mocked():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "explanation": "Refraction index depends on phase velocity.",
                                    "summary": ["Snell's Law relates angles"],
                                    "formulas": ["n1 sin(th1) = n2 sin(th2)"],
                                    "variable_breakdown": {"n": "refractive index"},
                                    "example": "Straw in water cup",
                                    "mistakes": ["Measuring angle to surface instead of normal"],
                                    "practice_questions": ["Find theta2 when n1=1, n2=1.33."],
                                    "resources": ["Optics Refraction Chapter"],
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    notes = await follow_up_notes(
        topic="Optics",
        previous_notes={"summary": ["Light bends"]},
        user_prompt="Why does light bend?",
    )
    assert "Refraction" in notes.explanation
    assert notes.degraded is False


@pytest.mark.asyncio
@respx.mock
async def test_visualiser_chat_llm_mocked():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "type": "update",
                                    "changes": {"theta": 60.0},
                                    "message": "Increased launch angle to 60 degrees.",
                                }
                            )
                        }
                    }
                ]
            },
        )
    )

    res = await process_visualiser_chat_llm(
        user_message="Aim higher",
        topic="Projectile Motion",
        parameters={"theta": 45.0, "U": 20.0},
    )
    assert res.type == "update"
    assert res.changes.get("theta") == 60.0
    assert res.degraded is False


def test_fallback_keyword_branches():
    t_opt, v_opt = detect_topic_from_keywords("The ray hits the focal point of the convex lens")
    assert t_opt == "Optics"
    assert "f" in v_opt

    t_kin, v_kin = detect_topic_from_keywords("Calculate the acceleration and velocity of the car")
    assert t_kin in ["Kinematics", "Mechanics"]
    assert "v" in v_kin

    t_elec, v_elec = detect_topic_from_keywords("Measure circuit voltage and ohm resistance")
    assert t_elec == "Electricity"
    assert "V" in v_elec

    # Partial quiz search
    quiz = get_fallback_quiz("projectile")
    assert quiz["topic"] == "Projectile Motion"
    assert len(quiz["questions"]) >= 1
