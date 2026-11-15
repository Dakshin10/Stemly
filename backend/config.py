from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application Settings with strict startup validation via pydantic-settings.
    Secrets and API keys are never printed or logged.
    """

    # Groq Vision Model Configuration
    GROQ_VISION_API_KEY: str = Field(
        default="",
        description="API key for Groq Vision models. Never log or leak this value.",
    )
    GROQ_VISION_MODEL: str = Field(
        default="llama-3.2-11b-vision-preview",
        description="Groq Vision model identifier.",
    )

    # Groq Text Model Configuration
    GROQ_TEXT_API_KEY: str = Field(
        default="",
        description="API key for Groq Text models. Never log or leak this value.",
    )
    GROQ_TEXT_MODEL: str = Field(
        default="openai/gpt-oss-120b",
        description="Groq Text model identifier.",
    )

    # LLM Operational Constraints
    LLM_TIMEOUT_SECONDS: float = Field(
        default=30.0,
        ge=1.0,
        le=180.0,
        description="Hard timeout for LLM HTTP calls in seconds.",
    )
    LLM_MAX_RETRIES: int = Field(
        default=3,
        ge=0,
        le=10,
        description="Maximum backoff retries for transient 429/5xx errors.",
    )
    DAILY_LLM_QUOTA: int = Field(
        default=50,
        ge=1,
        le=10000,
        description="Daily quota of LLM generation requests per user.",
    )

    # Database Configuration & Connection Pool
    MONGO_URI: Optional[str] = Field(
        default=None,
        description="MongoDB connection URI.",
    )
    MONGO_ALLOW_INVALID_CERTS: bool = Field(
        default=False,
        description="Allow invalid TLS certs for local development only.",
    )
    MONGO_MAX_POOL_SIZE: int = Field(
        default=25,
        ge=1,
        le=500,
        description="Maximum connection pool size per worker process.",
    )
    MONGO_MIN_POOL_SIZE: int = Field(
        default=5,
        ge=0,
        le=50,
        description="Minimum connection pool size kept warm per worker process.",
    )

    # Distributed Redis Cache & Rate Limiting
    REDIS_URL: Optional[str] = Field(
        default=None,
        description="Redis connection URI for distributed rate limiting across workers (e.g. rediss://...).",
    )

    # Cloud Object Storage (Cloudflare R2 / AWS S3)
    S3_ENDPOINT_URL: Optional[str] = Field(
        default=None,
        description="S3 endpoint URL (e.g. https://<accountid>.r2.cloudflarestorage.com for Cloudflare R2).",
    )
    S3_BUCKET: Optional[str] = Field(
        default=None,
        description="Target S3 or Cloudflare R2 bucket name for scan images.",
    )
    S3_ACCESS_KEY_ID: Optional[str] = Field(
        default=None,
        description="S3 access key ID.",
    )
    S3_SECRET_ACCESS_KEY: Optional[str] = Field(
        default=None,
        description="S3 secret access key. Never log or leak this value.",
    )
    S3_REGION_NAME: str = Field(
        default="auto",
        description="S3 region name ('auto' for Cloudflare R2, 'us-east-1' etc. for AWS).",
    )
    S3_PUBLIC_DOMAIN: Optional[str] = Field(
        default=None,
        description="Public CDN or domain prefix for scan assets (e.g. https://cdn.stemly.app).",
    )

    # Gemini LLM Fallback Configuration
    GEMINI_API_KEY: Optional[str] = Field(
        default=None,
        description="Google Gemini API key for high-RPM secondary fallback when Groq is throttled.",
    )
    GEMINI_VISION_MODEL: str = Field(
        default="gemini-1.5-flash",
        description="Gemini Vision model identifier.",
    )
    GEMINI_TEXT_MODEL: str = Field(
        default="gemini-1.5-flash",
        description="Gemini Text model identifier.",
    )

    # Firebase Authentication
    FIREBASE_CREDENTIALS_FILE: str = Field(
        default="serviceAccountKey.json",
        description="Path to Firebase service account key JSON.",
    )
    FIREBASE_CREDENTIALS_JSON: Optional[str] = Field(
        default=None,
        description="Raw JSON string of Firebase service account credentials.",
    )

    # Observability & Monitoring
    SENTRY_DSN: Optional[str] = Field(
        default=None,
        description="Sentry DSN for error reporting and performance monitoring.",
    )
    ENVIRONMENT: str = Field(
        default="production",
        description="Deployment environment (development, staging, production).",
    )
    SENTRY_TRACES_SAMPLE_RATE: float = Field(
        default=0.2,
        ge=0.0,
        le=1.0,
        description="Traces sample rate for Sentry performance monitoring.",
    )

    # Testing & Server Configuration
    TESTING: bool = Field(
        default=False,
        description="Set to True during testing to skip required key verification.",
    )
    HOST: str = Field(default="0.0.0.0", description="Server host.")
    PORT: int = Field(default=8080, description="Server port.")
    CORS_ORIGINS: list[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:8080",
            "http://127.0.0.1:8080",
            "http://10.0.2.2:8080",
            "https://stemly.app",
            "https://stemly-backend.vercel.app",
        ],
        description="Allowed CORS origin domains.",
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    def validate_startup_keys(self) -> None:
        """
        Validate required Groq API keys on startup.
        Fails fast if missing. Never logs key values.
        """
        if self.TESTING:
            return

        missing = []
        if not self.GROQ_VISION_API_KEY or not self.GROQ_VISION_API_KEY.strip():
            missing.append("GROQ_VISION_API_KEY")
        if not self.GROQ_TEXT_API_KEY or not self.GROQ_TEXT_API_KEY.strip():
            missing.append("GROQ_TEXT_API_KEY")

        if missing:
            raise ValueError(
                f"Missing required Groq configuration keys: {', '.join(missing)}. "
                "Please configure them in your environment or .env file before starting the application."
            )

    def __repr__(self) -> str:
        # Never log API key values
        return (
            f"Settings("
            f"GROQ_VISION_MODEL={self.GROQ_VISION_MODEL!r}, "
            f"GROQ_TEXT_MODEL={self.GROQ_TEXT_MODEL!r}, "
            f"LLM_TIMEOUT_SECONDS={self.LLM_TIMEOUT_SECONDS}, "
            f"LLM_MAX_RETRIES={self.LLM_MAX_RETRIES}, "
            f"TESTING={self.TESTING})"
        )


settings = Settings()
