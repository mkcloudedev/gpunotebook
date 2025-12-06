"""
AutoML models and algorithm definitions.
"""
from enum import Enum
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from datetime import datetime


class TaskType(str, Enum):
    """ML task types."""
    CLASSIFICATION = "classification"
    REGRESSION = "regression"
    CLUSTERING = "clustering"
    DIMENSIONALITY_REDUCTION = "dimensionality_reduction"
    ANOMALY_DETECTION = "anomaly_detection"
    TIME_SERIES = "time_series"
    NLP = "nlp"
    COMPUTER_VISION = "computer_vision"
    RECOMMENDATION = "recommendation"
    REINFORCEMENT_LEARNING = "reinforcement_learning"


class AlgorithmCategory(str, Enum):
    """Algorithm categories."""
    LINEAR = "linear"
    TREE_BASED = "tree_based"
    ENSEMBLE = "ensemble"
    NEURAL_NETWORK = "neural_network"
    SVM = "svm"
    NEIGHBORS = "neighbors"
    CLUSTERING = "clustering"
    BAYESIAN = "bayesian"
    DIMENSIONALITY = "dimensionality"
    BOOSTING = "boosting"
    DEEP_LEARNING = "deep_learning"
    TRANSFORMER = "transformer"
    OTHER = "other"


class Algorithm(BaseModel):
    """ML Algorithm definition."""
    id: str
    name: str
    category: AlgorithmCategory
    task_types: List[TaskType]
    description: str
    hyperparameters: List[Dict[str, Any]]
    pros: List[str]
    cons: List[str]
    complexity: str  # O(n), O(n^2), etc.
    gpu_accelerated: bool = False
    library: str  # sklearn, pytorch, tensorflow, xgboost, etc.


# ============================================================================
# COMPLETE ALGORITHM CATALOG
# ============================================================================

