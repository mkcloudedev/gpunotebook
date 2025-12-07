"""
GPU monitoring API endpoints.
"""
import json
from datetime import datetime
from fastapi import APIRouter, HTTPException

from models.gpu import GPUSystemStatus, GPUStatus
from services.gpu_monitor import gpu_monitor
from services.redis_service import redis_service

router = APIRouter()

# History retention: how many points to keep per GPU
HISTORY_MAX_POINTS = 1800  # 1 hour at 2s interval


async def _get_gpu_status_cached():
    """Get GPU status with caching."""
    # Try cache first (2 second TTL for real-time data)
    if redis_service.is_connected:
        cached = await redis_service.get_cached_gpu_status()
        if cached:
            return GPUSystemStatus(**cached)

    # Get fresh status
    status = await gpu_monitor.get_status()
    if status and redis_service.is_connected:
        # Cache the result
        await redis_service.cache_gpu_status(status.model_dump(), expire=2)
        # Store history point
        await _store_history_point(status)

    return status


async def _store_history_point(status: GPUSystemStatus):
    """Store a history point for each GPU in Redis."""
    if not redis_service.is_connected:
        return

    timestamp = datetime.utcnow().isoformat()

    for gpu in status.gpus:
        history_key = f"gpu:history:{gpu.index}"
        point = json.dumps({
            "timestamp": timestamp,
            "utilization_gpu": gpu.utilization_percent,
            "utilization_memory": 0,
            "memory_used": gpu.memory_used_mb,
            "temperature": gpu.temperature_c,
            "power_draw": gpu.power_draw_w,
        })

        # Add to list and trim to max points
        await redis_service.rpush(history_key, point)
        await redis_service.ltrim(history_key, -HISTORY_MAX_POINTS, -1)


@router.get("", response_model=GPUSystemStatus)
async def get_gpu_status_root():
    """Get status of all GPUs (alias for /status)."""
    status = await _get_gpu_status_cached()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")
    return status


@router.get("/status", response_model=GPUSystemStatus)
async def get_gpu_status():
    """Get status of all GPUs."""
    status = await _get_gpu_status_cached()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")
    return status


@router.get("/{gpu_index}", response_model=GPUStatus)
async def get_gpu_by_index(gpu_index: int):
    """Get status of a specific GPU."""
    status = await _get_gpu_status_cached()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")

    if gpu_index >= len(status.gpus):
        raise HTTPException(status_code=404, detail="GPU not found")

    return status.gpus[gpu_index]


@router.get("/{gpu_index}/processes")
async def get_gpu_processes(gpu_index: int):
    """Get processes running on a GPU."""
    status = await _get_gpu_status_cached()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")

    if gpu_index >= len(status.gpus):
        raise HTTPException(status_code=404, detail="GPU not found")

    return {"processes": status.gpus[gpu_index].processes}


@router.get("/{gpu_index}/history")
async def get_gpu_history(gpu_index: int, duration: str = "1h"):
    """Get GPU metrics history from Redis.

    Args:
        gpu_index: GPU index
        duration: Time duration (1h, 6h, 24h, 7d)

    Returns:
        List of history points with timestamp, utilization, memory, temperature, power
    """
    # First verify the GPU exists
    status = await _get_gpu_status_cached()
    if not status:
        raise HTTPException(status_code=503, detail="GPU monitoring unavailable")

    if gpu_index >= len(status.gpus):
        raise HTTPException(status_code=404, detail="GPU not found")

    # Calculate how many points to retrieve based on duration
    duration_points = {
        "1h": 1800,    # 1 hour at 2s interval
        "6h": 1800,    # 6 hours (downsampled to ~1800 points)
        "24h": 1800,   # 24 hours (downsampled)
        "7d": 1800,    # 7 days (downsampled)
    }
    max_points = duration_points.get(duration, 1800)

    # Get history from Redis
    if not redis_service.is_connected:
        return []

    history_key = f"gpu:history:{gpu_index}"
    raw_history = await redis_service.lrange(history_key, -max_points, -1)

    # Parse JSON points
    history = []
    for point_str in raw_history:
        try:
            point = json.loads(point_str)
            history.append(point)
        except json.JSONDecodeError:
            continue

    return history
