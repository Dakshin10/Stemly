"""
Per-UID and IP-based rate limiting configuration using SlowAPI.
Applies stricter limits on Vision and Generation endpoints.
"""

import logging
import os

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

logger = logging.getLogger("stemly.core.limiter")


def get_rate_limit_key(request: Request) -> str:
    """
    Derive rate limit key based on authenticated user ID (UID),
    falling back to client IP address for unauthenticated routes.
    """
    # 1. Try authenticated user in request state
    user = getattr(request.state, "user", None)
    if user and isinstance(user, dict) and user.get("uid"):
        return f"uid:{user['uid']}"

    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return f"uid:{user_id}"

    # 2. Check X-Forwarded-For header for reverse proxies
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()
        return f"ip:{client_ip}"

    # 3. Fallback to direct client host
    return f"ip:{get_remote_address(request)}"


# Centralized Limiter instance (supports distributed Redis or in-memory fallback)
_redis_url = os.getenv("REDIS_URL")
if _redis_url and _redis_url.strip():
    logger.info("Configuring SlowAPI with distributed Redis storage.")
    _storage_uri = _redis_url.strip()
else:
    _storage_uri = "memory://"

limiter = Limiter(
    key_func=get_rate_limit_key,
    default_limits=["60/minute"],
    storage_uri=_storage_uri,
    headers_enabled=False,
)

# Defined Rate Limits
LIMIT_VISION = "10/minute"
LIMIT_GENERATION = "10/minute"
LIMIT_CHAT = "30/minute"
LIMIT_STANDARD = "60/minute"
