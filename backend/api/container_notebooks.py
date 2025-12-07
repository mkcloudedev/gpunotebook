"""API endpoints for container-based notebook execution."""

from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
import json

from services.container_notebook_service import (
    container_notebook_service,
    ContainerNotebook,
    ContainerExecutionResult,
    ContainerStatus,
)

router = APIRouter(prefix="/container-notebooks", tags=["Container Notebooks"])


# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class CreateContainerRequest(BaseModel):
    """Request to create a new notebook container."""
    name: Optional[str] = None
    image: str = Field(default="python", description="Image type: python, python-ml, datascience, tensorflow, pytorch")
    environment: Optional[Dict[str, str]] = None
    gpu: bool = False
    memory_limit: str = "2g"
    cpu_limit: float = 2.0


class ExecuteCodeRequest(BaseModel):
    """Request to execute code in a container."""
    code: str
    timeout: int = Field(default=300, ge=1, le=3600)


class InstallPackageRequest(BaseModel):
    """Request to install a package."""
    package: str
    upgrade: bool = False


class CopyFileRequest(BaseModel):
    """Request to copy a file."""
    local_path: str
    container_path: str


class ContainerResponse(BaseModel):
    """Container information response."""
    container_id: str
    name: str
    image: str
    status: str
    created_at: str
    kernel_type: str = "python3"
    workspace_path: Optional[str] = None
    execution_count: int = 0

    @classmethod
    def from_container(cls, container: ContainerNotebook) -> "ContainerResponse":
        return cls(
            container_id=container.container_id,
            name=container.name,
            image=container.image,
            status=container.status.value,
            created_at=container.created_at.isoformat(),
            kernel_type=container.kernel_type,
            workspace_path=container.workspace_path,
            execution_count=container.execution_count,
        )


class ExecutionResponse(BaseModel):
    """Execution result response."""
    execution_id: str
    container_id: str
    status: str
    outputs: List[Dict[str, Any]]
    error: Optional[str] = None
    duration_ms: int = 0

    @classmethod
    def from_result(cls, result: ContainerExecutionResult) -> "ExecutionResponse":
        return cls(
            execution_id=result.execution_id,
            container_id=result.container_id,
            status=result.status,
            outputs=result.outputs,
            error=result.error,
            duration_ms=result.duration_ms,
        )


# ============================================================================
# CONTAINER MANAGEMENT ENDPOINTS
# ============================================================================

@router.get("/images")
async def list_available_images():
    """List available container images for notebooks."""
    return {
        "images": [
            {"id": "python", "name": "Python 3.11 (Slim)", "description": "Basic Python environment"},
            {"id": "python-ml", "name": "Python ML", "description": "Scientific Python with NumPy, Pandas, SciPy"},
            {"id": "datascience", "name": "Data Science", "description": "Full data science stack"},
            {"id": "tensorflow", "name": "TensorFlow", "description": "TensorFlow with Jupyter"},
            {"id": "pytorch", "name": "PyTorch", "description": "PyTorch environment"},
            {"id": "python-gpu", "name": "Python GPU", "description": "CUDA-enabled Python environment"},
        ]
    }


@router.post("/containers", response_model=ContainerResponse)
async def create_container(request: CreateContainerRequest):
    """Create a new notebook container."""
    try:
        container = await container_notebook_service.create_container(
            name=request.name,
            image=request.image,
            environment=request.environment,
            gpu=request.gpu,
            memory_limit=request.memory_limit,
            cpu_limit=request.cpu_limit,
        )
        return ContainerResponse.from_container(container)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/containers", response_model=List[ContainerResponse])
async def list_containers():
    """List all notebook containers."""
    containers = await container_notebook_service.list_containers()
    return [ContainerResponse.from_container(c) for c in containers]


@router.get("/containers/{container_id}", response_model=ContainerResponse)
async def get_container(container_id: str):
    """Get a specific container."""
    container = await container_notebook_service.get_container(container_id)
    if not container:
        raise HTTPException(status_code=404, detail="Container not found")
    return ContainerResponse.from_container(container)


