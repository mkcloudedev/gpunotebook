"""Docker service for container management."""

import asyncio
import json
from typing import Optional, List, Dict, Any
from datetime import datetime


class DockerService:
    """Async Docker service for managing containers."""

    def __init__(self):
        self._docker_available = None

    async def _run_docker_command(self, *args: str) -> tuple[bool, str, str]:
        """Run a docker command and return (success, stdout, stderr)."""
        try:
            process = await asyncio.create_subprocess_exec(
                "docker", *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            success = process.returncode == 0
            return success, stdout.decode().strip(), stderr.decode().strip()
        except Exception as e:
            return False, "", str(e)

    async def is_available(self) -> bool:
        """Check if Docker is available."""
        if self._docker_available is None:
            success, _, _ = await self._run_docker_command("info")
            self._docker_available = success
        return self._docker_available

    async def list_containers(self, all_containers: bool = True) -> List[Dict[str, Any]]:
        """List Docker containers."""
        args = ["ps", "--format", "{{json .}}"]
        if all_containers:
            args.insert(1, "-a")

        success, stdout, stderr = await self._run_docker_command(*args)
        if not success:
            return []

        containers = []
        for line in stdout.split("\n"):
            if line.strip():
                try:
                    container = json.loads(line)
                    containers.append({
                        "id": container.get("ID", ""),
                        "name": container.get("Names", ""),
                        "image": container.get("Image", ""),
                        "status": container.get("Status", ""),
                        "state": container.get("State", ""),
                        "ports": container.get("Ports", ""),
                        "created": container.get("CreatedAt", ""),
                        "size": container.get("Size", ""),
                    })
                except json.JSONDecodeError:
                    continue

        return containers

    async def get_container(self, container_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed container info."""
        success, stdout, stderr = await self._run_docker_command(
            "inspect", container_id
        )
        if not success:
            return None

        try:
            data = json.loads(stdout)
            if data and len(data) > 0:
                container = data[0]
                state = container.get("State", {})
                config = container.get("Config", {})
                network = container.get("NetworkSettings", {})

                return {
                    "id": container.get("Id", "")[:12],
                    "name": container.get("Name", "").lstrip("/"),
                    "image": config.get("Image", ""),
                    "created": container.get("Created", ""),
                    "state": {
                        "status": state.get("Status", ""),
                        "running": state.get("Running", False),
                        "paused": state.get("Paused", False),
                        "restarting": state.get("Restarting", False),
                        "started_at": state.get("StartedAt", ""),
                        "finished_at": state.get("FinishedAt", ""),
                        "exit_code": state.get("ExitCode", 0),
                    },
                    "ports": network.get("Ports", {}),
                    "env": config.get("Env", []),
                    "cmd": config.get("Cmd", []),
                    "labels": config.get("Labels", {}),
                    "mounts": container.get("Mounts", []),
                }
        except json.JSONDecodeError:
            return None

        return None

    async def get_container_stats(self, container_id: str) -> Optional[Dict[str, Any]]:
        """Get container resource usage stats."""
        success, stdout, stderr = await self._run_docker_command(
            "stats", container_id, "--no-stream", "--format", "{{json .}}"
        )
        if not success:
            return None

        try:
            stats = json.loads(stdout)
            return {
                "container_id": stats.get("ID", ""),
                "name": stats.get("Name", ""),
                "cpu_percent": stats.get("CPUPerc", "0%"),
                "memory_usage": stats.get("MemUsage", ""),
                "memory_percent": stats.get("MemPerc", "0%"),
                "network_io": stats.get("NetIO", ""),
                "block_io": stats.get("BlockIO", ""),
                "pids": stats.get("PIDs", "0"),
            }
        except json.JSONDecodeError:
            return None

    async def get_container_logs(
        self,
        container_id: str,
        tail: int = 100,
        timestamps: bool = False
    ) -> str:
        """Get container logs."""
        args = ["logs", "--tail", str(tail)]
        if timestamps:
            args.append("--timestamps")
        args.append(container_id)

        success, stdout, stderr = await self._run_docker_command(*args)
        # Docker logs may come from stderr for some containers
        return stdout or stderr

    async def start_container(self, container_id: str) -> tuple[bool, str]:
        """Start a container."""
        success, stdout, stderr = await self._run_docker_command("start", container_id)
        return success, stderr if not success else f"Container {container_id} started"

    async def stop_container(self, container_id: str, timeout: int = 10) -> tuple[bool, str]:
        """Stop a container."""
        success, stdout, stderr = await self._run_docker_command(
            "stop", "-t", str(timeout), container_id
        )
        return success, stderr if not success else f"Container {container_id} stopped"

    async def restart_container(self, container_id: str, timeout: int = 10) -> tuple[bool, str]:
        """Restart a container."""
        success, stdout, stderr = await self._run_docker_command(
            "restart", "-t", str(timeout), container_id
        )
        return success, stderr if not success else f"Container {container_id} restarted"

    async def remove_container(self, container_id: str, force: bool = False) -> tuple[bool, str]:
        """Remove a container."""
        args = ["rm"]
        if force:
            args.append("-f")
        args.append(container_id)

        success, stdout, stderr = await self._run_docker_command(*args)
        return success, stderr if not success else f"Container {container_id} removed"

    async def list_images(self) -> List[Dict[str, Any]]:
        """List Docker images."""
        success, stdout, stderr = await self._run_docker_command(
            "images", "--format", "{{json .}}"
        )
        if not success:
            return []

        images = []
        for line in stdout.split("\n"):
            if line.strip():
                try:
                    image = json.loads(line)
                    images.append({
                        "id": image.get("ID", ""),
                        "repository": image.get("Repository", ""),
                        "tag": image.get("Tag", ""),
                        "created": image.get("CreatedAt", ""),
                        "size": image.get("Size", ""),
                    })
                except json.JSONDecodeError:
                    continue

        return images

    async def pull_image(self, image_name: str) -> tuple[bool, str]:
        """Pull a Docker image."""
        success, stdout, stderr = await self._run_docker_command("pull", image_name)
        return success, stdout if success else stderr

    async def pull_image_stream(self, image_name: str):
        """Pull a Docker image with streaming progress."""
        try:
            process = await asyncio.create_subprocess_exec(
                "docker", "pull", image_name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )

            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                yield {"type": "progress", "message": line.decode().strip()}

            await process.wait()

            if process.returncode == 0:
                yield {"type": "complete", "success": True, "message": f"Successfully pulled {image_name}"}
            else:
                yield {"type": "error", "success": False, "message": f"Failed to pull {image_name}"}

        except Exception as e:
            yield {"type": "error", "success": False, "message": str(e)}

    async def remove_image(self, image_id: str, force: bool = False) -> tuple[bool, str]:
        """Remove a Docker image."""
        args = ["rmi"]
        if force:
            args.append("-f")
        args.append(image_id)

        success, stdout, stderr = await self._run_docker_command(*args)
        return success, stderr if not success else f"Image {image_id} removed"

    async def run_container(
        self,
        image: str,
        name: Optional[str] = None,
        ports: Optional[Dict[str, str]] = None,
        env: Optional[Dict[str, str]] = None,
        volumes: Optional[Dict[str, str]] = None,
        detach: bool = True,
        restart_policy: Optional[str] = None,
        command: Optional[str] = None,
    ) -> tuple[bool, str]:
        """Run a new container."""
        args = ["run"]

        if detach:
            args.append("-d")

        if name:
            args.extend(["--name", name])

        if restart_policy:
            args.extend(["--restart", restart_policy])

        if ports:
            for host_port, container_port in ports.items():
                args.extend(["-p", f"{host_port}:{container_port}"])

        if env:
            for key, value in env.items():
                args.extend(["-e", f"{key}={value}"])

        if volumes:
            for host_path, container_path in volumes.items():
                args.extend(["-v", f"{host_path}:{container_path}"])

        args.append(image)

        if command:
            args.extend(command.split())

        success, stdout, stderr = await self._run_docker_command(*args)
        return success, stdout if success else stderr

    async def get_system_info(self) -> Optional[Dict[str, Any]]:
        """Get Docker system information."""
        success, stdout, stderr = await self._run_docker_command(
            "system", "df", "--format", "{{json .}}"
        )

        info_success, info_stdout, _ = await self._run_docker_command("info", "--format", "{{json .}}")

        result = {
            "disk_usage": [],
            "info": None
        }

        if success:
            for line in stdout.split("\n"):
                if line.strip():
                    try:
                        result["disk_usage"].append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        if info_success:
            try:
                info = json.loads(info_stdout)
                result["info"] = {
                    "containers": info.get("Containers", 0),
                    "containers_running": info.get("ContainersRunning", 0),
                    "containers_paused": info.get("ContainersPaused", 0),
                    "containers_stopped": info.get("ContainersStopped", 0),
                    "images": info.get("Images", 0),
                    "server_version": info.get("ServerVersion", ""),
                    "storage_driver": info.get("Driver", ""),
                    "memory_total": info.get("MemTotal", 0),
                    "cpus": info.get("NCPU", 0),
                    "os": info.get("OperatingSystem", ""),
                    "kernel_version": info.get("KernelVersion", ""),
                }
            except json.JSONDecodeError:
                pass

        return result

    async def exec_command(
        self,
        container_id: str,
        command: str,
        workdir: Optional[str] = None
    ) -> tuple[bool, str, str]:
        """Execute a command in a running container."""
        args = ["exec"]
        if workdir:
            args.extend(["-w", workdir])
        args.append(container_id)
        args.extend(command.split())

        return await self._run_docker_command(*args)


# Global singleton
docker_service = DockerService()
