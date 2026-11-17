"""
Pytest configuration for Stemly backend tests.
"""

import os
import pytest

# Ensure tests run with TESTING=true and mock keys
os.environ["TESTING"] = "true"
os.environ["MONGO_URI"] = ""
os.environ["GROQ_VISION_API_KEY"] = "mock_vision_api_key_12345"
os.environ["GROQ_TEXT_API_KEY"] = "mock_text_api_key_67890"

from config import settings

settings.TESTING = True
settings.GROQ_VISION_API_KEY = "mock_vision_api_key_12345"
settings.GROQ_TEXT_API_KEY = "mock_text_api_key_67890"


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}
