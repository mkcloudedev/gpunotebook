"""
Package management API endpoints.
"""
import subprocess
import sys
from typing import List, Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from kernel.manager import kernel_manager

router = APIRouter()


class PackageInfo(BaseModel):
    name: str
    version: str
    location: str = ""


class OutdatedPackage(BaseModel):
    name: str
    current_version: str
    latest_version: str


class InstallRequest(BaseModel):
    package: str


class InstallResult(BaseModel):
    success: bool
    message: str
    output: str = ""
    kernels_restarted: int = 0


class PackagesResponse(BaseModel):
    packages: List[PackageInfo]


class OutdatedResponse(BaseModel):
    packages: List[OutdatedPackage]


class RequirementsResponse(BaseModel):
    requirements: str


@router.get("", response_model=PackagesResponse)
async def list_packages():
    """List all installed pip packages."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "list", "--format=json"],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode == 0:
            import json
            packages_data = json.loads(result.stdout)
            packages = [
                PackageInfo(
                    name=pkg.get("name", ""),
                    version=pkg.get("version", ""),
                    location=pkg.get("location", "")
                )
                for pkg in packages_data
            ]
            return PackagesResponse(packages=packages)
        else:
            return PackagesResponse(packages=[])
    except Exception as e:
        print(f"Error listing packages: {e}")
        return PackagesResponse(packages=[])


async def restart_all_kernels() -> int:
    """Restart all active kernels to pick up new packages."""
    restarted = 0
    try:
        kernels = await kernel_manager.list_kernels()
        for kernel in kernels:
            try:
                await kernel_manager.restart_kernel(kernel.id)
                restarted += 1
            except Exception as e:
                print(f"Failed to restart kernel {kernel.id}: {e}")
    except Exception as e:
        print(f"Error restarting kernels: {e}")
    return restarted


@router.post("/install", response_model=InstallResult)
async def install_package(request: InstallRequest):
    """Install a pip package and restart all kernels."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", request.package],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout
        )

        success = result.returncode == 0
        kernels_restarted = 0

        # Restart all kernels if installation was successful
        if success:
            kernels_restarted = await restart_all_kernels()

        return InstallResult(
            success=success,
            message=f"Package installed successfully. {kernels_restarted} kernel(s) restarted." if success else "Installation failed",
            output=result.stdout + result.stderr,
            kernels_restarted=kernels_restarted
        )
    except subprocess.TimeoutExpired:
        return InstallResult(
            success=False,
            message="Installation timed out",
            output=""
        )
    except Exception as e:
        return InstallResult(
            success=False,
            message=str(e),
            output=""
        )


@router.post("/uninstall", response_model=InstallResult)
async def uninstall_package(request: InstallRequest):
    """Uninstall a pip package and restart all kernels."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "uninstall", "-y", request.package],
            capture_output=True,
            text=True,
            timeout=120
        )

        success = result.returncode == 0
        kernels_restarted = 0

        # Restart all kernels if uninstallation was successful
        if success:
            kernels_restarted = await restart_all_kernels()

        return InstallResult(
            success=success,
            message=f"Package uninstalled successfully. {kernels_restarted} kernel(s) restarted." if success else "Uninstallation failed",
            output=result.stdout + result.stderr,
            kernels_restarted=kernels_restarted
        )
    except Exception as e:
        return InstallResult(
            success=False,
            message=str(e),
            output=""
        )


@router.get("/outdated", response_model=OutdatedResponse)
async def check_outdated():
    """Check for outdated packages."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "list", "--outdated", "--format=json"],
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode == 0:
            import json
            packages_data = json.loads(result.stdout)
            packages = [
                OutdatedPackage(
                    name=pkg.get("name", ""),
                    current_version=pkg.get("version", ""),
                    latest_version=pkg.get("latest_version", "")
                )
                for pkg in packages_data
            ]
            return OutdatedResponse(packages=packages)
        else:
            return OutdatedResponse(packages=[])
    except Exception as e:
        print(f"Error checking outdated: {e}")
        return OutdatedResponse(packages=[])


@router.get("/requirements", response_model=RequirementsResponse)
async def export_requirements():
    """Export installed packages as requirements.txt format."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "freeze"],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode == 0:
            return RequirementsResponse(requirements=result.stdout)
        else:
            return RequirementsResponse(requirements="")
    except Exception as e:
        print(f"Error exporting requirements: {e}")
        return RequirementsResponse(requirements="")


@router.post("/install-requirements", response_model=InstallResult)
async def install_from_requirements(requirements: str):
    """Install packages from requirements.txt content and restart all kernels."""
    import tempfile
    import os

    try:
        # Write requirements to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(requirements)
            temp_path = f.name

        try:
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "-r", temp_path],
                capture_output=True,
                text=True,
                timeout=600  # 10 minutes
            )

            success = result.returncode == 0
            kernels_restarted = 0

            # Restart all kernels if installation was successful
            if success:
                kernels_restarted = await restart_all_kernels()

            return InstallResult(
                success=success,
                message=f"Requirements installed successfully. {kernels_restarted} kernel(s) restarted." if success else "Installation failed",
                output=result.stdout + result.stderr,
                kernels_restarted=kernels_restarted
            )
        finally:
            os.unlink(temp_path)
    except Exception as e:
        return InstallResult(
            success=False,
            message=str(e),
            output=""
        )
