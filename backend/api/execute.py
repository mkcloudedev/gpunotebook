"""
Code execution API endpoints.
"""
from fastapi import APIRouter, HTTPException

from models.execution import (
    ExecutionRequest,
    ExecutionResult,
    ExecutionResponse,
    ExecutionStatus,
)
from kernel.executor import code_executor
from kernel.manager import kernel_manager
from core.exceptions import KernelNotFoundError

router = APIRouter()


@router.post("", response_model=ExecutionResult)
async def execute_code(request: ExecutionRequest):
    """Execute code in a kernel."""
    try:
        await kernel_manager.get_kernel(request.kernel_id)
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")

    result = await code_executor.execute(request)
    return result


@router.get("/{execution_id}", response_model=ExecutionResult)
async def get_execution(execution_id: str):
    """Get execution result by ID."""
    result = await code_executor.get_execution(execution_id)
    if not result:
        raise HTTPException(status_code=404, detail="Execution not found")
    return result


@router.post("/{kernel_id}/cancel", status_code=204)
async def cancel_execution(kernel_id: str):
    """Cancel execution in a kernel."""
    try:
        await code_executor.cancel_execution(kernel_id)
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")
