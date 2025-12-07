"""
File management API endpoints.
"""
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel

from models.file import FileInfo, DirectoryListing, UploadResponse
from services.file_manager import file_manager
from core.exceptions import FileOperationError


class WriteFileRequest(BaseModel):
    path: str
    content: str

router = APIRouter()


@router.get("", response_model=DirectoryListing)
async def list_files(path: str = ""):
    """List files in a directory."""
    try:
        listing = await file_manager.list_directory(path)
        return listing
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/storage")
async def get_storage_info():
    """Get storage information."""
    import shutil
    from core.config import settings

    total, used, free = shutil.disk_usage(settings.UPLOAD_DIR)
    return {
        "used": used,
        "total": total,
        "free": free,
    }


@router.get("/{path:path}")
async def get_file(path: str):
    """Download a file."""
    try:
        file_path = await file_manager.get_file_path(path)
        return FileResponse(file_path)
    except FileOperationError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/upload", response_model=UploadResponse)
async def upload_file(file: UploadFile = File(...), path: str = ""):
    """Upload a file."""
    try:
        result = await file_manager.save_file(file, path)
        return result
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{path:path}", status_code=204)
async def delete_file(path: str):
    """Delete a file."""
    try:
        await file_manager.delete_file(path)
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/mkdir")
async def create_directory(path: str):
    """Create a directory."""
    try:
        await file_manager.create_directory(path)
        return {"message": f"Directory {path} created"}
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/content/{path:path}")
async def read_file_content(path: str):
    """Read file content as text."""
    try:
        content = await file_manager.read_file_content(path)
        return {"path": path, "content": content}
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/write")
async def write_file_content(request: WriteFileRequest):
    """Write content to a file."""
    try:
        await file_manager.write_file_content(request.path, request.content)
        return {"message": f"File {request.path} written", "path": request.path}
    except FileOperationError as e:
        raise HTTPException(status_code=400, detail=str(e))
