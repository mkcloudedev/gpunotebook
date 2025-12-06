"""
Kernel lifecycle manager - creates, tracks, and destroys kernels.
"""
import asyncio
import uuid
from typing import Dict, Optional
from datetime import datetime

from jupyter_client import KernelManager as JupyterKernelManager
from jupyter_client import AsyncKernelClient

from models.kernel import Kernel, KernelStatus, KernelCreate
from core.config import settings
from core.exceptions import KernelNotFoundError, KernelStartError


class KernelManager:
    """Manages IPython kernel lifecycle."""

    def __init__(self):
        self._kernels: Dict[str, Kernel] = {}
        self._jupyter_managers: Dict[str, JupyterKernelManager] = {}
        self._clients: Dict[str, AsyncKernelClient] = {}
        self._lock = asyncio.Lock()

    async def initialize(self) -> None:
        """Initialize the kernel manager."""
        pass

    async def create_kernel(self, request: KernelCreate) -> Kernel:
        """Create a new kernel."""
        kernel_id = str(uuid.uuid4())

        async with self._lock:
            if len(self._kernels) >= settings.MAX_KERNELS:
                oldest = min(self._kernels.values(), key=lambda k: k.last_activity)
                await self.shutdown_kernel(oldest.id)

        try:
            km = JupyterKernelManager(kernel_name=request.name)
            km.start_kernel()

            client = km.client()
            client.start_channels()
            client.wait_for_ready(timeout=settings.KERNEL_TIMEOUT)

            kernel = Kernel(
                id=kernel_id,
                name=request.name,
                status=KernelStatus.IDLE,
                notebook_id=request.notebook_id,
            )

            async with self._lock:
                self._kernels[kernel_id] = kernel
                self._jupyter_managers[kernel_id] = km
                self._clients[kernel_id] = client

            return kernel

        except Exception as e:
            raise KernelStartError(f"Failed to start kernel: {e}")

    async def get_kernel(self, kernel_id: str) -> Kernel:
        """Get kernel by ID."""
        if kernel_id not in self._kernels:
            raise KernelNotFoundError(f"Kernel {kernel_id} not found")
        return self._kernels[kernel_id]

    async def list_kernels(self) -> list[Kernel]:
        """List all active kernels."""
        return list(self._kernels.values())

    async def get_client(self, kernel_id: str) -> AsyncKernelClient:
        """Get Jupyter client for kernel."""
        if kernel_id not in self._clients:
            raise KernelNotFoundError(f"Kernel {kernel_id} not found")
        return self._clients[kernel_id]

    async def update_status(self, kernel_id: str, status: KernelStatus) -> None:
        """Update kernel status."""
        if kernel_id in self._kernels:
            self._kernels[kernel_id].status = status
            self._kernels[kernel_id].last_activity = datetime.utcnow()

    async def interrupt_kernel(self, kernel_id: str) -> None:
        """Interrupt kernel execution."""
        if kernel_id not in self._jupyter_managers:
            raise KernelNotFoundError(f"Kernel {kernel_id} not found")

        self._jupyter_managers[kernel_id].interrupt_kernel()
        await self.update_status(kernel_id, KernelStatus.IDLE)

    async def restart_kernel(self, kernel_id: str) -> Kernel:
        """Restart a kernel."""
        if kernel_id not in self._jupyter_managers:
            raise KernelNotFoundError(f"Kernel {kernel_id} not found")

        await self.update_status(kernel_id, KernelStatus.RESTARTING)

        km = self._jupyter_managers[kernel_id]
        km.restart_kernel()

        client = self._clients[kernel_id]
        client.wait_for_ready(timeout=settings.KERNEL_TIMEOUT)

        kernel = self._kernels[kernel_id]
        kernel.status = KernelStatus.IDLE
        kernel.execution_count = 0
        kernel.last_activity = datetime.utcnow()

        return kernel

    async def shutdown_kernel(self, kernel_id: str) -> None:
        """Shutdown a kernel."""
        async with self._lock:
            if kernel_id in self._clients:
                self._clients[kernel_id].stop_channels()
                del self._clients[kernel_id]

            if kernel_id in self._jupyter_managers:
                self._jupyter_managers[kernel_id].shutdown_kernel()
                del self._jupyter_managers[kernel_id]

            if kernel_id in self._kernels:
                del self._kernels[kernel_id]

    async def shutdown_all(self) -> None:
        """Shutdown all kernels."""
        kernel_ids = list(self._kernels.keys())
        for kernel_id in kernel_ids:
            await self.shutdown_kernel(kernel_id)


kernel_manager = KernelManager()
