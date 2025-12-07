// Task types for ML
export type TaskType =
  | "classification"
  | "regression"
  | "clustering"
  | "dimensionality_reduction"
  | "anomaly_detection"
  | "time_series"
  | "nlp"
  | "computer_vision"
  | "recommendation"
  | "reinforcement_learning";

// Algorithm categories
export type AlgorithmCategory =
  | "linear"
  | "tree_based"
  | "ensemble"
  | "neural_network"
  | "svm"
  | "neighbors"
  | "clustering"
  | "bayesian"
  | "dimensionality"
  | "boosting"
  | "deep_learning"
  | "transformer"
  | "other";

// Hyperparameter definition
export interface Hyperparameter {
  name: string;
  type: string;
  default?: string | number | boolean;
  min?: number;
  max?: number;
  options?: string[];
  description?: string;
}

// ML Algorithm
export interface Algorithm {
  id: string;
  name: string;
  category: AlgorithmCategory;
  taskTypes: TaskType[];
  description: string;
  hyperparameters: Hyperparameter[];
  pros: string[];
  cons: string[];
  complexity: string;
  gpuAccelerated: boolean;
  library: string;
}

// Model score
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
  calinskiHarabasz?: number;
  daviesBouldin?: number;
}

// Score maps by task type
export const getClassificationScores = (scores: ModelScore): Record<string, number | undefined> => ({
  "Accuracy": scores.accuracy,
  "Precision": scores.precision,
  "Recall": scores.recall,
  "F1": scores.f1,
  "ROC-AUC": scores.rocAuc,
});

export const getRegressionScores = (scores: ModelScore): Record<string, number | undefined> => ({
  "R²": scores.r2,
  "MSE": scores.mse,
  "RMSE": scores.rmse,
  "MAE": scores.mae,
});

export const getClusteringScores = (scores: ModelScore): Record<string, number | undefined> => ({
  "Silhouette": scores.silhouette,
  "Calinski-Harabasz": scores.calinskiHarabasz,
  "Davies-Bouldin": scores.daviesBouldin,
});

// Trained model
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

// Dataset info
export interface DatasetInfo {
  name: string;
  nSamples: number;
  nFeatures: number;
  nClasses?: number;
  targetColumn: string;
  featureColumns: string[];
  taskType: TaskType;
  hasMissing: boolean;
  hasCategorical: boolean;
}

// AutoML Experiment
export interface AutoMLExperiment {
  id: string;
  name: string;
  datasetInfo: DatasetInfo;
  taskType: TaskType;
  algorithmsToTry: string[];
  optimizationMetric: string;
  cvFolds: number;
  maxTimeMinutes?: number;
  status: "pending" | "running" | "completed" | "failed" | "stopped";
  models: TrainedModel[];
  bestModelId?: string;
  createdAt: Date;
  completedAt?: Date;
}

// Get best model from experiment
export const getBestModel = (experiment: AutoMLExperiment): TrainedModel | null => {
  if (!experiment.bestModelId || experiment.models.length === 0) return null;
  return experiment.models.find((m) => m.id === experiment.bestModelId) || experiment.models[0];
};

// Algorithm recommendation
export interface AlgorithmRecommendation {
  algorithm: Algorithm;
  score: number;
  reasons: string[];
}

// Recommendation request params
export interface RecommendationParams {
  taskType: TaskType;
  nSamples: number;
  nFeatures: number;
  hasCategorical?: boolean;
  hasMissing?: boolean;
  needInterpretability?: boolean;
  needSpeed?: boolean;
  hasGpu?: boolean;
}

// Create experiment params
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
