"""
Code executor - handles code execution in kernels.
"""
import uuid
import asyncio
from typing import Optional, Callable, Any
from datetime import datetime

from kernel.manager import kernel_manager
from kernel.client import KernelClient
from kernel.magic import magic_processor
from models.kernel import KernelStatus
from models.execution import (
    ExecutionRequest,
    ExecutionResult,
    ExecutionStatus,
)
from core.exceptions import KernelNotFoundError, ExecutionError


class CodeExecutor:
    """Executes code in IPython kernels."""

    def __init__(self):
        self._executions: dict[str, ExecutionResult] = {}

    async def execute(
        self,
        request: ExecutionRequest,
        on_output: Optional[Callable[[dict], Any]] = None,
    ) -> ExecutionResult:
        """Execute code and return result."""
        execution_id = str(uuid.uuid4())
        started_at = datetime.utcnow()

        result = ExecutionResult(
            execution_id=execution_id,
            status=ExecutionStatus.RUNNING,
            started_at=started_at,
        )
        self._executions[execution_id] = result

        try:
            jupyter_client = await kernel_manager.get_client(request.kernel_id)
            await kernel_manager.update_status(request.kernel_id, KernelStatus.BUSY)

            # Process magic commands
            processed_code, magic_result = magic_processor.process(request.code)

            # If magic processing produced immediate output, add it
            if magic_result and on_output:
                await on_output({
                    'type': 'stream',
                    'name': 'stdout',
                    'text': str(magic_result.get('outputs', []))
                })

            client = KernelClient(jupyter_client)
            msg_id = await client.execute(
                processed_code,
                silent=request.silent,
                store_history=request.store_history,
            )

            outputs = []
            async for output in client.stream_output(msg_id):
                outputs.append(output)

                if on_output:
                    await on_output(output)

                if output["type"] == "error":
                    result.status = ExecutionStatus.ERROR
                    result.error = output

            if result.status != ExecutionStatus.ERROR:
                result.status = ExecutionStatus.SUCCESS

            result.outputs = outputs
            result.completed_at = datetime.utcnow()
            result.duration_ms = int(
                (result.completed_at - started_at).total_seconds() * 1000
            )

            kernel = await kernel_manager.get_kernel(request.kernel_id)
            kernel.execution_count += 1
            result.execution_count = kernel.execution_count

        except KernelNotFoundError:
            result.status = ExecutionStatus.ERROR
            result.error = {"ename": "KernelNotFound", "evalue": "Kernel not found"}

        except Exception as e:
            result.status = ExecutionStatus.ERROR
            result.error = {"ename": type(e).__name__, "evalue": str(e)}

        finally:
            await kernel_manager.update_status(request.kernel_id, KernelStatus.IDLE)

        self._executions[execution_id] = result
        return result

    async def get_execution(self, execution_id: str) -> Optional[ExecutionResult]:
        """Get execution result by ID."""
        return self._executions.get(execution_id)

    async def cancel_execution(self, kernel_id: str) -> None:
        """Cancel execution by interrupting kernel."""
        await kernel_manager.interrupt_kernel(kernel_id)


code_executor = CodeExecutor()
