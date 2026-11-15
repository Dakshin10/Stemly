"""
Session History and Rolling Summary Persistence.
Supports:
- MongoDB Atlas collection (sessions) when configured
- In-memory fallback for local development or disconnected mode
- Session summary retention across turns
"""

import logging
import time
from typing import Any, Dict, List, Optional, Tuple
from database.db import db

logger = logging.getLogger("stemly.database.chat_history")

sessions_collection = db["chat_sessions"] if db is not None else None

# In-memory storage: session_id -> {turns: [...], summary: str, updated_at: float}
_IN_MEMORY_SESSIONS: Dict[str, Dict[str, Any]] = {}


async def get_session_history(session_id: str) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """Retrieves session turns and rolling summary."""
    if not session_id:
        return [], None

    # Check MongoDB collection if available
    if sessions_collection is not None:
        try:
            doc = await sessions_collection.find_one({"session_id": session_id})
            if doc:
                return doc.get("turns", []), doc.get("summary")
        except Exception as exc:
            logger.warning("MongoDB error fetching session %s: %s", session_id, exc)

    # In-memory fallback
    entry = _IN_MEMORY_SESSIONS.get(session_id)
    if entry:
        return entry.get("turns", []), entry.get("summary")

    return [], None


async def save_session_turn(
    session_id: str,
    user_turn: Dict[str, str],
    assistant_turn: Dict[str, str],
    summary: Optional[str] = None,
) -> None:
    """Appends conversational turn pair to session history and updates rolling summary."""
    if not session_id:
        return

    now = time.time()
    turns_to_append = [user_turn, assistant_turn]

    # In-memory record
    if session_id not in _IN_MEMORY_SESSIONS:
        _IN_MEMORY_SESSIONS[session_id] = {
            "session_id": session_id,
            "turns": [],
            "summary": summary,
            "updated_at": now,
        }
    _IN_MEMORY_SESSIONS[session_id]["turns"].extend(turns_to_append)
    if summary:
        _IN_MEMORY_SESSIONS[session_id]["summary"] = summary
    _IN_MEMORY_SESSIONS[session_id]["updated_at"] = now

    # MongoDB persistence
    if sessions_collection is not None:
        try:
            update_data: Dict[str, Any] = {
                "$push": {"turns": {"$each": turns_to_append}},
                "$set": {"updated_at": now},
            }
            if summary:
                update_data["$set"]["summary"] = summary

            await sessions_collection.update_one(
                {"session_id": session_id},
                update_data,
                upsert=True,
            )
        except Exception as exc:
            logger.warning("MongoDB error saving session %s: %s", session_id, exc)
