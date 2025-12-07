"""Redis service for caching and pub/sub."""

import os
import json
import asyncio
from typing import Any, Optional, Union
from datetime import timedelta
import redis.asyncio as redis
from redis.asyncio.client import PubSub


class RedisService:
    """Async Redis service for caching and pub/sub."""

    def __init__(self):
        self.redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
        self._client: Optional[redis.Redis] = None
        self._pubsub: Optional[PubSub] = None
        self._connected = False

    async def connect(self) -> bool:
        """Connect to Redis."""
        if self._connected and self._client:
            return True

        try:
            self._client = redis.from_url(
                self.redis_url,
                encoding="utf-8",
                decode_responses=True
            )
            # Test connection
            await self._client.ping()
            self._connected = True
            print(f"✓ Connected to Redis at {self.redis_url}")
            return True
        except Exception as e:
            print(f"✗ Redis connection failed: {e}")
            self._connected = False
            return False

    async def disconnect(self):
        """Disconnect from Redis."""
        if self._client:
            await self._client.close()
            self._client = None
            self._connected = False

    @property
    def is_connected(self) -> bool:
        """Check if connected to Redis."""
        return self._connected

    async def ensure_connected(self):
        """Ensure connection is established."""
        if not self._connected:
            await self.connect()

    # ==================== BASIC KEY-VALUE ====================

    async def get(self, key: str) -> Optional[str]:
        """Get a value by key."""
        await self.ensure_connected()
        if not self._client:
            return None
        return await self._client.get(key)

    async def set(
        self,
        key: str,
        value: str,
        expire: Optional[Union[int, timedelta]] = None
    ) -> bool:
        """Set a value with optional expiration (seconds or timedelta)."""
        await self.ensure_connected()
        if not self._client:
            return False
        try:
            await self._client.set(key, value, ex=expire)
            return True
        except Exception:
            return False

    async def delete(self, key: str) -> bool:
        """Delete a key."""
        await self.ensure_connected()
        if not self._client:
            return False
        try:
            await self._client.delete(key)
            return True
        except Exception:
            return False

    async def exists(self, key: str) -> bool:
        """Check if key exists."""
        await self.ensure_connected()
        if not self._client:
            return False
        return await self._client.exists(key) > 0

    async def expire(self, key: str, seconds: int) -> bool:
        """Set expiration on a key."""
        await self.ensure_connected()
        if not self._client:
            return False
        return await self._client.expire(key, seconds)

    async def ttl(self, key: str) -> int:
        """Get TTL of a key in seconds."""
        await self.ensure_connected()
        if not self._client:
            return -2
        return await self._client.ttl(key)

    # ==================== JSON HELPERS ====================

    async def get_json(self, key: str) -> Optional[Any]:
        """Get a JSON value."""
        value = await self.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return None
        return None

    async def set_json(
        self,
        key: str,
        value: Any,
        expire: Optional[Union[int, timedelta]] = None
    ) -> bool:
        """Set a JSON value."""
        try:
            json_str = json.dumps(value)
            return await self.set(key, json_str, expire)
        except (TypeError, json.JSONDecodeError):
            return False

    # ==================== HASH OPERATIONS ====================

    async def hget(self, name: str, key: str) -> Optional[str]:
        """Get a hash field value."""
        await self.ensure_connected()
        if not self._client:
            return None
        return await self._client.hget(name, key)

    async def hset(self, name: str, key: str, value: str) -> bool:
        """Set a hash field value."""
        await self.ensure_connected()
        if not self._client:
            return False
        try:
            await self._client.hset(name, key, value)
            return True
        except Exception:
            return False

    async def hgetall(self, name: str) -> dict:
        """Get all hash fields."""
        await self.ensure_connected()
        if not self._client:
            return {}
        return await self._client.hgetall(name)

    async def hdel(self, name: str, *keys: str) -> int:
        """Delete hash fields."""
        await self.ensure_connected()
        if not self._client:
            return 0
        return await self._client.hdel(name, *keys)

    # ==================== LIST OPERATIONS ====================

    async def lpush(self, key: str, *values: str) -> int:
        """Push values to the left of a list."""
        await self.ensure_connected()
        if not self._client:
            return 0
        return await self._client.lpush(key, *values)

    async def rpush(self, key: str, *values: str) -> int:
        """Push values to the right of a list."""
        await self.ensure_connected()
        if not self._client:
            return 0
        return await self._client.rpush(key, *values)

    async def lrange(self, key: str, start: int, end: int) -> list:
        """Get a range of list elements."""
        await self.ensure_connected()
        if not self._client:
            return []
        return await self._client.lrange(key, start, end)

    async def llen(self, key: str) -> int:
        """Get list length."""
        await self.ensure_connected()
        if not self._client:
            return 0
        return await self._client.llen(key)

    async def ltrim(self, key: str, start: int, end: int) -> bool:
        """Trim list to specified range."""
        await self.ensure_connected()
        if not self._client:
            return False
        await self._client.ltrim(key, start, end)
        return True

    # ==================== PUB/SUB ====================

    async def publish(self, channel: str, message: str) -> int:
        """Publish a message to a channel."""
        await self.ensure_connected()
        if not self._client:
            return 0
        return await self._client.publish(channel, message)

    async def subscribe(self, *channels: str) -> PubSub:
        """Subscribe to channels."""
        await self.ensure_connected()
        if not self._client:
            raise ConnectionError("Redis not connected")

        pubsub = self._client.pubsub()
        await pubsub.subscribe(*channels)
        return pubsub

    # ==================== CACHE HELPERS ====================

    async def cache_get_or_set(
        self,
        key: str,
        factory,
        expire: Optional[Union[int, timedelta]] = None
    ) -> Any:
        """Get from cache or compute and cache the value."""
        cached = await self.get_json(key)
        if cached is not None:
            return cached

        # Compute value
        if asyncio.iscoroutinefunction(factory):
            value = await factory()
        else:
            value = factory()

        # Cache it
        await self.set_json(key, value, expire)
        return value

    async def invalidate_pattern(self, pattern: str) -> int:
        """Delete all keys matching a pattern."""
        await self.ensure_connected()
        if not self._client:
            return 0

        count = 0
        async for key in self._client.scan_iter(match=pattern):
            await self._client.delete(key)
            count += 1
        return count

    # ==================== GPU CACHE HELPERS ====================

    async def cache_gpu_status(self, status: dict, expire: int = 5) -> bool:
        """Cache GPU status (short TTL for real-time data)."""
        return await self.set_json("gpu:status", status, expire)

    async def get_cached_gpu_status(self) -> Optional[dict]:
        """Get cached GPU status."""
        return await self.get_json("gpu:status")

    # ==================== SETTINGS CACHE ====================

    async def cache_settings(self, settings: dict) -> bool:
        """Cache application settings."""
        return await self.set_json("app:settings", settings, expire=300)

    async def get_cached_settings(self) -> Optional[dict]:
        """Get cached settings."""
        return await self.get_json("app:settings")

    async def invalidate_settings(self) -> bool:
        """Invalidate settings cache."""
        return await self.delete("app:settings")

    # ==================== CONVERSATION CACHE ====================

    async def cache_conversation(self, conv_id: str, messages: list, expire: int = 3600) -> bool:
        """Cache conversation messages."""
        return await self.set_json(f"conv:{conv_id}", messages, expire)

    async def get_cached_conversation(self, conv_id: str) -> Optional[list]:
        """Get cached conversation."""
        return await self.get_json(f"conv:{conv_id}")


# Global singleton
redis_service = RedisService()
