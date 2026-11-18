"""
Session History and Rolling Summary Persistence with Multi-Tenant Isolation.
Supports:
- MongoDB Atlas collection (chat_sessions) with strict user_id scoping
- In-memory fallback for local development or disconnected mode
- Session summary retention across turns
- Complete personal data deletion for GDPR / Privacy compliance
"""

import logging
import time
from typing import Any, Dict, List, Optional, Tuple
from database.db import db

logger = logging.getLogger("stemly.database.chat_history")

sessions_collection = db["chat_sessions"] if db is not None else None

# In-memory storage: session_id -> {turns: [...], summary: str, updated_at: float, user_id: str}
_IN_MEMORY_SESSIONS: Dict[str, Dict[str, Any]] = {}


async def get_session_history(
    session_id: str,
    user_id: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """Retrieves session turns and rolling summary, enforcing user isolation when user_id is provided."""
    if not session_id:
        return [], None

    # Check MongoDB collection if available
    if sessions_collection is not None:
        try:
            query: Dict[str, Any] = {"session_id": session_id}
            if user_id:
                # Allows matching either explicitly scoped user session or unassigned legacy session
                query["$or"] = [{"user_id": user_id}, {"user_id": {"$exists": False}}]
            doc = await sessions_collection.find_one(query)
            if doc:
                return doc.get("turns", []), doc.get("summary")
        except Exception as exc:
            logger.warning("MongoDB error fetching session %s: %s", session_id, exc)

    # In-memory fallback
    entry = _IN_MEMORY_SESSIONS.get(session_id)
    if entry:
        if user_id and entry.get("user_id") and entry.get("user_id") != user_id:
            return [], None
        return entry.get("turns", []), entry.get("summary")

    return [], None


async def save_session_turn(
    session_id: str,
    user_turn: Dict[str, str],
    assistant_turn: Dict[str, str],
    summary: Optional[str] = None,
    user_id: Optional[str] = None,
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
            "user_id": user_id,
            "turns": [],
            "summary": summary,
            "updated_at": now,
        }
    elif user_id and not _IN_MEMORY_SESSIONS[session_id].get("user_id"):
        _IN_MEMORY_SESSIONS[session_id]["user_id"] = user_id

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
            if user_id:
                update_data["$set"]["user_id"] = user_id

            await sessions_collection.update_one(
                {"session_id": session_id},
                update_data,
                upsert=True,
            )
        except Exception as exc:
            logger.warning("MongoDB error saving session %s: %s", session_id, exc)


async def delete_user_chat_sessions(user_id: str) -> int:
    """Permanently deletes all chat sessions belonging to user_id for GDPR erasure."""
    if not user_id:
        return 0

    # Purge from memory
    to_delete = [
        sid for sid, data in _IN_MEMORY_SESSIONS.items()
        if data.get("user_id") == user_id
    ]
    for sid in to_delete:
        _IN_MEMORY_SESSIONS.pop(sid, None)

    # Purge from MongoDB
    if sessions_collection is None:
        return len(to_delete)

    try:
        result = await sessions_collection.delete_many({"user_id": user_id})
        logger.info("Deleted %d chat session documents for user %s", result.deleted_count, user_id)
        return result.deleted_count
    except Exception as exc:
        logger.error("MongoDB error deleting chat sessions for user %s: %s", user_id, exc)
        return 0
