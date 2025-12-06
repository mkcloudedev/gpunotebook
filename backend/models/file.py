"""
File management data models.
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from enum import Enum


class FileType(str, Enum):
    """Type of file."""
    FILE = "file"
    DIRECTORY = "directory"


class FileInfo(BaseModel):
    """Information about a file or directory."""
    name: str
    path: str
    file_type: FileType
    size: int = 0
    modified_at: Optional[datetime] = None
    mime_type: Optional[str] = None


class DirectoryListing(BaseModel):
    """Contents of a directory."""
    path: str
    files: List[FileInfo]


class UploadResponse(BaseModel):
    """Response after file upload."""
    filename: str
    path: str
    size: int
    mime_type: Optional[str] = None


class FileContent(BaseModel):
    """Content of a file."""
    path: str
    content: str
    encoding: str = "utf-8"
