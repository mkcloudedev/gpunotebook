"""
GPU monitoring service using nvidia-smi.
"""
import asyncio
import subprocess
import xml.etree.ElementTree as ET
from typing import Optional, List

from models.gpu import GPUStatus, GPUProcess, GPUSystemStatus
from core.config import settings


class GPUMonitor:
    """Monitors GPU status using nvidia-smi."""

    def __init__(self):
        self._running = False
        self._last_status: Optional[GPUSystemStatus] = None
        self._update_task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        """Start background monitoring."""
        if not settings.ENABLE_GPU:
            return

        self._running = True
        self._update_task = asyncio.create_task(self._update_loop())

    async def stop(self) -> None:
        """Stop background monitoring."""
        self._running = False
        if self._update_task:
            self._update_task.cancel()
            try:
                await self._update_task
            except asyncio.CancelledError:
                pass

    async def _update_loop(self) -> None:
        """Background update loop."""
        while self._running:
            try:
                self._last_status = await self._fetch_status()
            except Exception:
                self._last_status = None

            await asyncio.sleep(2)

    async def _fetch_status(self) -> Optional[GPUSystemStatus]:
        """Fetch GPU status from nvidia-smi."""
        proc = None
        try:
            proc = await asyncio.create_subprocess_exec(
                "nvidia-smi", "-q", "-x",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)

            if proc.returncode != 0:
                return None

            return self._parse_nvidia_smi(stdout.decode())

        except FileNotFoundError:
            return None
        except asyncio.TimeoutError:
            if proc:
                proc.kill()
            return None
        except OSError as e:
            # Handle "Too many open files" and similar errors
            return None
        finally:
            # Ensure process is cleaned up
            if proc and proc.returncode is None:
                try:
                    proc.kill()
                    await proc.wait()
                except Exception:
                    pass

    def _parse_nvidia_smi(self, xml_output: str) -> GPUSystemStatus:
        """Parse nvidia-smi XML output."""
        root = ET.fromstring(xml_output)

        driver_version = root.findtext("driver_version", "")
        cuda_version = root.findtext("cuda_version", "")

        gpus = []
        for i, gpu in enumerate(root.findall("gpu")):
            memory = gpu.find("fb_memory_usage")
            utilization = gpu.find("utilization")
            temperature = gpu.find("temperature")
            power = gpu.find("gpu_power_readings") or gpu.find("power_readings")

            processes = []
            procs_elem = gpu.find("processes")
            if procs_elem is not None:
                for proc in procs_elem.findall("process_info"):
                    pid = proc.findtext("pid", "0")
                    name = proc.findtext("process_name", "")
                    mem = proc.findtext("used_memory", "0 MiB")
                    mem_mb = int(mem.replace(" MiB", "").replace(" MB", ""))

                    processes.append(GPUProcess(
                        pid=int(pid),
                        name=name,
                        memory_used_mb=mem_mb,
                        gpu_index=i,
                    ))

            gpu_status = GPUStatus(
                index=i,
                name=gpu.findtext("product_name", "Unknown"),
                uuid=gpu.findtext("uuid", ""),
                temperature_c=self._parse_int(temperature.findtext("gpu_temp", "0") if temperature else "0"),
                utilization_percent=self._parse_int(utilization.findtext("gpu_util", "0") if utilization else "0"),
                memory_used_mb=self._parse_int(memory.findtext("used", "0") if memory else "0"),
                memory_total_mb=self._parse_int(memory.findtext("total", "0") if memory else "0"),
                memory_free_mb=self._parse_int(memory.findtext("free", "0") if memory else "0"),
                power_draw_w=self._parse_float(
                    power.findtext("instant_power_draw", "") or
                    power.findtext("average_power_draw", "") or
                    power.findtext("power_draw", "") if power else ""
                ),
                power_limit_w=self._parse_float(
                    power.findtext("current_power_limit", "") or
                    power.findtext("power_limit", "") if power else ""
                ),
                processes=processes,
            )
            gpus.append(gpu_status)

        return GPUSystemStatus(
            driver_version=driver_version,
            cuda_version=cuda_version,
            gpu_count=len(gpus),
            gpus=gpus,
        )

    def _parse_int(self, value: str) -> int:
        """Parse integer from nvidia-smi output."""
        value = value.replace(" MiB", "").replace(" MB", "")
        value = value.replace(" %", "").replace(" C", "")
        try:
            return int(float(value))
        except (ValueError, TypeError):
            return 0

    def _parse_float(self, value: str) -> Optional[float]:
        """Parse float from nvidia-smi output."""
        if not value:
            return None
        value = value.replace(" W", "")
        try:
            return float(value)
        except (ValueError, TypeError):
            return None

    async def get_status(self) -> Optional[GPUSystemStatus]:
        """Get current GPU status."""
        if self._last_status:
            return self._last_status
        return await self._fetch_status()


gpu_monitor = GPUMonitor()
