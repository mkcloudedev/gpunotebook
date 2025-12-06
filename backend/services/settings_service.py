"""
Settings service using SQLite database.
"""
from typing import Optional, Dict, Any
from sqlalchemy import select
from datetime import datetime

from core.database import async_session
from models.db_models import SettingsDB


class SettingsService:
    """Service for managing application settings."""

    async def get(self, key: str) -> Optional[str]:
        """Get a setting value by key."""
        async with async_session() as session:
            result = await session.execute(
                select(SettingsDB).where(SettingsDB.key == key)
            )
            setting = result.scalar_one_or_none()
            return setting.value if setting else None

    async def set(self, key: str, value: str) -> None:
        """Set a setting value."""
        async with async_session() as session:
            result = await session.execute(
                select(SettingsDB).where(SettingsDB.key == key)
            )
            setting = result.scalar_one_or_none()

            if setting:
                setting.value = value
                setting.updated_at = datetime.utcnow()
            else:
                setting = SettingsDB(key=key, value=value)
                session.add(setting)

            await session.commit()

    async def delete(self, key: str) -> bool:
        """Delete a setting."""
        async with async_session() as session:
            result = await session.execute(
                select(SettingsDB).where(SettingsDB.key == key)
            )
            setting = result.scalar_one_or_none()

            if not setting:
                return False

            await session.delete(setting)
            await session.commit()
            return True

    async def get_all(self) -> Dict[str, str]:
        """Get all settings."""
        async with async_session() as session:
            result = await session.execute(select(SettingsDB))
            settings = result.scalars().all()
            return {s.key: s.value for s in settings}

    async def set_many(self, settings: Dict[str, str]) -> None:
        """Set multiple settings at once."""
        for key, value in settings.items():
            await self.set(key, value)

    # Convenience methods for specific settings
    async def get_api_keys(self) -> Dict[str, Optional[str]]:
        """Get all API keys."""
        return {
            "claude_key": await self.get("claude_api_key"),
            "openai_key": await self.get("openai_api_key"),
            "gemini_key": await self.get("gemini_api_key"),
        }

    async def set_api_key(self, provider: str, key: str) -> None:
        """Set an API key for a provider."""
        key_map = {
            "claude": "claude_api_key",
            "openai": "openai_api_key",
            "gemini": "gemini_api_key",
        }
        if provider in key_map:
            await self.set(key_map[provider], key)


settings_service = SettingsService()
