"""
Strict Specification & Behavioral Tests for the Stemly Multi-Agent Architecture.
These tests strictly evaluate physical correctness, mathematical invariants,
adversarial safety bounds, Socratic pedagogy, parallel execution, and SSE protocol compliance.
"""

import json
import math
import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services.agents import (
    build_orchestrator,
    get_orchestrator,
    run_orchestrated_tutor,
    stream_orchestrated_tutor,
)
from services.agents.math_solver import solve_deterministic_stem_math
from services.agents.pedagogy_assessor import assess_student_pedagogy
from services.agents.sim_controller import is_allowed_phet_url, resolve_simulation_action


# ==============================================================================
# 1. MATHEMATICAL INVARIANTS & PHYSICAL PRECISION
# ==============================================================================

def test_kinematics_numerical_invariants():
    """
    STRICT INVARIANT:
    v = 30 m/s, theta = 45 deg, g = 9.8 m/s^2
    vy = 30 * sin(45 deg) = 21.2132 m/s
    h_max = vy^2 / (2g) = 450 / 19.6 = 22.959 m (~22.96 m)
    R = (v^2 * sin(90 deg)) / g = 900 / 9.8 = 91.836 m (~91.84 m)
    T = (2 * vy) / g = 42.426 / 9.8 = 4.329 s (~4.33 s)
    """
    res = solve_deterministic_stem_math(
        query="A projectile is launched at a velocity of 30 m/s at an angle of 45 degrees",
        topic="projectile motion",
    )
    assert res is not None, "Failed to resolve standard kinematic query"
    results = res["exact_results"]

    assert math.isclose(results["max_height_m"], 22.96, abs_tol=0.05), f"Expected h_max ~ 22.96, got {results['max_height_m']}"
    assert math.isclose(results["horizontal_range_m"], 91.84, abs_tol=0.05), f"Expected range ~ 91.84, got {results['horizontal_range_m']}"
    assert math.isclose(results["time_of_flight_s"], 4.33, abs_tol=0.05), f"Expected flight time ~ 4.33, got {results['time_of_flight_s']}"
    assert math.isclose(results["initial_vx"], 21.21, abs_tol=0.05)
    assert math.isclose(results["initial_vy"], 21.21, abs_tol=0.05)


def test_kinematics_boundary_extremes():
    """STRICT INVARIANT: Horizontal launch (0 deg) has zero max height and flight time."""
    horizontal = solve_deterministic_stem_math(
        query="A ball launched horizontally at 25 m/s at an angle of 0 degrees",
        topic="projectile motion",
    )
    assert horizontal is not None
    assert horizontal["exact_results"]["max_height_m"] == 0.0
    assert horizontal["exact_results"]["time_of_flight_s"] == 0.0
    assert horizontal["exact_results"]["horizontal_range_m"] == 0.0

    # Vertical launch (90 deg) has zero horizontal range
    vertical = solve_deterministic_stem_math(
        query="Rocket launched vertically at speed of 40 m/s at 90 deg angle",
        topic="projectile motion",
    )
    assert vertical is not None
    assert vertical["exact_results"]["horizontal_range_m"] == 0.0
    # h_max = 40^2 / (2 * 9.8) = 1600 / 19.6 = 81.63 m
    assert math.isclose(vertical["exact_results"]["max_height_m"], 81.63, abs_tol=0.05)


def test_simple_harmonic_motion_pendulum():
    """
    STRICT INVARIANT:
    L = 2.45 m, g = 9.8 m/s^2
    T = 2 * pi * sqrt(2.45 / 9.8) = 2 * pi * sqrt(0.25) = pi ~ 3.14 s
    f = 1 / pi ~ 0.32 Hz
    """
    res = solve_deterministic_stem_math(
        query="Find the period of a simple pendulum with a length of 2.45 meters",
        topic="simple harmonic motion",
    )
    assert res is not None
    assert res["type"] == "simple_pendulum"
    assert math.isclose(res["exact_results"]["period_s"], 3.14, abs_tol=0.05)
    assert math.isclose(res["exact_results"]["frequency_hz"], 0.32, abs_tol=0.05)


def test_simple_harmonic_motion_spring_mass():
    """
    STRICT INVARIANT:
    m = 2.0 kg, k = 200.0 N/m
    T = 2 * pi * sqrt(2 / 200) = 2 * pi * 0.1 ~ 0.63 s
    f = 1 / 0.63 ~ 1.59 Hz
    """
    res = solve_deterministic_stem_math(
        query="Oscillating spring with mass of 2 kg and spring constant of 200 N/m",
        topic="harmonic oscillator",
    )
    assert res is not None
    assert res["type"] == "spring_mass_shm"
    assert math.isclose(res["exact_results"]["period_s"], 0.63, abs_tol=0.05)
    assert math.isclose(res["exact_results"]["frequency_hz"], 1.59, abs_tol=0.05)


