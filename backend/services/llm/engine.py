"""
Core Groq LLM Execution Engine.
Features:
- Structured JSON outputs with Pydantic validation.
- One automatic repair retry if JSON is invalid.
- Exponential backoff with jitter on 429/5xx honoring Retry-After.
- Hard timeouts.
- Structured logging of latency, model, and token usage (no prompt content).
"""

import asyncio
import json
import logging
import random
import re
import time
from typing import Any, Dict, List, Optional, Tuple, Type, TypeVar

import httpx
from pydantic import BaseModel, ValidationError

from config import settings
from core.circuit_breaker import groq_circuit_breaker

logger = logging.getLogger("stemly.llm.engine")

T = TypeVar("T", bound=BaseModel)


def extract_json_from_response(text: str) -> Optional[dict]:
    """
    Sanitize and extract JSON object from raw LLM output.
    Handles raw markdown fences, trailing comments, and preamble text.
    """
    if not text:
        return None

    cleaned = text.strip()

    # 1. Strip markdown fences if present
    cleaned = re.sub(r"^```json\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"^```\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()

    # 2. Direct JSON decode
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # 3. Greedy search for outermost balanced braces
    match = re.search(r"(\{[\s\S]*\})", cleaned)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    return None


async def execute_groq_request_with_backoff(
    client: httpx.AsyncClient,
    payload: Dict[str, Any],
    max_retries: Optional[int] = None,
) -> Tuple[Optional[dict], Optional[dict], float]:
    """
    Executes a POST request to Groq with exponential backoff and jitter on 429/5xx.
    Honors Retry-After header when present.
    Returns: (response_json_dict, usage_dict, latency_ms)
    """
    retries = max_retries if max_retries is not None else settings.LLM_MAX_RETRIES
    model_name = payload.get("model", "unknown")

    # Circuit breaker check: fail fast if upstream is degraded
    if not groq_circuit_breaker.can_execute():
        logger.warning("Groq circuit breaker is OPEN; failing fast to local degraded fallback.")
        return None, None, 0.0

    for attempt in range(retries + 1):
        start_time = time.perf_counter()
        try:
            response = await client.post(
                "/chat/completions",
                json=payload,
                timeout=settings.LLM_TIMEOUT_SECONDS,
            )
            latency_ms = round((time.perf_counter() - start_time) * 1000, 2)

            # Handle Rate Limiting (429) or Server Errors (5xx)
            if response.status_code == 429 or 500 <= response.status_code < 600:
                if attempt < retries:
                    retry_after_header = response.headers.get("Retry-After")
                    delay = None
                    if retry_after_header:
                        try:
                            delay = float(retry_after_header) + random.uniform(0.1, 0.5)
                        except ValueError:
                            delay = None

                    if delay is None:
                        # Full jitter exponential backoff: base * 2^attempt + jitter
                        delay = (2**attempt) + random.uniform(0.1, 1.0)

                    logger.warning(
                        "Groq rate limit or server error (status=%d, attempt=%d/%d). Backing off for %.2fs",
                        response.status_code,
                        attempt + 1,
                        retries,
                        delay,
                    )
                    await asyncio.sleep(delay)
                    continue

                logger.error(
                    "Groq request exhausted retries (status=%d, latency=%.1fms)",
                    response.status_code,
                    latency_ms,
                )
                groq_circuit_breaker.record_failure()
                return None, None, latency_ms

            response.raise_for_status()
            groq_circuit_breaker.record_success()
            data = response.json()
            usage = data.get("usage", {})

            # Structured logging: NEVER log prompt or content
            logger.info(
                "Groq LLM call succeeded",
                extra={
                    "model": model_name,
                    "latency_ms": latency_ms,
                    "prompt_tokens": usage.get("prompt_tokens"),
                    "completion_tokens": usage.get("completion_tokens"),
                    "total_tokens": usage.get("total_tokens"),
                },
            )
            return data, usage, latency_ms

        except httpx.TimeoutException:
            latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
            logger.warning(
                "Groq request timed out after %.1fms (attempt=%d/%d, model=%s)",
                latency_ms,
                attempt + 1,
                retries,
                model_name,
            )
            if attempt < retries:
                delay = (2**attempt) + random.uniform(0.1, 0.5)
                await asyncio.sleep(delay)
                continue
            groq_circuit_breaker.record_failure()
            return None, None, latency_ms

        except httpx.HTTPError as exc:
            latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
            logger.error(
                "Groq HTTP error: %s (attempt=%d/%d, latency=%.1fms)",
                exc.__class__.__name__,
                attempt + 1,
                retries,
                latency_ms,
            )
            if attempt < retries:
                delay = (2**attempt) + random.uniform(0.1, 0.5)
                await asyncio.sleep(delay)
                continue
            groq_circuit_breaker.record_failure()
            return None, None, latency_ms

        except Exception as exc:
            latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
            logger.error("Unexpected error during Groq call: %s", exc)
            groq_circuit_breaker.record_failure()
            return None, None, latency_ms

    return None, None, 0.0


async def call_groq_structured(
    client: httpx.AsyncClient,
    model: str,
    messages: List[Dict[str, Any]],
    schema: Type[T],
    temperature: float = 0.2,
    max_tokens: int = 4096,
) -> Optional[T]:
    """
    Calls Groq in JSON mode, validates against a Pydantic schema, and executes
    ONE automatic repair retry if the output is malformed or invalid JSON.
    """
    payload = {
        "model": model,
        "messages": messages,
        "response_format": {"type": "json_object"},
        "temperature": temperature,
        "max_tokens": max_tokens,
    }

    # Step 1: Initial call
    data, usage, _ = await execute_groq_request_with_backoff(client, payload)
    if not data:
        return None

    raw_text = ""
    try:
        choices = data.get("choices", [])
        if choices:
            raw_text = choices[0].get("message", {}).get("content", "")
    except Exception:
        raw_text = ""

    parsed_json = extract_json_from_response(raw_text)

    # Validate against Pydantic schema
    validation_error: Optional[str] = None
    if parsed_json is not None:
        try:
            return schema.model_validate(parsed_json)
        except ValidationError as val_err:
            validation_error = str(val_err)
    else:
        validation_error = "Response was not valid JSON."

    # Step 2: One automatic repair retry if initial response failed schema validation
    logger.warning("Groq response failed schema validation: %s. Initiating repair retry.", validation_error)

    repair_messages = list(messages) + [
        {"role": "assistant", "content": raw_text[:2000]},
        {
            "role": "user",
            "content": (
                f"Your previous response had a schema error: {validation_error}. "
                "Please fix it and output ONLY a valid JSON object matching the requested schema."
            ),
        },
    ]

    repair_payload = {
        "model": model,
        "messages": repair_messages,
        "response_format": {"type": "json_object"},
        "temperature": 0.1,
        "max_tokens": max_tokens,
    }

    repair_data, _, _ = await execute_groq_request_with_backoff(client, repair_payload, max_retries=1)
    if not repair_data:
        return None

    try:
        repair_choices = repair_data.get("choices", [])
        if repair_choices:
            repair_text = repair_choices[0].get("message", {}).get("content", "")
            repaired_json = extract_json_from_response(repair_text)
            if repaired_json:
                return schema.model_validate(repaired_json)
    except Exception as exc:
        logger.error("Automatic repair retry failed: %s", exc)

    return None