@router.post("/containers/{container_id}/start")
async def start_container(container_id: str):
    """Start a stopped container."""
    success = await container_notebook_service.start_container(container_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to start container")
    return {"success": True, "message": f"Container {container_id} started"}


@router.post("/containers/{container_id}/stop")
async def stop_container(container_id: str):
    """Stop a running container."""
    success = await container_notebook_service.stop_container(container_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to stop container")
    return {"success": True, "message": f"Container {container_id} stopped"}


@router.delete("/containers/{container_id}")
async def remove_container(container_id: str, force: bool = False):
    """Remove a container."""
    success = await container_notebook_service.remove_container(container_id, force=force)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to remove container")
    return {"success": True, "message": f"Container {container_id} removed"}


# ============================================================================
# CODE EXECUTION ENDPOINTS
# ============================================================================

@router.post("/containers/{container_id}/execute", response_model=ExecutionResponse)
async def execute_code(container_id: str, request: ExecuteCodeRequest):
    """Execute code in a container and return the result."""
    try:
        result = await container_notebook_service.execute_code(
            container_id=container_id,
            code=request.code,
            timeout=request.timeout,
        )
        return ExecutionResponse.from_result(result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/containers/{container_id}/execute/stream")
async def execute_code_stream(container_id: str, request: ExecuteCodeRequest):
    """Execute code and stream output in real-time."""

    async def generate():
        async for output in container_notebook_service.execute_code_stream(
            container_id=container_id,
            code=request.code,
            timeout=request.timeout,
        ):
            yield f"data: {json.dumps(output)}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


# ============================================================================
# PACKAGE MANAGEMENT ENDPOINTS
# ============================================================================

@router.post("/containers/{container_id}/packages/install")
async def install_package(container_id: str, request: InstallPackageRequest):
    """Install a Python package in a container."""
    result = await container_notebook_service.install_package(
        container_id=container_id,
        package=request.package,
        upgrade=request.upgrade,
    )
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result["output"])
    return result


@router.get("/containers/{container_id}/packages")
async def list_packages(container_id: str):
    """List installed packages in a container."""
    packages = await container_notebook_service.get_installed_packages(container_id)
    return {"packages": packages}


# ============================================================================
# FILE OPERATIONS ENDPOINTS
# ============================================================================

@router.get("/containers/{container_id}/files")
async def list_files(container_id: str, path: str = "/workspace"):
    """List files in a container directory."""
    files = await container_notebook_service.get_container_files(container_id, path)
    return {"path": path, "files": files}


@router.post("/containers/{container_id}/files/upload")
async def upload_file(container_id: str, request: CopyFileRequest):
    """Copy a file to a container."""
    success = await container_notebook_service.copy_file_to_container(
        container_id=container_id,
        local_path=request.local_path,
        container_path=request.container_path,
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to upload file")
    return {"success": True, "message": f"File copied to {request.container_path}"}


@router.post("/containers/{container_id}/files/download")
async def download_file(container_id: str, request: CopyFileRequest):
    """Copy a file from a container."""
    success = await container_notebook_service.copy_file_from_container(
        container_id=container_id,
        container_path=request.container_path,
        local_path=request.local_path,
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to download file")
    return {"success": True, "message": f"File copied to {request.local_path}"}


# ============================================================================
# QUICK EXECUTION (create + execute + cleanup)
# ============================================================================

class QuickExecuteRequest(BaseModel):
    """Request for quick execution (ephemeral container)."""
    code: str
    image: str = "python"
    packages: Optional[List[str]] = None
    timeout: int = 300
    cleanup: bool = True  # Remove container after execution


@router.post("/quick-execute")
async def quick_execute(request: QuickExecuteRequest):
    """
    Execute code in an ephemeral container.

    Creates a container, installs packages, executes code, and optionally cleans up.
    Useful for one-off executions or AI-driven code execution.
    """
    container = None
    try:
        # Create container
        container = await container_notebook_service.create_container(
            image=request.image,
        )

        # Install packages if specified
        if request.packages:
            for package in request.packages:
                await container_notebook_service.install_package(
                    container.container_id, package
                )

        # Execute code
        result = await container_notebook_service.execute_code(
            container_id=container.container_id,
            code=request.code,
            timeout=request.timeout,
        )

        response = {
            "execution_id": result.execution_id,
            "container_id": container.container_id,
            "status": result.status,
            "outputs": result.outputs,
            "error": result.error,
            "duration_ms": result.duration_ms,
        }

        # Cleanup if requested
        if request.cleanup:
            await container_notebook_service.remove_container(
                container.container_id, force=True
            )
            response["cleaned_up"] = True

        return response

    except Exception as e:
        # Cleanup on error
        if container and request.cleanup:
            try:
                await container_notebook_service.remove_container(
                    container.container_id, force=True
                )
            except:
                pass
        raise HTTPException(status_code=500, detail=str(e))
