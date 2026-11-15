import io
import json

import httpx
import pytest
import respx
from PIL import Image

from config import Settings
from services.llm.client import get_text_client
from services.llm.engine import (
    call_groq_structured,
)
from services.llm.text import (
    NotesResponse,
    ParameterUpdateResponse,
    QuizResponse,
    TutorChatResponse,
    generate_notes,
    generate_quiz,
    parse_param_update,
    tutor_chat,
)
from services.llm.vision import TopicAnalysis, analyze_image, prepare_image_data_url

# ==============================================================================
# 1. Config & Security Tests
# ==============================================================================


def test_settings_fail_fast_on_missing_keys():
    """Verify that startup validation raises an error if keys are missing."""
    test_settings = Settings(
        GROQ_VISION_API_KEY="",
        GROQ_TEXT_API_KEY="",
        TESTING=False,
    )
    with pytest.raises(ValueError, match="Missing required Groq configuration keys"):
        test_settings.validate_startup_keys()


def test_settings_never_logs_key_values():
    """Verify that repr(settings) never contains actual secret key values."""
    secret_key = "gsk_super_secret_unique_key_9999"
    test_settings = Settings(
        GROQ_VISION_API_KEY=secret_key,
        GROQ_TEXT_API_KEY=secret_key,
        TESTING=True,
    )
    repr_str = repr(test_settings)
    assert secret_key not in repr_str
    assert "GROQ_VISION_MODEL" in repr_str


# ==============================================================================
# 2. Image Preprocessing Tests
# ==============================================================================


def test_prepare_image_data_url():
    """Verify Pillow resizes, converts to RGB, and generates a valid base64 data URL."""
    # Create a 2000x2000 RGBA image in memory
    img = Image.new("RGBA", (2000, 2000), color=(255, 0, 0, 128))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    raw_bytes = buf.getvalue()

    data_url = prepare_image_data_url(raw_bytes)

    assert data_url.startswith("data:image/jpeg;base64,")
    # Base64 string should be non-empty and reasonably sized
    assert len(data_url) > 100


# ==============================================================================
# 3. Vision Analysis Tests (Mocked Groq)
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_analyze_image_success():
    """Verify successful vision topic detection via Groq."""
    groq_route = respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=200,
        json={
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "topic": "Projectile Motion",
                                "variables": ["v0", "theta", "g"],
                                "confidence": 0.98,
                            }
                        )
                    }
                }
            ],
            "usage": {"prompt_tokens": 120, "completion_tokens": 30, "total_tokens": 150},
        },
    )

    # Simple 100x100 RGB image
    img = Image.new("RGB", (100, 100), color=(0, 255, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")

    result = await analyze_image(buf.getvalue(), ocr_text="velocity angle")

    assert groq_route.called
    assert isinstance(result, TopicAnalysis)
    assert result.topic == "Projectile Motion"
    assert "theta" in result.variables
    assert result.degraded is False


@pytest.mark.asyncio
@respx.mock
async def test_analyze_image_fallback_on_failure():
    """Verify fallback to local keyword engine when Groq returns 500."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=500,
        text="Internal Server Error",
    )

    img = Image.new("RGB", (50, 50), color=(0, 0, 255))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")

    # OCR text contains optics keywords
    result = await analyze_image(buf.getvalue(), ocr_text="focal length lens refraction")

    assert isinstance(result, TopicAnalysis)
    assert result.topic == "Optics"
    assert result.degraded is True


# ==============================================================================
# 4. Text Generation Tests (Mocked Groq)
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_generate_notes_success():
    """Verify structured notes generation with Groq."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=200,
        json={
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "explanation": "Newton's laws explain the relationship between force and motion.",
                                "variable_breakdown": {"F": "Force (N)", "m": "Mass (kg)", "a": "Acceleration (m/s^2)"},
                                "formulas": ["F = m * a"],
                                "example": "A 5kg box pushed with 10N accelerates at 2m/s^2.",
                                "mistakes": ["Confusing mass and weight"],
                                "practice_questions": ["What force is needed to accelerate 10kg at 3m/s^2?"],
                                "summary": ["Force causes acceleration", "Inertia opposes change in motion"],
                                "resources": ["Khan Academy Newton's Laws"],
                            }
                        )
                    }
                }
            ],
            "usage": {"prompt_tokens": 200, "completion_tokens": 150, "total_tokens": 350},
        },
    )

    notes = await generate_notes("Mechanics", ["F", "m", "a"])

    assert isinstance(notes, NotesResponse)
    assert "Newton" in notes.explanation
    assert notes.variable_breakdown.get("F") == "Force (N)"
    assert notes.degraded is False


@pytest.mark.asyncio
@respx.mock
async def test_generate_notes_fallback():
    """Verify fallback notes when Groq request fails."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(status_code=503)

    notes = await generate_notes("Mechanics Uncached Fallback", ["F", "m", "a"])

    assert isinstance(notes, NotesResponse)
    assert notes.degraded is True
    assert len(notes.summary) > 0


@pytest.mark.asyncio
@respx.mock
async def test_generate_quiz_success():
    """Verify structured quiz generation with Groq."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=200,
        json={
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "topic": "Optics",
                                "difficulty": "mixed",
                                "questions": [
                                    {
                                        "question": "What happens to light during refraction?",
                                        "options": ["It bends", "It stops", "It reflects fully", "It changes color"],
                                        "correct_index": 0,
                                        "explanation": "Light bends when changing speed across media.",
                                        "takeaway": "Refraction is bending of light.",
                                    }
                                ],
                            }
                        )
                    }
                }
            ],
            "usage": {"prompt_tokens": 150, "completion_tokens": 100, "total_tokens": 250},
        },
    )

    quiz = await generate_quiz("Optics", num_questions=1)

    assert isinstance(quiz, QuizResponse)
    assert quiz.topic == "Optics"
    assert len(quiz.questions) == 1
    assert quiz.questions[0].correct_index == 0
    assert quiz.degraded is False


