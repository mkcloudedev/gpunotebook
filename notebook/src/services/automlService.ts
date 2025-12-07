// AutoML Service - Automated Machine Learning experiments

import apiClient from "./apiClient";

export type TaskType =
  | "classification"
  | "regression"
  | "clustering"
  | "dimensionality_reduction"
  | "anomaly_detection"
  | "time_series";

export type AlgorithmCategory =
  | "linear"
  | "tree_based"
  | "ensemble"
  | "neural_network"
  | "svm"
  | "neighbors"
  | "clustering"
  | "bayesian"
  | "boosting";

export interface Algorithm {
  id: string;
  name: string;
  category: AlgorithmCategory;
  taskTypes: TaskType[];
  description: string;
  hyperparameters: Array<{
    name: string;
    type: string;
    default?: unknown;
    min?: number;
    max?: number;
    options?: string[];
  }>;
  pros: string[];
  cons: string[];
  complexity: string;
  gpuAccelerated: boolean;
  library: string;
}

export interface ModelScore {
  accuracy?: number;
  precision?: number;
  recall?: number;
  f1?: number;
  rocAuc?: number;
  mse?: number;
  rmse?: number;
  mae?: number;
  r2?: number;
  silhouette?: number;
}

export interface TrainedModel {
  id: string;
  algorithmId: string;
  algorithmName: string;
  hyperparameters: Record<string, unknown>;
  scores: ModelScore;
  trainingTime: number;
  createdAt: Date;
  recommendations: string[];
}

export interface AutoMLExperiment {
  id: string;
  name: string;
  datasetPath: string;
  targetColumn: string;
  taskType: TaskType;
  algorithmsToTry: string[];
  optimizationMetric: string;
  cvFolds: number;
  maxTimeMinutes?: number;
  testSize: number;
  status: "pending" | "running" | "completed" | "failed" | "stopped";
  progress: number;
  models: TrainedModel[];
  bestModelId?: string;
  createdAt: Date;
  completedAt?: Date;
  error?: string;
}

export interface AlgorithmRecommendation {
  algorithm: Algorithm;
  score: number;
  reasons: string[];
}

export interface CreateExperimentParams {
  name: string;
  datasetPath: string;
  targetColumn: string;
  taskType: TaskType;
  algorithms?: string[];
  optimizationMetric?: string;
  cvFolds?: number;
  maxTimeMinutes?: number;
  testSize?: number;
}

interface AlgorithmResponse {
  id: string;
  name: string;
  category: string;
  task_types: string[];
  description: string;
  hyperparameters: Array<{
    name: string;
    type: string;
    default?: unknown;
    min?: number;
    max?: number;
    options?: string[];
  }>;
  pros: string[];
  cons: string[];
  complexity: string;
  gpu_accelerated: boolean;
  library: string;
}

interface ExperimentResponse {
  id: string;
  name: string;
  dataset_path: string;
  target_column: string;
  task_type: string;
  algorithms_to_try: string[];
  optimization_metric: string;
  cv_folds: number;
  max_time_minutes?: number;
  test_size: number;
  status: string;
  progress: number;
  models: Array<{
    id: string;
    algorithm_id: string;
    algorithm_name: string;
    hyperparameters: Record<string, unknown>;
    scores: Record<string, number>;
    training_time: number;
    created_at: string;
    recommendations: string[];
  }>;
  best_model_id?: string;
  created_at: string;
  completed_at?: string;
  error?: string;
}

class AutoMLService {
  private parseAlgorithm(data: AlgorithmResponse): Algorithm {
    return {
      id: data.id,
      name: data.name,
      category: data.category as AlgorithmCategory,
      taskTypes: data.task_types as TaskType[],
      description: data.description,
      hyperparameters: data.hyperparameters,
      pros: data.pros,
      cons: data.cons,
      complexity: data.complexity,
      gpuAccelerated: data.gpu_accelerated,
      library: data.library,
    };
  }

  private parseExperiment(data: ExperimentResponse): AutoMLExperiment {
    return {
      id: data.id,
      name: data.name,
      datasetPath: data.dataset_path,
      targetColumn: data.target_column,
      taskType: data.task_type as TaskType,
      algorithmsToTry: data.algorithms_to_try,
      optimizationMetric: data.optimization_metric,
      cvFolds: data.cv_folds,
      maxTimeMinutes: data.max_time_minutes,
      testSize: data.test_size,
      status: data.status as AutoMLExperiment["status"],
      progress: data.progress,
      models: data.models.map((m) => ({
        id: m.id,
        algorithmId: m.algorithm_id,
        algorithmName: m.algorithm_name,
        hyperparameters: m.hyperparameters,
        scores: m.scores as ModelScore,
        trainingTime: m.training_time,
        createdAt: new Date(m.created_at),
        recommendations: m.recommendations,
      })),
      bestModelId: data.best_model_id,
      createdAt: new Date(data.created_at),
      completedAt: data.completed_at ? new Date(data.completed_at) : undefined,
      error: data.error,
    };
  }

