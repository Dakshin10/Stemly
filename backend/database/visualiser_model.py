# backend/database/visualiser_model.py

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from bson import ObjectId

from .db import db

logger = logging.getLogger("stemly.database.visualiser")

# Handle case where db is None
visualiser_collection = db["visualiser"] if db is not None else None


async def save_visualiser_entry(
    user_id: str,
    template_id: str,
    parameters: Dict[str, Any],
    history_id: Optional[str] = None,
) -> str:
    if not user_id:
        raise ValueError("user_id is required")

    doc = {
        "user_id": user_id,
        "template_id": template_id,
        "parameters": parameters,
        "timestamp": datetime.now(timezone.utc),
    }

    if visualiser_collection is None:
        logger.warning("MongoDB disabled, skipping save_visualiser_entry for user %s", user_id)
        return "no-db-record"

    if history_id and ObjectId.is_valid(history_id):
        try:
            # Update existing entry
            await visualiser_collection.update_one(
                {"_id": ObjectId(history_id), "user_id": user_id},
                {"$set": doc},
            )
            return history_id
        except Exception as e:
            logger.error("Error updating visualiser entry %s: %s", history_id, e)

    try:
        result = await visualiser_collection.insert_one(doc)
        return str(result.inserted_id)
    except Exception as exc:
        logger.error(
            "MongoDB error inserting visualiser entry for user %s: %s. Gracefully degraded.",
            user_id,
            exc,
        )
        return "db-error"


async def get_visualiser_entries_paginated(
    user_id: str,
    limit: int = 20,
    skip: int = 0,
) -> Tuple[List[Dict[str, Any]], int]:
    if not user_id or visualiser_collection is None:
        return [], 0

    try:
        query = {"user_id": user_id}
        total_count = await visualiser_collection.count_documents(query)

        cursor = visualiser_collection.find(query).sort("timestamp", -1).skip(skip).limit(limit)

        entries: List[Dict[str, Any]] = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            entries.append(doc)
        return entries, total_count
    except Exception as exc:
        logger.error("MongoDB error querying visualiser entries for user %s: %s", user_id, exc)
        return [], 0


async def get_visualiser_entries(user_id: str, limit: int = 20) -> List[Dict[str, Any]]:
    items, _ = await get_visualiser_entries_paginated(user_id, limit=limit, skip=0)
    return items


async def delete_user_visualiser_entries(user_id: str) -> int:
    """
    Deletes all saved visualiser entries for a user (Delete-My-Data).
    Returns count of deleted documents.
    """
    if not user_id or visualiser_collection is None:
        return 0

    try:
        result = await visualiser_collection.delete_many({"user_id": user_id})
        logger.info("Deleted %d visualiser records for user %s", result.deleted_count, user_id)
        return result.deleted_count
    except Exception as exc:
        logger.error("MongoDB error deleting visualiser entries for user %s: %s", user_id, exc)
        return 0
