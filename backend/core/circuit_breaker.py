"""
Asynchronous Circuit Breaker for Upstream LLM Services (Groq).
Protects backend from cascading timeouts and rate exhaustion during cloud outages.
States:
- CLOSED: Normal operation; requests pass to upstream.
- OPEN: Tripped after N consecutive upstream failures; requests fail fast to degraded mode.
- HALF_OPEN: Cooldown expired; allows a single probe request to test service recovery.
"""

import enum
import logging
import time
from typing import Optional

logger = logging.getLogger("stemly.core.circuit_breaker")


class CircuitState(str, enum.Enum):
    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"


class CircuitBreaker:
    """
    In-memory state machine implementing the circuit breaker pattern.
    """

    def __init__(
        self,
        name: str = "groq_llm",
        failure_threshold: int = 5,
        cooldown_seconds: float = 30.0,
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds

        self._state = CircuitState.CLOSED
        self._consecutive_failures = 0
        self._last_state_change = time.time()
        self._last_failure_time = 0.0

    @property
    def state(self) -> CircuitState:
        now = time.time()
        # Check if OPEN circuit cooldown has elapsed -> transition to HALF_OPEN
        if self._state == CircuitState.OPEN:
            if now - self._last_state_change >= self.cooldown_seconds:
                logger.info(
                    "CircuitBreaker [%s] cooldown of %.1fs elapsed; transitioning OPEN -> HALF_OPEN",
                    self.name,
                    self.cooldown_seconds,
                )
                self._state = CircuitState.HALF_OPEN
                self._last_state_change = now
        return self._state

    def can_execute(self) -> bool:
        """Returns True if a request may attempt upstream communication."""
        current_state = self.state
        if current_state == CircuitState.CLOSED:
            return True
        if current_state == CircuitState.HALF_OPEN:
            return True
        return False

    def record_success(self) -> None:
        """Records a successful upstream interaction and closes circuit if recovering."""
        if self._state != CircuitState.CLOSED:
            logger.info("CircuitBreaker [%s] upstream succeeded; transitioning to CLOSED", self.name)
        self._state = CircuitState.CLOSED
        self._consecutive_failures = 0
        self._last_state_change = time.time()

    def record_failure(self, error: Optional[Exception] = None) -> None:
        """Records an upstream failure (5xx or connection error). Trips to OPEN if threshold reached."""
        self._consecutive_failures += 1
        self._last_failure_time = time.time()

        if self._state == CircuitState.HALF_OPEN:
            logger.warning(
                "CircuitBreaker [%s] probe request failed in HALF_OPEN; tripping back to OPEN",
                self.name,
            )
            self._state = CircuitState.OPEN
            self._last_state_change = time.time()
            return

        if self._consecutive_failures >= self.failure_threshold:
            if self._state != CircuitState.OPEN:
                logger.error(
                    "CircuitBreaker [%s] reached %d consecutive failures; TRIPPING to OPEN (cooldown=%.1fs)",
                    self.name,
                    self._consecutive_failures,
                    self.cooldown_seconds,
                )
                self._state = CircuitState.OPEN
                self._last_state_change = time.time()

    def reset(self) -> None:
        """Manual reset for tests or administrative override."""
        self._state = CircuitState.CLOSED
        self._consecutive_failures = 0
        self._last_state_change = time.time()


# Global circuit breaker instance for Groq LLM text services
groq_circuit_breaker = CircuitBreaker(
    name="groq_text",
    failure_threshold=5,
    cooldown_seconds=30.0,
)
