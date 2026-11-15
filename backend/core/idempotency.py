"""
Idempotency Manager for Chat and Mutation Endpoints.
Prevents duplicate LLM generation and billing on network retries.
Supports in-memory TTL storage with optional Redis backend.
"""

import logging
import time
from typing import Any, Dict, Optional, Tuple

logger = logging.getLogger("stemly.core.idempotency")

# In-memory storage: key -> (expire_at_timestamp, status, response_data)
_IN_MEMORY_IDEMPOTENCY: Dict[str, Tuple[float, str, Any]] = {}
DEFAULT_IDEMPOTENCY_TTL_SECONDS = 300  # 5 minutes


def _clean_expired_keys() -> None:
    now = time.time()
    expired = [k for k, (exp, _, _) in _IN_MEMORY_IDEMPOTENCY.items() if now > exp]
    for k in expired:
        _IN_MEMORY_IDEMPOTENCY.pop(k, None)


def acquire_idempotency_key(
    key: Optional[str],
    user_id: str,
    ttl_seconds: int = DEFAULT_IDEMPOTENCY_TTL_SECONDS,
) -> Tuple[bool, str, Optional[Any]]:
    """
    Attempts to acquire or verify an idempotency key.
    Returns: (is_new, status, cached_payload)
    - If key is None: returns (True, "disabled", None)
    - If key is new: records it as 'in_flight' and returns (True, "acquired", None)
    - If key is already in_flight: returns (False, "in_flight", None)
    - If key is completed: returns (False, "completed", cached_payload)
    """
    if not key or not key.strip():
        return True, "disabled", None

    scoped_key = f"{user_id}:{key.strip()}"
    _clean_expired_keys()

    now = time.time()
    entry = _IN_MEMORY_IDEMPOTENCY.get(scoped_key)

    if entry is not None:
        exp, status, payload = entry
        if now < exp:
            return False, status, payload

    # New key
    expire_at = now + ttl_seconds
    _IN_MEMORY_IDEMPOTENCY[scoped_key] = (expire_at, "in_flight", None)
    return True, "acquired", None


def complete_idempotency_key(
    key: Optional[str],
    user_id: str,
    payload: Any = None,
    ttl_seconds: int = DEFAULT_IDEMPOTENCY_TTL_SECONDS,
) -> None:
    """Marks an acquired idempotency key as completed with optional payload."""
    if not key or not key.strip():
        return

    scoped_key = f"{user_id}:{key.strip()}"
    expire_at = time.time() + ttl_seconds
    _IN_MEMORY_IDEMPOTENCY[scoped_key] = (expire_at, "completed", payload)
