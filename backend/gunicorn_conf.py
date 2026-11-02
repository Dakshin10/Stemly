"""
Gunicorn configuration for production FastAPI deployment.
Uses Uvicorn worker class for high-throughput asynchronous request handling.
"""

import multiprocessing
import os

# ------------------------------------------------------------------------------
# Network & Server Socket
# ------------------------------------------------------------------------------
host = os.getenv("HOST", "0.0.0.0")
port = os.getenv("PORT", "8080")
bind = f"{host}:{port}"
backlog = 2048

# ------------------------------------------------------------------------------
# Worker Processes & Concurrency
# ------------------------------------------------------------------------------
# In containerized platforms (Cloud Run, Render, ECS), allocate 2-4 workers per core.
default_workers = min(4, max(2, multiprocessing.cpu_count()))
workers = int(os.getenv("WEB_CONCURRENCY", default_workers))
worker_class = "uvicorn.workers.UvicornWorker"

# Use in-memory temporary filesystem for heartbeat on Linux if available
if os.path.exists("/dev/shm") and os.access("/dev/shm", os.W_OK):
    worker_tmp_dir = "/dev/shm"

# ------------------------------------------------------------------------------
# Timeouts & Keepalive
# ------------------------------------------------------------------------------
# Keep timeout slightly higher than LLM_TIMEOUT_SECONDS (30s) to allow clean fallbacks
timeout = int(os.getenv("GUNICORN_TIMEOUT", "60"))
graceful_timeout = int(os.getenv("GUNICORN_GRACEFUL_TIMEOUT", "30"))
keepalive = int(os.getenv("GUNICORN_KEEPALIVE", "5"))

# ------------------------------------------------------------------------------
# Logging & Observability
# ------------------------------------------------------------------------------
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info").lower()
access_log_format = (
    '{"time": "%(t)s", "remote_ip": "%(h)s", "request": "%(r)s", '
    '"status": "%(s)s", "bytes": "%(b)s", "duration_ms": "%(D)s"}'
)


# ------------------------------------------------------------------------------
# Server Lifecycle Callbacks
# ------------------------------------------------------------------------------
def on_starting(server):
    server.log.info(
        f"Stemly Gunicorn server starting on {bind} with {workers} Uvicorn workers."
    )


def post_fork(server, worker):
    server.log.info(f"Worker spawned (pid: {worker.pid})")


def worker_exit(server, worker):
    server.log.info(f"Worker exiting (pid: {worker.pid})")
