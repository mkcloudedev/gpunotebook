"""
GPU monitoring API endpoints.
"""
from fastapi import APIRouter, HTTPException

from models.gpu import GPUSystemStatus, GPUStatus
from services.gpu_monitor import gpu_monitor

router = APIRouter()


@router.get("", response_model=GPUSystemStatus)
async def get_gpu_status_root():
    """Get status of all GPUs (alias for /status)."""
    status = await gpu_monitor.get_status()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")
    return status


@router.get("/status", response_model=GPUSystemStatus)
async def get_gpu_status():
    """Get status of all GPUs."""
    status = await gpu_monitor.get_status()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")
    return status


@router.get("/{gpu_index}", response_model=GPUStatus)
async def get_gpu_by_index(gpu_index: int):
    """Get status of a specific GPU."""
    status = await gpu_monitor.get_status()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")

    if gpu_index >= len(status.gpus):
        raise HTTPException(status_code=404, detail="GPU not found")

    return status.gpus[gpu_index]


@router.get("/{gpu_index}/processes")
async def get_gpu_processes(gpu_index: int):
    """Get processes running on a GPU."""
    status = await gpu_monitor.get_status()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")

    if gpu_index >= len(status.gpus):
        raise HTTPException(status_code=404, detail="GPU not found")

    return {"processes": status.gpus[gpu_index].processes}
