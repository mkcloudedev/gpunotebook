"""
Application configuration loaded from environment variables.

Secrets should be provided via environment variables or a .env file.
Never commit secrets to version control.
"""
from pydantic_settings import BaseSettings
from pydantic import Field, SecretStr
from typing import List, Optional
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings."""

    APP_NAME: str = "GPU Notebook"
    VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # CORS
    CORS_ORIGINS: List[str] = ["http://10.1.10.70:8282", "http://10.1.10.70:8080", "*"]

    # Database
    DATABASE_URL: str = "sqlite:///./notebooks.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # Kernel settings
    KERNEL_TIMEOUT: int = 60
    MAX_KERNELS: int = 10
    KERNEL_WORKING_DIR: str = "/tmp/notebooks"

    # GPU
    ENABLE_GPU: bool = True
    GPU_MEMORY_FRACTION: float = 0.8

    # AI Providers - No defaults, must be set via env vars
    ANTHROPIC_API_KEY: Optional[SecretStr] = Field(default=None, description="Anthropic API key for Claude")
    OPENAI_API_KEY: Optional[SecretStr] = Field(default=None, description="OpenAI API key")
    GOOGLE_API_KEY: Optional[SecretStr] = Field(default=None, description="Google API key for Gemini")

    # File storage
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_SIZE: int = 100 * 1024 * 1024  # 100MB

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        # Don't allow extra fields
        extra = "ignore"

    def get_anthropic_key(self) -> Optional[str]:
        """Get Anthropic API key as string."""
        return self.ANTHROPIC_API_KEY.get_secret_value() if self.ANTHROPIC_API_KEY else None

    def get_openai_key(self) -> Optional[str]:
        """Get OpenAI API key as string."""
        return self.OPENAI_API_KEY.get_secret_value() if self.OPENAI_API_KEY else None

    def get_google_key(self) -> Optional[str]:
        """Get Google API key as string."""
        return self.GOOGLE_API_KEY.get_secret_value() if self.GOOGLE_API_KEY else None


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
