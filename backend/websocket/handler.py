"""
WebSocket handler for real-time communication.
"""
import json
from typing import Dict, Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from websocket.connection_manager import connection_manager
from websocket.message_handler import handle_message

router = APIRouter()


@router.websocket("/notebook/{notebook_id}")
async def notebook_websocket(websocket: WebSocket, notebook_id: str):
    """WebSocket endpoint for notebook real-time updates."""
    await connection_manager.connect(websocket, notebook_id)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            await handle_message(websocket, notebook_id, message)

    except WebSocketDisconnect:
        connection_manager.disconnect(websocket, notebook_id)


@router.websocket("/kernel/{kernel_id}")
async def kernel_websocket(websocket: WebSocket, kernel_id: str):
    """WebSocket endpoint for kernel output streaming."""
    await connection_manager.connect(websocket, f"kernel:{kernel_id}")

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            await handle_message(websocket, f"kernel:{kernel_id}", message)

    except WebSocketDisconnect:
        connection_manager.disconnect(websocket, f"kernel:{kernel_id}")
