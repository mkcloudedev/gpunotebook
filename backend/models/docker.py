"""Docker models for container and image management."""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class ContainerState(BaseModel):
    """Container state information."""
    status: str = ""
    running: bool = False
    paused: bool = False
    restarting: bool = False
    started_at: str = ""
    finished_at: str = ""
    exit_code: int = 0


class ContainerSummary(BaseModel):
    """Summary of a Docker container."""
    id: str
    name: str
    image: str
    status: str
    state: str
    ports: str = ""
    created: str = ""
    size: str = ""


class ContainerDetail(BaseModel):
    """Detailed container information."""
    id: str
    name: str
    image: str
    created: str
    state: ContainerState
    ports: Dict[str, Any] = {}
    env: List[str] = []
    cmd: List[str] = []
    labels: Dict[str, str] = {}
    mounts: List[Dict[str, Any]] = []


class ContainerStats(BaseModel):
    """Container resource usage statistics."""
    container_id: str
    name: str
    cpu_percent: str
    memory_usage: str
    memory_percent: str
    network_io: str
    block_io: str
    pids: str


class ImageSummary(BaseModel):
    """Summary of a Docker image."""
    id: str
    repository: str
    tag: str
    created: str = ""
    size: str = ""


class DockerSystemInfo(BaseModel):
    """Docker system information."""
    containers: int = 0
    containers_running: int = 0
    containers_paused: int = 0
    containers_stopped: int = 0
    images: int = 0
    server_version: str = ""
    storage_driver: str = ""
    memory_total: int = 0
    cpus: int = 0
    os: str = ""
    kernel_version: str = ""


class DockerSystemStatus(BaseModel):
    """Docker system status including disk usage."""
    disk_usage: List[Dict[str, Any]] = []
    info: Optional[DockerSystemInfo] = None


class RunContainerRequest(BaseModel):
    """Request to run a new container."""
    image: str
    name: Optional[str] = None
    ports: Optional[Dict[str, str]] = Field(
        default=None,
        description="Port mappings: host_port -> container_port"
    )
    env: Optional[Dict[str, str]] = Field(
        default=None,
        description="Environment variables"
    )
    volumes: Optional[Dict[str, str]] = Field(
        default=None,
        description="Volume mounts: host_path -> container_path"
    )
    restart_policy: Optional[str] = Field(
        default=None,
        description="Restart policy: no, always, on-failure, unless-stopped"
    )
    command: Optional[str] = Field(
        default=None,
        description="Command to run in container"
    )


class ExecCommandRequest(BaseModel):
    """Request to execute a command in a container."""
    command: str
    workdir: Optional[str] = None


class OperationResponse(BaseModel):
    """Response for container/image operations."""
    success: bool
    message: str
