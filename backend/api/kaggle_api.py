"""
Kaggle API Integration
"""
import os
import json
import csv
import io
import subprocess
from pathlib import Path
from typing import Optional, List
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel

router = APIRouter(tags=["kaggle"])

# Kaggle credentials path
KAGGLE_DIR = Path.home() / ".kaggle"
KAGGLE_JSON = KAGGLE_DIR / "kaggle.json"
DATASETS_DIR = Path.home() / "datasets"


class KaggleCredentials(BaseModel):
    username: str
    key: str


class DatasetDownload(BaseModel):
    dataset: str  # format: owner/dataset-name
    path: Optional[str] = None
    unzip: bool = True


class CompetitionDownload(BaseModel):
    competition: str
    path: Optional[str] = None
    file: Optional[str] = None


class SubmissionUpload(BaseModel):
    competition: str
    message: str


class KernelPull(BaseModel):
    kernel_ref: str  # format: owner/kernel-name
    path: Optional[str] = None


class DatasetInfo(BaseModel):
    ref: str
    title: str
    size: str
    lastUpdated: str
    downloadCount: int
    voteCount: int
    usabilityRating: float


class CompetitionInfo(BaseModel):
    ref: str
    title: str
    deadline: str
    category: str
    reward: str
    teamCount: int
    userHasEntered: bool


# ============================================================================
# CREDENTIALS
# ============================================================================

@router.get("/status")
async def get_kaggle_status():
    """Check if Kaggle is configured"""
    if not KAGGLE_JSON.exists():
        return {
            "configured": False,
            "message": "Kaggle credentials not found. Please configure your API key."
        }

    try:
        with open(KAGGLE_JSON) as f:
            creds = json.load(f)

        # Test the credentials
        result = subprocess.run(
            ["kaggle", "config", "view"],
            capture_output=True,
            text=True,
            timeout=10
        )

        return {
            "configured": True,
            "username": creds.get("username", "Unknown"),
            "message": "Kaggle is configured and ready"
        }
    except Exception as e:
        return {
            "configured": False,
            "message": f"Error checking Kaggle status: {str(e)}"
        }


