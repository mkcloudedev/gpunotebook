"""
AutoML service for training and managing experiments.
"""
import os
import uuid
import time
from datetime import datetime
from typing import Optional, List, Dict, Any
from sqlalchemy import select, delete as sql_delete
from sqlalchemy.orm import selectinload

from models.automl import (
    AutoMLExperiment,
    AutoMLRequest,
    TrainedModel,
    ModelScore,
    DatasetInfo,
    TaskType,
    get_algorithms_for_task,
    get_algorithm_by_id,
)
from models.db_models import AutoMLExperimentDB, TrainedModelDB
from core.config import settings
from core.database import async_session


class AutoMLService:
    """Service for managing AutoML experiments."""

    def __init__(self):
        self._running_experiments: Dict[str, bool] = {}

    def _db_to_experiment(self, db_exp: AutoMLExperimentDB) -> AutoMLExperiment:
        """Convert database model to Pydantic model."""
        models = []
        for db_model in db_exp.models:
            models.append(TrainedModel(
                id=db_model.id,
                algorithm_id=db_model.algorithm_id,
                algorithm_name=db_model.algorithm_name,
                hyperparameters=db_model.hyperparameters or {},
                scores=ModelScore(**db_model.scores) if db_model.scores else ModelScore(),
                training_time=db_model.training_time or 0,
                recommendations=db_model.recommendations or []
            ))

        return AutoMLExperiment(
            id=db_exp.id,
            name=db_exp.name,
            dataset_info=DatasetInfo(**db_exp.dataset_info) if db_exp.dataset_info else None,
            task_type=TaskType(db_exp.task_type),
            algorithms_to_try=db_exp.algorithms_to_try or [],
            optimization_metric=db_exp.optimization_metric,
            cv_folds=db_exp.cv_folds,
            max_time_minutes=db_exp.max_time_minutes,
            status=db_exp.status,
            models=models,
            best_model_id=db_exp.best_model_id,
            created_at=db_exp.created_at,
            completed_at=db_exp.completed_at
        )

    async def create_experiment(self, request: AutoMLRequest) -> AutoMLExperiment:
        """Create a new AutoML experiment."""
        experiment_id = str(uuid.uuid4())

        # Analyze dataset to get info
        dataset_info = await self._analyze_dataset(
            request.dataset_path,
            request.target_column,
            request.task_type
        )

        # Determine algorithms to use
        if request.algorithms:
            algorithms_to_try = request.algorithms
        else:
            applicable = get_algorithms_for_task(request.task_type)
            algorithms_to_try = [a.id for a in applicable[:15]]

        # Determine optimization metric
        if request.optimization_metric:
            opt_metric = request.optimization_metric
        else:
            opt_metric = self._get_default_metric(request.task_type)

        experiment = AutoMLExperiment(
            id=experiment_id,
            name=request.name,
            dataset_info=dataset_info,
            task_type=request.task_type,
            algorithms_to_try=algorithms_to_try,
            optimization_metric=opt_metric,
            cv_folds=request.cv_folds,
            max_time_minutes=request.max_time_minutes,
            status="pending",
            models=[],
            created_at=datetime.now()
        )

        await self._save_experiment(experiment)
        return experiment

    async def _analyze_dataset(
        self,
        dataset_path: str,
        target_column: str,
        task_type: TaskType
    ) -> DatasetInfo:
        """Analyze dataset and return info."""
        try:
            import pandas as pd

            if dataset_path.endswith('.csv'):
                df = pd.read_csv(dataset_path)
            elif dataset_path.endswith('.parquet'):
                df = pd.read_parquet(dataset_path)
            else:
                df = pd.read_csv(dataset_path)

            feature_columns = [c for c in df.columns if c != target_column]

            # Determine number of classes for classification
            n_classes = None
            if task_type == TaskType.CLASSIFICATION:
                n_classes = df[target_column].nunique()

            # Check for categorical and missing values
            has_categorical = any(df[col].dtype == 'object' for col in feature_columns)
            has_missing = df.isnull().any().any()

            return DatasetInfo(
                name=os.path.basename(dataset_path),
                n_samples=len(df),
                n_features=len(feature_columns),
                n_classes=n_classes,
                target_column=target_column,
                feature_columns=feature_columns,
                task_type=task_type,
                has_missing=has_missing,
                has_categorical=has_categorical
            )
        except Exception as e:
            return DatasetInfo(
                name=os.path.basename(dataset_path),
                n_samples=0,
                n_features=0,
                target_column=target_column,
                feature_columns=[],
                task_type=task_type
            )

    def _get_default_metric(self, task_type: TaskType) -> str:
        """Get default optimization metric for task type."""
        metrics = {
            TaskType.CLASSIFICATION: "f1",
            TaskType.REGRESSION: "r2",
            TaskType.CLUSTERING: "silhouette",
            TaskType.ANOMALY_DETECTION: "f1",
            TaskType.DIMENSIONALITY_REDUCTION: "explained_variance",
            TaskType.TIME_SERIES: "rmse",
        }
        return metrics.get(task_type, "accuracy")

    async def run_experiment(self, experiment_id: str):
        """Run an AutoML experiment."""
        experiment = await self.get_experiment(experiment_id)
        if not experiment:
            return

        self._running_experiments[experiment_id] = True
        experiment.status = "running"
        await self._save_experiment(experiment)

        start_time = time.time()
        max_time = (experiment.max_time_minutes or 60) * 60

        try:
            for algorithm_id in experiment.algorithms_to_try:
                if not self._running_experiments.get(experiment_id, False):
                    break

                if time.time() - start_time > max_time:
                    break

                try:
                    model = await self._train_model(
                        experiment,
                        algorithm_id
                    )
                    experiment.models.append(model)
                    await self._save_experiment(experiment)
                except Exception as e:
                    print(f"Error training {algorithm_id}: {e}")
                    continue

            # Find best model
            if experiment.models:
                experiment.best_model_id = self._find_best_model(
                    experiment.models,
                    experiment.optimization_metric
                )

            experiment.status = "completed"
            experiment.completed_at = datetime.now()

        except Exception as e:
            experiment.status = "failed"
            print(f"Experiment failed: {e}")

        finally:
            self._running_experiments.pop(experiment_id, None)
            await self._save_experiment(experiment)

    async def _train_model(
        self,
        experiment: AutoMLExperiment,
        algorithm_id: str
    ) -> TrainedModel:
        """Train a single model."""
        import pandas as pd
        from sklearn.model_selection import cross_val_score, train_test_split
        import numpy as np

        algo = get_algorithm_by_id(algorithm_id)
        if not algo:
            raise ValueError(f"Algorithm {algorithm_id} not found")

        # Load data
        dataset_path = os.path.join(settings.UPLOAD_DIR, experiment.dataset_info.name)
        if not os.path.exists(dataset_path):
            dataset_path = experiment.dataset_info.name

        if dataset_path.endswith('.csv'):
            df = pd.read_csv(dataset_path)
        else:
            df = pd.read_csv(dataset_path)

        X = df[experiment.dataset_info.feature_columns]
        y = df[experiment.dataset_info.target_column]

        # Handle categorical features
        for col in X.select_dtypes(include=['object']).columns:
            X[col] = pd.Categorical(X[col]).codes

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Get model
        model = self._get_sklearn_model(algorithm_id)

        # Train
        start_time = time.time()
        model.fit(X_train, y_train)
        training_time = time.time() - start_time

        # Evaluate
        scores = self._evaluate_model(
            model, X_test, y_test, experiment.task_type
        )

        # Generate recommendations
        recommendations = self._generate_recommendations(
            scores, algo, experiment
        )

        # Create hyperparameters dict from model
        hyperparameters = {}
        for param in algo.hyperparameters:
            param_name = param["name"]
            if hasattr(model, param_name):
                hyperparameters[param_name] = getattr(model, param_name)

        return TrainedModel(
            id=str(uuid.uuid4()),
            algorithm_id=algorithm_id,
            algorithm_name=algo.name,
            hyperparameters=hyperparameters,
            scores=scores,
            training_time=training_time,
            recommendations=recommendations
        )

    def _get_sklearn_model(self, algorithm_id: str):
        """Get sklearn model instance."""
        models = {
            # Linear
            "linear_regression": lambda: __import__('sklearn.linear_model', fromlist=['LinearRegression']).LinearRegression(),
            "ridge_regression": lambda: __import__('sklearn.linear_model', fromlist=['Ridge']).Ridge(),
            "lasso_regression": lambda: __import__('sklearn.linear_model', fromlist=['Lasso']).Lasso(),
            "elastic_net": lambda: __import__('sklearn.linear_model', fromlist=['ElasticNet']).ElasticNet(),
            "logistic_regression": lambda: __import__('sklearn.linear_model', fromlist=['LogisticRegression']).LogisticRegression(max_iter=1000),
            "sgd_classifier": lambda: __import__('sklearn.linear_model', fromlist=['SGDClassifier']).SGDClassifier(),

            # Tree-based
            "decision_tree": lambda: __import__('sklearn.tree', fromlist=['DecisionTreeClassifier']).DecisionTreeClassifier(),
            "random_forest": lambda: __import__('sklearn.ensemble', fromlist=['RandomForestClassifier']).RandomForestClassifier(n_estimators=100),
            "extra_trees": lambda: __import__('sklearn.ensemble', fromlist=['ExtraTreesClassifier']).ExtraTreesClassifier(n_estimators=100),

            # Boosting
            "gradient_boosting": lambda: __import__('sklearn.ensemble', fromlist=['GradientBoostingClassifier']).GradientBoostingClassifier(),
            "adaboost": lambda: __import__('sklearn.ensemble', fromlist=['AdaBoostClassifier']).AdaBoostClassifier(),
            "histgradient_boosting": lambda: __import__('sklearn.ensemble', fromlist=['HistGradientBoostingClassifier']).HistGradientBoostingClassifier(),

            # SVM
            "svc": lambda: __import__('sklearn.svm', fromlist=['SVC']).SVC(probability=True),
            "svr": lambda: __import__('sklearn.svm', fromlist=['SVR']).SVR(),
            "linear_svc": lambda: __import__('sklearn.svm', fromlist=['LinearSVC']).LinearSVC(max_iter=2000),

            # Neighbors
            "knn_classifier": lambda: __import__('sklearn.neighbors', fromlist=['KNeighborsClassifier']).KNeighborsClassifier(),
            "knn_regressor": lambda: __import__('sklearn.neighbors', fromlist=['KNeighborsRegressor']).KNeighborsRegressor(),

            # Bayesian
            "naive_bayes_gaussian": lambda: __import__('sklearn.naive_bayes', fromlist=['GaussianNB']).GaussianNB(),
            "naive_bayes_multinomial": lambda: __import__('sklearn.naive_bayes', fromlist=['MultinomialNB']).MultinomialNB(),
            "bayesian_ridge": lambda: __import__('sklearn.linear_model', fromlist=['BayesianRidge']).BayesianRidge(),

            # Clustering
            "kmeans": lambda: __import__('sklearn.cluster', fromlist=['KMeans']).KMeans(n_clusters=3),
            "dbscan": lambda: __import__('sklearn.cluster', fromlist=['DBSCAN']).DBSCAN(),
            "agglomerative": lambda: __import__('sklearn.cluster', fromlist=['AgglomerativeClustering']).AgglomerativeClustering(),

            # Neural Network
            "mlp_classifier": lambda: __import__('sklearn.neural_network', fromlist=['MLPClassifier']).MLPClassifier(max_iter=500),
            "mlp_regressor": lambda: __import__('sklearn.neural_network', fromlist=['MLPRegressor']).MLPRegressor(max_iter=500),

            # Anomaly
            "isolation_forest": lambda: __import__('sklearn.ensemble', fromlist=['IsolationForest']).IsolationForest(),
            "one_class_svm": lambda: __import__('sklearn.svm', fromlist=['OneClassSVM']).OneClassSVM(),

            # Dimensionality
            "pca": lambda: __import__('sklearn.decomposition', fromlist=['PCA']).PCA(n_components=2),
        }

        if algorithm_id in models:
            return models[algorithm_id]()

        # Try XGBoost
        if algorithm_id == "xgboost":
            try:
                import xgboost as xgb
                return xgb.XGBClassifier(n_estimators=100, use_label_encoder=False, eval_metric='logloss')
            except ImportError:
                pass

        # Try LightGBM
        if algorithm_id == "lightgbm":
            try:
                import lightgbm as lgb
                return lgb.LGBMClassifier(n_estimators=100, verbose=-1)
            except ImportError:
                pass

        # Try CatBoost
        if algorithm_id == "catboost":
            try:
                from catboost import CatBoostClassifier
                return CatBoostClassifier(iterations=100, verbose=False)
            except ImportError:
                pass

        raise ValueError(f"Model {algorithm_id} not available")

    def _evaluate_model(self, model, X_test, y_test, task_type: TaskType) -> ModelScore:
        """Evaluate model and return scores."""
        from sklearn import metrics
        import numpy as np

        scores = ModelScore()

        try:
            if task_type == TaskType.CLASSIFICATION:
                y_pred = model.predict(X_test)
                scores.accuracy = float(metrics.accuracy_score(y_test, y_pred))
                scores.precision = float(metrics.precision_score(y_test, y_pred, average='weighted', zero_division=0))
                scores.recall = float(metrics.recall_score(y_test, y_pred, average='weighted', zero_division=0))
                scores.f1 = float(metrics.f1_score(y_test, y_pred, average='weighted', zero_division=0))

                if hasattr(model, 'predict_proba'):
                    try:
                        y_proba = model.predict_proba(X_test)
                        if len(np.unique(y_test)) == 2:
                            scores.roc_auc = float(metrics.roc_auc_score(y_test, y_proba[:, 1]))
                        else:
                            scores.roc_auc = float(metrics.roc_auc_score(y_test, y_proba, multi_class='ovr'))
                    except:
                        pass

            elif task_type == TaskType.REGRESSION:
                y_pred = model.predict(X_test)
                scores.mse = float(metrics.mean_squared_error(y_test, y_pred))
                scores.rmse = float(np.sqrt(scores.mse))
                scores.mae = float(metrics.mean_absolute_error(y_test, y_pred))
                scores.r2 = float(metrics.r2_score(y_test, y_pred))

            elif task_type == TaskType.CLUSTERING:
                if hasattr(model, 'labels_'):
                    labels = model.labels_
                else:
                    labels = model.predict(X_test)

                if len(set(labels)) > 1:
                    scores.silhouette = float(metrics.silhouette_score(X_test, labels))
                    scores.calinski_harabasz = float(metrics.calinski_harabasz_score(X_test, labels))
                    scores.davies_bouldin = float(metrics.davies_bouldin_score(X_test, labels))

        except Exception as e:
            print(f"Error evaluating model: {e}")

        return scores

    def _generate_recommendations(
        self,
        scores: ModelScore,
        algo,
        experiment: AutoMLExperiment
    ) -> List[str]:
        """Generate recommendations for improving the model."""
        recommendations = []

        if scores.accuracy and scores.accuracy < 0.7:
            recommendations.append("Consider using more complex models like XGBoost or Neural Networks")
            recommendations.append("Try feature engineering to create more informative features")

        if scores.f1 and scores.f1 < 0.6:
            recommendations.append("F1 score is low - check for class imbalance and consider SMOTE")

        if scores.roc_auc and scores.roc_auc < 0.7:
            recommendations.append("AUC-ROC is low - try adjusting classification threshold")

        if scores.r2 and scores.r2 < 0.5:
            recommendations.append("R² is low - consider polynomial features or tree-based models")
            recommendations.append("Check for outliers and consider robust regression")

        if experiment.dataset_info.has_categorical and algo.id != "catboost":
            recommendations.append("Dataset has categorical features - consider CatBoost")

        if experiment.dataset_info.n_samples > 10000 and algo.complexity in ["O(n^2)", "O(n^3)"]:
            recommendations.append("Consider faster algorithms like LightGBM for large datasets")

        if not recommendations:
            recommendations.append("Model performance looks good! Consider hyperparameter tuning for further improvements")

        return recommendations

    def _find_best_model(self, models: List[TrainedModel], metric: str) -> str:
        """Find best model based on metric."""
        best_model = None
        best_score = -float('inf')

        for model in models:
            score = getattr(model.scores, metric, None)
            if score is not None and score > best_score:
                best_score = score
                best_model = model

        return best_model.id if best_model else models[0].id

    async def _save_experiment(self, experiment: AutoMLExperiment):
        """Save experiment to database."""
        async with async_session() as session:
            # Check if experiment exists
            result = await session.execute(
                select(AutoMLExperimentDB).where(AutoMLExperimentDB.id == experiment.id)
            )
            db_exp = result.scalar_one_or_none()

            if db_exp:
                # Update existing
                db_exp.name = experiment.name
                db_exp.status = experiment.status
                db_exp.best_model_id = experiment.best_model_id
                db_exp.completed_at = experiment.completed_at

                # Delete old models and add new ones
                await session.execute(
                    sql_delete(TrainedModelDB).where(TrainedModelDB.experiment_id == experiment.id)
                )
            else:
                # Create new
                db_exp = AutoMLExperimentDB(
                    id=experiment.id,
                    name=experiment.name,
                    task_type=experiment.task_type.value,
                    dataset_info=experiment.dataset_info.model_dump() if experiment.dataset_info else None,
                    algorithms_to_try=experiment.algorithms_to_try,
                    optimization_metric=experiment.optimization_metric,
                    cv_folds=experiment.cv_folds,
                    max_time_minutes=experiment.max_time_minutes,
                    status=experiment.status,
                    created_at=experiment.created_at
                )
                session.add(db_exp)

            # Add models
            for model in experiment.models:
                db_model = TrainedModelDB(
                    id=model.id,
                    experiment_id=experiment.id,
                    algorithm_id=model.algorithm_id,
                    algorithm_name=model.algorithm_name,
                    hyperparameters=model.hyperparameters,
                    scores=model.scores.model_dump() if model.scores else None,
                    training_time=int(model.training_time) if model.training_time else None,
                    recommendations=model.recommendations
                )
                session.add(db_model)

            await session.commit()

    async def get_experiment(self, experiment_id: str) -> Optional[AutoMLExperiment]:
        """Get experiment by ID."""
        async with async_session() as session:
            result = await session.execute(
                select(AutoMLExperimentDB)
                .options(selectinload(AutoMLExperimentDB.models))
                .where(AutoMLExperimentDB.id == experiment_id)
            )
            db_exp = result.scalar_one_or_none()

            if not db_exp:
                return None

            return self._db_to_experiment(db_exp)

    async def list_experiments(self) -> List[AutoMLExperiment]:
        """List all experiments."""
        async with async_session() as session:
            result = await session.execute(
                select(AutoMLExperimentDB)
                .options(selectinload(AutoMLExperimentDB.models))
                .order_by(AutoMLExperimentDB.created_at.desc())
            )
            db_experiments = result.scalars().all()

            return [self._db_to_experiment(exp) for exp in db_experiments]

    async def delete_experiment(self, experiment_id: str) -> bool:
        """Delete an experiment."""
        async with async_session() as session:
            result = await session.execute(
                select(AutoMLExperimentDB).where(AutoMLExperimentDB.id == experiment_id)
            )
            db_exp = result.scalar_one_or_none()

            if not db_exp:
                return False

            await session.delete(db_exp)
            await session.commit()
            return True

    async def stop_experiment(self, experiment_id: str) -> bool:
        """Stop a running experiment."""
        if experiment_id in self._running_experiments:
            self._running_experiments[experiment_id] = False
            return True
        return False

    async def quick_train(
        self,
        algorithm_id: str,
        dataset_path: str,
        target_column: str,
        hyperparameters: Optional[dict] = None,
        test_size: float = 0.2
    ) -> Dict[str, Any]:
        """Quick train a single model."""
        import pandas as pd
        from sklearn.model_selection import train_test_split

        algo = get_algorithm_by_id(algorithm_id)
        if not algo:
            raise ValueError(f"Algorithm {algorithm_id} not found")

        # Load data
        if dataset_path.endswith('.csv'):
            df = pd.read_csv(dataset_path)
        else:
            df = pd.read_csv(dataset_path)

        feature_columns = [c for c in df.columns if c != target_column]
        X = df[feature_columns]
        y = df[target_column]

        # Handle categorical
        for col in X.select_dtypes(include=['object']).columns:
            X[col] = pd.Categorical(X[col]).codes

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42
        )

        # Get model
        model = self._get_sklearn_model(algorithm_id)

        # Apply custom hyperparameters
        if hyperparameters:
            for param, value in hyperparameters.items():
                if hasattr(model, param):
                    setattr(model, param, value)

        # Train
        start_time = time.time()
        model.fit(X_train, y_train)
        training_time = time.time() - start_time

        # Determine task type
        task_type = TaskType.CLASSIFICATION if algo.task_types[0] == TaskType.CLASSIFICATION else TaskType.REGRESSION

        # Evaluate
        scores = self._evaluate_model(model, X_test, y_test, task_type)

        return {
            "algorithm_id": algorithm_id,
            "algorithm_name": algo.name,
            "training_time": training_time,
            "scores": scores.model_dump(),
            "test_samples": len(X_test)
        }


automl_service = AutoMLService()
