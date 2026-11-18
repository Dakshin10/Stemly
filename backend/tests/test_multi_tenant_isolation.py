import jwt
import pytest
from httpx import ASGITransport, AsyncClient

from database.chat_history import get_session_history, save_session_turn
from main import app


def _make_user_token(uid: str, email: str) -> str:
    # 32+ bytes secret for SHA-256
    secret = "a_very_secure_test_secret_key_32_bytes_long!"
    return jwt.encode({"user_id": uid, "sub": uid, "email": email}, secret, algorithm="HS256")


@pytest.mark.asyncio
async def test_notes_endpoint_requires_auth():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Without auth -> 401
        res = await client.get("/notes")
        assert res.status_code == 401

        # With auth -> 200
        res_auth = await client.get("/notes", headers={"Authorization": "Bearer test-token"})
        assert res_auth.status_code == 200
        data = res_auth.json()
        assert "notes" in data
        assert "total" in data
        assert "limit" in data
        assert "has_more" in data


@pytest.mark.asyncio
async def test_multi_tenant_data_isolation(monkeypatch):
    """
    Guarantees strict tenant data isolation:
    User A can never access or view User B's scans or notes.
    """
    # In-memory tenant stores
    mock_db_scans = [
        {"user_id": "student-alice-456", "topic": "Alice's Quantum Tunneling", "_id": "1"},
        {"user_id": "student-bob-789", "topic": "Bob's Organic Chemistry", "_id": "2"},
    ]
    mock_db_notes = [
        {"user_id": "student-alice-456", "topic": "Alice's Quantum Notes", "_id": "10"},
        {"user_id": "student-bob-789", "topic": "Bob's Chemistry Notes", "_id": "20"},
    ]

    async def mock_get_user_history(user_id: str, limit: int = 20, skip: int = 0):
        user_scans = [s for s in mock_db_scans if s["user_id"] == user_id]
        return user_scans, len(user_scans)

    async def mock_get_user_notes(user_id: str, limit: int = 20, skip: int = 0):
        user_notes = [n for n in mock_db_notes if n["user_id"] == user_id]
        return user_notes, len(user_notes)

    monkeypatch.setattr("routers.scan.get_user_history_paginated", mock_get_user_history)
    monkeypatch.setattr("routers.notes.get_notes_for_user_paginated", mock_get_user_notes)

    token_a = _make_user_token("student-alice-456", "alice@stemly.app")
    token_b = _make_user_token("student-bob-789", "bob@stemly.app")

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Query Scans
        res_a_scans = await client.get("/scan/history", headers=headers_a)
        assert res_a_scans.status_code == 200
        alice_scans = res_a_scans.json().get("history", [])
        alice_scan_topics = [s.get("topic") for s in alice_scans]
        assert "Alice's Quantum Tunneling" in alice_scan_topics
        assert "Bob's Organic Chemistry" not in alice_scan_topics

        res_b_scans = await client.get("/scan/history", headers=headers_b)
        assert res_b_scans.status_code == 200
        bob_scans = res_b_scans.json().get("history", [])
        bob_scan_topics = [s.get("topic") for s in bob_scans]
        assert "Bob's Organic Chemistry" in bob_scan_topics
        assert "Alice's Quantum Tunneling" not in bob_scan_topics

        # 2. Query Notes
        res_a_notes = await client.get("/notes", headers=headers_a)
        assert res_a_notes.status_code == 200
        alice_notes = res_a_notes.json().get("notes", [])
        alice_note_topics = [n.get("topic") for n in alice_notes]
        assert "Alice's Quantum Notes" in alice_note_topics
        assert "Bob's Chemistry Notes" not in alice_note_topics

        res_b_notes = await client.get("/notes", headers=headers_b)
        assert res_b_notes.status_code == 200
        bob_notes = res_b_notes.json().get("notes", [])
        bob_note_topics = [n.get("topic") for n in bob_notes]
        assert "Bob's Chemistry Notes" in bob_note_topics
        assert "Alice's Quantum Notes" not in bob_note_topics


@pytest.mark.asyncio
async def test_chat_session_user_isolation():
    """Verifies chat history turns with user_id cannot be read across user tenants."""
    session_id = "test-isolated-chat-session-001"

    await save_session_turn(
        session_id=session_id,
        user_turn={"role": "user", "content": "Hello Tutor Alice"},
        assistant_turn={"role": "assistant", "content": "Hello Alice!"},
        summary="Alice introductory turn",
        user_id="student-alice-456",
    )

    # Alice retrieving her own session -> gets turns
    alice_turns, alice_summary = await get_session_history(session_id, user_id="student-alice-456")
    assert len(alice_turns) == 2
    assert alice_summary == "Alice introductory turn"

    # Bob attempting to read Alice's session -> gets empty
    bob_turns, bob_summary = await get_session_history(session_id, user_id="student-bob-789")
    assert bob_turns == []
    assert bob_summary is None
