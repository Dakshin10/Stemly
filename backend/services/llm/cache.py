"""
Semantic Generation Caching for Notes and Quizzes.
Caches LLM outputs by normalized topic and variables hash.
Includes:
- Cache versioning: bumping CACHE_VERSION invalidates prior prompts automatically.
- MongoDB persistent caching with 7-day TTL index.
- In-memory LRU fallback for zero-latency hits and resilience during DB downtime.
"""

import hashlib
import logging
import re
import time
from collections import OrderedDict
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from database.db import db

logger = logging.getLogger("stemly.llm.cache")

# Bump this key whenever prompts, schemas, or models change
CACHE_VERSION = "v1"

# In-memory LRU fallback cache (capacity: 500 entries)
_MEMORY_CACHE_LIMIT = 500
_MEMORY_CACHE: OrderedDict[str, tuple[float, Dict[str, Any]]] = OrderedDict()
_MEMORY_CACHE_TTL_SECONDS = 7 * 86400  # 7 days

llm_cache_collection = db["llm_cache"] if db is not None else None


def normalize_topic(topic: str) -> str:
    """Normalize topic string for stable cache hashing."""
    return re.sub(r"\s+", " ", topic.strip().lower())


def normalize_variables(variables: Optional[List[str]]) -> str:
    """Normalize and sort variable names for stable cache hashing."""
    if not variables:
        return ""
    cleaned = sorted([re.sub(r"\s+", "", str(v).lower()) for v in variables if str(v).strip()])
    return ",".join(cleaned)


def compute_notes_cache_key(topic: str, variables: Optional[List[str]] = None) -> str:
    norm_topic = normalize_topic(topic)
    norm_vars = normalize_variables(variables)
    seed = f"notes:{CACHE_VERSION}:{norm_topic}:{norm_vars}"
    return hashlib.sha256(seed.encode("utf-8")).hexdigest()


def compute_quiz_cache_key(topic: str, num_questions: int) -> str:
    norm_topic = normalize_topic(topic)
    seed = f"quiz:{CACHE_VERSION}:{norm_topic}:{num_questions}"
    return hashlib.sha256(seed.encode("utf-8")).hexdigest()


# ------------------------------------------------------------------------------
# In-Memory Cache Helpers
# ------------------------------------------------------------------------------


def _get_from_memory(key: str) -> Optional[Dict[str, Any]]:
    if key in _MEMORY_CACHE:
        timestamp, data = _MEMORY_CACHE[key]
        if time.time() - timestamp < _MEMORY_CACHE_TTL_SECONDS:
            _MEMORY_CACHE.move_to_end(key)
            return data
        else:
            del _MEMORY_CACHE[key]
    return None


def _set_to_memory(key: str, data: Dict[str, Any]) -> None:
    _MEMORY_CACHE[key] = (time.time(), data)
    _MEMORY_CACHE.move_to_end(key)
    if len(_MEMORY_CACHE) > _MEMORY_CACHE_LIMIT:
        _MEMORY_CACHE.popitem(last=False)


# ------------------------------------------------------------------------------
# Notes Caching API
# ------------------------------------------------------------------------------


async def get_cached_notes(topic: str, variables: Optional[List[str]] = None) -> Optional[Dict[str, Any]]:
    key = compute_notes_cache_key(topic, variables)

    # 1. Check in-memory fast tier
    mem_hit = _get_from_memory(key)
    if mem_hit:
        logger.info("Notes cache hit (in-memory) for topic='%s' (key=%s)", topic, key[:8])
        return mem_hit

    # 2. Check MongoDB collection
    if llm_cache_collection is not None:
        try:
            doc = await llm_cache_collection.find_one({"cache_key": key})
            if doc and "payload" in doc:
                logger.info("Notes cache hit (MongoDB) for topic='%s' (key=%s)", topic, key[:8])
                _set_to_memory(key, doc["payload"])
                return doc["payload"]
        except Exception as exc:
            logger.error("MongoDB error reading notes cache: %s. Continuing without cache.", exc)

    return None


