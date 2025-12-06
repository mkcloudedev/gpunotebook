"""
Cluster and GPU node models for distributed kernel execution.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class NodeStatus(str, Enum):
    """Status of a cluster node."""
    ONLINE = "online"
    OFFLINE = "offline"
    BUSY = "busy"
    ERROR = "error"
    MAINTENANCE = "maintenance"


class GPUInfo(BaseModel):
    """GPU information for a node."""
    index: int = 0
    name: str = "Unknown GPU"
    memory_total: int = 0  # MB
    memory_used: int = 0   # MB
    memory_free: int = 0   # MB
    utilization: int = 0   # Percentage
    temperature: int = 0   # Celsius
    power_usage: float = 0.0  # Watts
    driver_version: str = ""
    cuda_version: str = ""


class ClusterNode(BaseModel):
    """A node in the GPU cluster."""
    id: str = Field(..., description="Unique node identifier")
    name: str = Field(..., description="Display name for the node")
    host: str = Field(..., description="Hostname or IP address")
    port: int = Field(default=8888, description="Enterprise Gateway port")
    status: NodeStatus = NodeStatus.OFFLINE
    gpus: List[GPUInfo] = []
    cpu_count: int = 0
    memory_total: int = 0  # MB
    memory_available: int = 0  # MB
    active_kernels: int = 0
    max_kernels: int = 10
    last_heartbeat: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    tags: List[str] = []  # e.g., ["training", "inference", "high-memory"]
    priority: int = 0  # Higher = preferred


class ClusterNodeCreate(BaseModel):
    """Request to add a node to the cluster."""
    name: str
    host: str
    port: int = 8888
    tags: List[str] = []
    priority: int = 0


class ClusterNodeUpdate(BaseModel):
    """Request to update a cluster node."""
    name: Optional[str] = None
    port: Optional[int] = None
    tags: Optional[List[str]] = None
    priority: Optional[int] = None
    status: Optional[NodeStatus] = None


class ClusterStats(BaseModel):
    """Overall cluster statistics."""
    total_nodes: int = 0
    online_nodes: int = 0
    total_gpus: int = 0
    available_gpus: int = 0
    total_memory: int = 0  # MB
    available_memory: int = 0  # MB
    active_kernels: int = 0
    max_kernels: int = 0


class KernelPlacement(BaseModel):
    """Request for kernel placement on a specific node."""
    node_id: Optional[str] = None  # None = auto-select best node
    gpu_index: Optional[int] = None  # None = auto-select
    require_gpu: bool = True
    min_gpu_memory: int = 0  # MB, 0 = no minimum
    tags: List[str] = []  # Required node tags
