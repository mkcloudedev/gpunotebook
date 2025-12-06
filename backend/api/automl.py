"""
AutoML API endpoints.
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel

from models.automl import (
    Algorithm,
    ALGORITHMS,
    TaskType,
    AlgorithmCategory,
    AutoMLRequest,
    AutoMLExperiment,
    TrainedModel,
    get_algorithms_for_task,
    get_algorithm_by_id,
)
from services.automl_service import automl_service


router = APIRouter()


# ============================================================================
# ALGORITHM ENDPOINTS
# ============================================================================

@router.get("/algorithms", response_model=List[Algorithm])
async def list_algorithms(
    task_type: Optional[TaskType] = None,
    category: Optional[AlgorithmCategory] = None,
    gpu_only: bool = False,
):
    """List all available algorithms with optional filtering."""
    algorithms = ALGORITHMS

    if task_type:
        algorithms = [a for a in algorithms if task_type in a.task_types]

    if category:
        algorithms = [a for a in algorithms if a.category == category]

    if gpu_only:
        algorithms = [a for a in algorithms if a.gpu_accelerated]

    return algorithms


@router.get("/algorithms/{algorithm_id}", response_model=Algorithm)
async def get_algorithm(algorithm_id: str):
    """Get algorithm by ID."""
    algo = get_algorithm_by_id(algorithm_id)
    if not algo:
        raise HTTPException(status_code=404, detail="Algorithm not found")
    return algo


@router.get("/algorithms/task/{task_type}", response_model=List[Algorithm])
async def get_algorithms_by_task(task_type: TaskType):
    """Get all algorithms for a specific task type."""
    return get_algorithms_for_task(task_type)


@router.get("/categories")
async def list_categories():
    """List all algorithm categories with counts."""
    categories = {}
    for algo in ALGORITHMS:
        cat = algo.category.value
        if cat not in categories:
            categories[cat] = {"name": cat, "count": 0, "algorithms": []}
        categories[cat]["count"] += 1
        categories[cat]["algorithms"].append(algo.id)
    return list(categories.values())


@router.get("/task-types")
async def list_task_types():
    """List all task types with algorithm counts."""
    task_types = {}
    for task in TaskType:
        algos = get_algorithms_for_task(task)
        task_types[task.value] = {
            "name": task.value,
            "count": len(algos),
            "algorithms": [a.id for a in algos]
        }
    return task_types


# ============================================================================
# EXPERIMENT ENDPOINTS
# ============================================================================

@router.post("/experiments", response_model=AutoMLExperiment)
async def create_experiment(
    request: AutoMLRequest,
    background_tasks: BackgroundTasks
):
    """Create and start a new AutoML experiment."""
    experiment = await automl_service.create_experiment(request)

    # Run training in background
    background_tasks.add_task(automl_service.run_experiment, experiment.id)

    return experiment


@router.get("/experiments", response_model=List[AutoMLExperiment])
async def list_experiments():
    """List all experiments."""
    return await automl_service.list_experiments()


@router.get("/experiments/{experiment_id}", response_model=AutoMLExperiment)
async def get_experiment(experiment_id: str):
    """Get experiment by ID."""
    experiment = await automl_service.get_experiment(experiment_id)
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")
    return experiment


@router.delete("/experiments/{experiment_id}")
async def delete_experiment(experiment_id: str):
    """Delete an experiment."""
    success = await automl_service.delete_experiment(experiment_id)
    if not success:
        raise HTTPException(status_code=404, detail="Experiment not found")
    return {"status": "deleted"}


@router.post("/experiments/{experiment_id}/stop")
async def stop_experiment(experiment_id: str):
    """Stop a running experiment."""
    success = await automl_service.stop_experiment(experiment_id)
    if not success:
        raise HTTPException(status_code=404, detail="Experiment not found or not running")
    return {"status": "stopped"}


@router.get("/experiments/{experiment_id}/models", response_model=List[TrainedModel])
async def get_experiment_models(experiment_id: str):
    """Get all trained models for an experiment."""
    experiment = await automl_service.get_experiment(experiment_id)
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")
    return experiment.models


@router.get("/experiments/{experiment_id}/best-model")
async def get_best_model(experiment_id: str):
    """Get the best model for an experiment."""
    experiment = await automl_service.get_experiment(experiment_id)
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")

    if not experiment.best_model_id:
        raise HTTPException(status_code=404, detail="No best model found yet")

    best_model = next(
        (m for m in experiment.models if m.id == experiment.best_model_id),
        None
    )
    if not best_model:
        raise HTTPException(status_code=404, detail="Best model not found")

    return best_model


# ============================================================================
# RECOMMENDATIONS
# ============================================================================

class RecommendationRequest(BaseModel):
    """Request for algorithm recommendations."""
    task_type: TaskType
    n_samples: int
    n_features: int
    has_categorical: bool = False
    has_missing: bool = False
    need_interpretability: bool = False
    need_speed: bool = False
    has_gpu: bool = False


@router.post("/recommend")
async def recommend_algorithms(request: RecommendationRequest):
    """Get algorithm recommendations based on data characteristics."""
    recommendations = []

    # Get applicable algorithms
    applicable = get_algorithms_for_task(request.task_type)

    for algo in applicable:
        score = 100
        reasons = []

        # Large dataset considerations
        if request.n_samples > 100000:
            if algo.complexity in ["O(n^2)", "O(n^3)", "O(n^2*p)", "O(n^3*p)"]:
                score -= 40
                reasons.append("May be slow for large datasets")
            if algo.id in ["lightgbm", "xgboost", "histgradient_boosting", "minibatch_kmeans"]:
                score += 20
                reasons.append("Efficient for large datasets")

        # Small dataset considerations
        if request.n_samples < 1000:
            if algo.category == AlgorithmCategory.DEEP_LEARNING:
                score -= 30
                reasons.append("May need more data for deep learning")
            if algo.id in ["gaussian_process_regressor", "gaussian_process_classifier"]:
                score += 20
                reasons.append("Great for small datasets")

        # High dimensionality
        if request.n_features > 100:
            if algo.id in ["random_forest", "xgboost", "lightgbm"]:
                score += 15
                reasons.append("Handles high dimensions well")

        # Categorical features
        if request.has_categorical:
            if algo.id == "catboost":
                score += 30
                reasons.append("Best for categorical features")
            if algo.id in ["lightgbm", "xgboost", "histgradient_boosting"]:
                score += 15
                reasons.append("Handles categorical features")

        # Missing values
        if request.has_missing:
            if algo.id in ["xgboost", "lightgbm", "catboost", "histgradient_boosting"]:
                score += 20
                reasons.append("Handles missing values natively")

        # Interpretability
        if request.need_interpretability:
            if algo.id in ["logistic_regression", "decision_tree", "linear_regression"]:
                score += 25
                reasons.append("Highly interpretable")
            if algo.category == AlgorithmCategory.DEEP_LEARNING:
                score -= 20
                reasons.append("Black box model")

        # Speed requirement
        if request.need_speed:
            if algo.id in ["lightgbm", "histgradient_boosting", "linear_regression", "logistic_regression"]:
                score += 20
                reasons.append("Fast training")

        # GPU
        if request.has_gpu and algo.gpu_accelerated:
            score += 25
            reasons.append("GPU accelerated")

        recommendations.append({
            "algorithm": algo,
            "score": min(100, max(0, score)),
            "reasons": reasons if reasons else ["General purpose algorithm"]
        })

    # Sort by score
    recommendations.sort(key=lambda x: x["score"], reverse=True)

    return {"recommendations": recommendations[:10]}


# ============================================================================
# QUICK TRAIN
# ============================================================================

class QuickTrainRequest(BaseModel):
    """Request for quick single model training."""
    algorithm_id: str
    dataset_path: str
    target_column: str
    hyperparameters: Optional[dict] = None
    test_size: float = 0.2


@router.post("/quick-train")
async def quick_train(
    request: QuickTrainRequest,
    background_tasks: BackgroundTasks
):
    """Quick train a single model."""
    algo = get_algorithm_by_id(request.algorithm_id)
    if not algo:
        raise HTTPException(status_code=404, detail="Algorithm not found")

    result = await automl_service.quick_train(
        algorithm_id=request.algorithm_id,
        dataset_path=request.dataset_path,
        target_column=request.target_column,
        hyperparameters=request.hyperparameters,
        test_size=request.test_size
    )

    return result