ALGORITHMS: List[Algorithm] = [
    # =========================================================================
    # LINEAR MODELS
    # =========================================================================
    Algorithm(
        id="linear_regression",
        name="Linear Regression",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.REGRESSION],
        description="Simple linear model that fits a line to minimize squared errors",
        hyperparameters=[
            {"name": "fit_intercept", "type": "bool", "default": True},
            {"name": "normalize", "type": "bool", "default": False},
        ],
        pros=["Fast training", "Interpretable", "No hyperparameters"],
        cons=["Assumes linearity", "Sensitive to outliers"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="ridge_regression",
        name="Ridge Regression (L2)",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.REGRESSION],
        description="Linear regression with L2 regularization to prevent overfitting",
        hyperparameters=[
            {"name": "alpha", "type": "float", "default": 1.0, "range": [0.001, 100]},
        ],
        pros=["Handles multicollinearity", "Prevents overfitting"],
        cons=["All features retained", "Requires scaling"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="lasso_regression",
        name="Lasso Regression (L1)",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.REGRESSION],
        description="Linear regression with L1 regularization for feature selection",
        hyperparameters=[
            {"name": "alpha", "type": "float", "default": 1.0, "range": [0.001, 100]},
        ],
        pros=["Feature selection", "Sparse solutions"],
        cons=["Selects one from correlated features", "Less stable"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="elastic_net",
        name="Elastic Net",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.REGRESSION],
        description="Combines L1 and L2 regularization",
        hyperparameters=[
            {"name": "alpha", "type": "float", "default": 1.0, "range": [0.001, 100]},
            {"name": "l1_ratio", "type": "float", "default": 0.5, "range": [0, 1]},
        ],
        pros=["Best of L1 and L2", "Handles correlated features"],
        cons=["Two hyperparameters to tune"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="logistic_regression",
        name="Logistic Regression",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.CLASSIFICATION],
        description="Linear model for binary/multiclass classification using logistic function",
        hyperparameters=[
            {"name": "C", "type": "float", "default": 1.0, "range": [0.001, 100]},
            {"name": "penalty", "type": "choice", "default": "l2", "options": ["l1", "l2", "elasticnet", "none"]},
            {"name": "solver", "type": "choice", "default": "lbfgs", "options": ["lbfgs", "liblinear", "saga", "newton-cg"]},
        ],
        pros=["Fast", "Probabilistic output", "Interpretable"],
        cons=["Assumes linearity", "Limited complexity"],
        complexity="O(n*p)",
        library="sklearn"
    ),
    Algorithm(
        id="sgd_classifier",
        name="SGD Classifier",
        category=AlgorithmCategory.LINEAR,
        task_types=[TaskType.CLASSIFICATION],
        description="Linear classifier with stochastic gradient descent optimization",
        hyperparameters=[
            {"name": "loss", "type": "choice", "default": "hinge", "options": ["hinge", "log_loss", "modified_huber", "perceptron"]},
            {"name": "alpha", "type": "float", "default": 0.0001, "range": [0.00001, 0.1]},
            {"name": "learning_rate", "type": "choice", "default": "optimal", "options": ["constant", "optimal", "invscaling", "adaptive"]},
        ],
        pros=["Scales to large datasets", "Online learning"],
        cons=["Sensitive to scaling", "Many hyperparameters"],
        complexity="O(n*p)",
        library="sklearn"
    ),

    # =========================================================================
    # TREE-BASED MODELS
    # =========================================================================
    Algorithm(
        id="decision_tree",
        name="Decision Tree",
        category=AlgorithmCategory.TREE_BASED,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Tree-based model that splits data based on feature thresholds",
        hyperparameters=[
            {"name": "max_depth", "type": "int", "default": None, "range": [1, 50]},
            {"name": "min_samples_split", "type": "int", "default": 2, "range": [2, 20]},
            {"name": "min_samples_leaf", "type": "int", "default": 1, "range": [1, 20]},
            {"name": "criterion", "type": "choice", "default": "gini", "options": ["gini", "entropy", "log_loss"]},
        ],
        pros=["Interpretable", "Handles non-linear", "No scaling needed"],
        cons=["Overfits easily", "Unstable"],
        complexity="O(n*p*log(n))",
        library="sklearn"
    ),
    Algorithm(
        id="random_forest",
        name="Random Forest",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Ensemble of decision trees with bagging and feature randomization",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "max_depth", "type": "int", "default": None, "range": [1, 50]},
            {"name": "min_samples_split", "type": "int", "default": 2, "range": [2, 20]},
            {"name": "max_features", "type": "choice", "default": "sqrt", "options": ["sqrt", "log2", None]},
        ],
        pros=["Robust", "Handles high dimensions", "Feature importance"],
        cons=["Less interpretable", "Slow for large data"],
        complexity="O(n*p*log(n)*k)",
        library="sklearn"
    ),
    Algorithm(
        id="extra_trees",
        name="Extra Trees (Extremely Randomized Trees)",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="More randomized version of Random Forest with random splits",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "max_depth", "type": "int", "default": None, "range": [1, 50]},
            {"name": "min_samples_split", "type": "int", "default": 2, "range": [2, 20]},
        ],
        pros=["Faster than RF", "Less overfitting"],
        cons=["Higher variance", "Less interpretable"],
        complexity="O(n*p*log(n)*k)",
        library="sklearn"
    ),

    # =========================================================================
    # BOOSTING MODELS
    # =========================================================================
    Algorithm(
        id="gradient_boosting",
        name="Gradient Boosting",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Sequential ensemble that fits trees to residual errors",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "learning_rate", "type": "float", "default": 0.1, "range": [0.01, 1.0]},
            {"name": "max_depth", "type": "int", "default": 3, "range": [1, 10]},
            {"name": "subsample", "type": "float", "default": 1.0, "range": [0.5, 1.0]},
        ],
        pros=["High accuracy", "Handles mixed features"],
        cons=["Slow training", "Can overfit"],
        complexity="O(n*p*k*d)",
        library="sklearn"
    ),
    Algorithm(
        id="xgboost",
        name="XGBoost",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Optimized gradient boosting with regularization and parallel processing",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "learning_rate", "type": "float", "default": 0.3, "range": [0.01, 1.0]},
            {"name": "max_depth", "type": "int", "default": 6, "range": [1, 15]},
            {"name": "subsample", "type": "float", "default": 1.0, "range": [0.5, 1.0]},
            {"name": "colsample_bytree", "type": "float", "default": 1.0, "range": [0.5, 1.0]},
            {"name": "reg_alpha", "type": "float", "default": 0, "range": [0, 10]},
            {"name": "reg_lambda", "type": "float", "default": 1, "range": [0, 10]},
        ],
        pros=["State-of-art performance", "GPU support", "Handles missing values"],
        cons=["Many hyperparameters", "Can overfit"],
        complexity="O(n*p*k*d)",
        gpu_accelerated=True,
        library="xgboost"
    ),
    Algorithm(
        id="lightgbm",
        name="LightGBM",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Fast gradient boosting with histogram-based learning and leaf-wise growth",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "learning_rate", "type": "float", "default": 0.1, "range": [0.01, 1.0]},
            {"name": "max_depth", "type": "int", "default": -1, "range": [-1, 20]},
            {"name": "num_leaves", "type": "int", "default": 31, "range": [10, 200]},
            {"name": "subsample", "type": "float", "default": 1.0, "range": [0.5, 1.0]},
            {"name": "colsample_bytree", "type": "float", "default": 1.0, "range": [0.5, 1.0]},
        ],
        pros=["Very fast", "Low memory", "GPU support", "Handles large data"],
        cons=["Can overfit on small data", "Sensitive to parameters"],
        complexity="O(n*p*k)",
        gpu_accelerated=True,
        library="lightgbm"
    ),
    Algorithm(
        id="catboost",
        name="CatBoost",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Gradient boosting optimized for categorical features with ordered boosting",
        hyperparameters=[
            {"name": "iterations", "type": "int", "default": 1000, "range": [100, 5000]},
            {"name": "learning_rate", "type": "float", "default": 0.03, "range": [0.01, 0.3]},
            {"name": "depth", "type": "int", "default": 6, "range": [1, 16]},
            {"name": "l2_leaf_reg", "type": "float", "default": 3, "range": [1, 10]},
        ],
        pros=["Best for categorical data", "Less overfitting", "GPU support"],
        cons=["Slower than LightGBM", "Large model size"],
        complexity="O(n*p*k*d)",
        gpu_accelerated=True,
        library="catboost"
    ),
    Algorithm(
        id="adaboost",
        name="AdaBoost",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Adaptive boosting that focuses on misclassified samples",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 50, "range": [10, 500]},
            {"name": "learning_rate", "type": "float", "default": 1.0, "range": [0.01, 2.0]},
        ],
        pros=["Simple", "Less prone to overfitting", "Feature selection"],
        cons=["Sensitive to noise", "Slower than RF"],
        complexity="O(n*p*k)",
        library="sklearn"
    ),
    Algorithm(
        id="histgradient_boosting",
        name="Histogram Gradient Boosting",
        category=AlgorithmCategory.BOOSTING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Sklearn's fast histogram-based gradient boosting (inspired by LightGBM)",
        hyperparameters=[
            {"name": "max_iter", "type": "int", "default": 100, "range": [10, 1000]},
            {"name": "learning_rate", "type": "float", "default": 0.1, "range": [0.01, 1.0]},
            {"name": "max_depth", "type": "int", "default": None, "range": [1, 20]},
            {"name": "max_leaf_nodes", "type": "int", "default": 31, "range": [10, 200]},
        ],
        pros=["Fast", "Native missing value support", "Native categorical support"],
        cons=["Newer, less tested"],
        complexity="O(n*p*k)",
        library="sklearn"
    ),

    # =========================================================================
    # SUPPORT VECTOR MACHINES
    # =========================================================================
    Algorithm(
        id="svc",
        name="Support Vector Classifier (SVC)",
        category=AlgorithmCategory.SVM,
        task_types=[TaskType.CLASSIFICATION],
        description="Finds optimal hyperplane to separate classes with maximum margin",
        hyperparameters=[
            {"name": "C", "type": "float", "default": 1.0, "range": [0.001, 100]},
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["linear", "poly", "rbf", "sigmoid"]},
            {"name": "gamma", "type": "choice", "default": "scale", "options": ["scale", "auto"]},
            {"name": "degree", "type": "int", "default": 3, "range": [2, 5]},
        ],
        pros=["Effective in high dimensions", "Memory efficient", "Versatile kernels"],
        cons=["Slow for large datasets", "Sensitive to scaling"],
        complexity="O(n^2*p) to O(n^3*p)",
        library="sklearn"
    ),
    Algorithm(
        id="svr",
        name="Support Vector Regression (SVR)",
        category=AlgorithmCategory.SVM,
        task_types=[TaskType.REGRESSION],
        description="SVM for regression with epsilon-insensitive loss",
        hyperparameters=[
            {"name": "C", "type": "float", "default": 1.0, "range": [0.001, 100]},
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["linear", "poly", "rbf", "sigmoid"]},
            {"name": "epsilon", "type": "float", "default": 0.1, "range": [0.01, 1.0]},
        ],
        pros=["Handles non-linear", "Robust to outliers"],
        cons=["Slow", "Requires scaling"],
        complexity="O(n^2*p)",
        library="sklearn"
    ),
    Algorithm(
        id="linear_svc",
        name="Linear SVC",
        category=AlgorithmCategory.SVM,
        task_types=[TaskType.CLASSIFICATION],
        description="Linear SVM optimized for large datasets",
        hyperparameters=[
            {"name": "C", "type": "float", "default": 1.0, "range": [0.001, 100]},
            {"name": "loss", "type": "choice", "default": "squared_hinge", "options": ["hinge", "squared_hinge"]},
        ],
        pros=["Fast for large data", "Scales well"],
        cons=["Only linear boundaries"],
        complexity="O(n*p)",
        library="sklearn"
    ),
    Algorithm(
        id="nu_svc",
        name="Nu-SVC",
        category=AlgorithmCategory.SVM,
        task_types=[TaskType.CLASSIFICATION],
        description="SVC with nu parameter to control support vectors",
        hyperparameters=[
            {"name": "nu", "type": "float", "default": 0.5, "range": [0.01, 1.0]},
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["linear", "poly", "rbf", "sigmoid"]},
        ],
        pros=["Controls support vector fraction", "More intuitive than C"],
        cons=["Slower", "Complex to tune"],
        complexity="O(n^2*p)",
        library="sklearn"
    ),

    # =========================================================================
    # NEIGHBORS-BASED
    # =========================================================================
    Algorithm(
        id="knn_classifier",
        name="K-Nearest Neighbors Classifier",
        category=AlgorithmCategory.NEIGHBORS,
        task_types=[TaskType.CLASSIFICATION],
        description="Classifies based on majority vote of k nearest neighbors",
        hyperparameters=[
            {"name": "n_neighbors", "type": "int", "default": 5, "range": [1, 50]},
            {"name": "weights", "type": "choice", "default": "uniform", "options": ["uniform", "distance"]},
            {"name": "metric", "type": "choice", "default": "minkowski", "options": ["euclidean", "manhattan", "minkowski", "chebyshev"]},
            {"name": "p", "type": "int", "default": 2, "range": [1, 5]},
        ],
        pros=["Simple", "No training phase", "Naturally handles multi-class"],
        cons=["Slow prediction", "Memory intensive", "Sensitive to scaling"],
        complexity="O(n*p) per query",
        library="sklearn"
    ),
    Algorithm(
        id="knn_regressor",
        name="K-Nearest Neighbors Regressor",
        category=AlgorithmCategory.NEIGHBORS,
        task_types=[TaskType.REGRESSION],
        description="Predicts based on average of k nearest neighbors",
        hyperparameters=[
            {"name": "n_neighbors", "type": "int", "default": 5, "range": [1, 50]},
            {"name": "weights", "type": "choice", "default": "uniform", "options": ["uniform", "distance"]},
            {"name": "metric", "type": "choice", "default": "minkowski", "options": ["euclidean", "manhattan", "minkowski"]},
        ],
        pros=["Non-parametric", "Intuitive"],
        cons=["Slow for large data", "Curse of dimensionality"],
        complexity="O(n*p) per query",
        library="sklearn"
    ),
    Algorithm(
        id="radius_neighbors",
        name="Radius Neighbors Classifier",
        category=AlgorithmCategory.NEIGHBORS,
        task_types=[TaskType.CLASSIFICATION],
        description="Classifies based on neighbors within a fixed radius",
        hyperparameters=[
            {"name": "radius", "type": "float", "default": 1.0, "range": [0.1, 10.0]},
            {"name": "weights", "type": "choice", "default": "uniform", "options": ["uniform", "distance"]},
        ],
        pros=["Adapts to local density", "No fixed k"],
        cons=["Sensitive to radius", "May have no neighbors"],
        complexity="O(n*p) per query",
        library="sklearn"
    ),

    # =========================================================================
    # BAYESIAN MODELS
    # =========================================================================
    Algorithm(
        id="naive_bayes_gaussian",
        name="Gaussian Naive Bayes",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.CLASSIFICATION],
        description="Probabilistic classifier assuming Gaussian feature distributions",
        hyperparameters=[
            {"name": "var_smoothing", "type": "float", "default": 1e-9, "range": [1e-12, 1e-6]},
        ],
        pros=["Very fast", "Works with small data", "Probabilistic"],
        cons=["Assumes feature independence", "Continuous features only"],
        complexity="O(n*p)",
        library="sklearn"
    ),
    Algorithm(
        id="naive_bayes_multinomial",
        name="Multinomial Naive Bayes",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.CLASSIFICATION, TaskType.NLP],
        description="Naive Bayes for discrete features (text classification)",
        hyperparameters=[
            {"name": "alpha", "type": "float", "default": 1.0, "range": [0.001, 10]},
        ],
        pros=["Great for text", "Fast", "Handles sparse data"],
        cons=["Requires discrete features", "Independence assumption"],
        complexity="O(n*p)",
        library="sklearn"
    ),
    Algorithm(
        id="naive_bayes_bernoulli",
        name="Bernoulli Naive Bayes",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.CLASSIFICATION],
        description="Naive Bayes for binary features",
        hyperparameters=[
            {"name": "alpha", "type": "float", "default": 1.0, "range": [0.001, 10]},
            {"name": "binarize", "type": "float", "default": 0.0, "range": [0, 1]},
        ],
        pros=["Fast", "Good for binary features"],
        cons=["Limited to binary data"],
        complexity="O(n*p)",
        library="sklearn"
    ),
    Algorithm(
        id="bayesian_ridge",
        name="Bayesian Ridge Regression",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.REGRESSION],
        description="Bayesian linear regression with automatic relevance determination",
        hyperparameters=[
            {"name": "n_iter", "type": "int", "default": 300, "range": [100, 1000]},
            {"name": "alpha_1", "type": "float", "default": 1e-6, "range": [1e-9, 1e-3]},
            {"name": "alpha_2", "type": "float", "default": 1e-6, "range": [1e-9, 1e-3]},
        ],
        pros=["Uncertainty estimates", "Automatic regularization"],
        cons=["Slower than OLS", "Assumes normality"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="gaussian_process_classifier",
        name="Gaussian Process Classifier",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.CLASSIFICATION],
        description="Non-parametric Bayesian classifier with uncertainty estimates",
        hyperparameters=[
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["rbf", "matern", "rational_quadratic"]},
            {"name": "n_restarts_optimizer", "type": "int", "default": 0, "range": [0, 10]},
        ],
        pros=["Uncertainty quantification", "Flexible"],
        cons=["Very slow for large data", "O(n^3) complexity"],
        complexity="O(n^3)",
        library="sklearn"
    ),
    Algorithm(
        id="gaussian_process_regressor",
        name="Gaussian Process Regressor",
        category=AlgorithmCategory.BAYESIAN,
        task_types=[TaskType.REGRESSION],
        description="Non-parametric Bayesian regression with confidence intervals",
        hyperparameters=[
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["rbf", "matern", "rational_quadratic", "dot_product"]},
            {"name": "alpha", "type": "float", "default": 1e-10, "range": [1e-12, 1e-6]},
            {"name": "n_restarts_optimizer", "type": "int", "default": 0, "range": [0, 10]},
        ],
        pros=["Uncertainty estimates", "Great for small data", "Flexible"],
        cons=["O(n^3) complexity", "Not for large datasets"],
        complexity="O(n^3)",
        library="sklearn"
    ),

    # =========================================================================
    # CLUSTERING
    # =========================================================================
    Algorithm(
        id="kmeans",
        name="K-Means Clustering",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Partitions data into k clusters by minimizing within-cluster variance",
        hyperparameters=[
            {"name": "n_clusters", "type": "int", "default": 8, "range": [2, 100]},
            {"name": "init", "type": "choice", "default": "k-means++", "options": ["k-means++", "random"]},
            {"name": "n_init", "type": "int", "default": 10, "range": [1, 50]},
            {"name": "max_iter", "type": "int", "default": 300, "range": [100, 1000]},
        ],
        pros=["Fast", "Scales well", "Easy to interpret"],
        cons=["Requires k specification", "Assumes spherical clusters"],
        complexity="O(n*k*p*i)",
        library="sklearn"
    ),
    Algorithm(
        id="minibatch_kmeans",
        name="Mini-Batch K-Means",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Faster K-Means using random mini-batches",
        hyperparameters=[
            {"name": "n_clusters", "type": "int", "default": 8, "range": [2, 100]},
            {"name": "batch_size", "type": "int", "default": 1024, "range": [100, 10000]},
        ],
        pros=["Much faster than K-Means", "Scales to large data"],
        cons=["Slightly worse results", "Still requires k"],
        complexity="O(n*k*p)",
        library="sklearn"
    ),
    Algorithm(
        id="dbscan",
        name="DBSCAN",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING, TaskType.ANOMALY_DETECTION],
        description="Density-based clustering that finds arbitrary-shaped clusters",
        hyperparameters=[
            {"name": "eps", "type": "float", "default": 0.5, "range": [0.1, 10.0]},
            {"name": "min_samples", "type": "int", "default": 5, "range": [2, 50]},
        ],
        pros=["No k required", "Finds outliers", "Arbitrary shapes"],
        cons=["Sensitive to eps", "Struggles with varying density"],
        complexity="O(n*log(n)) with index",
        library="sklearn"
    ),
    Algorithm(
        id="hdbscan",
        name="HDBSCAN",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING, TaskType.ANOMALY_DETECTION],
        description="Hierarchical DBSCAN that adapts to varying densities",
        hyperparameters=[
            {"name": "min_cluster_size", "type": "int", "default": 5, "range": [2, 100]},
            {"name": "min_samples", "type": "int", "default": None, "range": [1, 50]},
            {"name": "cluster_selection_epsilon", "type": "float", "default": 0.0, "range": [0, 1]},
        ],
        pros=["No eps required", "Handles varying densities", "Robust"],
        cons=["Slower than DBSCAN", "Complex hierarchy"],
        complexity="O(n*log(n))",
        library="hdbscan"
    ),
    Algorithm(
        id="agglomerative",
        name="Agglomerative Clustering",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Hierarchical clustering that merges clusters bottom-up",
        hyperparameters=[
            {"name": "n_clusters", "type": "int", "default": 2, "range": [2, 100]},
            {"name": "linkage", "type": "choice", "default": "ward", "options": ["ward", "complete", "average", "single"]},
            {"name": "metric", "type": "choice", "default": "euclidean", "options": ["euclidean", "manhattan", "cosine"]},
        ],
        pros=["Hierarchical structure", "No k required initially", "Any shape"],
        cons=["O(n^3) memory", "Slow for large data"],
        complexity="O(n^2*log(n))",
        library="sklearn"
    ),
    Algorithm(
        id="spectral_clustering",
        name="Spectral Clustering",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Uses graph Laplacian eigenvectors for clustering",
        hyperparameters=[
            {"name": "n_clusters", "type": "int", "default": 8, "range": [2, 50]},
            {"name": "affinity", "type": "choice", "default": "rbf", "options": ["rbf", "nearest_neighbors", "precomputed"]},
            {"name": "n_neighbors", "type": "int", "default": 10, "range": [5, 50]},
        ],
        pros=["Finds complex shapes", "Based on graph theory"],
        cons=["Slow", "Requires k", "Memory intensive"],
        complexity="O(n^3)",
        library="sklearn"
    ),
    Algorithm(
        id="gaussian_mixture",
        name="Gaussian Mixture Model (GMM)",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Probabilistic clustering assuming Gaussian mixture distributions",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 1, "range": [1, 50]},
            {"name": "covariance_type", "type": "choice", "default": "full", "options": ["full", "tied", "diag", "spherical"]},
            {"name": "max_iter", "type": "int", "default": 100, "range": [50, 500]},
        ],
        pros=["Soft clustering", "Probabilistic", "Flexible shapes"],
        cons=["Requires n_components", "Can converge to local optima"],
        complexity="O(n*k*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="birch",
        name="BIRCH",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Balanced Iterative Reducing and Clustering using Hierarchies",
        hyperparameters=[
            {"name": "n_clusters", "type": "int", "default": 3, "range": [2, 50]},
            {"name": "threshold", "type": "float", "default": 0.5, "range": [0.1, 2.0]},
            {"name": "branching_factor", "type": "int", "default": 50, "range": [10, 200]},
        ],
        pros=["Scales to large data", "Single pass", "Memory efficient"],
        cons=["Only spherical clusters", "Sensitive to order"],
        complexity="O(n)",
        library="sklearn"
    ),
    Algorithm(
        id="optics",
        name="OPTICS",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Ordering Points To Identify Clustering Structure",
        hyperparameters=[
            {"name": "min_samples", "type": "int", "default": 5, "range": [2, 50]},
            {"name": "max_eps", "type": "float", "default": float('inf'), "range": [0.1, 100]},
            {"name": "xi", "type": "float", "default": 0.05, "range": [0.01, 0.5]},
        ],
        pros=["No epsilon needed", "Hierarchical", "Handles varying density"],
        cons=["Slower than DBSCAN", "Complex to interpret"],
        complexity="O(n^2)",
        library="sklearn"
    ),
    Algorithm(
        id="mean_shift",
        name="Mean Shift",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Finds clusters by shifting points toward density peaks",
        hyperparameters=[
            {"name": "bandwidth", "type": "float", "default": None, "range": [0.1, 10.0]},
            {"name": "bin_seeding", "type": "bool", "default": False},
        ],
        pros=["No k required", "Finds arbitrary shapes"],
        cons=["Slow", "Sensitive to bandwidth"],
        complexity="O(n^2*p)",
        library="sklearn"
    ),
    Algorithm(
        id="affinity_propagation",
        name="Affinity Propagation",
        category=AlgorithmCategory.CLUSTERING,
        task_types=[TaskType.CLUSTERING],
        description="Message-passing algorithm that identifies exemplars",
        hyperparameters=[
            {"name": "damping", "type": "float", "default": 0.5, "range": [0.5, 0.99]},
            {"name": "preference", "type": "float", "default": None, "range": [-100, 0]},
        ],
        pros=["No k required", "Finds exemplars"],
        cons=["Slow O(n^2)", "Memory intensive"],
        complexity="O(n^2*i)",
        library="sklearn"
    ),

    # =========================================================================
    # DIMENSIONALITY REDUCTION
    # =========================================================================
    Algorithm(
        id="pca",
        name="Principal Component Analysis (PCA)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Linear dimensionality reduction using SVD",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": None, "range": [1, 100]},
            {"name": "whiten", "type": "bool", "default": False},
        ],
        pros=["Fast", "Preserves variance", "Removes correlations"],
        cons=["Linear only", "Sensitive to scaling"],
        complexity="O(min(n*p^2, n^2*p))",
        library="sklearn"
    ),
    Algorithm(
        id="kernel_pca",
        name="Kernel PCA",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Non-linear PCA using kernel trick",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": None, "range": [1, 100]},
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["linear", "poly", "rbf", "sigmoid", "cosine"]},
            {"name": "gamma", "type": "float", "default": None, "range": [0.001, 10]},
        ],
        pros=["Non-linear reduction", "Flexible kernels"],
        cons=["Slow for large data", "Kernel selection"],
        complexity="O(n^3)",
        library="sklearn"
    ),
    Algorithm(
        id="tsne",
        name="t-SNE",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Non-linear reduction for visualization using probability distributions",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [2, 3]},
            {"name": "perplexity", "type": "float", "default": 30.0, "range": [5, 100]},
            {"name": "learning_rate", "type": "float", "default": 200.0, "range": [10, 1000]},
            {"name": "n_iter", "type": "int", "default": 1000, "range": [250, 5000]},
        ],
        pros=["Great for visualization", "Preserves local structure"],
        cons=["Slow", "Non-deterministic", "Only for visualization"],
        complexity="O(n^2)",
        library="sklearn"
    ),
    Algorithm(
        id="umap",
        name="UMAP",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Uniform Manifold Approximation and Projection",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [2, 100]},
            {"name": "n_neighbors", "type": "int", "default": 15, "range": [2, 200]},
            {"name": "min_dist", "type": "float", "default": 0.1, "range": [0.0, 1.0]},
            {"name": "metric", "type": "choice", "default": "euclidean", "options": ["euclidean", "manhattan", "cosine", "correlation"]},
        ],
        pros=["Faster than t-SNE", "Preserves global structure", "General purpose"],
        cons=["Hyperparameter sensitive", "Non-deterministic"],
        complexity="O(n^1.14)",
        gpu_accelerated=True,
        library="umap"
    ),
    Algorithm(
        id="lda",
        name="Linear Discriminant Analysis (LDA)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION, TaskType.CLASSIFICATION],
        description="Supervised dimensionality reduction maximizing class separability",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": None, "range": [1, 50]},
            {"name": "solver", "type": "choice", "default": "svd", "options": ["svd", "lsqr", "eigen"]},
        ],
        pros=["Supervised", "Also classifies", "Fast"],
        cons=["Linear only", "Limited to C-1 components"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="ica",
        name="Independent Component Analysis (ICA)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Finds statistically independent components (blind source separation)",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": None, "range": [1, 100]},
            {"name": "algorithm", "type": "choice", "default": "parallel", "options": ["parallel", "deflation"]},
            {"name": "max_iter", "type": "int", "default": 200, "range": [100, 1000]},
        ],
        pros=["Finds independent sources", "Non-Gaussian signals"],
        cons=["Order not determined", "Assumes independence"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),
    Algorithm(
        id="nmf",
        name="Non-negative Matrix Factorization (NMF)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Factorizes non-negative matrix into non-negative factors",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": None, "range": [1, 100]},
            {"name": "init", "type": "choice", "default": "nndsvda", "options": ["random", "nndsvd", "nndsvda", "nndsvdar"]},
            {"name": "max_iter", "type": "int", "default": 200, "range": [100, 1000]},
        ],
        pros=["Parts-based representation", "Interpretable", "Non-negative"],
        cons=["Non-negative data only", "Local optima"],
        complexity="O(n*p*k)",
        library="sklearn"
    ),
    Algorithm(
        id="truncated_svd",
        name="Truncated SVD (LSA)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION, TaskType.NLP],
        description="SVD for sparse matrices, used in Latent Semantic Analysis",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [1, 500]},
            {"name": "algorithm", "type": "choice", "default": "randomized", "options": ["arpack", "randomized"]},
        ],
        pros=["Works with sparse data", "Fast", "Great for text"],
        cons=["No mean centering", "Linear only"],
        complexity="O(n*p*k)",
        library="sklearn"
    ),
    Algorithm(
        id="isomap",
        name="Isomap",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Non-linear reduction using geodesic distances",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [1, 10]},
            {"name": "n_neighbors", "type": "int", "default": 5, "range": [2, 50]},
        ],
        pros=["Preserves geodesic distances", "Finds manifold"],
        cons=["Slow", "Sensitive to noise"],
        complexity="O(n^3)",
        library="sklearn"
    ),
    Algorithm(
        id="lle",
        name="Locally Linear Embedding (LLE)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Non-linear reduction preserving local neighborhood structure",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [1, 10]},
            {"name": "n_neighbors", "type": "int", "default": 5, "range": [2, 50]},
            {"name": "method", "type": "choice", "default": "standard", "options": ["standard", "hessian", "modified", "ltsa"]},
        ],
        pros=["Preserves local structure", "Non-linear"],
        cons=["Slow", "Sensitive to neighbors"],
        complexity="O(n^2)",
        library="sklearn"
    ),
    Algorithm(
        id="mds",
        name="Multidimensional Scaling (MDS)",
        category=AlgorithmCategory.DIMENSIONALITY,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Preserves pairwise distances in lower dimensions",
        hyperparameters=[
            {"name": "n_components", "type": "int", "default": 2, "range": [1, 10]},
            {"name": "metric", "type": "bool", "default": True},
            {"name": "n_init", "type": "int", "default": 4, "range": [1, 10]},
        ],
        pros=["Preserves distances", "Visualization"],
        cons=["Slow O(n^3)", "Memory intensive"],
        complexity="O(n^3)",
        library="sklearn"
    ),

    # =========================================================================
    # ANOMALY DETECTION
    # =========================================================================
    Algorithm(
        id="isolation_forest",
        name="Isolation Forest",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.ANOMALY_DETECTION],
        description="Detects anomalies using random forests that isolate observations",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 100, "range": [50, 500]},
            {"name": "contamination", "type": "float", "default": 0.1, "range": [0.01, 0.5]},
            {"name": "max_samples", "type": "float", "default": 1.0, "range": [0.1, 1.0]},
        ],
        pros=["Fast", "Scales well", "No distance computation"],
        cons=["Contamination parameter needed", "Less interpretable"],
        complexity="O(n*log(n)*k)",
        library="sklearn"
    ),
    Algorithm(
        id="one_class_svm",
        name="One-Class SVM",
        category=AlgorithmCategory.SVM,
        task_types=[TaskType.ANOMALY_DETECTION],
        description="SVM that learns a decision boundary around normal data",
        hyperparameters=[
            {"name": "kernel", "type": "choice", "default": "rbf", "options": ["linear", "poly", "rbf", "sigmoid"]},
            {"name": "nu", "type": "float", "default": 0.5, "range": [0.01, 0.99]},
            {"name": "gamma", "type": "choice", "default": "scale", "options": ["scale", "auto"]},
        ],
        pros=["Flexible kernels", "Well-established"],
        cons=["Slow for large data", "Sensitive to scaling"],
        complexity="O(n^2)",
        library="sklearn"
    ),
    Algorithm(
        id="local_outlier_factor",
        name="Local Outlier Factor (LOF)",
        category=AlgorithmCategory.NEIGHBORS,
        task_types=[TaskType.ANOMALY_DETECTION],
        description="Density-based outlier detection using local density deviation",
        hyperparameters=[
            {"name": "n_neighbors", "type": "int", "default": 20, "range": [5, 100]},
            {"name": "contamination", "type": "float", "default": 0.1, "range": [0.01, 0.5]},
            {"name": "metric", "type": "choice", "default": "minkowski", "options": ["euclidean", "manhattan", "minkowski"]},
        ],
        pros=["Local density aware", "No assumptions"],
        cons=["Slow for large data", "Memory intensive"],
        complexity="O(n^2)",
        library="sklearn"
    ),
    Algorithm(
        id="elliptic_envelope",
        name="Elliptic Envelope",
        category=AlgorithmCategory.OTHER,
        task_types=[TaskType.ANOMALY_DETECTION],
        description="Fits ellipse to data assuming Gaussian distribution",
        hyperparameters=[
            {"name": "contamination", "type": "float", "default": 0.1, "range": [0.01, 0.5]},
            {"name": "support_fraction", "type": "float", "default": None, "range": [0.1, 1.0]},
        ],
        pros=["Fast", "Parametric"],
        cons=["Assumes Gaussian", "Sensitive to outliers in fitting"],
        complexity="O(n*p^2)",
        library="sklearn"
    ),

    # =========================================================================
    # NEURAL NETWORKS (Classical)
    # =========================================================================
    Algorithm(
        id="mlp_classifier",
        name="Multi-Layer Perceptron Classifier",
        category=AlgorithmCategory.NEURAL_NETWORK,
        task_types=[TaskType.CLASSIFICATION],
        description="Feedforward neural network with backpropagation",
        hyperparameters=[
            {"name": "hidden_layer_sizes", "type": "tuple", "default": (100,), "range": [(50,), (100,), (100, 50), (200, 100)]},
            {"name": "activation", "type": "choice", "default": "relu", "options": ["relu", "tanh", "logistic"]},
            {"name": "solver", "type": "choice", "default": "adam", "options": ["adam", "sgd", "lbfgs"]},
            {"name": "learning_rate_init", "type": "float", "default": 0.001, "range": [0.0001, 0.1]},
            {"name": "alpha", "type": "float", "default": 0.0001, "range": [0.00001, 0.01]},
            {"name": "batch_size", "type": "int", "default": 200, "range": [32, 512]},
            {"name": "max_iter", "type": "int", "default": 200, "range": [100, 1000]},
        ],
        pros=["Learns non-linear patterns", "Flexible architecture"],
        cons=["Black box", "Requires tuning", "Sensitive to scaling"],
        complexity="O(n*p*h*o*i)",
        library="sklearn"
    ),
    Algorithm(
        id="mlp_regressor",
        name="Multi-Layer Perceptron Regressor",
        category=AlgorithmCategory.NEURAL_NETWORK,
        task_types=[TaskType.REGRESSION],
        description="Neural network for regression tasks",
        hyperparameters=[
            {"name": "hidden_layer_sizes", "type": "tuple", "default": (100,), "range": [(50,), (100,), (100, 50)]},
            {"name": "activation", "type": "choice", "default": "relu", "options": ["relu", "tanh", "logistic", "identity"]},
            {"name": "solver", "type": "choice", "default": "adam", "options": ["adam", "sgd", "lbfgs"]},
            {"name": "learning_rate_init", "type": "float", "default": 0.001, "range": [0.0001, 0.1]},
            {"name": "alpha", "type": "float", "default": 0.0001, "range": [0.00001, 0.01]},
        ],
        pros=["Non-linear regression", "Universal approximator"],
        cons=["Overfits easily", "Requires feature scaling"],
        complexity="O(n*p*h*o*i)",
        library="sklearn"
    ),

    # =========================================================================
    # DEEP LEARNING (PyTorch)
    # =========================================================================
    Algorithm(
        id="pytorch_mlp",
        name="PyTorch MLP",
        category=AlgorithmCategory.DEEP_LEARNING,
        task_types=[TaskType.CLASSIFICATION, TaskType.REGRESSION],
        description="Custom MLP with PyTorch for GPU acceleration",
        hyperparameters=[
            {"name": "hidden_sizes", "type": "list", "default": [256, 128, 64]},
            {"name": "dropout", "type": "float", "default": 0.2, "range": [0, 0.5]},
            {"name": "learning_rate", "type": "float", "default": 0.001, "range": [0.00001, 0.1]},
            {"name": "batch_size", "type": "int", "default": 64, "range": [16, 512]},
            {"name": "epochs", "type": "int", "default": 100, "range": [10, 500]},
            {"name": "optimizer", "type": "choice", "default": "adam", "options": ["adam", "sgd", "adamw", "rmsprop"]},
            {"name": "activation", "type": "choice", "default": "relu", "options": ["relu", "gelu", "silu", "tanh"]},
        ],
        pros=["GPU acceleration", "Flexible", "Modern optimizers"],
        cons=["Requires more code", "Hyperparameter tuning"],
        complexity="O(n*h*e)",
        gpu_accelerated=True,
        library="pytorch"
    ),
    Algorithm(
        id="pytorch_cnn",
        name="PyTorch CNN",
        category=AlgorithmCategory.DEEP_LEARNING,
        task_types=[TaskType.CLASSIFICATION, TaskType.COMPUTER_VISION],
        description="Convolutional Neural Network for image classification",
        hyperparameters=[
            {"name": "conv_channels", "type": "list", "default": [32, 64, 128]},
            {"name": "kernel_size", "type": "int", "default": 3, "range": [3, 7]},
            {"name": "dropout", "type": "float", "default": 0.25, "range": [0, 0.5]},
            {"name": "learning_rate", "type": "float", "default": 0.001, "range": [0.00001, 0.01]},
            {"name": "batch_size", "type": "int", "default": 32, "range": [8, 128]},
            {"name": "epochs", "type": "int", "default": 50, "range": [10, 200]},
        ],
        pros=["State-of-art for images", "Transfer learning", "GPU optimized"],
        cons=["Requires lots of data", "Computational intensive"],
        complexity="O(n*c*k^2*h*w)",
        gpu_accelerated=True,
        library="pytorch"
    ),
    Algorithm(
        id="pytorch_rnn",
        name="PyTorch RNN/LSTM",
        category=AlgorithmCategory.DEEP_LEARNING,
        task_types=[TaskType.TIME_SERIES, TaskType.NLP],
        description="Recurrent Neural Network for sequential data",
        hyperparameters=[
            {"name": "hidden_size", "type": "int", "default": 128, "range": [32, 512]},
            {"name": "num_layers", "type": "int", "default": 2, "range": [1, 6]},
            {"name": "cell_type", "type": "choice", "default": "lstm", "options": ["rnn", "lstm", "gru"]},
            {"name": "bidirectional", "type": "bool", "default": False},
            {"name": "dropout", "type": "float", "default": 0.2, "range": [0, 0.5]},
            {"name": "learning_rate", "type": "float", "default": 0.001, "range": [0.0001, 0.01]},
        ],
        pros=["Handles sequences", "Memory of past", "Variable length input"],
        cons=["Vanishing gradients", "Sequential computation"],
        complexity="O(n*t*h^2)",
        gpu_accelerated=True,
        library="pytorch"
    ),
    Algorithm(
        id="pytorch_transformer",
        name="PyTorch Transformer",
        category=AlgorithmCategory.TRANSFORMER,
        task_types=[TaskType.NLP, TaskType.TIME_SERIES, TaskType.CLASSIFICATION],
        description="Transformer architecture with self-attention",
        hyperparameters=[
            {"name": "d_model", "type": "int", "default": 512, "range": [64, 1024]},
            {"name": "nhead", "type": "int", "default": 8, "range": [2, 16]},
            {"name": "num_layers", "type": "int", "default": 6, "range": [2, 12]},
            {"name": "dim_feedforward", "type": "int", "default": 2048, "range": [256, 4096]},
            {"name": "dropout", "type": "float", "default": 0.1, "range": [0, 0.3]},
            {"name": "learning_rate", "type": "float", "default": 0.0001, "range": [0.00001, 0.001]},
        ],
        pros=["Parallel processing", "Long-range dependencies", "State-of-art NLP"],
        cons=["Quadratic attention complexity", "Needs lots of data"],
        complexity="O(n^2*d)",
        gpu_accelerated=True,
        library="pytorch"
    ),
    Algorithm(
        id="pytorch_autoencoder",
        name="PyTorch Autoencoder",
        category=AlgorithmCategory.DEEP_LEARNING,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION, TaskType.ANOMALY_DETECTION],
        description="Neural network that learns compressed representations",
        hyperparameters=[
            {"name": "encoder_sizes", "type": "list", "default": [256, 128, 64]},
            {"name": "latent_dim", "type": "int", "default": 32, "range": [2, 128]},
            {"name": "learning_rate", "type": "float", "default": 0.001, "range": [0.0001, 0.01]},
            {"name": "epochs", "type": "int", "default": 100, "range": [10, 500]},
        ],
        pros=["Non-linear reduction", "Anomaly detection", "Feature learning"],
        cons=["Complex to train", "Reconstruction loss choice"],
        complexity="O(n*h*e)",
        gpu_accelerated=True,
        library="pytorch"
    ),
    Algorithm(
        id="pytorch_vae",
        name="PyTorch VAE",
        category=AlgorithmCategory.DEEP_LEARNING,
        task_types=[TaskType.DIMENSIONALITY_REDUCTION],
        description="Variational Autoencoder for generative modeling",
        hyperparameters=[
            {"name": "encoder_sizes", "type": "list", "default": [256, 128]},
            {"name": "latent_dim", "type": "int", "default": 20, "range": [2, 100]},
            {"name": "beta", "type": "float", "default": 1.0, "range": [0.1, 10]},
            {"name": "learning_rate", "type": "float", "default": 0.001, "range": [0.0001, 0.01]},
        ],
        pros=["Generative", "Continuous latent space", "Uncertainty"],
        cons=["Blurry reconstructions", "KL divergence balancing"],
        complexity="O(n*h*e)",
        gpu_accelerated=True,
        library="pytorch"
    ),

    # =========================================================================
    # TIME SERIES
    # =========================================================================
    Algorithm(
        id="arima",
        name="ARIMA",
        category=AlgorithmCategory.OTHER,
        task_types=[TaskType.TIME_SERIES],
        description="AutoRegressive Integrated Moving Average for time series",
        hyperparameters=[
            {"name": "p", "type": "int", "default": 1, "range": [0, 10]},
            {"name": "d", "type": "int", "default": 1, "range": [0, 2]},
            {"name": "q", "type": "int", "default": 1, "range": [0, 10]},
        ],
        pros=["Well-established", "Interpretable", "Works for stationary data"],
        cons=["Assumes linearity", "Manual parameter selection"],
        complexity="O(n*p)",
        library="statsmodels"
    ),
    Algorithm(
        id="sarima",
        name="SARIMA",
        category=AlgorithmCategory.OTHER,
        task_types=[TaskType.TIME_SERIES],
        description="Seasonal ARIMA for time series with seasonality",
        hyperparameters=[
            {"name": "p", "type": "int", "default": 1, "range": [0, 5]},
            {"name": "d", "type": "int", "default": 1, "range": [0, 2]},
            {"name": "q", "type": "int", "default": 1, "range": [0, 5]},
            {"name": "P", "type": "int", "default": 1, "range": [0, 3]},
            {"name": "D", "type": "int", "default": 1, "range": [0, 2]},
            {"name": "Q", "type": "int", "default": 1, "range": [0, 3]},
            {"name": "m", "type": "int", "default": 12, "range": [4, 52]},
        ],
        pros=["Handles seasonality", "Interpretable"],
        cons=["Many parameters", "Complex to tune"],
        complexity="O(n*p*s)",
        library="statsmodels"
    ),
    Algorithm(
        id="prophet",
        name="Prophet",
        category=AlgorithmCategory.OTHER,
        task_types=[TaskType.TIME_SERIES],
        description="Facebook's time series forecasting with seasonality and holidays",
        hyperparameters=[
            {"name": "seasonality_mode", "type": "choice", "default": "additive", "options": ["additive", "multiplicative"]},
            {"name": "changepoint_prior_scale", "type": "float", "default": 0.05, "range": [0.001, 0.5]},
            {"name": "seasonality_prior_scale", "type": "float", "default": 10, "range": [0.01, 50]},
        ],
        pros=["Handles holidays", "Automatic seasonality", "Robust to missing data"],
        cons=["Less flexible than ARIMA", "Slower"],
        complexity="O(n)",
        library="prophet"
    ),

    # =========================================================================
    # OTHER SPECIALIZED
    # =========================================================================
    Algorithm(
        id="voting_classifier",
        name="Voting Classifier",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.CLASSIFICATION],
        description="Ensemble that combines multiple classifiers by voting",
        hyperparameters=[
            {"name": "voting", "type": "choice", "default": "hard", "options": ["hard", "soft"]},
        ],
        pros=["Combines models", "Reduces variance"],
        cons=["All models must be trained", "Complex tuning"],
        complexity="O(sum of base models)",
        library="sklearn"
    ),
    Algorithm(
        id="stacking_classifier",
        name="Stacking Classifier",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.CLASSIFICATION],
        description="Meta-learner that combines base model predictions",
        hyperparameters=[
            {"name": "cv", "type": "int", "default": 5, "range": [3, 10]},
            {"name": "passthrough", "type": "bool", "default": False},
        ],
        pros=["Often best performance", "Flexible"],
        cons=["Slow training", "Risk of overfitting"],
        complexity="O(n*k*base_models)",
        library="sklearn"
    ),
    Algorithm(
        id="bagging_classifier",
        name="Bagging Classifier",
        category=AlgorithmCategory.ENSEMBLE,
        task_types=[TaskType.CLASSIFICATION],
        description="Bootstrap aggregating for any base classifier",
        hyperparameters=[
            {"name": "n_estimators", "type": "int", "default": 10, "range": [5, 100]},
            {"name": "max_samples", "type": "float", "default": 1.0, "range": [0.1, 1.0]},
            {"name": "max_features", "type": "float", "default": 1.0, "range": [0.1, 1.0]},
        ],
        pros=["Reduces variance", "Parallelizable"],
        cons=["Increased complexity", "Slower inference"],
        complexity="O(n*k*base_model)",
        library="sklearn"
    ),
    Algorithm(
        id="calibrated_classifier",
        name="Calibrated Classifier",
        category=AlgorithmCategory.OTHER,
        task_types=[TaskType.CLASSIFICATION],
        description="Probability calibration using Platt scaling or isotonic regression",
        hyperparameters=[
            {"name": "method", "type": "choice", "default": "sigmoid", "options": ["sigmoid", "isotonic"]},
            {"name": "cv", "type": "int", "default": 5, "range": [3, 10]},
        ],
        pros=["Better probability estimates", "Works with any classifier"],
        cons=["Requires more data", "Extra training"],
        complexity="O(base_model + n)",
        library="sklearn"
    ),
]