def test_algebraic_quadratic_exact_roots():
    """STRICT INVARIANT: x^2 - 7x + 12 = 0 must yield exact roots 4.0 and 3.0."""
    res = solve_deterministic_stem_math(
        query="Solve quadratic equation 1x^2 - 7x + 12",
        topic="algebra",
    )
    assert res is not None
    assert res["type"] == "quadratic_roots"
    roots = {res["exact_results"]["root_1"], res["exact_results"]["root_2"]}
    assert roots == {4.0, 3.0}


# ==============================================================================
# 2. ADVERSARIAL INPUT & PARAMETER BOUND CLAMPING
# ==============================================================================

def test_adversarial_parameter_clamping():
    """STRICT INVARIANT: Out-of-bounds parameters MUST be clamped to safe physics ranges."""
    res = resolve_simulation_action(
        query="Set speed to 999999 and gravity to -500 and angle to 720",
        topic="projectile motion",
    )
    params = res["parameter_updates"]
    assert params["speed"] <= 500.0, "Speed overflow not clamped"
    assert params["gravity"] >= 0.1, "Negative gravity not clamped to physical minimum"
    assert -360.0 <= params["angle"] <= 360.0, "Angle not clamped"


def test_phet_url_security_strict_enforcement():
    """STRICT INVARIANT: Non-HTTPS, external domains, and directory traversals must be rejected."""
    valid_phet = "https://phet.colorado.edu/sims/html/projectile-motion/latest/projectile-motion_en.html"
    assert is_allowed_phet_url(valid_phet) is True

    # Insecure HTTP
    assert is_allowed_phet_url("http://phet.colorado.edu/sims/html/sim.html") is False
    # Phishing subdomains
    assert is_allowed_phet_url("https://phet.colorado.edu.evil.com/sims/html/sim.html") is False
    # Invalid root path / administrative URLs
    assert is_allowed_phet_url("https://phet.colorado.edu/admin/login") is False
    # Non-string / None / Empty
    assert is_allowed_phet_url(None) is False
    assert is_allowed_phet_url("") is False


# ==============================================================================
# 3. SOCRATIC PEDAGOGY & MISCONCEPTION DETECTION
# ==============================================================================

@pytest.mark.parametrize("query,expected_misconception", [
    ("Does a 10kg mass fall faster than a 1kg mass?", "Free Fall Mass Independence"),
    ("If a heavy rock and light rock are dropped, why does the heavy rock fall faster?", "Free Fall Mass Independence"),
    ("At maximum height, is the acceleration zero?", "Kinematics Peak Acceleration"),
    ("Why is acceleration 0 at the peak of the throw?", "Kinematics Peak Acceleration"),
    ("Do you need a constant force to keep an object moving in space?", "Newton's First Law / Inertia"),
    ("Why does centrifugal force push me to the outside of the curve?", "Centripetal vs Centrifugal"),
])
def test_pedagogy_misconception_detection_diversity(query, expected_misconception):
    """STRICT INVARIANT: Common student physics misconceptions must be explicitly flagged."""
    res = assess_student_pedagogy(query)
    assert res["has_misconception"] is True, f"Failed to detect misconception in: {query}"
    assert res["misconception_name"] == expected_misconception
    assert res["scaffolding_tier"] == "misconception_intervention"
    assert "socratic_strategy" in res
    assert len(res["socratic_strategy"]) > 10


# ==============================================================================
# 4. PARALLEL ORCHESTRATION & STATE COMPLETENESS
# ==============================================================================

def test_orchestration_topology():
    """STRICT INVARIANT: Graph must have router, 3 parallel workers, and synthesizer."""
    graph = get_orchestrator()
    nodes = set(graph.nodes.keys())
    assert {"router", "worker_math", "worker_sim", "worker_pedagogy", "synthesizer"}.issubset(nodes)


