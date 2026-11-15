"""
Tests for Phase 6: Circuit Breaker & Resilience Modes.
Covers:
- Circuit breaker state machine (CLOSED -> OPEN -> HALF_OPEN -> CLOSED)
- Failure threshold tripping
- Cooldown expiration and probe recovery
- Fast degraded mode stream execution when circuit is OPEN
"""

import time
import pytest
from core.circuit_breaker import CircuitBreaker, CircuitState
from services.llm.text import stream_tutor_chat


def test_circuit_breaker_state_transitions():
    """Verify circuit breaker trips to OPEN after threshold and recovers via HALF_OPEN."""
    cb = CircuitBreaker(name="test_cb", failure_threshold=3, cooldown_seconds=0.1)
    assert cb.state == CircuitState.CLOSED
    assert cb.can_execute() is True

    # 1st failure
    cb.record_failure()
    assert cb.state == CircuitState.CLOSED

    # 2nd failure
    cb.record_failure()
    assert cb.state == CircuitState.CLOSED

    # 3rd failure trips the circuit
    cb.record_failure()
    assert cb.state == CircuitState.OPEN
    assert cb.can_execute() is False

    # Wait for cooldown
    time.sleep(0.15)
    # State should now be HALF_OPEN
    assert cb.state == CircuitState.HALF_OPEN
    assert cb.can_execute() is True

    # Successful probe restores to CLOSED
    cb.record_success()
    assert cb.state == CircuitState.CLOSED
    assert cb.can_execute() is True


def test_circuit_breaker_half_open_failure_re_trips():
    """Verify failure during probe in HALF_OPEN immediately re-trips back to OPEN."""
    cb = CircuitBreaker(name="test_cb2", failure_threshold=2, cooldown_seconds=0.05)
    cb.record_failure()
    cb.record_failure()
    assert cb.state == CircuitState.OPEN

    time.sleep(0.06)
    assert cb.state == CircuitState.HALF_OPEN

    # Probe fails -> immediately re-trips to OPEN
    cb.record_failure()
    assert cb.state == CircuitState.OPEN
    assert cb.can_execute() is False


@pytest.mark.asyncio
async def test_stream_tutor_chat_fast_degraded_fallback_when_open():
    """Verify stream_tutor_chat yields degraded explanation fast when circuit breaker is tripped."""
    from core.circuit_breaker import groq_circuit_breaker

    try:
        # Trip the global circuit breaker
        for _ in range(groq_circuit_breaker.failure_threshold):
            groq_circuit_breaker.record_failure()

        assert groq_circuit_breaker.state == CircuitState.OPEN

        events = []
        async for env in stream_tutor_chat(
            message="Calculate trajectory height",
            topic="Kinematics",
        ):
            events.append(env)

        types = [e.type for e in events]
        assert types == ["meta", "token", "followups", "usage", "done"]

        token_event = next(e for e in events if e.type == "token")
        assert "degraded mode" in token_event.data["delta"]

        usage_event = next(e for e in events if e.type == "usage")
        assert usage_event.data["ttft_ms"] < 20.0
    finally:
        # Restore circuit breaker
        groq_circuit_breaker.reset()
        assert groq_circuit_breaker.state == CircuitState.CLOSED