  // Algorithms
  async getAlgorithms(): Promise<Algorithm[]> {
    const response = await apiClient.get<AlgorithmResponse[]>("/api/automl/algorithms");
    return response.map((a) => this.parseAlgorithm(a));
  }

  async getAlgorithm(id: string): Promise<Algorithm> {
    const response = await apiClient.get<AlgorithmResponse>(`/api/automl/algorithms/${id}`);
    return this.parseAlgorithm(response);
  }

  async getAlgorithmsByTask(taskType: TaskType): Promise<Algorithm[]> {
    const response = await apiClient.get<AlgorithmResponse[]>(
      `/api/automl/algorithms?task_type=${taskType}`
    );
    return response.map((a) => this.parseAlgorithm(a));
  }

  // Experiments
  async listExperiments(): Promise<AutoMLExperiment[]> {
    const response = await apiClient.get<ExperimentResponse[]>("/api/automl/experiments");
    return response.map((e) => this.parseExperiment(e));
  }

  async getExperiment(id: string): Promise<AutoMLExperiment> {
    const response = await apiClient.get<ExperimentResponse>(`/api/automl/experiments/${id}`);
    return this.parseExperiment(response);
  }

  async createExperiment(params: CreateExperimentParams): Promise<AutoMLExperiment> {
    const response = await apiClient.post<ExperimentResponse>("/api/automl/experiments", {
      name: params.name,
      dataset_path: params.datasetPath,
      target_column: params.targetColumn,
      task_type: params.taskType,
      algorithms: params.algorithms,
      optimization_metric: params.optimizationMetric,
      cv_folds: params.cvFolds,
      max_time_minutes: params.maxTimeMinutes,
      test_size: params.testSize,
    });
    return this.parseExperiment(response);
  }

  async stopExperiment(id: string): Promise<void> {
    await apiClient.post(`/api/automl/experiments/${id}/stop`, {});
  }

  async deleteExperiment(id: string): Promise<void> {
    await apiClient.delete(`/api/automl/experiments/${id}`);
  }

  async rerunExperiment(id: string): Promise<AutoMLExperiment> {
    const response = await apiClient.post<ExperimentResponse>(
      `/api/automl/experiments/${id}/rerun`,
      {}
    );
    return this.parseExperiment(response);
  }

  // Recommendations
  async getRecommendations(params: {
    taskType: TaskType;
    nSamples: number;
    nFeatures: number;
    hasCategorical?: boolean;
    hasMissing?: boolean;
    needInterpretability?: boolean;
    needSpeed?: boolean;
    hasGpu?: boolean;
  }): Promise<AlgorithmRecommendation[]> {
    const response = await apiClient.post<
      Array<{
        algorithm: AlgorithmResponse;
        score: number;
        reasons: string[];
      }>
    >("/api/automl/recommendations", {
      task_type: params.taskType,
      n_samples: params.nSamples,
      n_features: params.nFeatures,
      has_categorical: params.hasCategorical,
      has_missing: params.hasMissing,
      need_interpretability: params.needInterpretability,
      need_speed: params.needSpeed,
      has_gpu: params.hasGpu,
    });

    return response.map((r) => ({
      algorithm: this.parseAlgorithm(r.algorithm),
      score: r.score,
      reasons: r.reasons,
    }));
  }

  // Model operations
  async exportModel(experimentId: string, modelId: string, format: "pickle" | "onnx" | "joblib"): Promise<Blob> {
    const response = await fetch(
      `${apiClient.getBaseUrl()}/api/automl/experiments/${experimentId}/models/${modelId}/export?format=${format}`
    );
    return response.blob();
  }

  async predictWithModel(
    experimentId: string,
    modelId: string,
    data: Record<string, unknown>[]
  ): Promise<unknown[]> {
    const response = await apiClient.post<{ predictions: unknown[] }>(
      `/api/automl/experiments/${experimentId}/models/${modelId}/predict`,
      { data }
    );
    return response.predictions;
  }

  // Dataset analysis
  async analyzeDataset(path: string): Promise<{
    nSamples: number;
    nFeatures: number;
    columns: Array<{
      name: string;
      dtype: string;
      unique: number;
      missing: number;
      isCategorical: boolean;
    }>;
    suggestedTaskType: TaskType;
    suggestedTarget: string;
  }> {
    const response = await apiClient.post<{
      n_samples: number;
      n_features: number;
      columns: Array<{
        name: string;
        dtype: string;
        unique: number;
        missing: number;
        is_categorical: boolean;
      }>;
      suggested_task_type: string;
      suggested_target: string;
    }>("/api/automl/analyze-dataset", { path });

    return {
      nSamples: response.n_samples,
      nFeatures: response.n_features,
      columns: response.columns.map((c) => ({
        name: c.name,
        dtype: c.dtype,
        unique: c.unique,
        missing: c.missing,
        isCategorical: c.is_categorical,
      })),
      suggestedTaskType: response.suggested_task_type as TaskType,
      suggestedTarget: response.suggested_target,
    };
  }
}

export const automlService = new AutoMLService();
export default automlService;
