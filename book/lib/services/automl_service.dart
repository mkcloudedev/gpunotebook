import 'api_client.dart';

/// Task types for ML
enum TaskType {
  classification,
  regression,
  clustering,
  dimensionalityReduction,
  anomalyDetection,
  timeSeries,
  nlp,
  computerVision,
  recommendation,
  reinforcementLearning,
}

/// Algorithm categories
enum AlgorithmCategory {
  linear,
  treeBased,
  ensemble,
  neuralNetwork,
  svm,
  neighbors,
  clustering,
  bayesian,
  dimensionality,
  boosting,
  deepLearning,
  transformer,
  other,
}

/// ML Algorithm
class Algorithm {
  final String id;
  final String name;
  final String category;
  final List<String> taskTypes;
  final String description;
  final List<Map<String, dynamic>> hyperparameters;
  final List<String> pros;
  final List<String> cons;
  final String complexity;
  final bool gpuAccelerated;
  final String library;

  Algorithm({
    required this.id,
    required this.name,
    required this.category,
    required this.taskTypes,
    required this.description,
    required this.hyperparameters,
    required this.pros,
    required this.cons,
    required this.complexity,
    required this.gpuAccelerated,
    required this.library,
  });

  factory Algorithm.fromJson(Map<String, dynamic> json) {
    return Algorithm(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      taskTypes: List<String>.from(json['task_types'] ?? []),
      description: json['description'] ?? '',
      hyperparameters: List<Map<String, dynamic>>.from(json['hyperparameters'] ?? []),
      pros: List<String>.from(json['pros'] ?? []),
      cons: List<String>.from(json['cons'] ?? []),
      complexity: json['complexity'] ?? '',
      gpuAccelerated: json['gpu_accelerated'] ?? false,
      library: json['library'] ?? '',
    );
  }
}

/// Model score
class ModelScore {
  final double? accuracy;
  final double? precision;
  final double? recall;
  final double? f1;
  final double? rocAuc;
  final double? mse;
  final double? rmse;
  final double? mae;
  final double? r2;
  final double? silhouette;
  final double? calinskiHarabasz;
  final double? daviesBouldin;

  ModelScore({
    this.accuracy,
    this.precision,
    this.recall,
    this.f1,
    this.rocAuc,
    this.mse,
    this.rmse,
    this.mae,
    this.r2,
    this.silhouette,
    this.calinskiHarabasz,
    this.daviesBouldin,
  });

  factory ModelScore.fromJson(Map<String, dynamic> json) {
    return ModelScore(
      accuracy: json['accuracy']?.toDouble(),
      precision: json['precision']?.toDouble(),
      recall: json['recall']?.toDouble(),
      f1: json['f1']?.toDouble(),
      rocAuc: json['roc_auc']?.toDouble(),
      mse: json['mse']?.toDouble(),
      rmse: json['rmse']?.toDouble(),
      mae: json['mae']?.toDouble(),
      r2: json['r2']?.toDouble(),
      silhouette: json['silhouette']?.toDouble(),
      calinskiHarabasz: json['calinski_harabasz']?.toDouble(),
      daviesBouldin: json['davies_bouldin']?.toDouble(),
    );
  }

  Map<String, double?> get classificationScores => {
    'Accuracy': accuracy,
    'Precision': precision,
    'Recall': recall,
    'F1': f1,
    'ROC-AUC': rocAuc,
  };

  Map<String, double?> get regressionScores => {
    'R²': r2,
    'MSE': mse,
    'RMSE': rmse,
    'MAE': mae,
  };

  Map<String, double?> get clusteringScores => {
    'Silhouette': silhouette,
    'Calinski-Harabasz': calinskiHarabasz,
    'Davies-Bouldin': daviesBouldin,
  };
}

/// Trained model
class TrainedModel {
  final String id;
  final String algorithmId;
  final String algorithmName;
  final Map<String, dynamic> hyperparameters;
  final ModelScore scores;
  final double trainingTime;
  final DateTime createdAt;
  final List<String> recommendations;

  TrainedModel({
    required this.id,
    required this.algorithmId,
    required this.algorithmName,
    required this.hyperparameters,
    required this.scores,
    required this.trainingTime,
    required this.createdAt,
    required this.recommendations,
  });

