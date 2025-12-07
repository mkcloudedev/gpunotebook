// Services Index - Export all services

export { apiClient } from "./apiClient";
export type { ApiError } from "./apiClient";

export { websocketService } from "./websocketService";
export type { WebSocketMessage, KernelOutput, ExecutionState } from "./websocketService";

export { kernelService } from "./kernelService";
export type { Kernel, KernelSpec, KernelStatus, CreateKernelParams } from "./kernelService";

export { executionService } from "./executionService";
export type {
  ExecutionRequest,
  ExecutionResult,
  ExecutionOutput,
  CompletionResult,
  InspectionResult,
} from "./executionService";

export { notebookService } from "./notebookService";
export type {
  Notebook,
  Cell,
  CellType,
  CellOutput,
  NotebookMetadata,
  CreateNotebookParams,
  NotebookTemplate,
} from "./notebookService";

export { gpuService } from "./gpuService";
export type {
  GPUInfo,
  GPUProcess,
  GPUMetrics,
  GPUHistoryPoint,
} from "./gpuService";

export { fileService } from "./fileService";
export type {
  FileItem,
  FileType,
  StorageInfo,
  DatasetPreview,
  UploadResult,
} from "./fileService";

export { aiService } from "./aiService";
export type {
  AIProvider,
  AIMessage,
  AIAction,
  AIResponse,
  ChatRequest,
  PromptTemplate,
  ProviderStatus,
} from "./aiService";

export { settingsService } from "./settingsService";
export type {
  APIKeys,
  EditorSettings,
  KernelSettings,
  GeneralSettings,
  AllSettings,
} from "./settingsService";

export { kaggleService } from "./kaggleService";
export type {
  KaggleDataset,
  KaggleCompetition,
  KaggleKernel,
  KaggleSubmission,
} from "./kaggleService";

export { automlService } from "./automlService";
export type {
  TaskType,
  AlgorithmCategory,
  Algorithm,
  ModelScore,
  TrainedModel,
  AutoMLExperiment,
  AlgorithmRecommendation,
  CreateExperimentParams,
} from "./automlService";

export { clusterService } from "./clusterService";
export type {
  NodeStatus,
  ClusterNode,
  NodeHealth,
  ClusterStats,
  AddNodeParams,
} from "./clusterService";

export { pipService } from "./pipService";
export type {
  InstalledPackage,
  PackageInfo,
  PackageSearchResult,
  InstallProgress,
  InstallResult,
  UninstallResult,
  RequirementsParseResult,
} from "./pipService";
