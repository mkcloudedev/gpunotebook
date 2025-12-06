"""
Application lifespan management - startup and shutdown events.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI

from kernel.manager import kernel_manager
from services.gpu_monitor import gpu_monitor
from services.notebook_store import notebook_store
from cluster.manager import cluster_manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application startup and shutdown."""
    # Startup
    await notebook_store.init()  # Initialize database
    await kernel_manager.initialize()
    await cluster_manager.initialize()  # Initialize GPU cluster
    await gpu_monitor.start()

    yield

    # Shutdown
    await kernel_manager.shutdown_all()
    await cluster_manager.shutdown()
    await gpu_monitor.stop()
