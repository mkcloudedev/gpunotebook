"""
WebSocket message handler.
"""
from fastapi import WebSocket

from websocket.connection_manager import connection_manager
from kernel.executor import code_executor
from kernel.manager import kernel_manager
from models.execution import ExecutionRequest
from core.exceptions import KernelNotFoundError


async def handle_message(websocket: WebSocket, channel: str, message: dict) -> None:
    """Handle incoming WebSocket message."""
    msg_type = message.get("type")

    handlers = {
        "execute": handle_execute,
        "interrupt": handle_interrupt,
        "ping": handle_ping,
    }

    handler = handlers.get(msg_type)
    if handler:
        await handler(websocket, channel, message)
    else:
        await connection_manager.send_personal(websocket, {
            "type": "error",
            "message": f"Unknown message type: {msg_type}",
        })


async def handle_execute(websocket: WebSocket, channel: str, message: dict) -> None:
    """Handle code execution request."""
    kernel_id = message.get("kernel_id")
    code = message.get("code", "")
    cell_id = message.get("cell_id")

    if not kernel_id or not code:
        await connection_manager.send_personal(websocket, {
            "type": "error",
            "message": "kernel_id and code are required",
        })
        return

    async def on_output(output: dict) -> None:
        """Callback for streaming output."""
        await connection_manager.send_personal(websocket, {
            "type": "output",
            "cell_id": cell_id,
            **output,
        })

    try:
        await connection_manager.send_personal(websocket, {
            "type": "execution_start",
            "cell_id": cell_id,
        })

        request = ExecutionRequest(
            kernel_id=kernel_id,
            code=code,
            cell_id=cell_id,
        )

        result = await code_executor.execute(request, on_output=on_output)

        await connection_manager.send_personal(websocket, {
            "type": "execution_complete",
            "cell_id": cell_id,
            "execution_count": result.execution_count,
            "status": result.status.value,
            "duration_ms": result.duration_ms,
        })

    except KernelNotFoundError:
        await connection_manager.send_personal(websocket, {
            "type": "error",
            "cell_id": cell_id,
            "message": "Kernel not found",
        })


async def handle_interrupt(websocket: WebSocket, channel: str, message: dict) -> None:
    """Handle interrupt request."""
    kernel_id = message.get("kernel_id")

    if not kernel_id:
        await connection_manager.send_personal(websocket, {
            "type": "error",
            "message": "kernel_id is required",
        })
        return

    try:
        await kernel_manager.interrupt_kernel(kernel_id)
        await connection_manager.send_personal(websocket, {
            "type": "interrupted",
            "kernel_id": kernel_id,
        })
    except KernelNotFoundError:
        await connection_manager.send_personal(websocket, {
            "type": "error",
            "message": "Kernel not found",
        })


async def handle_ping(websocket: WebSocket, channel: str, message: dict) -> None:
    """Handle ping for keepalive."""
    await connection_manager.send_personal(websocket, {"type": "pong"})
