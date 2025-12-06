"""
GPU monitoring data models.
"""
from pydantic import BaseModel
from typing import List, Optional


class GPUProcess(BaseModel):
    """A process running on GPU."""
    pid: int
    name: str
    memory_used_mb: int
    gpu_index: int


class GPUStatus(BaseModel):
    """Status of a single GPU."""
    index: int
    name: str
    uuid: str
    temperature_c: int
    utilization_percent: int
    memory_used_mb: int
    memory_total_mb: int
    memory_free_mb: int
    power_draw_w: Optional[float] = None
    power_limit_w: Optional[float] = None
    processes: List[GPUProcess] = []


class GPUSystemStatus(BaseModel):
    """Status of all GPUs in the system."""
    driver_version: str
    cuda_version: str
    gpu_count: int
    gpus: List[GPUStatus]
