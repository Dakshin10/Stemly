import logging
import os

from fastapi import Depends, HTTPException, Request, status
from fastapi.concurrency import run_in_threadpool
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from auth.firebase import verify_firebase_token
from config import settings

logger = logging.getLogger("stemly.auth.middleware")

http_bearer = HTTPBearer(auto_error=False)


async def require_firebase_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(http_bearer),
) -> dict:
    """
    Dependency that enforces valid Firebase authentication on protected routes.
    Non-blocking: offloads cryptographic token verification to threadpool.
    Attaches authenticated user to request.state.user and request.state.user_id.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    id_token = credentials.credentials
    if not id_token or not id_token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or empty Bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Dev/Testing bypass for local test suites
    is_dev_bypass = os.getenv("ALLOW_DEV_AUTH_BYPASS", "false").lower() == "true" or settings.TESTING
    if is_dev_bypass and id_token.strip() == "test-token":
        mock_user = {
            "uid": "test-user-123",
            "email": "test@stemly.app",
            "name": "Test User",
            "picture": None,
        }
        request.state.user = mock_user
        request.state.user_id = mock_user["uid"]
        request.state.id_token = id_token
        return mock_user

    try:
        # Offload synchronous Firebase token verification to threadpool
        firebase_user = await run_in_threadpool(verify_firebase_token, id_token)
    except Exception as exc:
        logger.warning("Token verification failed: %s", exc)
        if is_dev_bypass:
            try:
                import jwt
                decoded = jwt.decode(id_token, options={"verify_signature": False})
                dev_user = {
                    "uid": decoded.get("user_id") or decoded.get("sub") or "dev-user-123",
                    "email": decoded.get("email", "dev@stemly.app"),
                    "name": decoded.get("name", "Stemly User"),
                    "picture": decoded.get("picture"),
                }
                logger.info("Dev bypass decoded token claims for user: %s", dev_user.get("email"))
                request.state.user = dev_user
                request.state.user_id = dev_user["uid"]
                request.state.id_token = id_token
                return dev_user
            except Exception as decode_err:
                logger.warning("Dev bypass JWT decode failed: %s", decode_err)

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    request.state.user = firebase_user
    request.state.user_id = firebase_user.get("uid")
    request.state.id_token = id_token
    return firebase_user
