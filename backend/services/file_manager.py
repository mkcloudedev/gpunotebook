"""
File management service.

Uses asyncio.to_thread for blocking I/O operations to prevent
blocking the async event loop.
"""
import asyncio
import os
import shutil
import mimetypes
from datetime import datetime
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

from fastapi import UploadFile

from models.file import FileInfo, FileType, DirectoryListing, UploadResponse
from core.config import settings
from core.exceptions import FileOperationError

# Thread pool for file I/O operations
_file_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="file_io")


class FileManager:
    """Manages user files."""

    def __init__(self):
        self._base_dir = settings.UPLOAD_DIR
        os.makedirs(self._base_dir, exist_ok=True)

    def _resolve_path(self, path: str) -> str:
        """Resolve and validate path."""
        if path.startswith("/"):
            path = path[1:]

        full_path = os.path.normpath(os.path.join(self._base_dir, path))

        if not full_path.startswith(os.path.normpath(self._base_dir)):
            raise FileOperationError("Invalid path: outside base directory")

        return full_path

    def _list_directory_sync(self, path: str, full_path: str) -> DirectoryListing:
        """Synchronous directory listing (runs in thread pool)."""
        if not os.path.exists(full_path):
            # Create the directory if it doesn't exist
            os.makedirs(full_path, exist_ok=True)
            return DirectoryListing(path=path, files=[])

        if not os.path.isdir(full_path):
            raise FileOperationError(f"Not a directory: {path}")

        files = []
        for name in os.listdir(full_path):
            item_path = os.path.join(full_path, name)
            stat = os.stat(item_path)

            file_info = FileInfo(
                name=name,
                path=os.path.join(path, name) if path else name,
                file_type=FileType.DIRECTORY if os.path.isdir(item_path) else FileType.FILE,
                size=stat.st_size if os.path.isfile(item_path) else 0,
                modified_at=datetime.fromtimestamp(stat.st_mtime),
                mime_type=mimetypes.guess_type(name)[0] if os.path.isfile(item_path) else None,
            )
            files.append(file_info)

        files.sort(key=lambda f: (f.file_type != FileType.DIRECTORY, f.name.lower()))
        return DirectoryListing(path=path, files=files)

    async def list_directory(self, path: str = "") -> DirectoryListing:
        """List contents of a directory."""
        full_path = self._resolve_path(path)
        return await asyncio.get_event_loop().run_in_executor(
            _file_executor, self._list_directory_sync, path, full_path
        )

    async def get_file_path(self, path: str) -> str:
        """Get full path to a file."""
        full_path = self._resolve_path(path)

        if not os.path.exists(full_path):
            raise FileOperationError(f"File not found: {path}")

        if not os.path.isfile(full_path):
            raise FileOperationError(f"Not a file: {path}")

        return full_path

    def _save_file_sync(self, file_path: str, content: bytes) -> None:
        """Synchronous file write (runs in thread pool)."""
        with open(file_path, "wb") as f:
            f.write(content)

    async def save_file(self, file: UploadFile, path: str = "") -> UploadResponse:
        """Save uploaded file."""
        if file.size and file.size > settings.MAX_UPLOAD_SIZE:
            raise FileOperationError(f"File too large: max {settings.MAX_UPLOAD_SIZE} bytes")

        dir_path = self._resolve_path(path)
        await asyncio.get_event_loop().run_in_executor(
            _file_executor, lambda: os.makedirs(dir_path, exist_ok=True)
        )

        filename = file.filename or "unnamed"
        file_path = os.path.join(dir_path, filename)

        counter = 1
        base, ext = os.path.splitext(filename)
        while os.path.exists(file_path):
            filename = f"{base}_{counter}{ext}"
            file_path = os.path.join(dir_path, filename)
            counter += 1

        content = await file.read()
        await asyncio.get_event_loop().run_in_executor(
            _file_executor, self._save_file_sync, file_path, content
        )

        return UploadResponse(
            filename=filename,
            path=os.path.join(path, filename) if path else filename,
            size=len(content),
            mime_type=file.content_type,
        )

    def _delete_sync(self, full_path: str) -> None:
        """Synchronous delete (runs in thread pool)."""
        if os.path.isdir(full_path):
            shutil.rmtree(full_path)
        else:
            os.remove(full_path)

    async def delete_file(self, path: str) -> None:
        """Delete a file or directory."""
        full_path = self._resolve_path(path)

        if not os.path.exists(full_path):
            raise FileOperationError(f"Not found: {path}")

        await asyncio.get_event_loop().run_in_executor(
            _file_executor, self._delete_sync, full_path
        )

    async def create_directory(self, path: str) -> None:
        """Create a directory."""
        full_path = self._resolve_path(path)

        if os.path.exists(full_path):
            raise FileOperationError(f"Already exists: {path}")

        await asyncio.get_event_loop().run_in_executor(
            _file_executor, os.makedirs, full_path
        )


file_manager = FileManager()
