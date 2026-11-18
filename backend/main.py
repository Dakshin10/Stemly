import datetime
import logging
import os
from contextlib import asynccontextmanager

logger = logging.getLogger("stemly.main")
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from slowapi.middleware import SlowAPIMiddleware

# Routers
from auth import auth_router
from config import settings
from core.exceptions import register_exception_handlers
from core.middleware import RequestIdAndSecurityMiddleware
from core.observability import init_sentry
from core.rate_limiter import limiter
from database.db import check_db_connection
from database.indexes import init_db_indexes
from routers import chat, notes, scan, visualiser, visualiser_engine
from routers.quiz_router import router as quiz_router
from services.agents import get_orchestrator, llm_clients

# Initialize Sentry telemetry early if configured
init_sentry()


# ----------------------------
# Application Lifespan
# ----------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Validate required Groq configuration and initialize connection pools
    settings.validate_startup_keys()
    await llm_clients.start()

    # Initialize MongoDB performance and TTL indexes (graceful on DB downtime)
    await init_db_indexes()

    # Pre-warm LangGraph multi-agent pipeline for zero-latency execution
    get_orchestrator()

    yield
    # Shutdown: Cleanly close connection pools
    await llm_clients.close()


# ----------------------------
# App Initialization
# ----------------------------
app = FastAPI(
    title="Stemly Backend",
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url=None,
)

# 1. State & Exception Handlers
app.state.limiter = limiter
register_exception_handlers(app)

# 2. Middlewares (Order: RequestID/Security -> GZip -> SlowAPI -> CORS)
app.add_middleware(RequestIdAndSecurityMiddleware)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"],
)

# ----------------------------
# Static Files
# ----------------------------
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# ----------------------------
# Routers
# ----------------------------
app.include_router(auth_router.router)
app.include_router(scan.router, prefix="/scan")
app.include_router(notes.router)
app.include_router(visualiser.router)
app.include_router(visualiser_engine.router)
app.include_router(quiz_router)
app.include_router(chat.router)


# ----------------------------
# Observability & Health Probes
# ----------------------------
class HealthResponse(BaseModel):
    status: str = Field(default="ok")
    service: str = Field(default="stemly-backend")
    timestamp: str


class ReadyResponse(BaseModel):
    status: str = Field(default="ready")
    service: str = Field(default="stemly-backend")
    database: str
    config: str
    timestamp: str


@app.get("/healthz", response_model=HealthResponse, tags=["Observability"])
def healthz():
    """
    Liveness probe: verifies that the FastAPI process is responsive.
    """
    return HealthResponse(
        status="ok",
        service="stemly-backend",
        timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    )


@app.get("/readyz", response_model=ReadyResponse, tags=["Observability"])
@limiter.limit("120/minute")
async def readyz(request: Request):
    """
    Readiness probe: verifies database connectivity and core configuration.
    """
    # 1. Check configuration
    try:
        settings.validate_startup_keys()
        config_status = "valid"
    except Exception as e:
        config_status = f"invalid: {str(e)}"
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Configuration not ready: {str(e)}",
        )

    # 2. Check Database connectivity
    db_ok, db_msg = await check_db_connection()
    if not db_ok:
        logger.error("Readiness check failure: MongoDB is configured but unreachable: %s", db_msg)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database not ready: {db_msg}",
        )

    return ReadyResponse(
        status="ready",
        service="stemly-backend",
        database=db_msg,
        config=config_status,
        timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    )


@app.get("/", tags=["Root"])
@limiter.limit("60/minute")
def root(request: Request):
    return {"message": "Stemly Backend API is running"}
