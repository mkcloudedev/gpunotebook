"""
Kernel data models.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class KernelStatus(str, Enum):
    """Status of a kernel."""
    STARTING = "starting"
    IDLE = "idle"
    BUSY = "busy"
    RESTARTING = "restarting"
    DEAD = "dead"


class KernelSpec(BaseModel):
    """Kernel specification."""
    name: str
    display_name: str
    language: str
    env: dict[str, str] = {}


class Kernel(BaseModel):
    """A running kernel instance."""
    id: str = Field(..., description="Unique kernel identifier")
    name: str = "python3"
    status: KernelStatus = KernelStatus.STARTING
    execution_count: int = 0
    notebook_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_activity: datetime = Field(default_factory=datetime.utcnow)


class KernelCreate(BaseModel):
    """Request to create a kernel."""
    name: str = "python3"
    notebook_id: Optional[str] = None


class KernelInfo(BaseModel):
    """Kernel information response."""
    id: str
    name: str
    status: KernelStatus
    execution_count: int
    created_at: datetime
    last_activity: datetime
