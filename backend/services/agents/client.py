import logging
from typing import Optional

import httpx

from config import settings

logger = logging.getLogger("stemly.llm.client")

GROQ_BASE_URL = "https://api.groq.com/openai/v1"


class LLMClientManager:
    """
    Manages long-lived asynchronous HTTP clients for Groq Vision and Text endpoints.
    Reused per worker process through FastAPI lifespan.
    API keys are never logged or exposed.
    """

    def __init__(self):
        self._vision_client: Optional[httpx.AsyncClient] = None
        self._text_client: Optional[httpx.AsyncClient] = None

    async def start(self) -> None:
        """Initialize connection pools on application startup."""
        limits = httpx.Limits(max_keepalive_connections=20, max_connections=50, keepalive_expiry=30.0)
        timeout = httpx.Timeout(settings.LLM_TIMEOUT_SECONDS, connect=10.0)

        if self._vision_client is None or self._vision_client.is_closed:
            self._vision_client = httpx.AsyncClient(
                base_url=GROQ_BASE_URL,
                headers={
                    "Authorization": f"Bearer {settings.GROQ_VISION_API_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "Stemly-Backend/1.0",
                },
                timeout=timeout,
                limits=limits,
            )

        if self._text_client is None or self._text_client.is_closed:
            self._text_client = httpx.AsyncClient(
                base_url=GROQ_BASE_URL,
                headers={
                    "Authorization": f"Bearer {settings.GROQ_TEXT_API_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "Stemly-Backend/1.0",
                },
                timeout=timeout,
                limits=limits,
            )

        logger.info(
            "Groq LLM clients initialized (timeout=%.1fs, vision_model=%s, text_model=%s)",
            settings.LLM_TIMEOUT_SECONDS,
            settings.GROQ_VISION_MODEL,
            settings.GROQ_TEXT_MODEL,
        )

    async def close(self) -> None:
        """Gracefully close HTTP client connection pools on application shutdown."""
        if self._vision_client and not self._vision_client.is_closed:
            await self._vision_client.aclose()
            self._vision_client = None

        if self._text_client and not self._text_client.is_closed:
            await self._text_client.aclose()
            self._text_client = None

        logger.info("Groq LLM clients shut down.")

    @property
    def vision_client(self) -> httpx.AsyncClient:
        """Returns the vision client, initializing on demand if accessed outside lifespan."""
        if self._vision_client is None or self._vision_client.is_closed:
            self._vision_client = httpx.AsyncClient(
                base_url=GROQ_BASE_URL,
                headers={
                    "Authorization": f"Bearer {settings.GROQ_VISION_API_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "Stemly-Backend/1.0",
                },
                timeout=httpx.Timeout(settings.LLM_TIMEOUT_SECONDS, connect=10.0),
                limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
            )
        return self._vision_client

    @property
    def text_client(self) -> httpx.AsyncClient:
        """Returns the text client, initializing on demand if accessed outside lifespan."""
        if self._text_client is None or self._text_client.is_closed:
            self._text_client = httpx.AsyncClient(
                base_url=GROQ_BASE_URL,
                headers={
                    "Authorization": f"Bearer {settings.GROQ_TEXT_API_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "Stemly-Backend/1.0",
                },
                timeout=httpx.Timeout(settings.LLM_TIMEOUT_SECONDS, connect=10.0),
                limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
            )
        return self._text_client


# Singleton client manager instance
llm_clients = LLMClientManager()


def get_vision_client() -> httpx.AsyncClient:
    return llm_clients.vision_client


def get_text_client() -> httpx.AsyncClient:
    return llm_clients.text_client
