"""
Kernels API endpoints.
"""
from typing import List
from fastapi import APIRouter, HTTPException

from models.kernel import Kernel, KernelCreate, KernelInfo
from kernel.manager import kernel_manager
from core.exceptions import KernelNotFoundError, KernelStartError

router = APIRouter()


@router.get("", response_model=List[KernelInfo])
async def list_kernels():
    """List all active kernels."""
    kernels = await kernel_manager.list_kernels()
    return [
        KernelInfo(
            id=k.id,
            name=k.name,
            status=k.status,
            execution_count=k.execution_count,
            created_at=k.created_at,
            last_activity=k.last_activity,
        )
        for k in kernels
    ]


@router.post("", response_model=Kernel, status_code=201)
async def create_kernel(request: KernelCreate):
    """Create a new kernel."""
    try:
        kernel = await kernel_manager.create_kernel(request)
        return kernel
    except KernelStartError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{kernel_id}", response_model=Kernel)
async def get_kernel(kernel_id: str):
    """Get kernel by ID."""
    try:
        kernel = await kernel_manager.get_kernel(kernel_id)
        return kernel
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")


@router.get("/{kernel_id}/status")
async def get_kernel_status(kernel_id: str):
    """Get kernel status."""
    try:
        kernel = await kernel_manager.get_kernel(kernel_id)
        return {"kernel_id": kernel.id, "status": kernel.status}
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")


@router.post("/{kernel_id}/interrupt", status_code=204)
async def interrupt_kernel(kernel_id: str):
    """Interrupt kernel execution."""
    try:
        await kernel_manager.interrupt_kernel(kernel_id)
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")


@router.post("/{kernel_id}/restart", response_model=Kernel)
async def restart_kernel(kernel_id: str):
    """Restart a kernel."""
    try:
        kernel = await kernel_manager.restart_kernel(kernel_id)
        return kernel
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")


@router.delete("/{kernel_id}", status_code=204)
async def shutdown_kernel(kernel_id: str):
    """Shutdown a kernel."""
    try:
        await kernel_manager.shutdown_kernel(kernel_id)
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")


@router.get("/{kernel_id}/variables")
async def get_kernel_variables(kernel_id: str):
    """Get variables from kernel namespace."""
    try:
        from kernel.client import KernelClient
        jupyter_client = await kernel_manager.get_client(kernel_id)
        client = KernelClient(jupyter_client)
        variables = await client.get_variables()
        return {"variables": variables}
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


from pydantic import BaseModel

class CompleteRequest(BaseModel):
    code: str
    cursor_pos: int


@router.post("/{kernel_id}/complete")
async def complete_code(kernel_id: str, request: CompleteRequest):
    """Get code completions from kernel."""
    try:
        from kernel.client import KernelClient
        jupyter_client = await kernel_manager.get_client(kernel_id)
        client = KernelClient(jupyter_client)
        completions = await client.complete(request.code, request.cursor_pos)
        return completions
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{kernel_id}/inspect")
async def inspect_code(kernel_id: str, request: CompleteRequest):
    """Get code inspection/documentation from kernel."""
    try:
        from kernel.client import KernelClient
        jupyter_client = await kernel_manager.get_client(kernel_id)
        client = KernelClient(jupyter_client)
        inspection = await client.inspect(request.code, request.cursor_pos)
        return inspection
    except KernelNotFoundError:
        raise HTTPException(status_code=404, detail="Kernel not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
