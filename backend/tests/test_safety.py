"""
Tests for Phase 7: Safety, PII Scrubbing, and Content Filtering.
Covers:
- Redaction of email, phone numbers, and credit cards
- Redaction of API credentials (Groq keys, Firebase keys, Bearer tokens)
- Disarming of destructive terminal commands in AI generation
- Clean mathematical expressions pass unmolested
"""

from core.safety import filter_unsafe_output, scrub_pii_and_secrets


def test_scrub_pii_email_phone_cards():
    """Verify personal identifying information is redacted."""
    raw = (
        "Contact student at student.john@university.edu or call +1 555-123-4567. "
        "Payment card was 4111 2222 3333 4444 on file."
    )
    scrubbed = scrub_pii_and_secrets(raw)
    assert "student.john@university.edu" not in scrubbed
    assert "[EMAIL_REDACTED]" in scrubbed
    assert "555-123-4567" not in scrubbed
    assert "[PHONE_REDACTED]" in scrubbed
    assert "4111 2222 3333 4444" not in scrubbed
    assert "[CARD_REDACTED]" in scrubbed


def test_scrub_api_keys_and_tokens():
    """Verify credentials and authorization headers are obscured."""
    raw = (
        "Internal headers: Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.token123 "
        "Groq key: gsk_1234567890abcdef1234567890abcdef1234567890 "
        "Firebase: AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q"
    )
    scrubbed = scrub_pii_and_secrets(raw)
    assert "gsk_" not in scrubbed
    assert "[GROQ_KEY_REDACTED]" in scrubbed
    assert "AIzaSy" not in scrubbed
    assert "[FIREBASE_KEY_REDACTED]" in scrubbed
    assert "token123" not in scrubbed
    assert "Bearer [TOKEN_REDACTED]" in scrubbed


def test_filter_unsafe_output_disarms_commands():
    """Verify destructive terminal instructions are neutralised."""
    unsafe = "To fix this, run `rm -rf /` on your terminal immediately."
    filtered = filter_unsafe_output(unsafe)
    assert "rm -rf" not in filtered
    assert "[POTENTIALLY_DANGEROUS_COMMAND_DISARMED]" in filtered


def test_clean_stem_content_preserves_latex():
    """Verify clean mathematical expressions and LaTeX are preserved untouched."""
    stem = "The kinetic energy formula is $E_k = \\frac{1}{2}mv^2$ and momentum is $p = mv$."
    filtered = filter_unsafe_output(stem)
    assert filtered == stem
