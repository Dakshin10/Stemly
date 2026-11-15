"""
Tests for Phase 5: Multi-Tier Caching & Latency Optimization.
Covers:
- Normalized hashing for topic and query (strips punctuation, whitespace, casing)
- In-memory LRU cache hit/miss behavior
- Sub-15ms cached stream replay in Streaming Protocol v2
"""

import pytest
from services.llm.cache import (
    compute_tutor_cache_key,
    get_cached_tutor,
    set_cached_tutor,
)
from services.llm.text import stream_tutor_chat


def test_tutor_cache_key_normalization():
    """Verify equivalent queries with differing casing, punctuation, and spacing map to identical keys."""
    k1 = compute_tutor_cache_key("Projectile Motion", "What is the formula for range?")
    k2 = compute_tutor_cache_key("projectile   motion", "what is the formula for range???")
    k3 = compute_tutor_cache_key("PROJECTILE MOTION", "what   is the formula for range")
    assert k1 == k2 == k3


@pytest.mark.asyncio
async def test_tutor_cache_get_and_set():
    """Verify caching in-memory stores and retrieves structured response dicts."""
    topic = "Thermodynamics"
    query = "State the first law of thermodynamics"

    # Cache miss
    miss = await get_cached_tutor(topic, query)
    assert miss is None

    # Populate cache
    payload = {
        "response": "Energy cannot be created or destroyed, only transformed: $\\Delta U = Q - W$.",
        "parameter_updates": {"delta_u": 0.0},
        "suggested_followups": ["What is an adiabatic process?", "Define enthalpy", "Explain work in PV diagram"],
    }
    await set_cached_tutor(topic, query, payload)

    # Cache hit
    hit = await get_cached_tutor(topic, query)
    assert hit is not None
    assert hit["response"] == payload["response"]
    assert hit["parameter_updates"]["delta_u"] == 0.0


@pytest.mark.asyncio
async def test_stream_tutor_chat_instant_cache_replay():
    """Verify stream_tutor_chat serves cached turns with TTFT < 15ms and full Protocol v2 envelope."""
    topic = "Classical Mechanics"
    query = "What is inertia?"
    cached_payload = {
        "response": "Inertia is the tendency of an object to resist changes in its state of motion ($F=0 \\implies a=0$).",
        "parameter_updates": {"mass": 10.0},
        "suggested_followups": ["What is Newton's first law?", "How does mass relate to inertia?", "Explain inertial frames"],
    }
    await set_cached_tutor(topic, query, cached_payload)

    events = []
    async for env in stream_tutor_chat(
        message=query,
        topic=topic,
        history=[],
    ):
        events.append(env)

    types = [e.type for e in events]
    assert "meta" in types
    assert "token" in types
    assert "parameters" in types
    assert "followups" in types
    assert "usage" in types
    assert "done" in types

    usage_event = next(e for e in events if e.type == "usage")
    # Measured TTFT should be ultra-low (< 15ms)
    assert usage_event.data["ttft_ms"] < 15.0
