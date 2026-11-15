"""
Context Window and Conversational Memory Manager for AI STEM Tutor.
Implements:
- Fast token estimation
- Token-budget-aware sliding window
- Progressive pedagogical summarization of older conversational turns
- Context injection preserving student misconceptions and parameter states
"""

import logging
from typing import Any, Dict, List, Optional, Tuple

from config import settings

logger = logging.getLogger("stemly.llm.context_manager")

# Default token budget for conversation history inside context window
DEFAULT_MAX_CONTEXT_TOKENS = settings.CHAT_MAX_CONTEXT_TOKENS
DEFAULT_MAX_HISTORY_TURNS = 12


def estimate_tokens(text: str) -> int:
    """
    Fast, safe heuristic token estimation for OpenAI/Groq tokenizers.
    Applies ~3.8 characters per token with a minimum floor of 1.
    """
    if not text:
        return 0
    # Average across English, mathematical formulas, and JSON
    return max(1, int(len(text) / 3.8) + 1)


def build_conversation_context(
    system_prompt: str,
    history: Optional[List[Dict[str, Any]]],
    user_query: str,
    max_context_tokens: int = DEFAULT_MAX_CONTEXT_TOKENS,
    existing_summary: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """
    Constructs an optimized message array for LLM completions within a strict token budget.
    Returns: (messages, updated_summary)

    Strategy:
    1. System prompt and current user query are mandatory.
    2. Available budget is allocated to recent turns from newest to oldest.
    3. Overflow turns that exceed the budget are condensed into a rolling pedagogical summary.
    """
    sys_tokens = estimate_tokens(system_prompt)
    query_tokens = estimate_tokens(user_query)
    reserved_tokens = sys_tokens + query_tokens

    # Usable budget for history
    history_budget = max(200, max_context_tokens - reserved_tokens)

    if not history:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_query},
        ]
        return messages, existing_summary

    normalized_history: List[Dict[str, str]] = []
    for turn in history:
        role = turn.get("role") or ("user" if turn.get("isUser") else "assistant")
        content = str(turn.get("content") or turn.get("text") or "").strip()
        if content:
            normalized_history.append({"role": role, "content": content})

    # Walk backwards from most recent turns to fit within history_budget
    included_turns: List[Dict[str, str]] = []
    overflow_turns: List[Dict[str, str]] = []
    used_tokens = 0

    for turn in reversed(normalized_history):
        t_tokens = estimate_tokens(turn["content"]) + 4  # +4 for role framing overhead
        if used_tokens + t_tokens <= history_budget and len(included_turns) < DEFAULT_MAX_HISTORY_TURNS:
            included_turns.append(turn)
            used_tokens += t_tokens
        else:
            overflow_turns.append(turn)

    # Reverse back to chronological order
    included_turns.reverse()
    overflow_turns.reverse()

    # If older turns overflowed, compress them into summary
    rolling_summary = existing_summary
    if overflow_turns:
        summary_snippets = []
        for t in overflow_turns[-6:]:  # Condense key points from up to 6 oldest turns
            role_label = "Student" if t["role"] == "user" else "Tutor"
            snippet = t["content"][:100] + ("..." if len(t["content"]) > 100 else "")
            summary_snippets.append(f"{role_label}: {snippet}")

        new_summary_text = " | ".join(summary_snippets)
        if rolling_summary:
            rolling_summary = f"{rolling_summary} -> {new_summary_text}"
        else:
            rolling_summary = f"Earlier discussion: {new_summary_text}"

        # Keep summary bounded
        if len(rolling_summary) > 600:
            rolling_summary = "Earlier discussion: ..." + rolling_summary[-550:]

    messages = [{"role": "system", "content": system_prompt}]

    # Inject pedagogical rolling summary if present
    if rolling_summary:
        messages.append({
            "role": "system",
            "content": f"[Context Memory Note: {rolling_summary}]",
        })

    # Add preserved recent turns
    for turn in included_turns:
        messages.append({"role": turn["role"], "content": turn["content"]})

    # Append active user query
    messages.append({"role": "user", "content": user_query})

    return messages, rolling_summary
