import logging
import os

import certifi
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi

logger = logging.getLogger("stemly.database")

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_ALLOW_INVALID_CERTS = os.getenv("MONGO_ALLOW_INVALID_CERTS", "false").lower() == "true"

from typing import Any, Optional

client: Optional[AsyncIOMotorClient] = None
db: Any = None

if not MONGO_URI:
    logger.info("MONGO_URI not configured in .env - database persistence disabled")
else:
    try:
        if MONGO_ALLOW_INVALID_CERTS:
            logger.warning("MongoDB running with invalid TLS certs allowed (development only).")
        max_pool = int(os.getenv("MONGO_MAX_POOL_SIZE", "25"))
        min_pool = int(os.getenv("MONGO_MIN_POOL_SIZE", "5"))
        client = AsyncIOMotorClient(
            MONGO_URI,
            tlsCAFile=certifi.where(),
            server_api=ServerApi("1"),
            maxPoolSize=max_pool,
            minPoolSize=min_pool,
            maxIdleTimeMS=45000,
            connectTimeoutMS=10000,
            socketTimeoutMS=20000,
            retryWrites=True,
            tlsAllowInvalidCertificates=MONGO_ALLOW_INVALID_CERTS,
        )
        db = client["stemly_db"]
    except Exception as e:
        logger.error("Critical error initializing MongoDB: %s", e)
        client = None
        db = None


async def check_db_connection() -> tuple[bool, str]:
    """
    Checks MongoDB connectivity for readiness probes.
    """
    if not MONGO_URI:
        return True, "disabled (running without MongoDB)"
    if client is None:
        return False, "MongoDB client not initialized"
    try:
        await client.admin.command("ping")
        return True, "connected"
    except Exception as e:
        return False, f"ping error: {str(e)}"
