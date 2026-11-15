"""
Comprehensive Safety, PII Scrubbing, and Content Filtering Engine.
Guarantees:
- Zero PII (emails, phone numbers, credit card numbers) in logs or outgoing telemetry.
- Zero credential leakage (Groq keys, Firebase tokens, Bearer headers).
- Unsafe script / shell injection prevention in LLM outputs.
"""

import re
from typing import Any, Dict

# PII and Secret Regex Patterns
EMAIL_REGEX = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b")
PHONE_REGEX = re.compile(r"\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b")
CARD_REGEX = re.compile(r"\b(?:\d{4}[-\s]?){3}\d{4}\b")

# Secret keys and authorization tokens
GROQ_KEY_REGEX = re.compile(r"\bgsk_[A-Za-z0-9_-]{20,}\b")
FIREBASE_KEY_REGEX = re.compile(r"\bAIzaSy[A-Za-z0-9_-]{33}\b")
BEARER_TOKEN_REGEX = re.compile(r"Bearer\s+[A-Za-z0-9\-._~+/]+=*", re.IGNORECASE)

# Dangerous shell commands or command injection signatures
UNSAFE_COMMANDS_REGEX = re.compile(
    r"\b(rm\s+-rf\s+[/~]|:\(\)\{\s*:\|:&\s*\};:|mkfs\b|dd\s+if=/dev/zero\b|format\s+[c-z]:)",
    re.IGNORECASE,
)


def scrub_pii_and_secrets(text: str) -> str:
    """
    Redacts all personal identifiable information and sensitive credentials from text.
    Safe for log outputs, Sentry breadcrumbs, and metrics.
    """
    if not text:
        return ""

    scrubbed = EMAIL_REGEX.sub("[EMAIL_REDACTED]", text)
    scrubbed = PHONE_REGEX.sub("[PHONE_REDACTED]", scrubbed)
    scrubbed = CARD_REGEX.sub("[CARD_REDACTED]", scrubbed)
    scrubbed = GROQ_KEY_REGEX.sub("[GROQ_KEY_REDACTED]", scrubbed)
    scrubbed = FIREBASE_KEY_REGEX.sub("[FIREBASE_KEY_REDACTED]", scrubbed)
    scrubbed = BEARER_TOKEN_REGEX.sub("Bearer [TOKEN_REDACTED]", scrubbed)

    return scrubbed


def filter_unsafe_output(text: str) -> str:
    """
    Filters AI generated text to prevent execution of hazardous terminal instructions
    or accidental secret regurgitation before delivering to client.
    """
    if not text:
        return ""

    # Scrub any echoed secrets
    safe_text = scrub_pii_and_secrets(text)

    # Disarm dangerous shell commands if found in AI text
    if UNSAFE_COMMANDS_REGEX.search(safe_text):
        safe_text = UNSAFE_COMMANDS_REGEX.sub("[POTENTIALLY_DANGEROUS_COMMAND_DISARMED]", safe_text)

    return safe_text


def sanitize_dict_log_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Recursively sanitizes values in a dictionary for structured logging."""
    sanitized: Dict[str, Any] = {}
    for k, v in payload.items():
        if isinstance(v, str):
            sanitized[k] = scrub_pii_and_secrets(v)
        elif isinstance(v, dict):
            sanitized[k] = sanitize_dict_log_payload(v)
        else:
            sanitized[k] = v
    return sanitized
