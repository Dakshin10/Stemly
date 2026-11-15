"""
Comprehensive tests for Streaming Protocol v2:
- Versioned envelope {v: 1, id, seq, type, data}
- Immediate meta event as seq 0
- Monotonic sequence ordering
- Required SSE response headers (Cache-Control, X-Accel-Buffering, Connection, Content-Encoding: identity)
- Usage and Done events
- Mid-stream failure envelope with error and finish_reason: error
- Client disconnect cancellation
- Idempotency-Key duplicate prevention (409 Conflict)
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services.llm.text import stream_tutor_chat


class MockStreamResponse:
    def __init__(self, lines, status_code=200):
        self.lines = lines
        self.status_code = status_code

    async def aiter_lines(self):
        for line in self.lines:
            yield line

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass


@pytest.fixture
def auth_headers():
    return {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
    }


@pytest.mark.asyncio
async def test_streaming_protocol_v2_envelope_and_headers(auth_headers):
    transport = ASGITransport(app=app)

    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Momentum "}}]}',
        'data: {"choices": [{"delta": {"content": "equals mass times velocity."}}]}',
        'data: {"usage": {"prompt_tokens": 20, "completion_tokens": 8}}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        async with AsyncClient(transport=transport, base_url="http://test") as client:
            payload = {
                "user_prompt": "What is momentum?",
                "topic": "Momentum",
                "variables": ["p=mv"],
                "history": [],
            }

            response = await client.post("/chat/stream", json=payload, headers=auth_headers)
            assert response.status_code == 200

            # Check required SSE headers
            assert "text/event-stream" in response.headers["content-type"]
            assert response.headers.get("cache-control") == "no-cache"
            assert response.headers.get("x-accel-buffering") == "no"
            assert response.headers.get("connection") == "keep-alive"
            assert response.headers.get("content-encoding") == "identity"

            # Parse SSE lines
            text_body = response.text
            lines = [line for line in text_body.split("\n") if line.startswith("data: ")]
            assert len(lines) >= 3

            events = [json.loads(l[6:]) for l in lines]

            # Verify envelope structure
            for e in events:
                assert e["v"] == 1
                assert "id" in e and len(e["id"]) > 0
                assert "seq" in e and isinstance(e["seq"], int)
                assert "type" in e
                assert "data" in e

            # First event must be meta at seq 0
            first_event = events[0]
            assert first_event["seq"] == 0
            assert first_event["type"] == "meta"
            assert "request_id" in first_event["data"]
            assert "model" in first_event["data"]
            assert "created_at" in first_event["data"]

            # Ensure seq numbers are strictly monotonic
            seqs = [e["seq"] for e in events]
            assert seqs == sorted(seqs)
            assert len(seqs) == len(set(seqs))

            # Check for token, followups, usage and done events
            event_types = [e["type"] for e in events]
            assert "token" in event_types
            assert "followups" in event_types
            assert "usage" in event_types
            assert "done" in event_types

            # Verify usage payload metrics
            usage_event = next(e for e in events if e["type"] == "usage")
            assert "latency_ms" in usage_event["data"]
            assert "ttft_ms" in usage_event["data"]
            assert usage_event["data"]["total_tokens"] > 0


@pytest.mark.asyncio
async def test_idempotency_key_duplicate_prevention(auth_headers):
    transport = ASGITransport(app=app)
    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Angular velocity is the rate of rotation."}}]}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        async with AsyncClient(transport=transport, base_url="http://test") as client:
            payload = {
                "user_prompt": "Explain angular velocity",
                "topic": "Rotation",
                "variables": ["omega=v/r"],
                "history": [],
            }
            headers = {**auth_headers, "Idempotency-Key": "unique-idem-test-9999"}

            # First attempt succeeds
            resp1 = await client.post("/chat/stream", json=payload, headers=headers)
            assert resp1.status_code == 200

            # Duplicate attempt with the same idempotency key is rejected
            resp2 = await client.post("/chat/stream", json=payload, headers=headers)
            assert resp2.status_code == 409
            error_data = resp2.json()["error"]
            assert "Idempotency-Key" in error_data["message"]


@pytest.mark.asyncio
async def test_disconnect_cancels_stream_generation():
    """Verify stream generator exits immediately when client disconnect is detected."""
    is_disconnected_called = False

    async def mock_is_disconnected():
        nonlocal is_disconnected_called
        is_disconnected_called = True
        return True

    events = []
    async for env in stream_tutor_chat(
        message="Calculate centripetal acceleration",
        topic="Circular Motion",
        is_disconnected_fn=mock_is_disconnected,
    ):
        events.append(env)

    # Should only emit meta (seq 0) before noticing disconnection and exiting cleanly
    assert len(events) == 1
    assert events[0].type == "meta"
    assert is_disconnected_called is True


@pytest.mark.asyncio
async def test_stream_error_envelope_does_not_leak_traces():
    """Verify mid-stream upstream exceptions emit structured error and done envelopes without traces."""
    with patch("services.llm.text.get_text_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.stream.side_effect = RuntimeError("Sensitive DB Connection String In Stack Trace")
        mock_get_client.return_value = mock_client

        events = []
        async for env in stream_tutor_chat(
            message="Explain Lenz's Law",
            topic="Electromagnetism",
        ):
            events.append(env)

        assert len(events) >= 2
        error_event = next(e for e in events if e.type == "error")
        assert error_event.data["code"] == "stream_internal_error"
        assert "Sensitive" not in error_event.data["message"]
        assert error_event.data["retryable"] is True

        done_event = events[-1]
        assert done_event.type == "done"
        assert done_event.data["finish_reason"] == "error"
