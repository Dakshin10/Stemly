"""
Observability and Security Middleware for Stemly Backend.
Includes:
- Request ID generation and tracking (X-Request-ID).
- Security headers injection (nosniff, DENY, HSTS, CSP).
- Structured JSON access logging with latency, method, path, status, and user attribution.
"""

import json
import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("stemly.access")


class RequestIdAndSecurityMiddleware(BaseHTTPMiddleware):
    """
    Assigns a unique request_id to each HTTP request, logs access in JSON,
    and attaches standard HTTP security headers to all responses.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        # 1. Extract or generate Request ID
        incoming_id = request.headers.get("X-Request-ID")
        request_id = incoming_id if incoming_id else uuid.uuid4().hex
        request.state.request_id = request_id

        start_time = time.perf_counter()

        # 2. Process request
        response: Response = await call_next(request)

        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)

        # 3. Attach Request ID header to response
        response.headers["X-Request-ID"] = request_id

        # 4. Attach Security Headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none';"

        # 5. Structured JSON Access Logging
        user = getattr(request.state, "user", None)
        user_id = user.get("uid") if isinstance(user, dict) else getattr(request.state, "user_id", None)

        forwarded = request.headers.get("X-Forwarded-For")
        client_ip = (
            forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")
        )

        log_payload = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "level": "INFO",
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "latency_ms": duration_ms,
            "user_id": user_id,
            "client_ip": client_ip,
        }
        logger.info(json.dumps(log_payload))

        return response
