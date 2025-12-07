"""Container-based notebook execution service.

Provides isolated Python/Jupyter execution environments using Docker containers.
"""

import os
import json
import asyncio
import uuid
from typing import Optional, Dict, Any, List, AsyncGenerator
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, field
from enum import Enum


class ContainerStatus(str, Enum):
    """Container execution status."""
    CREATING = "creating"
    RUNNING = "running"
    EXECUTING = "executing"
    IDLE = "idle"
    STOPPED = "stopped"
    ERROR = "error"


@dataclass
class ContainerNotebook:
    """Represents a notebook container instance."""
    container_id: str
    name: str
    image: str
    status: ContainerStatus
    created_at: datetime
    kernel_type: str = "python3"
    workspace_path: Optional[str] = None
    ports: Dict[str, int] = field(default_factory=dict)
    environment: Dict[str, str] = field(default_factory=dict)
    last_activity: Optional[datetime] = None
    execution_count: int = 0


@dataclass
class ContainerExecutionResult:
    """Result of code execution in container."""
    execution_id: str
    container_id: str
    status: str  # success, error
    outputs: List[Dict[str, Any]]
    error: Optional[str] = None
    duration_ms: int = 0
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class ContainerNotebookService:
    """Service for managing notebook execution in Docker containers."""

    # Default images for different environments
    IMAGES = {
        "python": "python:3.11-slim",
        "python-ml": "jupyter/scipy-notebook:latest",
        "python-gpu": "nvidia/cuda:12.0-runtime-ubuntu22.04",
        "datascience": "jupyter/datascience-notebook:latest",
        "tensorflow": "tensorflow/tensorflow:latest-jupyter",
        "pytorch": "pytorch/pytorch:latest",
    }

    def __init__(self, workspace_path: str = "/home/ubuntu/workspace"):
        self.workspace_path = Path(workspace_path)
        self.containers_path = self.workspace_path / "containers"
        self.containers_path.mkdir(parents=True, exist_ok=True)

        # Track active containers
        self._containers: Dict[str, ContainerNotebook] = {}
        self._execution_lock = asyncio.Lock()

    async def _run_docker_command(
        self,
        *args: str,
        timeout: int = 60
    ) -> tuple[int, str, str]:
        """Run a Docker command."""
        try:
            process = await asyncio.create_subprocess_exec(
                "docker", *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=timeout
            )
            return process.returncode or 0, stdout.decode(), stderr.decode()
        except asyncio.TimeoutError:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)

    async def create_container(
        self,
        name: Optional[str] = None,
        image: str = "python",
        environment: Optional[Dict[str, str]] = None,
        gpu: bool = False,
        memory_limit: str = "2g",
        cpu_limit: float = 2.0,
    ) -> ContainerNotebook:
        """Create a new notebook container."""

        # Resolve image name
        actual_image = self.IMAGES.get(image, image)

        # Generate container name
        container_name = name or f"notebook-{uuid.uuid4().hex[:8]}"

        # Create container workspace
        container_workspace = self.containers_path / container_name
        container_workspace.mkdir(parents=True, exist_ok=True)

        # Build docker run command
        cmd_args = [
            "run", "-d",
            "--name", container_name,
            "-v", f"{container_workspace}:/workspace",
            "-v", f"{self.workspace_path}:/data:ro",
            "-w", "/workspace",
            "--memory", memory_limit,
            f"--cpus={cpu_limit}",
        ]

        # Add GPU support if requested
        if gpu:
            cmd_args.extend(["--gpus", "all"])

        # Add environment variables
        env = environment or {}
        env["PYTHONUNBUFFERED"] = "1"
        for key, value in env.items():
            cmd_args.extend(["-e", f"{key}={value}"])

        # Add the image and keep container running
        cmd_args.extend([
            actual_image,
            "tail", "-f", "/dev/null"  # Keep container alive
        ])

        # Run the container
        returncode, stdout, stderr = await self._run_docker_command(*cmd_args, timeout=120)

        if returncode != 0:
            raise RuntimeError(f"Failed to create container: {stderr}")

        container_id = stdout.strip()[:12]

        # Create container record
        container = ContainerNotebook(
            container_id=container_id,
            name=container_name,
            image=actual_image,
            status=ContainerStatus.RUNNING,
            created_at=datetime.now(),
            workspace_path=str(container_workspace),
            environment=env,
        )

        self._containers[container_id] = container

        # Install base packages if using slim image
        if "slim" in actual_image:
            await self._setup_python_environment(container_id)

        return container

    async def _setup_python_environment(self, container_id: str) -> None:
        """Install base packages in a slim Python container."""
        setup_commands = [
            "pip install --quiet ipython numpy pandas matplotlib",
        ]

        for cmd in setup_commands:
            await self._run_docker_command(
                "exec", container_id,
                "sh", "-c", cmd,
                timeout=300
            )

    async def execute_code(
        self,
        container_id: str,
        code: str,
        timeout: int = 300,
    ) -> ContainerExecutionResult:
        """Execute Python code in a container."""

        if container_id not in self._containers:
            # Try to find container by name or full ID
            container_id = await self._resolve_container_id(container_id)

        container = self._containers.get(container_id)
        if container:
            container.status = ContainerStatus.EXECUTING
            container.last_activity = datetime.now()

        execution_id = uuid.uuid4().hex[:12]
        started_at = datetime.now()
        outputs: List[Dict[str, Any]] = []
        error: Optional[str] = None

        try:
            async with self._execution_lock:
                # Write code to temporary file
                code_escaped = code.replace("'", "'\"'\"'")

                # Execute using python -c or ipython
                returncode, stdout, stderr = await self._run_docker_command(
                    "exec", container_id,
                    "python", "-c", code,
                    timeout=timeout
                )

                if stdout:
                    outputs.append({
                        "output_type": "stream",
                        "name": "stdout",
                        "text": stdout
                    })

                if stderr:
                    if returncode != 0:
                        outputs.append({
                            "output_type": "error",
                            "ename": "ExecutionError",
                            "evalue": stderr.split('\n')[-2] if stderr.strip() else "Unknown error",
                            "traceback": stderr.split('\n')
                        })
                        error = stderr
                    else:
                        outputs.append({
                            "output_type": "stream",
                            "name": "stderr",
                            "text": stderr
                        })

                status = "error" if returncode != 0 else "success"

        except Exception as e:
            status = "error"
            error = str(e)
            outputs.append({
                "output_type": "error",
                "ename": type(e).__name__,
                "evalue": str(e),
                "traceback": []
            })

        finally:
            if container:
                container.status = ContainerStatus.IDLE
                container.execution_count += 1

        completed_at = datetime.now()
        duration_ms = int((completed_at - started_at).total_seconds() * 1000)

        return ContainerExecutionResult(
            execution_id=execution_id,
            container_id=container_id,
            status=status,
            outputs=outputs,
            error=error,
            duration_ms=duration_ms,
            started_at=started_at,
            completed_at=completed_at,
        )

    async def execute_code_stream(
        self,
        container_id: str,
        code: str,
        timeout: int = 300,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Execute code and stream output in real-time."""

        if container_id not in self._containers:
            container_id = await self._resolve_container_id(container_id)

        container = self._containers.get(container_id)
        if container:
            container.status = ContainerStatus.EXECUTING
            container.last_activity = datetime.now()

        execution_id = uuid.uuid4().hex[:12]

        yield {
            "type": "execution_start",
            "execution_id": execution_id,
            "container_id": container_id,
        }

        try:
            # Create a script file in the container
            script_content = code.replace("'", "'\"'\"'")

            # Write script to container
            await self._run_docker_command(
                "exec", container_id,
                "sh", "-c", f"echo '{script_content}' > /tmp/script.py"
            )

            # Execute with real-time output
            process = await asyncio.create_subprocess_exec(
                "docker", "exec", container_id,
                "python", "-u", "/tmp/script.py",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            async def read_stream(stream, name):
                while True:
                    line = await stream.readline()
                    if not line:
                        break
                    yield {
                        "type": "output",
                        "output_type": "stream",
                        "name": name,
                        "text": line.decode()
                    }

            # Read stdout and stderr concurrently
            stdout_task = asyncio.create_task(self._collect_stream(process.stdout, "stdout"))
            stderr_task = asyncio.create_task(self._collect_stream(process.stderr, "stderr"))

            # Stream outputs
            done = False
            while not done:
                if process.stdout:
                    line = await process.stdout.readline()
                    if line:
                        yield {
                            "type": "output",
                            "output_type": "stream",
                            "name": "stdout",
                            "text": line.decode()
                        }

                if process.returncode is not None:
                    done = True

                await asyncio.sleep(0.01)

            await process.wait()

            # Collect remaining stderr
            if process.stderr:
                stderr_remaining = await process.stderr.read()
                if stderr_remaining:
                    yield {
                        "type": "output",
                        "output_type": "stream",
                        "name": "stderr",
                        "text": stderr_remaining.decode()
                    }

            status = "success" if process.returncode == 0 else "error"

            yield {
                "type": "execution_complete",
                "execution_id": execution_id,
                "status": status,
            }

        except Exception as e:
            yield {
                "type": "error",
                "execution_id": execution_id,
                "error": str(e)
            }

        finally:
            if container:
                container.status = ContainerStatus.IDLE
                container.execution_count += 1

    async def _collect_stream(self, stream, name: str) -> List[str]:
        """Collect all output from a stream."""
        lines = []
        if stream:
            while True:
                line = await stream.readline()
                if not line:
                    break
                lines.append(line.decode())
        return lines

    async def _resolve_container_id(self, identifier: str) -> str:
        """Resolve container name or partial ID to full short ID."""
        returncode, stdout, stderr = await self._run_docker_command(
            "ps", "-aq", "--filter", f"name={identifier}"
        )
        if stdout.strip():
            return stdout.strip()[:12]

        returncode, stdout, stderr = await self._run_docker_command(
            "ps", "-aq", "--filter", f"id={identifier}"
        )
        if stdout.strip():
            return stdout.strip()[:12]

        raise ValueError(f"Container not found: {identifier}")

    async def list_containers(self) -> List[ContainerNotebook]:
        """List all notebook containers."""
        returncode, stdout, stderr = await self._run_docker_command(
            "ps", "-a",
            "--filter", "name=notebook-",
            "--format", "{{json .}}"
        )

        containers = []
        if stdout:
            for line in stdout.strip().split('\n'):
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    container_id = data.get("ID", "")[:12]

                    # Get from cache or create new
                    if container_id in self._containers:
                        container = self._containers[container_id]
                        # Update status
                        state = data.get("State", "").lower()
                        if state == "running":
                            container.status = ContainerStatus.RUNNING
                        elif state == "exited":
                            container.status = ContainerStatus.STOPPED
                    else:
                        container = ContainerNotebook(
                            container_id=container_id,
                            name=data.get("Names", ""),
                            image=data.get("Image", ""),
                            status=ContainerStatus.RUNNING if data.get("State") == "running" else ContainerStatus.STOPPED,
                            created_at=datetime.now(),  # Approximate
                        )
                        self._containers[container_id] = container

                    containers.append(container)
                except json.JSONDecodeError:
                    continue

        return containers

    async def get_container(self, container_id: str) -> Optional[ContainerNotebook]:
        """Get a specific container."""
        if container_id not in self._containers:
            try:
                container_id = await self._resolve_container_id(container_id)
            except ValueError:
                return None

        return self._containers.get(container_id)

    async def stop_container(self, container_id: str) -> bool:
        """Stop a notebook container."""
        if container_id not in self._containers:
            try:
                container_id = await self._resolve_container_id(container_id)
            except ValueError:
                return False

        returncode, _, _ = await self._run_docker_command(
            "stop", container_id, timeout=30
        )

        if returncode == 0:
            if container_id in self._containers:
                self._containers[container_id].status = ContainerStatus.STOPPED
            return True
        return False

    async def start_container(self, container_id: str) -> bool:
        """Start a stopped notebook container."""
        if container_id not in self._containers:
            try:
                container_id = await self._resolve_container_id(container_id)
            except ValueError:
                return False

        returncode, _, _ = await self._run_docker_command(
            "start", container_id
        )

        if returncode == 0:
            if container_id in self._containers:
                self._containers[container_id].status = ContainerStatus.RUNNING
            return True
        return False

    async def remove_container(self, container_id: str, force: bool = False) -> bool:
        """Remove a notebook container."""
        if container_id not in self._containers:
            try:
                container_id = await self._resolve_container_id(container_id)
            except ValueError:
                return False

        args = ["rm"]
        if force:
            args.append("-f")
        args.append(container_id)

        returncode, _, _ = await self._run_docker_command(*args)

        if returncode == 0:
            self._containers.pop(container_id, None)
            return True
        return False

    async def install_package(
        self,
        container_id: str,
        package: str,
        upgrade: bool = False
    ) -> Dict[str, Any]:
        """Install a Python package in a container."""
        cmd = ["pip", "install"]
        if upgrade:
            cmd.append("--upgrade")
        cmd.append(package)

        returncode, stdout, stderr = await self._run_docker_command(
            "exec", container_id, *cmd,
            timeout=300
        )

        return {
            "success": returncode == 0,
            "package": package,
            "output": stdout if returncode == 0 else stderr
        }

    async def get_installed_packages(self, container_id: str) -> List[Dict[str, str]]:
        """List installed packages in a container."""
        returncode, stdout, stderr = await self._run_docker_command(
            "exec", container_id,
            "pip", "list", "--format=json"
        )

        if returncode == 0:
            try:
                return json.loads(stdout)
            except json.JSONDecodeError:
                return []
        return []

    async def copy_file_to_container(
        self,
        container_id: str,
        local_path: str,
        container_path: str
    ) -> bool:
        """Copy a file to a container."""
        returncode, _, _ = await self._run_docker_command(
            "cp", local_path, f"{container_id}:{container_path}"
        )
        return returncode == 0

    async def copy_file_from_container(
        self,
        container_id: str,
        container_path: str,
        local_path: str
    ) -> bool:
        """Copy a file from a container."""
        returncode, _, _ = await self._run_docker_command(
            "cp", f"{container_id}:{container_path}", local_path
        )
        return returncode == 0

    async def get_container_files(
        self,
        container_id: str,
        path: str = "/workspace"
    ) -> List[Dict[str, Any]]:
        """List files in a container directory."""
        returncode, stdout, stderr = await self._run_docker_command(
            "exec", container_id,
            "ls", "-la", path
        )

        if returncode != 0:
            return []

        files = []
        for line in stdout.strip().split('\n')[1:]:  # Skip total line
            parts = line.split()
            if len(parts) >= 9:
                files.append({
                    "permissions": parts[0],
                    "size": int(parts[4]) if parts[4].isdigit() else 0,
                    "name": ' '.join(parts[8:]),
                    "is_directory": parts[0].startswith('d'),
                })

        return files


# Global service instance
container_notebook_service = ContainerNotebookService()
