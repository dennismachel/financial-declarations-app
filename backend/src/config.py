from functools import lru_cache
from pathlib import Path
from typing import Literal
from pydantic import Field, PostgresDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application runtime settings and environment validation."""

    # Environment
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

    # Database Configuration
    DATABASE_URL: PostgresDsn = Field(
        default="postgresql://compliance_admin:devpassword@localhost:5432/declarations_db",
        description="Async or sync PostgreSQL connection URI",
    )
    DB_POOL_MIN_SIZE: int = Field(default=2, ge=1)
    DB_POOL_MAX_SIZE: int = Field(default=10, ge=1)

    # LLM & Agent Provider
    OPENAI_API_KEY: str = Field(
        ...,
        description="OpenAI API key used by the compliance agent orchestrator",
    )
    LLM_MODEL: str = "gpt-4o"
    LLM_TEMPERATURE: float = Field(default=0.0, ge=0.0, le=1.0)

    # Document & PDF Storage
    PDF_STORAGE_PATH: Path = Field(
        default=Path("/app/storage/pdfs"),
        description="Absolute path to read-only mounted employee declaration PDFs",
    )

    # Security & CORS
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]
    MAX_QUERY_LIMIT: int = Field(default=50, le=200)

    @field_validator("PDF_STORAGE_PATH", mode="after")
    @classmethod
    def ensure_storage_path_exists(cls, v: Path) -> Path:
        # Resolves path; in local development, it creates the folder if missing
        if not v.exists():
            v.mkdir(parents=True, exist_ok=True)
        return v

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Singleton getter for application settings."""
    return Settings()