# ============================================================================
# AUTOML MODELS
# ============================================================================

class DatasetInfo(BaseModel):
    """Information about the dataset."""
    name: str
    n_samples: int
    n_features: int
    n_classes: Optional[int] = None
    target_column: str
    feature_columns: List[str]
    task_type: TaskType
    has_missing: bool = False
    has_categorical: bool = False


class ModelScore(BaseModel):
    """Model evaluation scores."""
    accuracy: Optional[float] = None
    precision: Optional[float] = None
    recall: Optional[float] = None
    f1: Optional[float] = None
    roc_auc: Optional[float] = None
    mse: Optional[float] = None
    rmse: Optional[float] = None
    mae: Optional[float] = None
    r2: Optional[float] = None
    silhouette: Optional[float] = None
    calinski_harabasz: Optional[float] = None
    davies_bouldin: Optional[float] = None


class TrainedModel(BaseModel):
    """A trained model with its configuration and scores."""
    id: str
    algorithm_id: str
    algorithm_name: str
    hyperparameters: Dict[str, Any]
    scores: ModelScore
    training_time: float
    created_at: datetime = datetime.now()
    recommendations: List[str] = []


class AutoMLExperiment(BaseModel):
    """An AutoML experiment."""
    id: str
    name: str
    dataset_info: DatasetInfo
    task_type: TaskType
    algorithms_to_try: List[str]
    optimization_metric: str
    cv_folds: int = 5
    max_time_minutes: Optional[int] = None
    status: str = "pending"  # pending, running, completed, failed
    models: List[TrainedModel] = []
    best_model_id: Optional[str] = None
    created_at: datetime = datetime.now()
    completed_at: Optional[datetime] = None


class AutoMLRequest(BaseModel):
    """Request to start AutoML experiment."""
    name: str
    dataset_path: str
    target_column: str
    task_type: TaskType
    algorithms: Optional[List[str]] = None  # None = all applicable
    optimization_metric: Optional[str] = None  # auto-select based on task
    cv_folds: int = 5
    max_time_minutes: Optional[int] = 60
    test_size: float = 0.2


def get_algorithms_for_task(task_type: TaskType) -> List[Algorithm]:
    """Get algorithms applicable to a task type."""
    return [algo for algo in ALGORITHMS if task_type in algo.task_types]


def get_algorithm_by_id(algorithm_id: str) -> Optional[Algorithm]:
    """Get algorithm by ID."""
    for algo in ALGORITHMS:
        if algo.id == algorithm_id:
            return algo
    return None
