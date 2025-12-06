"""
Code execution data models.
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime
from enum import Enum


class ExecutionStatus(str, Enum):
    """Status of code execution."""
    QUEUED = "queued"
    RUNNING = "running"
    SUCCESS = "success"
    ERROR = "error"
    CANCELLED = "cancelled"


class ExecutionRequest(BaseModel):
    """Request to execute code."""
    kernel_id: str
    code: str
    cell_id: Optional[str] = None
    silent: bool = False
    store_history: bool = True


class StreamOutput(BaseModel):
    """Streaming output from execution."""
    name: str  # stdout or stderr
    text: str


class ExecutionResult(BaseModel):
    """Result of code execution."""
    execution_id: str
    status: ExecutionStatus
    execution_count: Optional[int] = None
    outputs: List[dict[str, Any]] = []
    error: Optional[dict[str, Any]] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    duration_ms: Optional[int] = None


class ExecutionResponse(BaseModel):
    """Response for execution request."""
    execution_id: str
    status: ExecutionStatus
    message: str = ""
