"""API module - FastAPI routers."""
from fastapi import APIRouter

from .notebooks import router as notebooks_router
from .kernels import router as kernels_router
from .execute import router as execute_router
from .files import router as files_router
from .gpu import router as gpu_router
from .ai import router as ai_router
from .settings import router as settings_router
from .kaggle_api import router as kaggle_router
from .automl import router as automl_router
from .datasets import router as datasets_router
from .cluster import router as cluster_router
from .packages import router as packages_router

# Versioned API router
api_v1_router = APIRouter(prefix="/api/v1")

api_v1_router.include_router(notebooks_router, prefix="/notebooks", tags=["notebooks"])
api_v1_router.include_router(kernels_router, prefix="/kernels", tags=["kernels"])
api_v1_router.include_router(execute_router, prefix="/execute", tags=["execute"])
api_v1_router.include_router(files_router, prefix="/files", tags=["files"])
api_v1_router.include_router(gpu_router, prefix="/gpu", tags=["gpu"])
api_v1_router.include_router(ai_router, prefix="/ai", tags=["ai"])
api_v1_router.include_router(settings_router, prefix="/settings", tags=["settings"])
api_v1_router.include_router(automl_router, prefix="/automl", tags=["automl"])
api_v1_router.include_router(datasets_router, prefix="/datasets", tags=["datasets"])
api_v1_router.include_router(cluster_router, prefix="/cluster", tags=["cluster"])

# Legacy API router (for backwards compatibility)
legacy_api_router = APIRouter(prefix="/api")

legacy_api_router.include_router(notebooks_router, prefix="/notebooks", tags=["notebooks"])
legacy_api_router.include_router(kernels_router, prefix="/kernels", tags=["kernels"])
legacy_api_router.include_router(execute_router, prefix="/execute", tags=["execute"])
legacy_api_router.include_router(files_router, prefix="/files", tags=["files"])
legacy_api_router.include_router(gpu_router, prefix="/gpu", tags=["gpu"])
legacy_api_router.include_router(ai_router, prefix="/ai", tags=["ai"])
legacy_api_router.include_router(settings_router, prefix="/settings", tags=["settings"])
legacy_api_router.include_router(kaggle_router, prefix="/kaggle", tags=["kaggle"])
legacy_api_router.include_router(automl_router, prefix="/automl", tags=["automl"])
legacy_api_router.include_router(datasets_router, prefix="/datasets", tags=["datasets"])
legacy_api_router.include_router(cluster_router, prefix="/cluster", tags=["cluster"])
legacy_api_router.include_router(packages_router, prefix="/packages", tags=["packages"])
