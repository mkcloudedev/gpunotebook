"""Settings API endpoints."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from pathlib import Path
import json
import os

from services.settings_service import settings_service

# Kaggle credentials path
KAGGLE_JSON = Path.home() / ".kaggle" / "kaggle.json"

router = APIRouter()


class KaggleCredentials(BaseModel):
    username: str = ""
    key: str = ""


class APIKeys(BaseModel):
    claude: Optional[str] = None
    openai: Optional[str] = None
    gemini: Optional[str] = None
    kaggle: Optional[KaggleCredentials] = None


class EditorSettings(BaseModel):
    theme: str = "dark"
    font_size: int = 14
    tab_size: int = 4
    line_numbers: bool = True
    word_wrap: bool = True
    auto_save: bool = True
    auto_save_interval: int = 30
    minimap: bool = False
    bracket_matching: bool = True


class KernelSettings(BaseModel):
    default_python: str = "python3.11"
    gpu_memory_limit: int = 80
    execution_timeout: int = 300
    auto_restart_on_crash: bool = True


class GeneralSettings(BaseModel):
    language: str = "en"
    timezone: str = "UTC"
    date_format: str = "YYYY-MM-DD"
    notifications: bool = True


class ClaudeCodeSettings(BaseModel):
    model: str = "claude-sonnet-4-20250514"
    max_output_tokens: int = 32000
    enabled: bool = True


class AllSettings(BaseModel):
    api_keys: APIKeys = APIKeys()
    editor: EditorSettings = EditorSettings()
    kernel: KernelSettings = KernelSettings()
    general: GeneralSettings = GeneralSettings()
    claude_code: ClaudeCodeSettings = ClaudeCodeSettings()


class TestKeyRequest(BaseModel):
    provider: str
    key: str


class TestKeyResponse(BaseModel):
    valid: bool
    message: Optional[str] = None


def _parse_bool(value: str, default: bool = False) -> bool:
    """Parse boolean from string."""
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ("true", "1", "yes")
    return default


def _parse_int(value: str, default: int = 0) -> int:
    """Parse int from string."""
    if isinstance(value, int):
        return value
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


@router.get("")
async def get_settings():
    """Get current application settings."""
    all_settings = await settings_service.get_all()

    # Build kaggle credentials - check settings first, then ~/.kaggle/kaggle.json
    kaggle_creds = None
    kaggle_username = all_settings.get("kaggle_username")
    kaggle_key = all_settings.get("kaggle_key")

    # If not in settings, try to read from ~/.kaggle/kaggle.json
    if not kaggle_username and not kaggle_key and KAGGLE_JSON.exists():
        try:
            with open(KAGGLE_JSON) as f:
                kaggle_data = json.load(f)
                kaggle_username = kaggle_data.get("username", "")
                kaggle_key = kaggle_data.get("key", "")
        except (json.JSONDecodeError, IOError):
            pass

    if kaggle_username or kaggle_key:
        kaggle_creds = KaggleCredentials(
            username=kaggle_username or "",
            key=kaggle_key or "",
        )

    return AllSettings(
        api_keys=APIKeys(
            claude=all_settings.get("claude_key") or None,
            openai=all_settings.get("openai_key") or None,
            gemini=all_settings.get("gemini_key") or None,
            kaggle=kaggle_creds,
        ),
        editor=EditorSettings(
            theme=all_settings.get("theme", "dark"),
            font_size=_parse_int(all_settings.get("font_size", "14"), 14),
            tab_size=_parse_int(all_settings.get("tab_size", "4"), 4),
            line_numbers=_parse_bool(all_settings.get("line_numbers", "true"), True),
            word_wrap=_parse_bool(all_settings.get("word_wrap", "true"), True),
            auto_save=_parse_bool(all_settings.get("auto_save", "true"), True),
            auto_save_interval=_parse_int(all_settings.get("auto_save_interval", "30"), 30),
            minimap=_parse_bool(all_settings.get("minimap", "false"), False),
            bracket_matching=_parse_bool(all_settings.get("bracket_matching", "true"), True),
        ),
        kernel=KernelSettings(
            default_python=all_settings.get("default_python", "python3.11"),
            gpu_memory_limit=_parse_int(all_settings.get("gpu_memory_limit", "80"), 80),
            execution_timeout=_parse_int(all_settings.get("execution_timeout", "300"), 300),
            auto_restart_on_crash=_parse_bool(all_settings.get("auto_restart_on_crash", "true"), True),
        ),
        general=GeneralSettings(
            language=all_settings.get("language", "en"),
            timezone=all_settings.get("timezone", "UTC"),
            date_format=all_settings.get("date_format", "YYYY-MM-DD"),
            notifications=_parse_bool(all_settings.get("notifications", "true"), True),
        ),
        claude_code=ClaudeCodeSettings(
            model=all_settings.get("claude_code_model", "claude-sonnet-4-20250514"),
            max_output_tokens=_parse_int(all_settings.get("claude_code_max_tokens", "32000"), 32000),
            enabled=_parse_bool(all_settings.get("claude_code_enabled", "true"), True),
        ),
    )


@router.put("")
async def save_settings(settings: AllSettings):
    """Save application settings."""
    # Flatten settings for storage
    settings_dict = {
        # API Keys
        "claude_key": settings.api_keys.claude or "",
        "openai_key": settings.api_keys.openai or "",
        "gemini_key": settings.api_keys.gemini or "",
        "kaggle_username": settings.api_keys.kaggle.username if settings.api_keys.kaggle else "",
        "kaggle_key": settings.api_keys.kaggle.key if settings.api_keys.kaggle else "",
        # Editor
        "theme": settings.editor.theme,
        "font_size": str(settings.editor.font_size),
        "tab_size": str(settings.editor.tab_size),
        "line_numbers": str(settings.editor.line_numbers).lower(),
        "word_wrap": str(settings.editor.word_wrap).lower(),
        "auto_save": str(settings.editor.auto_save).lower(),
        "auto_save_interval": str(settings.editor.auto_save_interval),
        "minimap": str(settings.editor.minimap).lower(),
        "bracket_matching": str(settings.editor.bracket_matching).lower(),
        # Kernel
        "default_python": settings.kernel.default_python,
        "gpu_memory_limit": str(settings.kernel.gpu_memory_limit),
        "execution_timeout": str(settings.kernel.execution_timeout),
        "auto_restart_on_crash": str(settings.kernel.auto_restart_on_crash).lower(),
        # General
        "language": settings.general.language,
        "timezone": settings.general.timezone,
        "date_format": settings.general.date_format,
        "notifications": str(settings.general.notifications).lower(),
        # Claude Code
        "claude_code_model": settings.claude_code.model,
        "claude_code_max_tokens": str(settings.claude_code.max_output_tokens),
        "claude_code_enabled": str(settings.claude_code.enabled).lower(),
    }

    await settings_service.set_many(settings_dict)

    # Update Claude Code environment variables
    if settings.claude_code.model:
        os.environ["CLAUDE_CODE_MODEL"] = settings.claude_code.model
    os.environ["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] = str(settings.claude_code.max_output_tokens)

    # Update environment variables for AI providers
    if settings.api_keys.claude:
        os.environ["ANTHROPIC_API_KEY"] = settings.api_keys.claude
    if settings.api_keys.openai:
        os.environ["OPENAI_API_KEY"] = settings.api_keys.openai
    if settings.api_keys.gemini:
        os.environ["GOOGLE_API_KEY"] = settings.api_keys.gemini

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
