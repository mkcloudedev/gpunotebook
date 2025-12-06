"""Settings API endpoints."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import os

from services.settings_service import settings_service

router = APIRouter()


class AppSettings(BaseModel):
    claude_key: Optional[str] = None
    openai_key: Optional[str] = None
    gemini_key: Optional[str] = None
    theme: str = "dark"
    font_size: str = "14"
    tab_size: str = "4"
    auto_save: bool = True
    default_python: str = "python3.11"
    gpu_memory: str = "80"
    timeout: str = "60"


class TestKeyRequest(BaseModel):
    provider: str
    key: str


class TestKeyResponse(BaseModel):
    valid: bool
    message: Optional[str] = None


@router.get("", response_model=AppSettings)
async def get_settings():
    """Get current application settings."""
    all_settings = await settings_service.get_all()

    # Convert stored settings to AppSettings model
    return AppSettings(
        claude_key=all_settings.get("claude_key"),
        openai_key=all_settings.get("openai_key"),
        gemini_key=all_settings.get("gemini_key"),
        theme=all_settings.get("theme", "dark"),
        font_size=all_settings.get("font_size", "14"),
        tab_size=all_settings.get("tab_size", "4"),
        auto_save=all_settings.get("auto_save", "true").lower() == "true",
        default_python=all_settings.get("default_python", "python3.11"),
        gpu_memory=all_settings.get("gpu_memory", "80"),
        timeout=all_settings.get("timeout", "60"),
    )


@router.put("")
async def save_settings(settings: AppSettings):
    """Save application settings."""
    # Save each setting to database
    settings_dict = {
        "claude_key": settings.claude_key or "",
        "openai_key": settings.openai_key or "",
        "gemini_key": settings.gemini_key or "",
        "theme": settings.theme,
        "font_size": settings.font_size,
        "tab_size": settings.tab_size,
        "auto_save": str(settings.auto_save).lower(),
        "default_python": settings.default_python,
        "gpu_memory": settings.gpu_memory,
        "timeout": settings.timeout,
    }

    await settings_service.set_many(settings_dict)

    # Update environment variables for AI providers
    if settings.claude_key:
        os.environ["ANTHROPIC_API_KEY"] = settings.claude_key
    if settings.openai_key:
        os.environ["OPENAI_API_KEY"] = settings.openai_key
    if settings.gemini_key:
        os.environ["GOOGLE_API_KEY"] = settings.gemini_key

    return {"status": "saved"}


@router.post("/test-key", response_model=TestKeyResponse)
async def test_api_key(request: TestKeyRequest):
    """Test if an API key is valid."""
    provider = request.provider.lower()
    key = request.key

    if not key:
        return TestKeyResponse(valid=False, message="Key is empty")

    try:
        if provider == "claude" or provider == "anthropic":
            import anthropic
            client = anthropic.Anthropic(api_key=key)
            # Simple test - just try to create a message
            client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=10,
                messages=[{"role": "user", "content": "Hi"}]
            )
            return TestKeyResponse(valid=True, message="Claude API key is valid")

        elif provider == "openai":
            import openai
            client = openai.OpenAI(api_key=key)
            client.models.list()
            return TestKeyResponse(valid=True, message="OpenAI API key is valid")

        elif provider == "gemini" or provider == "google":
            import google.generativeai as genai
            genai.configure(api_key=key)
            model = genai.GenerativeModel("gemini-pro")
            model.generate_content("Hi", generation_config={"max_output_tokens": 10})
            return TestKeyResponse(valid=True, message="Gemini API key is valid")

        else:
            return TestKeyResponse(valid=False, message=f"Unknown provider: {provider}")

    except Exception as e:
        return TestKeyResponse(valid=False, message=str(e))