  factory TrainedModel.fromJson(Map<String, dynamic> json) {
    return TrainedModel(
      id: json['id'] ?? '',
      algorithmId: json['algorithm_id'] ?? '',
      algorithmName: json['algorithm_name'] ?? '',
      hyperparameters: Map<String, dynamic>.from(json['hyperparameters'] ?? {}),
      scores: ModelScore.fromJson(json['scores'] ?? {}),
      trainingTime: (json['training_time'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}

/// Dataset info
class DatasetInfo {
  final String name;
  final int nSamples;
  final int nFeatures;
  final int? nClasses;
  final String targetColumn;
  final List<String> featureColumns;
  final String taskType;
  final bool hasMissing;
  final bool hasCategorical;

  DatasetInfo({
    required this.name,
    required this.nSamples,
    required this.nFeatures,
    this.nClasses,
    required this.targetColumn,
    required this.featureColumns,
    required this.taskType,
    required this.hasMissing,
    required this.hasCategorical,
  });

  factory DatasetInfo.fromJson(Map<String, dynamic> json) {
    return DatasetInfo(
      name: json['name'] ?? '',
      nSamples: json['n_samples'] ?? 0,
      nFeatures: json['n_features'] ?? 0,
      nClasses: json['n_classes'],
      targetColumn: json['target_column'] ?? '',
      featureColumns: List<String>.from(json['feature_columns'] ?? []),
      taskType: json['task_type'] ?? '',
      hasMissing: json['has_missing'] ?? false,
      hasCategorical: json['has_categorical'] ?? false,
    );
  }
}

/// AutoML Experiment
class AutoMLExperiment {
  final String id;
  final String name;
  final DatasetInfo datasetInfo;
  final String taskType;
  final List<String> algorithmsToTry;
  final String optimizationMetric;
  final int cvFolds;
  final int? maxTimeMinutes;
  final String status;
  final List<TrainedModel> models;
  final String? bestModelId;
  final DateTime createdAt;
  final DateTime? completedAt;

  AutoMLExperiment({
    required this.id,
    required this.name,
    required this.datasetInfo,
    required this.taskType,
    required this.algorithmsToTry,
    required this.optimizationMetric,
    required this.cvFolds,
    this.maxTimeMinutes,
    required this.status,
    required this.models,
    this.bestModelId,
    required this.createdAt,
    this.completedAt,
  });

  factory AutoMLExperiment.fromJson(Map<String, dynamic> json) {
    return AutoMLExperiment(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      datasetInfo: DatasetInfo.fromJson(json['dataset_info'] ?? {}),
      taskType: json['task_type'] ?? '',
      algorithmsToTry: List<String>.from(json['algorithms_to_try'] ?? []),
      optimizationMetric: json['optimization_metric'] ?? '',
      cvFolds: json['cv_folds'] ?? 5,
      maxTimeMinutes: json['max_time_minutes'],
      status: json['status'] ?? 'pending',
      models: (json['models'] as List?)?.map((m) => TrainedModel.fromJson(m)).toList() ?? [],
      bestModelId: json['best_model_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
    );
  }

  TrainedModel? get bestModel {
    if (bestModelId == null) return null;
    return models.firstWhere((m) => m.id == bestModelId, orElse: () => models.first);
  }
}

/// Algorithm recommendation
class AlgorithmRecommendation {
  final Algorithm algorithm;
  final int score;
  final List<String> reasons;

  AlgorithmRecommendation({
    required this.algorithm,
    required this.score,
    required this.reasons,
  });

  factory AlgorithmRecommendation.fromJson(Map<String, dynamic> json) {
    return AlgorithmRecommendation(
      algorithm: Algorithm.fromJson(json['algorithm'] ?? {}),
      score: json['score'] ?? 0,
      reasons: List<String>.from(json['reasons'] ?? []),
    );
  }
}

/// AutoML Service
class AutoMLService {
  final ApiClient _api;

  AutoMLService({ApiClient? api}) : _api = api ?? apiClient;

  // =========================================================================
  // ALGORITHMS
  // =========================================================================

  Future<List<Algorithm>> listAlgorithms({
    String? taskType,
    String? category,
    bool gpuOnly = false,
  }) async {
    var endpoint = '/api/automl/algorithms';
    final params = <String>[];

    if (taskType != null) params.add('task_type=$taskType');
    if (category != null) params.add('category=$category');
    if (gpuOnly) params.add('gpu_only=true');

    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }

    final data = await _api.getList(endpoint);
    return data.map((json) => Algorithm.fromJson(json)).toList();
  }

  Future<Algorithm> getAlgorithm(String algorithmId) async {
    final data = await _api.get('/api/automl/algorithms/$algorithmId');
    return Algorithm.fromJson(data);
  }

  Future<List<Algorithm>> getAlgorithmsForTask(String taskType) async {
    final data = await _api.getList('/api/automl/algorithms/task/$taskType');
    return data.map((json) => Algorithm.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final data = await _api.getList('/api/automl/categories');
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> listTaskTypes() async {
    return await _api.get('/api/automl/task-types');
  }

  // =========================================================================
  // EXPERIMENTS
  // =========================================================================

  Future<AutoMLExperiment> createExperiment({
    required String name,
    required String datasetPath,
    required String targetColumn,
    required String taskType,
    List<String>? algorithms,
    String? optimizationMetric,
    int cvFolds = 5,
    int? maxTimeMinutes = 60,
    double testSize = 0.2,
  }) async {
    final data = await _api.post('/api/automl/experiments', {
      'name': name,
      'dataset_path': datasetPath,
      'target_column': targetColumn,
      'task_type': taskType,
      'algorithms': algorithms,
      'optimization_metric': optimizationMetric,
      'cv_folds': cvFolds,
      'max_time_minutes': maxTimeMinutes,
      'test_size': testSize,
    });
    return AutoMLExperiment.fromJson(data);
  }

  Future<List<AutoMLExperiment>> listExperiments() async {
    final data = await _api.getList('/api/automl/experiments');
    return data.map((json) => AutoMLExperiment.fromJson(json)).toList();
  }

  Future<AutoMLExperiment> getExperiment(String experimentId) async {
    final data = await _api.get('/api/automl/experiments/$experimentId');
    return AutoMLExperiment.fromJson(data);
  }

  Future<void> deleteExperiment(String experimentId) async {
    await _api.delete('/api/automl/experiments/$experimentId');
  }

  Future<void> stopExperiment(String experimentId) async {
    await _api.post('/api/automl/experiments/$experimentId/stop', {});
  }

  Future<List<TrainedModel>> getExperimentModels(String experimentId) async {
    final data = await _api.getList('/api/automl/experiments/$experimentId/models');
    return data.map((json) => TrainedModel.fromJson(json)).toList();
  }

  Future<TrainedModel> getBestModel(String experimentId) async {
    final data = await _api.get('/api/automl/experiments/$experimentId/best-model');
    return TrainedModel.fromJson(data);
  }

  // =========================================================================
  // RECOMMENDATIONS
  // =========================================================================

  Future<List<AlgorithmRecommendation>> getRecommendations({
    required String taskType,
    required int nSamples,
    required int nFeatures,
    bool hasCategorical = false,
    bool hasMissing = false,
    bool needInterpretability = false,
    bool needSpeed = false,
    bool hasGpu = false,
  }) async {
    final data = await _api.post('/api/automl/recommend', {
      'task_type': taskType,
      'n_samples': nSamples,
      'n_features': nFeatures,
      'has_categorical': hasCategorical,
      'has_missing': hasMissing,
      'need_interpretability': needInterpretability,
      'need_speed': needSpeed,
      'has_gpu': hasGpu,
    });

    final recommendations = data['recommendations'] as List? ?? [];
    return recommendations.map((r) => AlgorithmRecommendation.fromJson(r)).toList();
  }

  // =========================================================================
  // QUICK TRAIN
  // =========================================================================

  Future<Map<String, dynamic>> quickTrain({
    required String algorithmId,
    required String datasetPath,
    required String targetColumn,
    Map<String, dynamic>? hyperparameters,
    double testSize = 0.2,
  }) async {
    return await _api.post('/api/automl/quick-train', {
      'algorithm_id': algorithmId,
      'dataset_path': datasetPath,
      'target_column': targetColumn,
      'hyperparameters': hyperparameters,
      'test_size': testSize,
    });
  }
}

final automlService = AutoMLService();
