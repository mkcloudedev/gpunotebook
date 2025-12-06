"""
Kernel client wrapper for communication with IPython kernels.
"""
from typing import Optional, AsyncIterator, Any
from jupyter_client import AsyncKernelClient as JupyterAsyncClient

from models.execution import StreamOutput


class KernelClient:
    """Wrapper around Jupyter kernel client."""

    def __init__(self, client: JupyterAsyncClient):
        self._client = client

    @property
    def is_alive(self) -> bool:
        """Check if kernel is alive."""
        return self._client.is_alive()

    async def execute(
        self,
        code: str,
        silent: bool = False,
        store_history: bool = True,
    ) -> str:
        """Execute code and return message ID."""
        msg_id = self._client.execute(
            code,
            silent=silent,
            store_history=store_history,
        )
        return msg_id

    async def get_shell_msg(self, timeout: Optional[float] = None) -> dict:
        """Get message from shell channel."""
        return self._client.get_shell_msg(timeout=timeout)

    async def get_iopub_msg(self, timeout: Optional[float] = None) -> dict:
        """Get message from IOPub channel."""
        return self._client.get_iopub_msg(timeout=timeout)

    async def stream_output(self, msg_id: str) -> AsyncIterator[dict[str, Any]]:
        """Stream output messages for an execution."""
        import asyncio

        while True:
            try:
                # Use asyncio.to_thread to avoid blocking the event loop
                msg = await asyncio.to_thread(self._client.get_iopub_msg, timeout=1.0)
            except Exception:
                # Small delay to prevent tight loop
                await asyncio.sleep(0.01)
                continue

            if msg["parent_header"].get("msg_id") != msg_id:
                continue

            msg_type = msg["header"]["msg_type"]
            content = msg["content"]

            if msg_type == "stream":
                yield {
                    "type": "stream",
                    "output_type": "stream",
                    "name": content["name"],
                    "text": content["text"],
                }

            elif msg_type == "execute_result":
                yield {
                    "type": "execute_result",
                    "output_type": "execute_result",
                    "data": content["data"],
                    "execution_count": content["execution_count"],
                }

            elif msg_type == "display_data":
                yield {
                    "type": "display_data",
                    "output_type": "display_data",
                    "data": content["data"],
                }

            elif msg_type == "error":
                yield {
                    "type": "error",
                    "output_type": "error",
                    "ename": content["ename"],
                    "evalue": content["evalue"],
                    "traceback": content["traceback"],
                }

            elif msg_type == "status":
                if content["execution_state"] == "idle":
                    break

    async def complete(self, code: str, cursor_pos: int) -> dict:
        """Get code completions."""
        msg_id = self._client.complete(code, cursor_pos)
        reply = self._client.get_shell_msg(timeout=5.0)
        return reply["content"]

    async def inspect(self, code: str, cursor_pos: int) -> dict:
        """Get code inspection/documentation."""
        msg_id = self._client.inspect(code, cursor_pos)
        reply = self._client.get_shell_msg(timeout=5.0)
        return reply["content"]

    async def get_variables(self) -> list[dict]:
        """Get all variables in the kernel namespace."""
        # Execute code to get variable info
        code = """
import json
import sys

def _get_var_info():
    result = []
    user_ns = get_ipython().user_ns
    exclude = {'In', 'Out', 'get_ipython', 'exit', 'quit', '_', '__', '___',
               '_i', '_ii', '_iii', '_oh', '_dh', '_sh', '_getvar_info'}

    for name, value in user_ns.items():
        if name.startswith('_') or name in exclude:
            continue
        try:
            var_type = type(value).__name__

            # Get size/shape info
            if hasattr(value, 'shape'):
                shape = str(value.shape)
            elif hasattr(value, '__len__'):
                shape = f"len={len(value)}"
            else:
                shape = ""

            # Get preview
            str_val = str(value)
            preview = str_val[:100] + '...' if len(str_val) > 100 else str_val

            # Get size in bytes
            try:
                size = sys.getsizeof(value)
            except:
                size = 0

            result.append({
                'name': name,
                'type': var_type,
                'shape': shape,
                'preview': preview,
                'size': size
            })
        except:
            pass

    return result

print(json.dumps(_get_var_info()))
"""
        msg_id = self._client.execute(code, silent=True, store_history=False)

        variables = []
        while True:
            try:
                msg = self._client.get_iopub_msg(timeout=5.0)
            except:
                break

            if msg["parent_header"].get("msg_id") != msg_id:
                continue

            msg_type = msg["header"]["msg_type"]
            content = msg["content"]

            if msg_type == "stream" and content.get("name") == "stdout":
                import json
                try:
                    variables = json.loads(content["text"])
                except:
                    pass

            elif msg_type == "status" and content.get("execution_state") == "idle":
                break

        return variables
