# backend/database/notes_model.py

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from .db import db

logger = logging.getLogger("stemly.database.notes")

# Handle case where db is None
notes_collection = db["notes"] if db is not None else None


async def save_notes_entry(
    user_id: str,
    topic: str,
    notes_payload: Dict[str, Any],
    image_path: Optional[str] = None,
) -> str:
    if not user_id:
        raise ValueError("user_id is required to save notes.")

    doc = {
        "user_id": user_id,
        "topic": topic,
        "notes": notes_payload,
        "image_path": image_path,
        "timestamp": datetime.now(timezone.utc),
    }

    if notes_collection is None:
        logger.warning("MongoDB disabled, skipping save_notes_entry for user %s", user_id)
        return "no-db-record"

    try:
        result = await notes_collection.insert_one(doc)
        return str(result.inserted_id)
    except Exception as exc:
        logger.error(
            "MongoDB error saving notes for user %s: %s. Gracefully degraded.",
            user_id,
            exc,
        )
        return "db-error"


async def get_notes_for_user_paginated(
    user_id: str,
    limit: int = 20,
    skip: int = 0,
) -> Tuple[List[Dict[str, Any]], int]:
    if not user_id or notes_collection is None:
        return [], 0

    try:
        query = {"user_id": user_id}
        total_count = await notes_collection.count_documents(query)

        cursor = notes_collection.find(query).sort("timestamp", -1).skip(skip).limit(limit)

        notes = []
        async for entry in cursor:
            entry["_id"] = str(entry["_id"])
            notes.append(entry)
        return notes, total_count
    except Exception as exc:
        logger.error("MongoDB error querying notes for user %s: %s", user_id, exc)
        return [], 0


async def get_notes_for_user(user_id: str, limit: int = 20) -> List[Dict[str, Any]]:
    items, _ = await get_notes_for_user_paginated(user_id, limit=limit, skip=0)
    return items


async def delete_user_notes(user_id: str) -> int:
    """
    Deletes all saved notes for a user (Delete-My-Data).
    Returns count of deleted documents.
    """
    if not user_id or notes_collection is None:
        return 0

    try:
        result = await notes_collection.delete_many({"user_id": user_id})
        logger.info("Deleted %d notes records for user %s", result.deleted_count, user_id)
        return result.deleted_count
    except Exception as exc:
        logger.error("MongoDB error deleting notes for user %s: %s", user_id, exc)
        return 0
