import sys
from pathlib import Path

# Add backend root directory to sys.path so that local module imports work on Vercel
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Entrypoint exposing the FastAPI 'app' instance for Vercel Serverless Functions
from main import app  # noqa: E402