@pytest.mark.asyncio
@respx.mock
async def test_generate_quiz_fallback():
    """Verify fallback quiz returned on timeout or error."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        side_effect=httpx.TimeoutException("Mocked timeout")
    )

    quiz = await generate_quiz("Projectile Motion", num_questions=2)

    assert isinstance(quiz, QuizResponse)
    assert quiz.degraded is True
    assert len(quiz.questions) == 2


@pytest.mark.asyncio
@respx.mock
async def test_parse_param_update_success():
    """Verify simulation parameter parser updates values."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=200,
        json={
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "updated_parameters": {"velocity": 45.0, "angle": 30.0},
                                "ai_response": "I set the launch velocity to 45 m/s and angle to 30 degrees.",
                            }
                        )
                    }
                }
            ]
        },
    )

    result = await parse_param_update(
        template_id="projectile_motion",
        current_params={"velocity": 20.0, "angle": 45.0},
        user_prompt="make velocity 45 and angle 30",
    )

    assert isinstance(result, ParameterUpdateResponse)
    assert result.updated_parameters["velocity"] == 45.0
    assert result.updated_parameters["angle"] == 30.0
    assert result.degraded is False


@pytest.mark.asyncio
@respx.mock
async def test_tutor_chat_success():
    """Verify tutor chat returns response and parameter updates."""
    respx.post("https://api.groq.com/openai/v1/chat/completions").respond(
        status_code=200,
        json={
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "response": "Gravity accelerates all masses downward at 9.8 m/s².",
                                "parameter_updates": None,
                                "update_type": "explanation",
                            }
                        )
                    }
                }
            ]
        },
    )

    result = await tutor_chat(
        message="Why do objects fall at the same rate?",
        topic="Gravitation",
    )

    assert isinstance(result, TutorChatResponse)
    assert "9.8" in result.response
    assert result.update_type == "explanation"
    assert result.degraded is False


# ==============================================================================
# 5. Engine Repair Retry & Backoff Tests
# ==============================================================================


@pytest.mark.asyncio
@respx.mock
async def test_engine_repair_retry_on_invalid_json():
    """Verify engine performs ONE automatic repair retry when initial response is invalid JSON."""
    client = get_text_client()

    # Call 1: Returns invalid JSON
    # Call 2 (Repair): Returns valid JSON
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        side_effect=[
            httpx.Response(200, json={"choices": [{"message": {"content": "Not JSON at all"}}]}),
            httpx.Response(
                200,
                json={
                    "choices": [{"message": {"content": json.dumps({"topic": "Electricity", "variables": ["V", "I"]})}}]
                },
            ),
        ]
    )

    result = await call_groq_structured(
        client=client,
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": "analyze topic"}],
        schema=TopicAnalysis,
    )

    assert result is not None
    assert result.topic == "Electricity"
    assert "V" in result.variables


@pytest.mark.asyncio
@respx.mock
async def test_engine_rate_limit_backoff():
    """Verify engine handles 429 status code and retries."""
    client = get_text_client()

    # Call 1: 429 with Retry-After: 0.1
    # Call 2: 200 Success
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        side_effect=[
            httpx.Response(429, headers={"Retry-After": "0.1"}),
            httpx.Response(
                200,
                json={
                    "choices": [{"message": {"content": json.dumps({"topic": "Kinematics", "variables": ["v", "t"]})}}],
                    "usage": {"total_tokens": 50},
                },
            ),
        ]
    )

    result = await call_groq_structured(
        client=client,
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": "analyze topic"}],
        schema=TopicAnalysis,
    )

    assert result is not None
    assert result.topic == "Kinematics"


@pytest.mark.asyncio
async def test_topic_analysis_structured_variables_and_templates():
    """Verify structured variables extraction, sync, and mechanics templates."""
    from services.llm.vision import PhysicsVariable, TopicAnalysis, get_fallback_structured_data
    from services.visualiser_loader import get_template_by_topic

    # Test sync when structured_variables is supplied
    analysis = TopicAnalysis(
        topic="Projectile Motion",
        structured_variables=[
            PhysicsVariable(name="Initial Velocity", symbol="u", value=25.0, unit="m/s", is_target=False),
            PhysicsVariable(name="Maximum Height", symbol="H_max", value=None, unit="m", is_target=True),
        ],
        target_question="Find maximum height",
        latex_formula=r"H_{max} = \frac{u^2 \sin^2\theta}{2g}",
    )
    assert len(analysis.structured_variables) == 2
    assert "u=25.0m/s" in analysis.variables
    assert analysis.structured_variables[1].is_target is True

    # Test fallback structured variables
    struct_vars, target_q, latex = get_fallback_structured_data("projectile motion")
    assert len(struct_vars) >= 3
    assert target_q is not None
    assert "H" in latex

    # Test new templates loading
    incline_tmpl = await get_template_by_topic("inclined plane")
    assert incline_tmpl is not None
    assert incline_tmpl["template_id"] == "inclined_plane"

    pulley_tmpl = await get_template_by_topic("pulley")
    assert pulley_tmpl is not None
    assert pulley_tmpl["template_id"] == "pulley"

    collision_tmpl = await get_template_by_topic("collision")
    assert collision_tmpl is not None
    assert collision_tmpl["template_id"] == "collision"

    mechanics_tmpl = await get_template_by_topic("mechanics")
    assert mechanics_tmpl is not None
    assert mechanics_tmpl["template_id"] == "mechanics_2d"
