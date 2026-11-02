# ==============================================================================
# Stage 1: Builder
# Compiles and installs Python wheels into an isolated virtual environment
# ==============================================================================
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Install compiler dependencies required for certain C-extensions (Pillow, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Create dedicated virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# ==============================================================================
# Stage 2: Production Runner
# Minimal, non-root runtime image without compiler toolchains
# ==============================================================================
FROM python:3.11-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8080 \
    HOST=0.0.0.0

# Create dedicated non-root user and group
RUN groupadd -g 10001 stemly && \
    useradd -u 10001 -g stemly -s /bin/sh -d /app stemly

# Copy pre-built virtual environment from builder stage
COPY --from=builder --chown=stemly:stemly /opt/venv /opt/venv

WORKDIR /app

# Prepare upload storage directories with non-root ownership
RUN mkdir -p /app/static/scans && \
    chown -R stemly:stemly /app

# Copy application code with non-root ownership
COPY --chown=stemly:stemly . /app

# Run as non-root user
USER stemly:stemly

# Expose default HTTP port
EXPOSE 8080

# Health check probe against /healthz
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"

# Start Gunicorn with Uvicorn workers
CMD ["gunicorn", "-c", "gunicorn_conf.py", "main:app"]
