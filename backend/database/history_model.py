# backend/database/history_model.py

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from .db import db

logger = logging.getLogger("stemly.database.history")

# Handle case where db is None
scans_collection = db["scans"] if db is not None else None

# In-memory deduplication cache for offline resilience and instant hits: (user_id, content_hash) -> doc
_MEMORY_SCAN_HASH_CACHE: Dict[Tuple[str, str], Dict[str, Any]] = {}


async def get_scan_by_content_hash(user_id: str, content_hash: str) -> Optional[Dict[str, Any]]:
    """
    Finds an existing scan for the given user with an identical image content hash.
    Used for cost-saving deduplication.
    """
    if not user_id or not content_hash:
        return None

    # 1. Check in-memory tier (ignore degraded/unclassified scans)
    mem_hit = _MEMORY_SCAN_HASH_CACHE.get((user_id, content_hash))
    if mem_hit and mem_hit.get("topic") and mem_hit.get("topic") != "General Science":
        return mem_hit

    # 2. Check MongoDB collection
    if scans_collection is not None:
        try:
            doc = await scans_collection.find_one(
                {
                    "user_id": user_id,
                    "content_hash": content_hash,
                }
            )
            if doc and doc.get("topic") and doc.get("topic") != "General Science":
                doc["_id"] = str(doc["_id"])
                _MEMORY_SCAN_HASH_CACHE[(user_id, content_hash)] = doc
                return doc
        except Exception as exc:
            logger.error(
                "MongoDB error in get_scan_by_content_hash for user %s: %s. Operating in degraded mode.",
                user_id,
                exc,
            )

    return None


async def save_scan_history(
    user_id: str,
    topic: str,
    variables: list,
    image_path: str,
    content_hash: Optional[str] = None,
    structured_variables: Optional[List[dict]] = None,
    target_question: Optional[str] = None,
    latex_formula: Optional[str] = None,
    extracted_text: Optional[str] = None,
) -> str:
    if not user_id:
        raise ValueError("user_id is required to save scan history.")

    doc = {
        "user_id": user_id,
        "topic": topic,
        "variables": variables,
        "structured_variables": structured_variables or [],
        "target_question": target_question,
        "latex_formula": latex_formula,
        "extracted_text": extracted_text or "",
        "image_path": image_path,
        "content_hash": content_hash,
        "timestamp": datetime.now(timezone.utc),
    }

    if content_hash:
        _MEMORY_SCAN_HASH_CACHE[(user_id, content_hash)] = {
            "_id": "in-memory-record",
            "user_id": user_id,
            "topic": topic,
            "variables": variables,
            "structured_variables": structured_variables or [],
            "target_question": target_question,
            "latex_formula": latex_formula,
            "extracted_text": extracted_text or "",
            "image_path": image_path,
            "content_hash": content_hash,
        }

    if scans_collection is None:
        logger.warning("MongoDB disabled, skipping save_scan_history for user %s", user_id)
        return "no-db-record"

    try:
        result = await scans_collection.insert_one(doc)
        return str(result.inserted_id)
    except Exception as exc:
        logger.error(
            "MongoDB error saving scan history for user %s: %s. Gracefully degraded.",
            user_id,
            exc,
        )
        return "db-error"


async def get_user_history_paginated(
    user_id: str,
    limit: int = 20,
    skip: int = 0,
) -> Tuple[List[dict], int]:
    """
    Fetches paginated scans for user with total count.
    """
    if not user_id or scans_collection is None:
        return [], 0

    try:
        query = {"user_id": user_id}
        total_count = await scans_collection.count_documents(query)

        cursor = scans_collection.find(query).sort("timestamp", -1).skip(skip).limit(limit)

        history: List[dict] = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            history.append(doc)

        return history, total_count
    except Exception as exc:
        logger.error(
            "MongoDB error querying user history for user %s: %s. Gracefully degraded.",
            user_id,
            exc,
        )
        return [], 0


async def get_user_history(user_id: str) -> List[dict]:
    """Backward compatible non-paginated fetch."""
    items, _ = await get_user_history_paginated(user_id, limit=100, skip=0)
    return items


async def delete_user_scans(user_id: str) -> int:
    """
    Deletes all scan history records for a given user (Delete-My-Data).
    Returns count of deleted documents.
    """
    # Clean in-memory deduplication keys
    for k in list(_MEMORY_SCAN_HASH_CACHE.keys()):
        if k[0] == user_id:
            del _MEMORY_SCAN_HASH_CACHE[k]

    if not user_id or scans_collection is None:
        return 0

    try:
        result = await scans_collection.delete_many({"user_id": user_id})
        logger.info("Deleted %d scan records for user %s", result.deleted_count, user_id)
        return result.deleted_count
    except Exception as exc:
        logger.error("MongoDB error deleting scans for user %s: %s", user_id, exc)
        return 0
