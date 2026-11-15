"""
Tests for Phase 3: Context Window & Memory Management.
Covers:
- Fast token estimation
- Token-budget-aware sliding window
- Progressive pedagogical summarization of overflow turns
- Session history persistence (in-memory & db)
"""

import pytest
from database.chat_history import get_session_history, save_session_turn
from services.llm.context_manager import (
    DEFAULT_MAX_CONTEXT_TOKENS,
    build_conversation_context,
    estimate_tokens,
)


def test_estimate_tokens():
    """Verify heuristic token counting matches expected density."""
    assert estimate_tokens("") == 0
    assert estimate_tokens("hello") >= 1
    # ~380 chars should be ~100 tokens
    long_text = "a" * 380
    assert 90 <= estimate_tokens(long_text) <= 110


def test_build_conversation_context_fits_in_budget():
    """Verify short conversation histories are fully preserved without summarization."""
    sys_prompt = "You are an AI physics tutor."
    user_query = "What is gravity?"
    history = [
        {"role": "user", "content": "Hello"},
        {"role": "assistant", "content": "Hi! Ready to learn physics?"},
    ]

    messages, summary = build_conversation_context(
        system_prompt=sys_prompt,
        history=history,
        user_query=user_query,
        max_context_tokens=1000,
    )

    assert len(messages) == 4
    assert messages[0]["content"] == sys_prompt
    assert messages[1]["content"] == "Hello"
    assert messages[2]["content"] == "Hi! Ready to learn physics?"
    assert messages[3]["content"] == user_query
    assert summary is None


def test_build_conversation_context_sliding_window_and_summarization():
    """Verify long conversation histories exceeding budget are pruned with rolling summary."""
    sys_prompt = "You are an AI tutor."
    user_query = "What happens to the apex?"
    
    # Generate 25 verbose turns
    history = []
    for i in range(25):
        history.append({"role": "user", "content": f"Turn {i}: How does variable v{i} impact velocity?"})
        history.append({"role": "assistant", "content": f"Explanation for turn {i}: The variable v{i} determines kinetic energy."})

    # Strict token budget of 500 tokens
    messages, summary = build_conversation_context(
        system_prompt=sys_prompt,
        history=history,
        user_query=user_query,
        max_context_tokens=500,
    )

    # Must contain system prompt, summary note, recent turns, and user query
    assert len(messages) < len(history)
    assert messages[0]["content"] == sys_prompt
    assert "Context Memory Note" in messages[1]["content"]
    assert messages[-1]["content"] == user_query
    assert summary is not None
    assert "Earlier discussion:" in summary


@pytest.mark.asyncio
async def test_session_history_persistence_in_memory():
    """Verify session turns and summaries can be stored and retrieved."""
    session_id = "test-sess-uuid-777"
    user_turn = {"role": "user", "content": "What is torque?"}
    assistant_turn = {"role": "assistant", "content": "Torque is rotational force."}

    await save_session_turn(
        session_id=session_id,
        user_turn=user_turn,
        assistant_turn=assistant_turn,
        summary="Student asked about rotational mechanics.",
    )

    turns, summary = await get_session_history(session_id)
    assert len(turns) == 2
    assert turns[0]["content"] == "What is torque?"
    assert turns[1]["content"] == "Torque is rotational force."
    assert summary == "Student asked about rotational mechanics."