async def set_cached_notes(topic: str, variables: Optional[List[str]], payload: Dict[str, Any]) -> None:
    key = compute_notes_cache_key(topic, variables)

    # 1. Store in memory
    _set_to_memory(key, payload)

    # 2. Store in MongoDB
    if llm_cache_collection is not None:
        try:
            doc = {
                "cache_key": key,
                "type": "notes",
                "version": CACHE_VERSION,
                "topic": normalize_topic(topic),
                "payload": payload,
                "created_at": datetime.now(timezone.utc),
            }
            await llm_cache_collection.update_one(
                {"cache_key": key},
                {"$set": doc},
                upsert=True,
            )
        except Exception as exc:
            logger.error("MongoDB error writing notes cache: %s", exc)


# ------------------------------------------------------------------------------
# Quiz Caching API
# ------------------------------------------------------------------------------


async def get_cached_quiz(topic: str, num_questions: int) -> Optional[Dict[str, Any]]:
    key = compute_quiz_cache_key(topic, num_questions)

    # 1. Check in-memory fast tier
    mem_hit = _get_from_memory(key)
    if mem_hit:
        logger.info("Quiz cache hit (in-memory) for topic='%s' (key=%s)", topic, key[:8])
        return mem_hit

    # 2. Check MongoDB collection
    if llm_cache_collection is not None:
        try:
            doc = await llm_cache_collection.find_one({"cache_key": key})
            if doc and "payload" in doc:
                logger.info("Quiz cache hit (MongoDB) for topic='%s' (key=%s)", topic, key[:8])
                _set_to_memory(key, doc["payload"])
                return doc["payload"]
        except Exception as exc:
            logger.error("MongoDB error reading quiz cache: %s. Continuing without cache.", exc)

    return None


async def set_cached_quiz(topic: str, num_questions: int, payload: Dict[str, Any]) -> None:
    key = compute_quiz_cache_key(topic, num_questions)

    # 1. Store in memory
    _set_to_memory(key, payload)

    # 2. Store in MongoDB
    if llm_cache_collection is not None:
        try:
            doc = {
                "cache_key": key,
                "type": "quiz",
                "version": CACHE_VERSION,
                "topic": normalize_topic(topic),
                "payload": payload,
                "created_at": datetime.now(timezone.utc),
            }
            await llm_cache_collection.update_one(
                {"cache_key": key},
                {"$set": doc},
                upsert=True,
            )
        except Exception as exc:
            logger.error("MongoDB error writing quiz cache: %s", exc)


def normalize_query(query: str) -> str:
    """Normalize query text: lowercased, alphanumeric and single spaces."""
    cleaned = re.sub(r"[^\w\s]", "", query.lower())
    return re.sub(r"\s+", " ", cleaned).strip()


def compute_tutor_cache_key(topic: str, query: str) -> str:
    norm_topic = normalize_topic(topic)
    norm_query = normalize_query(query)
    seed = f"tutor:{CACHE_VERSION}:{norm_topic}:{norm_query}"
    return hashlib.sha256(seed.encode("utf-8")).hexdigest()


async def get_cached_tutor(topic: str, query: str) -> Optional[Dict[str, Any]]:
    """Retrieves cached tutor response from In-Memory LRU or MongoDB."""
    key = compute_tutor_cache_key(topic, query)
    mem_hit = _get_from_memory(key)
    if mem_hit:
        logger.info("Tutor cache hit (Memory) for topic='%s'", topic)
        return mem_hit

    if llm_cache_collection is not None:
        try:
            doc = await llm_cache_collection.find_one({"cache_key": key})
            if doc and "payload" in doc:
                logger.info("Tutor cache hit (MongoDB) for topic='%s'", topic)
                _set_to_memory(key, doc["payload"])
                return doc["payload"]
        except Exception as exc:
            logger.error("MongoDB error reading tutor cache: %s", exc)
    return None


async def set_cached_tutor(topic: str, query: str, payload: Dict[str, Any]) -> None:
    """Persists tutor response to In-Memory LRU and MongoDB."""
    key = compute_tutor_cache_key(topic, query)
    _set_to_memory(key, payload)
    if llm_cache_collection is not None:
        try:
            doc = {
                "cache_key": key,
                "type": "tutor",
                "version": CACHE_VERSION,
                "topic": normalize_topic(topic),
                "payload": payload,
                "created_at": datetime.now(timezone.utc),
            }
            await llm_cache_collection.update_one(
                {"cache_key": key},
                {"$set": doc},
                upsert=True,
            )
        except Exception as exc:
            logger.error("MongoDB error writing tutor cache: %s", exc)
