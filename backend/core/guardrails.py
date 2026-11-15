"""
Pedagogical and Security Guardrails for AI STEM Tutor.
Provides:
- Fast pre-flight prompt injection / jailbreak detection
- Non-STEM topical scope screening and polite pedagogical redirects
- Zero-token cost short-circuiting
"""

import re
from typing import Optional, Tuple

# Patterns indicating prompt injection or jailbreak attempts
INJECTION_PATTERNS = [
    r"ignore\s+(all\s+)?(previous|prior|above)\s+(instructions|prompts|directives)",
    r"disregard\s+(all\s+)?(previous|prior|above)",
    r"you\s+are\s+now\s+(in\s+)?(developer\s+mode|unfiltered|jailbroken|dan)",
    r"pretend\s+you\s+have\s+no\s+(rules|restrictions|filters)",
    r"reveal\s+(your\s+)?(system|hidden|initial|developer)?\s*(prompt|instructions)",
    r"print\s+(your\s+)?(hidden\s+prompt|developer\s+prompt)",
    r"bypass\s+safety\s+guidelines",
    r"act\s+as\s+an\s+unrestricted",
]

# Patterns indicating exclusively non-STEM queries that should be politely redirected
NON_STEM_PATTERNS = [
    r"\b(recipe|bake|cook|ingredients)\s+for\s+(cake|pasta|pizza|cookies|bread|soup)\b",
    r"\b(write\s+a\s+poem\s+about\s+(love|romance|dating|celebrities))\b",
    r"\b(who\s+won\s+the\s+(election|grammy|oscar|super\s+bowl))\b",
    r"\b(who\s+is\s+better\s+(messi|ronaldo|taylor\s+swift|kanye))\b",
    r"\b(stock\s+tips|buy\s+crypto|bitcoin\s+investment)\b",
]

INJECTION_REGEX = re.compile("|".join(INJECTION_PATTERNS), re.IGNORECASE)
NON_STEM_REGEX = re.compile("|".join(NON_STEM_PATTERNS), re.IGNORECASE)


def evaluate_guardrails(user_prompt: str, topic: Optional[str] = None) -> Tuple[bool, Optional[str]]:
    """
    Evaluates untrusted user prompt against security and pedagogical domain guardrails.
    Returns: (is_blocked, safe_response)
    - If clean: returns (False, None)
    - If prompt injection detected: returns (True, injection_deflection)
    - If non-STEM detected: returns (True, scope_deflection)
    """
    if not user_prompt or not user_prompt.strip():
        return False, None

    cleaned = user_prompt.strip()

    # 1. Check prompt injection / jailbreak
    if INJECTION_REGEX.search(cleaned):
        return True, (
            "I am Stemly, your dedicated AI STEM tutor. I cannot modify my core safety instructions or "
            "role. Let's focus on exploring your science, mathematics, or engineering questions!"
        )

    # 2. Check non-STEM topical diversion
    if NON_STEM_REGEX.search(cleaned):
        topic_hint = f" ({topic})" if topic else ""
        return True, (
            f"I am designed specifically to help you master STEM concepts{topic_hint}! "
            "I cannot assist with general lifestyle, entertainment, or political queries. "
            "How can I help you understand physics, mathematics, chemistry, or engineering today?"
        )

    return False, None
