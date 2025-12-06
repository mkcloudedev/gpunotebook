"""
WebSocket connection manager.
"""
import json
from typing import Dict, Set, Any
from fastapi import WebSocket


class ConnectionManager:
    """Manages WebSocket connections."""

    def __init__(self):
        self._connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, channel: str) -> None:
        """Accept and track a new connection."""
        await websocket.accept()

        if channel not in self._connections:
            self._connections[channel] = set()

        self._connections[channel].add(websocket)

    def disconnect(self, websocket: WebSocket, channel: str) -> None:
        """Remove a connection."""
        if channel in self._connections:
            self._connections[channel].discard(websocket)

            if not self._connections[channel]:
                del self._connections[channel]

    async def send_personal(self, websocket: WebSocket, message: dict) -> None:
        """Send message to a specific connection."""
        await websocket.send_text(json.dumps(message))

    async def broadcast(self, channel: str, message: dict) -> None:
        """Broadcast message to all connections in a channel."""
        if channel not in self._connections:
            return

        disconnected = []
        for websocket in self._connections[channel]:
            try:
                await websocket.send_text(json.dumps(message))
            except Exception:
                disconnected.append(websocket)

        for ws in disconnected:
            self._connections[channel].discard(ws)

    def get_connections(self, channel: str) -> Set[WebSocket]:
        """Get all connections for a channel."""
        return self._connections.get(channel, set())


connection_manager = ConnectionManager()