@pytest.mark.asyncio
async def test_end_to_end_orchestration_contract():
    """
    STRICT INVARIANT:
    Full graph execution must return:
    - Non-empty final Socratic explanation
    - Isolated math results
    - Isolated simulation action
    - Isolated pedagogical cues
    - Exactly 3 follow-up question chips
    """
    result = await run_orchestrated_tutor(
        query="If launch velocity is 25 m/s at 45 degrees, what is maximum height and update simulation?",
        topic="projectile motion",
        student_id="student_strict_01",
    )
    assert result is not None
    assert "final_response" in result and len(result["final_response"]) > 0
    assert result["math_result"] is not None
    assert result["sim_action"] is not None
    assert result["pedagogical_cues"] is not None

    followups = result.get("suggested_followups", [])
    assert len(followups) == 3, f"Expected exactly 3 follow-up chips, got {len(followups)}"
    for chip in followups:
        assert isinstance(chip, str) and len(chip.strip()) > 0


# ==============================================================================
# 5. REAL-TIME SERVER-SENT EVENTS (SSE) PROTOCOL COMPLIANCE
# ==============================================================================

@pytest.mark.asyncio
async def test_sse_streaming_protocol_strict():
    """
    STRICT INVARIANT:
    SSE output must strictly conform to:
    - Every event line starts with 'data: ' and ends with '\\n\\n'
    - 'sim_update' is emitted early for interactive UI
    - 'token' contains synthesized text
    - 'meta' contains array of 3 suggested follow-up chips
    - Concludes with 'data: [DONE]\\n\\n'
    """
    chunks = []
    async for chunk in stream_orchestrated_tutor(
        query="What is the trajectory of a projectile launched at 20 m/s at 30 deg?",
        topic="projectile motion",
        student_id="student_strict_02",
    ):
        chunks.append(chunk)

    assert len(chunks) > 0, "No SSE chunks generated"
    assert chunks[-1] == "data: [DONE]\n\n", "Stream did not terminate with standard [DONE] sentinel"

    types_received = set()
    for chunk in chunks[:-1]:
        assert chunk.startswith("data: "), f"Malformed SSE chunk: {chunk}"
        assert chunk.endswith("\n\n"), f"Chunk missing double newline: {chunk}"
        payload_str = chunk[6:-2]
        payload = json.loads(payload_str)
        assert "type" in payload
        types_received.add(payload["type"])

    assert "token" in types_received, "Stream failed to emit token event"
    assert "meta" in types_received, "Stream failed to emit meta event"


# ==============================================================================
# 6. FASTAPI ENDPOINT CONTRACT & AUTHENTICATION
# ==============================================================================

@pytest.mark.asyncio
async def test_chat_agent_route_unauthenticated():
    """STRICT INVARIANT: Unauthenticated calls must be rejected (401 or 403)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/chat/agent",
            json={"user_prompt": "What is acceleration?", "topic": "physics"},
        )
        assert resp.status_code in (401, 403), f"Expected 401/403, got {resp.status_code}"


@pytest.mark.asyncio
async def test_chat_agent_route_authenticated(auth_headers):
    """STRICT INVARIANT: Authenticated calls must return 200 with structured ChatResponse."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/chat/agent",
            headers=auth_headers,
            json={
                "user_prompt": "A ball is launched at velocity of 20 m/s at an angle of 45 degrees",
                "topic": "projectile motion",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "response" in data and len(data["response"]) > 0
        assert "suggested_followups" in data and len(data["suggested_followups"]) == 3
        assert "parameter_updates" in data
        assert "degraded" in data


@pytest.mark.asyncio
async def test_chat_transcribe_audio_route(auth_headers, monkeypatch):
    """STRICT INVARIANT: Authenticated audio upload returns transcribed student text."""
    async def mock_transcribe(file_bytes, filename="recording.m4a", language="en", prompt=None):
        return {
            "text": "Calculate the trajectory of a projectile launched at 25 meters per second",
            "duration": 3.42,
            "language": "en",
            "degraded": False,
        }

    monkeypatch.setattr("routers.chat.transcribe_audio", mock_transcribe)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Unauthenticated test
        resp_unauth = await client.post(
            "/chat/transcribe",
            files={"file": ("test.m4a", b"fake-audio-binary-data", "audio/m4a")},
        )
        assert resp_unauth.status_code in (401, 403)

        # 2. Authenticated test
        resp = await client.post(
            "/chat/transcribe",
            headers=auth_headers,
            files={"file": ("test.m4a", b"fake-audio-binary-data", "audio/m4a")},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "trajectory" in data["text"]
        assert data["duration"] == 3.42
        assert data["language"] == "en"
        assert data["degraded"] is False

        # 3. Empty audio test
        resp_empty = await client.post(
            "/chat/transcribe",
            headers=auth_headers,
            files={"file": ("empty.m4a", b"", "audio/m4a")},
        )
        assert resp_empty.status_code == 400

