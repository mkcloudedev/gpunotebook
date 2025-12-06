"""
Cluster manager for orchestrating multiple GPU nodes.
"""
import asyncio
import uuid
import json
from typing import Dict, Optional, List
from datetime import datetime
from pathlib import Path

from models.cluster import (
    ClusterNode, ClusterNodeCreate, ClusterNodeUpdate,
    NodeStatus, ClusterStats, KernelPlacement, GPUInfo
)
from .gateway_client import GatewayClient


class ClusterManager:
    """
    Manages a cluster of GPU nodes running Jupyter Enterprise Gateway.

    Features:
    - Node registration and discovery
    - Health monitoring
    - Kernel placement with GPU-awareness
    - Load balancing
    - Failover
    """

    def __init__(self, config_path: str = "cluster_config.json"):
        self._nodes: Dict[str, ClusterNode] = {}
        self._clients: Dict[str, GatewayClient] = {}
        self._kernel_to_node: Dict[str, str] = {}  # kernel_id -> node_id
        self._lock = asyncio.Lock()
        self._config_path = Path(config_path)
        self._monitor_task: Optional[asyncio.Task] = None
        self._monitor_interval = 30  # seconds

    async def initialize(self) -> None:
        """Initialize cluster manager and load saved configuration."""
        await self._load_config()
        self._monitor_task = asyncio.create_task(self._monitor_loop())

    async def shutdown(self) -> None:
        """Shutdown cluster manager."""
        if self._monitor_task:
            self._monitor_task.cancel()
            try:
                await self._monitor_task
            except asyncio.CancelledError:
                pass

        for client in self._clients.values():
            await client.close()

    async def _load_config(self) -> None:
        """Load cluster configuration from file."""
        if self._config_path.exists():
            try:
                with open(self._config_path, 'r') as f:
                    data = json.load(f)
                    for node_data in data.get("nodes", []):
                        node = ClusterNode(**node_data)
                        node.status = NodeStatus.OFFLINE  # Will be updated by monitor
                        self._nodes[node.id] = node
                        self._clients[node.id] = GatewayClient(node)
            except Exception as e:
                print(f"Error loading cluster config: {e}")

    async def _save_config(self) -> None:
        """Save cluster configuration to file."""
        try:
            data = {
                "nodes": [node.model_dump() for node in self._nodes.values()]
            }
            # Convert datetime objects to strings
            for node_data in data["nodes"]:
                for key, value in node_data.items():
                    if isinstance(value, datetime):
                        node_data[key] = value.isoformat()

            with open(self._config_path, 'w') as f:
                json.dump(data, f, indent=2, default=str)
        except Exception as e:
            print(f"Error saving cluster config: {e}")

    async def _monitor_loop(self) -> None:
        """Background task to monitor node health."""
        while True:
            try:
                await asyncio.sleep(self._monitor_interval)
                await self._check_all_nodes()
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Monitor error: {e}")

    async def _check_all_nodes(self) -> None:
        """Check health of all nodes."""
        tasks = []
        for node_id in list(self._nodes.keys()):
            tasks.append(self._check_node(node_id))
        await asyncio.gather(*tasks, return_exceptions=True)

    async def _check_node(self, node_id: str) -> None:
        """Check health of a single node."""
        if node_id not in self._clients:
            return

        client = self._clients[node_id]
        node = self._nodes[node_id]

        try:
            is_healthy = await client.health_check()

            if is_healthy:
                # Get detailed info
                gpus = await client.get_gpu_info()
                kernels = await client.list_kernels()
                system = await client.get_system_info()

                async with self._lock:
                    node.status = NodeStatus.ONLINE
                    node.gpus = gpus
                    node.active_kernels = len(kernels)
                    node.last_heartbeat = datetime.utcnow()
                    if system:
                        node.cpu_count = system.get("cpu_count", 0)
                        node.memory_total = system.get("memory_total", 0)
                        node.memory_available = system.get("memory_available", 0)
            else:
                async with self._lock:
                    node.status = NodeStatus.OFFLINE
                    node.last_heartbeat = None
        except Exception as e:
            async with self._lock:
                node.status = NodeStatus.ERROR
                print(f"Error checking node {node_id}: {e}")

    async def add_node(self, request: ClusterNodeCreate) -> ClusterNode:
        """Add a new node to the cluster."""
        node_id = str(uuid.uuid4())

        node = ClusterNode(
            id=node_id,
            name=request.name,
            host=request.host,
            port=request.port,
            tags=request.tags,
            priority=request.priority,
            status=NodeStatus.OFFLINE,
        )

        client = GatewayClient(node)

        # Check if node is reachable
        if await client.health_check():
            node.status = NodeStatus.ONLINE
            node.last_heartbeat = datetime.utcnow()

            # Get GPU info
            node.gpus = await client.get_gpu_info()

        async with self._lock:
            self._nodes[node_id] = node
            self._clients[node_id] = client

        await self._save_config()
        return node

    async def remove_node(self, node_id: str) -> bool:
        """Remove a node from the cluster."""
        async with self._lock:
            if node_id in self._clients:
                await self._clients[node_id].close()
                del self._clients[node_id]

            if node_id in self._nodes:
                del self._nodes[node_id]
                await self._save_config()
                return True

        return False

    async def update_node(self, node_id: str, update: ClusterNodeUpdate) -> Optional[ClusterNode]:
        """Update node configuration."""
        async with self._lock:
            if node_id not in self._nodes:
                return None

            node = self._nodes[node_id]
            if update.name is not None:
                node.name = update.name
            if update.port is not None:
                node.port = update.port
                # Recreate client with new port
                await self._clients[node_id].close()
                self._clients[node_id] = GatewayClient(node)
            if update.tags is not None:
                node.tags = update.tags
            if update.priority is not None:
                node.priority = update.priority
            if update.status is not None:
                node.status = update.status

        await self._save_config()
        return node

    async def get_node(self, node_id: str) -> Optional[ClusterNode]:
        """Get node by ID."""
        return self._nodes.get(node_id)

    async def list_nodes(self) -> List[ClusterNode]:
        """List all nodes."""
        return list(self._nodes.values())

    async def get_stats(self) -> ClusterStats:
        """Get cluster statistics."""
        nodes = list(self._nodes.values())
        online_nodes = [n for n in nodes if n.status == NodeStatus.ONLINE]

        total_gpus = sum(len(n.gpus) for n in nodes)
        available_gpus = sum(
            len([g for g in n.gpus if g.memory_free > 1000])  # >1GB free
            for n in online_nodes
        )

        return ClusterStats(
            total_nodes=len(nodes),
            online_nodes=len(online_nodes),
            total_gpus=total_gpus,
            available_gpus=available_gpus,
            total_memory=sum(n.memory_total for n in nodes),
            available_memory=sum(n.memory_available for n in online_nodes),
            active_kernels=sum(n.active_kernels for n in nodes),
            max_kernels=sum(n.max_kernels for n in nodes),
        )

    async def select_best_node(self, placement: KernelPlacement) -> Optional[ClusterNode]:
        """
        Select the best node for kernel placement based on criteria.

        Selection criteria:
        1. Node must be online
        2. Node must have available kernel slots
        3. If GPU required, node must have GPU with enough memory
        4. If tags specified, node must have all tags
        5. Prefer nodes with higher priority
        6. Prefer nodes with lower utilization
        """
        candidates = []

        for node in self._nodes.values():
            # Must be online
            if node.status != NodeStatus.ONLINE:
                continue

            # Must have kernel slots
            if node.active_kernels >= node.max_kernels:
                continue

            # Check GPU requirements
            if placement.require_gpu:
                suitable_gpus = [
                    g for g in node.gpus
                    if g.memory_free >= placement.min_gpu_memory
                ]
                if not suitable_gpus:
                    continue

            # Check tags
            if placement.tags:
                if not all(tag in node.tags for tag in placement.tags):
                    continue

            # Calculate score
            score = node.priority * 100

            # Prefer nodes with more free GPU memory
            if node.gpus:
                max_free = max(g.memory_free for g in node.gpus)
                score += max_free / 1000  # Add points per GB free

            # Prefer less utilized nodes
            if node.max_kernels > 0:
                utilization = node.active_kernels / node.max_kernels
                score += (1 - utilization) * 50

            candidates.append((score, node))

        if not candidates:
            return None

        # Sort by score (descending) and return best
        candidates.sort(key=lambda x: x[0], reverse=True)
        return candidates[0][1]

    async def create_kernel_on_node(
        self,
        node_id: str,
        kernel_name: str = "python3",
        env: Optional[Dict[str, str]] = None
    ) -> Optional[Dict]:
        """Create a kernel on a specific node."""
        if node_id not in self._clients:
            return None

        client = self._clients[node_id]
        result = await client.create_kernel(kernel_name, env)

        if result:
            kernel_id = result.get("id")
            if kernel_id:
                async with self._lock:
                    self._kernel_to_node[kernel_id] = node_id
                    self._nodes[node_id].active_kernels += 1
            result["node_id"] = node_id
            result["node_name"] = self._nodes[node_id].name

        return result

    async def create_kernel(
        self,
        placement: KernelPlacement,
        kernel_name: str = "python3",
        env: Optional[Dict[str, str]] = None
    ) -> Optional[Dict]:
        """Create a kernel with automatic or specified placement."""
        # Use specified node or select best
        if placement.node_id:
            node = await self.get_node(placement.node_id)
        else:
            node = await self.select_best_node(placement)

        if not node:
            return None

        return await self.create_kernel_on_node(node.id, kernel_name, env)

    async def get_kernel_node(self, kernel_id: str) -> Optional[ClusterNode]:
        """Get the node running a kernel."""
        node_id = self._kernel_to_node.get(kernel_id)
        if node_id:
            return self._nodes.get(node_id)
        return None

    async def interrupt_kernel(self, kernel_id: str) -> bool:
        """Interrupt a kernel."""
        node_id = self._kernel_to_node.get(kernel_id)
        if not node_id or node_id not in self._clients:
            return False
        return await self._clients[node_id].interrupt_kernel(kernel_id)

    async def restart_kernel(self, kernel_id: str) -> bool:
        """Restart a kernel."""
        node_id = self._kernel_to_node.get(kernel_id)
        if not node_id or node_id not in self._clients:
            return False
        return await self._clients[node_id].restart_kernel(kernel_id)

    async def shutdown_kernel(self, kernel_id: str) -> bool:
        """Shutdown a kernel."""
        node_id = self._kernel_to_node.get(kernel_id)
        if not node_id or node_id not in self._clients:
            return False

        result = await self._clients[node_id].shutdown_kernel(kernel_id)

        if result:
            async with self._lock:
                del self._kernel_to_node[kernel_id]
                if node_id in self._nodes:
                    self._nodes[node_id].active_kernels = max(
                        0, self._nodes[node_id].active_kernels - 1
                    )

        return result

    def get_websocket_url(self, kernel_id: str) -> Optional[str]:
        """Get WebSocket URL for a kernel."""
        node_id = self._kernel_to_node.get(kernel_id)
        if not node_id or node_id not in self._clients:
            return None
        return self._clients[node_id].get_websocket_url(kernel_id)


# Global instance
cluster_manager = ClusterManager()
