"""
Tests for ChatGPT-grade AI STEM tutor:
- Multi-turn conversation history
- Dynamic follow-up chips
- Server-Sent Events (SSE) streaming endpoint (/chat/stream)
"""

import json

import pytest
from httpx import ASGITransport, AsyncClient

from main import app


@pytest.fixture
def auth_headers():
    return {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
    }


@pytest.mark.asyncio
async def test_chat_ask_with_history_and_followups(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "user_prompt": "What if we double the velocity?",
            "topic": "projectile",
            "variables": ["u=20m/s", "theta=45deg"],
            "current_params": {"speed": 20.0, "angle": 45.0},
            "history": [
                {"role": "user", "content": "What is the maximum height?"},
                {"role": "assistant", "content": "The maximum height is H = (u^2 sin^2 theta) / (2g)."},
            ],
        }

        response = await client.post("/chat/ask", json=payload, headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "suggested_followups" in data
        assert isinstance(data["suggested_followups"], list)
        assert len(data["suggested_followups"]) > 0


@pytest.mark.asyncio
async def test_chat_stream_sse_endpoint(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "user_prompt": "Explain gravity in projectile motion",
            "topic": "projectile",
            "variables": ["g=9.8m/s^2"],
            "history": [],
        }

        response = await client.post("/chat/stream", json=payload, headers=auth_headers)
        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]

        # Verify stream lines have data: prefixes
        text_body = response.text
        lines = [line for line in text_body.split("\n") if line.startswith("data: ")]
        assert len(lines) >= 1

        # Parse SSE events
        events = []
        for line in lines:
            try:
                event_data = json.loads(line[6:])
                events.append(event_data)
            except json.JSONDecodeError:
                pass

        event_types = [e.get("type") for e in events]
        assert "token" in event_types or "followups" in event_types or "done" in event_types
