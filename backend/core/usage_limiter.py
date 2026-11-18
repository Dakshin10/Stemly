"""
Daily Per-User LLM Usage Counter to Bound API Costs.
Enforces a hard daily quota (default: 50 requests/day per user) for LLM invocations.
Resets automatically at 00:00 UTC via date-keyed documents with MongoDB TTL expiration.
Includes in-memory fallback for offline/ephemeral resilience.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple

from fastapi import HTTPException, status
from pymongo import ReturnDocument

from config import settings
from database.db import db

logger = logging.getLogger("stemly.core.usage")

# Daily quota per authenticated user (configured via settings with default=50)
DAILY_LLM_QUOTA = getattr(settings, "DAILY_LLM_QUOTA", 50)

usage_counters_collection = db["usage_counters"] if db is not None else None

# In-memory fallback: (user_id, date_str) -> count
_MEMORY_USAGE: Dict[str, int] = {}


def _get_today_utc_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


async def check_and_increment_daily_usage(user_id: str, cost: int = 1) -> Tuple[bool, int, int]:
    """
    Atomically increments the user's daily usage count.
    Raises HTTP 429 Too Many Requests if the quota is exceeded.
    Returns: (is_allowed, current_count, quota_limit)
    """
    if not user_id:
        return True, 0, DAILY_LLM_QUOTA

    today_str = _get_today_utc_str()
    key = f"{user_id}:{today_str}"

    current_count = 0

    # 1. Primary: Atomic MongoDB counter
    if usage_counters_collection is not None:
        try:
            expires_at = datetime.now(timezone.utc) + timedelta(days=2)
            doc = await asyncio.wait_for(
                usage_counters_collection.find_one_and_update(
                    {"_id": key},
                    {
                        "$inc": {"count": cost},
                        "$setOnInsert": {
                            "user_id": user_id,
                            "date": today_str,
                            "expires_at": expires_at,
                        },
                    },
                    upsert=True,
                    return_document=ReturnDocument.AFTER,
                ),
                timeout=1.5,
            )
            current_count = doc.get("count", 0)
        except Exception as exc:
            logger.error(
                "MongoDB error in check_and_increment_daily_usage for user %s: %s. Using in-memory fallback.",
                user_id,
                exc,
            )
            _MEMORY_USAGE[key] = _MEMORY_USAGE.get(key, 0) + cost
            current_count = _MEMORY_USAGE[key]
    else:
        # 2. In-memory fallback
        _MEMORY_USAGE[key] = _MEMORY_USAGE.get(key, 0) + cost
        current_count = _MEMORY_USAGE[key]

    if current_count > DAILY_LLM_QUOTA:
        logger.warning(
            "User %s exceeded daily LLM quota (%d/%d requests for %s)",
            user_id,
            current_count,
            DAILY_LLM_QUOTA,
            today_str,
        )
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Daily AI generation quota exceeded ({DAILY_LLM_QUOTA} requests/day). Quota resets at 00:00 UTC.",
            headers={"Retry-After": "86400"},
        )

    return True, current_count, DAILY_LLM_QUOTA


async def get_user_daily_usage(user_id: str) -> Tuple[int, int]:
    """
    Returns current usage and quota limit for the given user.
    """
    if not user_id:
        return 0, DAILY_LLM_QUOTA

    today_str = _get_today_utc_str()
    key = f"{user_id}:{today_str}"

    if usage_counters_collection is not None:
        try:
            doc = await usage_counters_collection.find_one({"_id": key})
            if doc:
                return doc.get("count", 0), DAILY_LLM_QUOTA
        except Exception:
            pass

    return _MEMORY_USAGE.get(key, 0), DAILY_LLM_QUOTA


async def delete_user_usage_records(user_id: str) -> int:
    """
    Deletes all usage records for a user (Delete-My-Data).
    """
    if not user_id:
        return 0

    count = 0
    if usage_counters_collection is not None:
        try:
            res = await usage_counters_collection.delete_many({"user_id": user_id})
            count = res.deleted_count
        except Exception as exc:
            logger.error("MongoDB error deleting usage records for user %s: %s", user_id, exc)

    # Clean in-memory keys
    for k in list(_MEMORY_USAGE.keys()):
        if k.startswith(f"{user_id}:"):
            del _MEMORY_USAGE[k]

    return count
