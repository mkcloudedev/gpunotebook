"""
Docker management API endpoints.
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query

from models.docker import (
    ContainerSummary,
    ContainerDetail,
    ContainerStats,
    ImageSummary,
    DockerSystemStatus,
    RunContainerRequest,
    ExecCommandRequest,
    OperationResponse,
)
from services.docker_service import docker_service

router = APIRouter()


@router.get("/status")
async def get_docker_status():
    """Check if Docker is available."""
    available = await docker_service.is_available()
    return {"available": available}


@router.get("/system", response_model=DockerSystemStatus)
async def get_system_info():
    """Get Docker system information and disk usage."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    info = await docker_service.get_system_info()
    if not info:
        raise HTTPException(status_code=500, detail="Failed to get system info")

    return info


# ==================== CONTAINERS ====================


@router.get("/containers", response_model=List[ContainerSummary])
async def list_containers(all: bool = Query(True, description="Include stopped containers")):
    """List all Docker containers."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    containers = await docker_service.list_containers(all_containers=all)
    return containers


@router.get("/containers/{container_id}", response_model=ContainerDetail)
async def get_container(container_id: str):
    """Get detailed information about a container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    container = await docker_service.get_container(container_id)
    if not container:
        raise HTTPException(status_code=404, detail="Container not found")

    return container


@router.get("/containers/{container_id}/stats", response_model=ContainerStats)
async def get_container_stats(container_id: str):
    """Get container resource usage statistics."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    stats = await docker_service.get_container_stats(container_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Container not found or not running")

    return stats


@router.get("/containers/{container_id}/logs")
async def get_container_logs(
    container_id: str,
    tail: int = Query(100, ge=1, le=10000, description="Number of lines to retrieve"),
    timestamps: bool = Query(False, description="Include timestamps")
):
    """Get container logs."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    logs = await docker_service.get_container_logs(container_id, tail, timestamps)
    return {"logs": logs}


@router.post("/containers/{container_id}/start", response_model=OperationResponse)
async def start_container(container_id: str):
    """Start a stopped container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.start_container(container_id)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}


@router.post("/containers/{container_id}/stop", response_model=OperationResponse)
async def stop_container(
    container_id: str,
    timeout: int = Query(10, ge=0, le=300, description="Timeout in seconds")
):
    """Stop a running container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.stop_container(container_id, timeout)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}


@router.post("/containers/{container_id}/restart", response_model=OperationResponse)
async def restart_container(
    container_id: str,
    timeout: int = Query(10, ge=0, le=300, description="Timeout in seconds")
):
    """Restart a container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.restart_container(container_id, timeout)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}


@router.delete("/containers/{container_id}", response_model=OperationResponse)
async def remove_container(
    container_id: str,
    force: bool = Query(False, description="Force removal of running container")
):
    """Remove a container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.remove_container(container_id, force)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}


@router.post("/containers", response_model=OperationResponse)
async def run_container(request: RunContainerRequest):
    """Run a new container from an image."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.run_container(
        image=request.image,
        name=request.name,
        ports=request.ports,
        env=request.env,
        volumes=request.volumes,
        restart_policy=request.restart_policy,
        command=request.command,
    )
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": f"Container started: {message}"}


@router.post("/containers/{container_id}/exec")
async def exec_in_container(container_id: str, request: ExecCommandRequest):
    """Execute a command in a running container."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, stdout, stderr = await docker_service.exec_command(
        container_id,
        request.command,
        request.workdir
    )

    return {
        "success": success,
        "stdout": stdout,
        "stderr": stderr
    }


# ==================== IMAGES ====================


@router.get("/images", response_model=List[ImageSummary])
async def list_images():
    """List all Docker images."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    images = await docker_service.list_images()
    return images


@router.post("/images/pull", response_model=OperationResponse)
async def pull_image(image: str = Query(..., description="Image name with optional tag")):
    """Pull a Docker image from registry."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.pull_image(image)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}


@router.delete("/images/{image_id}", response_model=OperationResponse)
async def remove_image(
    image_id: str,
    force: bool = Query(False, description="Force removal")
):
    """Remove a Docker image."""
    if not await docker_service.is_available():
        raise HTTPException(status_code=503, detail="Docker is not available")

    success, message = await docker_service.remove_image(image_id, force)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}
