"""
Client for communicating with Jupyter Enterprise Gateway instances.
"""
import asyncio
import aiohttp
from typing import Optional, Dict, Any, List
from datetime import datetime

from models.cluster import ClusterNode, NodeStatus, GPUInfo


class GatewayClient:
    """Client to communicate with a Jupyter Enterprise Gateway instance."""

    def __init__(self, node: ClusterNode, timeout: int = 30):
        self.node = node
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self._session: Optional[aiohttp.ClientSession] = None

    @property
    def base_url(self) -> str:
        return f"http://{self.node.host}:{self.node.port}"

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(timeout=self.timeout)
        return self._session

    async def close(self):
        if self._session and not self._session.closed:
            await self._session.close()

    async def health_check(self) -> bool:
        """Check if the gateway is healthy."""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api") as resp:
                return resp.status == 200
        except Exception:
            return False

    async def get_status(self) -> Dict[str, Any]:
        """Get gateway status information."""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/status") as resp:
                if resp.status == 200:
                    return await resp.json()
                return {"error": f"Status {resp.status}"}
        except Exception as e:
            return {"error": str(e)}

    async def list_kernelspecs(self) -> Dict[str, Any]:
        """List available kernel specifications."""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/kernelspecs") as resp:
                if resp.status == 200:
                    return await resp.json()
                return {"kernelspecs": {}}
        except Exception:
            return {"kernelspecs": {}}

    async def list_kernels(self) -> List[Dict[str, Any]]:
        """List running kernels on this gateway."""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/kernels") as resp:
                if resp.status == 200:
                    return await resp.json()
                return []
        except Exception:
            return []

    async def create_kernel(
        self,
        kernel_name: str = "python3",
        env: Optional[Dict[str, str]] = None
    ) -> Optional[Dict[str, Any]]:
        """Create a new kernel on this gateway."""
        try:
            session = await self._get_session()
            data = {"name": kernel_name}
            if env:
                data["env"] = env

            async with session.post(
                f"{self.base_url}/api/kernels",
                json=data
            ) as resp:
                if resp.status in (200, 201):
                    return await resp.json()
                return None
        except Exception as e:
            print(f"Error creating kernel: {e}")
            return None

    async def get_kernel(self, kernel_id: str) -> Optional[Dict[str, Any]]:
        """Get kernel information."""
        try:
            session = await self._get_session()
            async with session.get(
                f"{self.base_url}/api/kernels/{kernel_id}"
            ) as resp:
                if resp.status == 200:
                    return await resp.json()
                return None
        except Exception:
            return None

    async def interrupt_kernel(self, kernel_id: str) -> bool:
        """Interrupt a running kernel."""
        try:
            session = await self._get_session()
            async with session.post(
                f"{self.base_url}/api/kernels/{kernel_id}/interrupt"
            ) as resp:
                return resp.status == 204
        except Exception:
            return False

    async def restart_kernel(self, kernel_id: str) -> bool:
        """Restart a kernel."""
        try:
            session = await self._get_session()
            async with session.post(
                f"{self.base_url}/api/kernels/{kernel_id}/restart"
            ) as resp:
                return resp.status == 200
        except Exception:
            return False

    async def shutdown_kernel(self, kernel_id: str) -> bool:
        """Shutdown a kernel."""
        try:
            session = await self._get_session()
            async with session.delete(
                f"{self.base_url}/api/kernels/{kernel_id}"
            ) as resp:
                return resp.status == 204
        except Exception:
            return False

    async def get_gpu_info(self) -> List[GPUInfo]:
        """Get GPU information from the node."""
        try:
            session = await self._get_session()
            # Try custom GPU endpoint first
            async with session.get(f"{self.base_url}/api/gpu") as resp:
                if resp.status == 200:
                    data = await resp.json()
                    gpus = []
                    for gpu_data in data.get("gpus", []):
                        gpus.append(GPUInfo(
                            index=gpu_data.get("index", 0),
                            name=gpu_data.get("name", "Unknown"),
                            memory_total=gpu_data.get("memory_total", 0),
                            memory_used=gpu_data.get("memory_used", 0),
                            memory_free=gpu_data.get("memory_free", 0),
                            utilization=gpu_data.get("utilization", 0),
                            temperature=gpu_data.get("temperature", 0),
                            power_usage=gpu_data.get("power_usage", 0.0),
                            driver_version=gpu_data.get("driver_version", ""),
                            cuda_version=gpu_data.get("cuda_version", ""),
                        ))
                    return gpus
            return []
        except Exception:
            return []

    async def get_system_info(self) -> Dict[str, Any]:
        """Get system information from the node."""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/system") as resp:
                if resp.status == 200:
                    return await resp.json()
                return {}
        except Exception:
            return {}

    def get_websocket_url(self, kernel_id: str) -> str:
        """Get WebSocket URL for kernel communication."""
        ws_protocol = "ws"  # Use wss for production with TLS
        return f"{ws_protocol}://{self.node.host}:{self.node.port}/api/kernels/{kernel_id}/channels"