@router.post("/credentials")
async def set_kaggle_credentials(credentials: KaggleCredentials):
    """Set Kaggle API credentials"""
    try:
        # Create .kaggle directory if not exists
        KAGGLE_DIR.mkdir(parents=True, exist_ok=True)

        # Write credentials
        with open(KAGGLE_JSON, "w") as f:
            json.dump({
                "username": credentials.username,
                "key": credentials.key
            }, f)

        # Set permissions (required by Kaggle)
        os.chmod(KAGGLE_JSON, 0o600)

        return {"success": True, "message": "Kaggle credentials saved successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# DATASETS
# ============================================================================

@router.get("/datasets/search")
async def search_datasets(query: str, page: int = 1, page_size: int = 20):
    """Search Kaggle datasets"""
    try:
        result = subprocess.run(
            ["kaggle", "datasets", "list", "-s", query, "--csv", "-p", str(page)],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output properly using csv module
        if not result.stdout.strip():
            return {"datasets": [], "total": 0}

        reader = csv.DictReader(io.StringIO(result.stdout))
        datasets = []

        for row in reader:
            datasets.append({
                "ref": row.get("ref", ""),
                "title": row.get("title", ""),
                "size": row.get("size", "0"),
                "lastUpdated": row.get("lastUpdated", ""),
                "downloadCount": int(row.get("downloadCount", 0) or 0),
                "voteCount": int(row.get("voteCount", 0) or 0),
                "usabilityRating": float(row.get("usabilityRating", 0) or 0)
            })

        return {"datasets": datasets, "total": len(datasets)}
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Request timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/datasets/list")
async def list_datasets(sort_by: str = "hottest", page: int = 1, page_size: int = 20):
    """List popular Kaggle datasets"""
    try:
        result = subprocess.run(
            ["kaggle", "datasets", "list", "--sort-by", sort_by, "--csv", "-p", str(page)],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output properly using csv module
        if not result.stdout.strip():
            return {"datasets": [], "total": 0}

        reader = csv.DictReader(io.StringIO(result.stdout))
        datasets = []

        for row in reader:
            datasets.append({
                "ref": row.get("ref", ""),
                "title": row.get("title", ""),
                "size": row.get("size", "0"),
                "lastUpdated": row.get("lastUpdated", ""),
                "downloadCount": int(row.get("downloadCount", 0) or 0),
                "voteCount": int(row.get("voteCount", 0) or 0),
                "usabilityRating": float(row.get("usabilityRating", 0) or 0)
            })

        return {"datasets": datasets, "total": len(datasets)}
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Request timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/datasets/download")
async def download_dataset(request: DatasetDownload):
    """Download a Kaggle dataset"""
    try:
        # Create datasets directory
        download_path = Path(request.path) if request.path else DATASETS_DIR / request.dataset.replace("/", "_")
        download_path.mkdir(parents=True, exist_ok=True)

        cmd = ["kaggle", "datasets", "download", "-d", request.dataset, "-p", str(download_path)]
        if request.unzip:
            cmd.append("--unzip")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout for large datasets
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # List downloaded files
        files = list(download_path.glob("*"))

        return {
            "success": True,
            "path": str(download_path),
            "files": [f.name for f in files],
            "message": f"Dataset downloaded to {download_path}"
        }
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Download timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/datasets/{owner}/{dataset_name}/files")
async def get_dataset_files(owner: str, dataset_name: str):
    """Get files in a dataset"""
    try:
        result = subprocess.run(
            ["kaggle", "datasets", "files", f"{owner}/{dataset_name}", "--csv"],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output
        lines = result.stdout.strip().split("\n")
        if len(lines) <= 1:
            return {"files": []}

        headers = lines[0].split(",")
        files = []

        for line in lines[1:]:
            values = line.split(",")
            if len(values) >= len(headers):
                file_info = dict(zip(headers, values))
                files.append({
                    "name": file_info.get("name", ""),
                    "size": file_info.get("size", "0"),
                    "creationDate": file_info.get("creationDate", "")
                })

        return {"files": files}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# COMPETITIONS
# ============================================================================

@router.get("/competitions/list")
async def list_competitions(category: str = "all", sort_by: str = "latestDeadline", page: int = 1):
    """List Kaggle competitions"""
    try:
        cmd = ["kaggle", "competitions", "list", "--csv", "-p", str(page)]
        if category != "all":
            cmd.extend(["--category", category])
        cmd.extend(["--sort-by", sort_by])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output properly using csv module
        if not result.stdout.strip():
            return {"competitions": [], "total": 0}

        reader = csv.DictReader(io.StringIO(result.stdout))
        competitions = []

        for row in reader:
            competitions.append({
                "ref": row.get("ref", ""),
                "title": row.get("title", ""),
                "deadline": row.get("deadline", ""),
                "category": row.get("category", ""),
                "reward": row.get("reward", ""),
                "teamCount": int(row.get("teamCount", 0) or 0),
                "userHasEntered": row.get("userHasEntered", "False") == "True"
            })

        return {"competitions": competitions, "total": len(competitions)}
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Request timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/competitions/{competition}/files")
async def get_competition_files(competition: str):
    """Get files for a competition"""
    try:
        result = subprocess.run(
            ["kaggle", "competitions", "files", competition, "--csv"],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output
        lines = result.stdout.strip().split("\n")
        if len(lines) <= 1:
            return {"files": []}

        headers = lines[0].split(",")
        files = []

        for line in lines[1:]:
            values = line.split(",")
            if len(values) >= len(headers):
                file_info = dict(zip(headers, values))
                files.append({
                    "name": file_info.get("name", ""),
                    "size": file_info.get("size", "0"),
                    "description": file_info.get("description", "")
                })

        return {"files": files}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/competitions/download")
async def download_competition_data(request: CompetitionDownload):
    """Download competition data"""
    try:
        download_path = Path(request.path) if request.path else DATASETS_DIR / f"competition_{request.competition}"
        download_path.mkdir(parents=True, exist_ok=True)

        cmd = ["kaggle", "competitions", "download", "-c", request.competition, "-p", str(download_path)]
        if request.file:
            cmd.extend(["-f", request.file])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Unzip if needed
        zip_files = list(download_path.glob("*.zip"))
        for zip_file in zip_files:
            subprocess.run(["unzip", "-o", str(zip_file), "-d", str(download_path)], capture_output=True)

        files = list(download_path.glob("*"))

        return {
            "success": True,
            "path": str(download_path),
            "files": [f.name for f in files],
            "message": f"Competition data downloaded to {download_path}"
        }
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Download timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/competitions/{competition}/submit")
async def submit_to_competition(
    competition: str,
    message: str = Form(...),
    file: UploadFile = File(...)
):
    """Submit to a competition"""
    try:
        # Save uploaded file temporarily
        temp_path = Path("/tmp") / file.filename
        with open(temp_path, "wb") as f:
            content = await file.read()
            f.write(content)

        result = subprocess.run(
            ["kaggle", "competitions", "submit", "-c", competition, "-f", str(temp_path), "-m", message],
            capture_output=True,
            text=True,
            timeout=120
        )

        # Clean up
        temp_path.unlink(missing_ok=True)

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        return {
            "success": True,
            "message": "Submission uploaded successfully",
            "output": result.stdout
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/competitions/{competition}/submissions")
async def get_submissions(competition: str):
    """Get submission history for a competition"""
    try:
        result = subprocess.run(
            ["kaggle", "competitions", "submissions", "-c", competition, "--csv"],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output
        lines = result.stdout.strip().split("\n")
        if len(lines) <= 1:
            return {"submissions": []}

        headers = lines[0].split(",")
        submissions = []

        for line in lines[1:]:
            values = line.split(",")
            if len(values) >= len(headers):
                sub = dict(zip(headers, values))
                submissions.append({
                    "fileName": sub.get("fileName", ""),
                    "date": sub.get("date", ""),
                    "description": sub.get("description", ""),
                    "status": sub.get("status", ""),
                    "publicScore": sub.get("publicScore", ""),
                    "privateScore": sub.get("privateScore", "")
                })

        return {"submissions": submissions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# KERNELS / NOTEBOOKS
# ============================================================================

@router.get("/kernels/list")
async def list_kernels(page: int = 1, page_size: int = 20, sort_by: str = "hotness"):
    """List Kaggle kernels/notebooks"""
    try:
        result = subprocess.run(
            ["kaggle", "kernels", "list", "--csv", "-p", str(page), "--page-size", str(page_size), "--sort-by", sort_by],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output properly using csv module
        if not result.stdout.strip():
            return {"kernels": [], "total": 0}

        reader = csv.DictReader(io.StringIO(result.stdout))
        kernels = []

        for row in reader:
            kernels.append({
                "ref": row.get("ref", ""),
                "title": row.get("title", ""),
                "author": row.get("author", ""),
                "lastRunTime": row.get("lastRunTime", ""),
                "totalVotes": int(row.get("totalVotes", 0) or 0),
                "language": row.get("language", "")
            })

        return {"kernels": kernels, "total": len(kernels)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/kernels/search")
async def search_kernels(query: str, page: int = 1, page_size: int = 20):
    """Search Kaggle kernels"""
    try:
        result = subprocess.run(
            ["kaggle", "kernels", "list", "-s", query, "--csv", "-p", str(page), "--page-size", str(page_size)],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        # Parse CSV output
        lines = result.stdout.strip().split("\n")
        if len(lines) <= 1:
            return {"kernels": [], "total": 0}

        headers = lines[0].split(",")
        kernels = []

        for line in lines[1:]:
            values = line.split(",")
            if len(values) >= len(headers):
                kernel = dict(zip(headers, values))
                kernels.append({
                    "ref": kernel.get("ref", ""),
                    "title": kernel.get("title", ""),
                    "author": kernel.get("author", ""),
                    "lastRunTime": kernel.get("lastRunTime", ""),
                    "totalVotes": int(kernel.get("totalVotes", 0) or 0),
                    "language": kernel.get("language", "")
                })

        return {"kernels": kernels, "total": len(kernels)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/kernels/pull")
async def pull_kernel(request: KernelPull):
    """Download a Kaggle kernel/notebook"""
    try:
        download_path = Path(request.path) if request.path else Path.home() / "notebooks" / request.kernel_ref.replace("/", "_")
        download_path.mkdir(parents=True, exist_ok=True)

        result = subprocess.run(
            ["kaggle", "kernels", "pull", request.kernel_ref, "-p", str(download_path), "-m"],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        files = list(download_path.glob("*"))

        return {
            "success": True,
            "path": str(download_path),
            "files": [f.name for f in files],
            "message": f"Kernel downloaded to {download_path}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/kernels/{owner}/{kernel_name}/output")
async def get_kernel_output(owner: str, kernel_name: str):
    """Get output files from a kernel"""
    try:
        download_path = Path("/tmp") / f"{owner}_{kernel_name}_output"
        download_path.mkdir(parents=True, exist_ok=True)

        result = subprocess.run(
            ["kaggle", "kernels", "output", f"{owner}/{kernel_name}", "-p", str(download_path)],
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr)

        files = list(download_path.glob("*"))

        return {
            "success": True,
            "path": str(download_path),
            "files": [{"name": f.name, "size": f.stat().st_size} for f in files]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
