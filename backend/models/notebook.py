"""
Notebook data models.
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Any
from datetime import datetime
from enum import Enum


class CellType(str, Enum):
    """Type of notebook cell."""
    CODE = "code"
    MARKDOWN = "markdown"


class CellStatus(str, Enum):
    """Execution status of a cell."""
    IDLE = "idle"
    QUEUED = "queued"
    RUNNING = "running"
    SUCCESS = "success"
    ERROR = "error"


class OutputType(str, Enum):
    """Type of cell output."""
    STREAM = "stream"
    EXECUTE_RESULT = "execute_result"
    DISPLAY_DATA = "display_data"
    ERROR = "error"


class CellOutput(BaseModel):
    """Output from cell execution."""
    output_type: OutputType
    text: Optional[str] = None
    data: Optional[dict[str, Any]] = None
    ename: Optional[str] = None
    evalue: Optional[str] = None
    traceback: Optional[List[str]] = None


class Cell(BaseModel):
    """A single notebook cell."""
    id: str = Field(..., description="Unique cell identifier")
    cell_type: CellType = CellType.CODE
    source: str = ""
    outputs: List[CellOutput] = []
    execution_count: Optional[int] = None
    status: CellStatus = CellStatus.IDLE
    metadata: dict[str, Any] = {}


class NotebookMetadata(BaseModel):
    """Notebook metadata."""
    kernel_name: str = "python3"
    language: str = "python"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    modified_at: datetime = Field(default_factory=datetime.utcnow)


class Notebook(BaseModel):
    """A complete notebook."""
    id: str = Field(..., description="Unique notebook identifier")
    name: str = "Untitled"
    cells: List[Cell] = []
    metadata: NotebookMetadata = Field(default_factory=NotebookMetadata)
    kernel_id: Optional[str] = None


class NotebookCreate(BaseModel):
    """Request to create a notebook."""
    name: str = "Untitled"
    kernel_name: str = "python3"


class NotebookUpdate(BaseModel):
    """Request to update a notebook."""
    name: Optional[str] = None
    cells: Optional[List[Cell]] = None


class CellCreate(BaseModel):
    """Request to create a cell."""
    cell_type: CellType = CellType.CODE
    source: str = ""
    position: Optional[int] = None


class CellUpdate(BaseModel):
    """Request to update a cell."""
    source: Optional[str] = None
    cell_type: Optional[CellType] = None
