"""
MongoDB Index Definitions and Startup Routine for Stemly Backend.
Includes:
- Composite indexes on (user_id, timestamp) for rapid scan & visualiser history queries.
- Composite index on (user_id, topic) for fast notes lookup.
- Sparse index on (user_id, content_hash) for scan deduplication.
- TTL index (7 days) on LLM response cache.
- TTL index (48 hours) on daily usage counters.
"""

import logging
from typing import Optional

from motor.motor_asyncio import AsyncIOMotorDatabase

from .db import db

logger = logging.getLogger("stemly.database.indexes")


async def init_db_indexes(database: Optional[AsyncIOMotorDatabase] = None) -> bool:
    """
    Initializes all MongoDB performance and TTL indexes at application startup.
    Fails gracefully if MongoDB is unavailable or disabled.
    """
    target_db = database if database is not None else db

    if target_db is None:
        logger.warning("MongoDB is disabled or not configured. Skipping index initialization.")
        return False

    try:
        logger.info("Initializing MongoDB indexes...")

        # 1. Scans Collection
        # Fast user history sorting and query performance
        await target_db["scans"].create_index(
            [("user_id", 1), ("timestamp", -1)],
            name="idx_scans_user_timestamp",
            background=True,
        )
        # Scan deduplication lookup by perceptual / content hash per user
        await target_db["scans"].create_index(
            [("user_id", 1), ("content_hash", 1)],
            name="idx_scans_user_content_hash",
            sparse=True,
            background=True,
        )

        # 2. Notes Collection
        await target_db["notes"].create_index(
            [("user_id", 1), ("topic", 1)],
            name="idx_notes_user_topic",
            background=True,
        )
        await target_db["notes"].create_index(
            [("user_id", 1), ("timestamp", -1)],
            name="idx_notes_user_timestamp",
            background=True,
        )

        # 3. Visualiser Collection
        await target_db["visualiser"].create_index(
            [("user_id", 1), ("timestamp", -1)],
            name="idx_visualiser_user_timestamp",
            background=True,
        )

        # 4. LLM Generation Cache (TTL: 7 Days)
        await target_db["llm_cache"].create_index(
            [("cache_key", 1)],
            name="idx_llm_cache_key",
            unique=True,
            background=True,
        )
        await target_db["llm_cache"].create_index(
            [("created_at", 1)],
            name="idx_llm_cache_ttl",
            expireAfterSeconds=7 * 86400,  # 7 days TTL
            background=True,
        )

        # 5. Daily Usage Counters (TTL: Expire at designated timestamp)
        await target_db["usage_counters"].create_index(
            [("user_id", 1), ("date", 1)],
            name="idx_usage_user_date",
            unique=True,
            background=True,
        )
        await target_db["usage_counters"].create_index(
            [("expires_at", 1)],
            name="idx_usage_expires_at_ttl",
            expireAfterSeconds=0,  # Expires exactly when expires_at timestamp is reached
            background=True,
        )

        logger.info("MongoDB indexes successfully created/verified.")
        return True

    except Exception as exc:
        logger.error(
            "CRITICAL: Failed to create MongoDB indexes: %s. Application will operate in degraded database mode.",
            exc,
            exc_info=True,
        )
        return False
