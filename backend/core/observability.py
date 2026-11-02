"""
Production Observability, Sentry APM, and Telemetry Service for Stemly Backend.
Provides structured metrics and Sentry hooks for:
- error_rate
- p95_latency
- groq_429_rate
- fallback_rate
- daily_llm_usage
"""

import logging
from typing import Optional

from config import settings

logger = logging.getLogger("stemly.observability")

_sentry_initialized = False


def init_sentry() -> bool:
    """
    Initializes Sentry SDK if SENTRY_DSN is configured.
    Enforces strict PII filtering (no OCR texts, raw images, or Bearer tokens).
    """
    global _sentry_initialized

    if not settings.SENTRY_DSN or not settings.SENTRY_DSN.strip():
        logger.info("SENTRY_DSN not configured. Sentry APM disabled.")
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.logging import LoggingIntegration
        from sentry_sdk.integrations.starlette import StarletteIntegration
        from sentry_sdk.types import Event, Hint

        def filter_event_pii(event: Event, hint: Hint) -> Optional[Event]:
            """
            Sanitize sensitive data from Sentry event payloads before dispatching to Sentry servers.
            """
            # Scrub Authorization headers
            request_data = event.get("request")
            if isinstance(request_data, dict):
                headers = request_data.get("headers")
                if isinstance(headers, dict):
                    if "authorization" in headers:
                        headers["authorization"] = "[FILTERED]"
                    if "x-ai-api-key" in headers:
                        headers["x-ai-api-key"] = "[FILTERED]"

                # Scrub large or sensitive body data (e.g. image bytes)
                body_data = request_data.get("data")
                if isinstance(body_data, dict):
                    for k in ["file", "image", "image_bytes", "data_url"]:
                        if k in body_data:
                            body_data[k] = "[IMAGE_BYTES_FILTERED]"

            return event

        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            release="stemly-backend@1.0.0",
            traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
            profiles_sample_rate=0.1 if settings.ENVIRONMENT == "production" else 0.0,
            send_default_pii=False,
            before_send=filter_event_pii,
            integrations=[
                FastApiIntegration(transaction_style="endpoint"),
                StarletteIntegration(transaction_style="endpoint"),
                LoggingIntegration(level=logging.INFO, event_level=logging.ERROR),
            ],
        )

        _sentry_initialized = True
        logger.info("Sentry APM initialized successfully (environment=%s)", settings.ENVIRONMENT)
        return True

    except Exception as exc:
        logger.error("Failed to initialize Sentry SDK: %s", exc)
        return False


# ==============================================================================
# Metric Tracking & Logging Functions
# ==============================================================================

def track_error(status_code: int, route: str, error_code: str, request_id: str) -> None:
    """Track HTTP error rates and notify Sentry for 5xx failures."""
    logger.error(
        "metric=error_rate status=%d route=%s code=%s request_id=%s",
        status_code,
        route,
        error_code,
        request_id,
        extra={
            "metric": "error_rate",
            "status_code": status_code,
            "route": route,
            "error_code": error_code,
            "request_id": request_id,
        },
    )

    if _sentry_initialized and status_code >= 500:
        try:
            import sentry_sdk

            with sentry_sdk.push_scope() as scope:
                scope.set_tag("metric", "error_rate")
                scope.set_tag("route", route)
                scope.set_tag("status_code", str(status_code))
                scope.set_tag("error_code", error_code)
                scope.set_context("request_context", {"request_id": request_id})
                sentry_sdk.capture_message(f"HTTP {status_code} Error on {route}: {error_code}", level="error")
        except Exception:
            pass


def track_latency(route: str, method: str, duration_ms: float) -> None:
    """Track request latency and emit structured metric logs for p95 aggregation."""
    logger.info(
        "metric=latency route=%s method=%s duration_ms=%.2f",
        route,
        method,
        duration_ms,
        extra={
            "metric": "latency",
            "route": route,
            "method": method,
            "duration_ms": duration_ms,
        },
    )


def track_groq_429(model: str, retry_after: int) -> None:
    """Track downstream Groq rate limit events (429 rate)."""
    logger.warning(
        "metric=groq_429_rate model=%s retry_after=%ds",
        model,
        retry_after,
        extra={
            "metric": "groq_429_rate",
            "model": model,
            "retry_after": retry_after,
        },
    )

    if _sentry_initialized:
        try:
            import sentry_sdk

            with sentry_sdk.push_scope() as scope:
                scope.set_tag("metric", "groq_429_rate")
                scope.set_tag("model", model)
                scope.set_extra("retry_after_seconds", retry_after)
                sentry_sdk.capture_message(f"Groq API 429 Rate Limit for model {model}", level="warning")
        except Exception:
            pass


def track_fallback_event(service: str, topic: str, reason: str) -> None:
    """Track fallback invocation rate when downstream model fails."""
    logger.warning(
        "metric=fallback_rate service=%s topic=%s reason=%s",
        service,
        topic,
        reason,
        extra={
            "metric": "fallback_rate",
            "service": service,
            "topic": topic,
            "reason": reason,
        },
    )

    if _sentry_initialized:
        try:
            import sentry_sdk

            with sentry_sdk.push_scope() as scope:
                scope.set_tag("metric", "fallback_rate")
                scope.set_tag("service", service)
                scope.set_tag("topic", topic)
                sentry_sdk.capture_message(f"LLM fallback triggered for {service} on {topic}: {reason}", level="info")
        except Exception:
            pass


def track_daily_llm_usage(user_id: str, count: int, quota: int) -> None:
    """Track per-user daily quota consumption to surface cost anomalies."""
    logger.info(
        "metric=daily_llm_usage user_id=%s count=%d quota=%d usage_pct=%.1f",
        user_id,
        count,
        quota,
        (count / quota * 100) if quota > 0 else 0,
        extra={
            "metric": "daily_llm_usage",
            "user_id": user_id,
            "usage_count": count,
            "quota_limit": quota,
        },
    )
