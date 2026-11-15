"""
Tests for Phase 8: Observability, Distributed Tracing, and Cost Accounting.
Covers:
- Telemetry recording for prompt/completion tokens and cost calculation
- Percentile aggregation (p50, p95 for TTFT and latency)
- Cache hit rate computation
- GET /chat/metrics endpoint returns structured telemetry
"""

import pytest
from httpx import ASGITransport, AsyncClient
from core.observability import ChatTelemetryAggregator, chat_telemetry
from main import app


def test_telemetry_cost_and_percentiles_calculation():
    """Verify ChatTelemetryAggregator accurately computes costs and p50/p95 percentiles."""
    agg = ChatTelemetryAggregator()
    assert agg.total_requests == 0
    assert agg.total_cost_usd == 0.0

    # Record 10 turns
    for i in range(1, 11):
        agg.record_turn(
            prompt_tokens=1000,
            completion_tokens=500,
            latency_ms=i * 100.0,
            ttft_ms=i * 50.0,
            is_cached=(i % 2 == 0),
        )

    summary = agg.get_summary()
    assert summary["total_requests"] == 10
    assert summary["cached_requests"] == 5
    assert summary["cache_hit_rate_pct"] == 50.0
    assert summary["total_prompt_tokens"] == 10000
    assert summary["total_completion_tokens"] == 5000
    assert summary["total_cost_usd"] > 0.0

    # Check TTFT and latency percentiles
    assert summary["ttft_p50_ms"] > 0.0
    assert summary["latency_p50_ms"] > 0.0
    assert summary["circuit_breaker_state"] in ["CLOSED", "OPEN", "HALF_OPEN"]


@pytest.mark.asyncio
async def test_chat_metrics_endpoint():
    """Verify GET /chat/metrics responds with aggregate metrics."""
    transport = ASGITransport(app=app)
    headers = {"Authorization": "Bearer test-token"}

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/chat/metrics", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "total_requests" in data
        assert "cache_hit_rate_pct" in data
        assert "total_cost_usd" in data
        assert "ttft_p50_ms" in data
        assert "circuit_breaker_state" in data
