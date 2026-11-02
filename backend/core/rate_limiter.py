"""
Per-UID and IP-based rate limiting configuration using SlowAPI.
Applies stricter limits on Vision and Generation endpoints.
"""

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


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


# Centralized Limiter instance
limiter = Limiter(
    key_func=get_rate_limit_key,
    default_limits=["60/minute"],
    headers_enabled=False,
)

# Defined Rate Limits
LIMIT_VISION = "10/minute"
LIMIT_GENERATION = "10/minute"
LIMIT_CHAT = "30/minute"
LIMIT_STANDARD = "60/minute"
