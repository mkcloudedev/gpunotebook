"""
Cluster management API endpoints.
"""
from fastapi import APIRouter, HTTPException
from typing import List, Optional

from models.cluster import (
    ClusterNode, ClusterNodeCreate, ClusterNodeUpdate,
    ClusterStats, KernelPlacement
)
from cluster.manager import cluster_manager

router = APIRouter()


@router.get("/nodes", response_model=List[ClusterNode])
async def list_nodes():
    """List all cluster nodes."""
    return await cluster_manager.list_nodes()


@router.get("/nodes/{node_id}", response_model=ClusterNode)
async def get_node(node_id: str):
    """Get a specific node."""
    node = await cluster_manager.get_node(node_id)
    if not node:
        raise HTTPException(status_code=404, detail="Node not found")
    return node


@router.post("/nodes", response_model=ClusterNode)
async def add_node(request: ClusterNodeCreate):
    """Add a new node to the cluster."""
    try:
        return await cluster_manager.add_node(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/nodes/{node_id}", response_model=ClusterNode)
async def update_node(node_id: str, update: ClusterNodeUpdate):
    """Update node configuration."""
    node = await cluster_manager.update_node(node_id, update)
    if not node:
        raise HTTPException(status_code=404, detail="Node not found")
    return node


@router.delete("/nodes/{node_id}")
async def remove_node(node_id: str):
    """Remove a node from the cluster."""
    if await cluster_manager.remove_node(node_id):
        return {"status": "removed"}
    raise HTTPException(status_code=404, detail="Node not found")


@router.get("/stats", response_model=ClusterStats)
async def get_cluster_stats():
    """Get cluster statistics."""
    return await cluster_manager.get_stats()


@router.post("/kernels")
async def create_cluster_kernel(
    placement: Optional[KernelPlacement] = None,
    kernel_name: str = "python3"
):
    """Create a kernel on the cluster with automatic or specified placement."""
    if placement is None:
        placement = KernelPlacement()

    result = await cluster_manager.create_kernel(placement, kernel_name)
    if not result:
        raise HTTPException(
            status_code=503,
            detail="No available nodes match the placement criteria"
        )
    return result


@router.post("/nodes/{node_id}/kernels")
async def create_kernel_on_node(node_id: str, kernel_name: str = "python3"):
    """Create a kernel on a specific node."""
    node = await cluster_manager.get_node(node_id)
    if not node:
        raise HTTPException(status_code=404, detail="Node not found")

    result = await cluster_manager.create_kernel_on_node(node_id, kernel_name)
    if not result:
        raise HTTPException(
            status_code=500,
            detail="Failed to create kernel on node"
        )
    return result


@router.get("/kernels/{kernel_id}/node")
async def get_kernel_node(kernel_id: str):
    """Get the node running a specific kernel."""
    node = await cluster_manager.get_kernel_node(kernel_id)
    if not node:
        raise HTTPException(status_code=404, detail="Kernel not found in cluster")
    return node


@router.post("/kernels/{kernel_id}/interrupt")
async def interrupt_cluster_kernel(kernel_id: str):
    """Interrupt a kernel running on the cluster."""
    if await cluster_manager.interrupt_kernel(kernel_id):
        return {"status": "interrupted"}
    raise HTTPException(status_code=404, detail="Kernel not found")


@router.post("/kernels/{kernel_id}/restart")
async def restart_cluster_kernel(kernel_id: str):
    """Restart a kernel running on the cluster."""
    if await cluster_manager.restart_kernel(kernel_id):
        return {"status": "restarted"}
    raise HTTPException(status_code=404, detail="Kernel not found")


@router.delete("/kernels/{kernel_id}")
async def shutdown_cluster_kernel(kernel_id: str):
    """Shutdown a kernel running on the cluster."""
    if await cluster_manager.shutdown_kernel(kernel_id):
        return {"status": "shutdown"}
    raise HTTPException(status_code=404, detail="Kernel not found")


@router.get("/kernels/{kernel_id}/websocket")
async def get_kernel_websocket(kernel_id: str):
    """Get WebSocket URL for a kernel."""
    url = cluster_manager.get_websocket_url(kernel_id)
    if not url:
        raise HTTPException(status_code=404, detail="Kernel not found")
    return {"url": url}


@router.post("/nodes/{node_id}/refresh")
async def refresh_node(node_id: str):
    """Force refresh node status."""
    node = await cluster_manager.get_node(node_id)
    if not node:
        raise HTTPException(status_code=404, detail="Node not found")

    await cluster_manager._check_node(node_id)
    return await cluster_manager.get_node(node_id)
