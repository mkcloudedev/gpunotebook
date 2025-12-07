import { useState, useEffect, useCallback, useRef } from "react";
import {
  Cpu,
  FlaskConical,
  Sparkles,
  Zap,
  TrendingUp,
  GitBranch,
  Layers,
  Brain,
  Divide,
  Users,
  Hexagon,
  PieChart,
  Minimize2,
  Rocket,
  Box,
  Plus,
  RefreshCw,
  MousePointerClick,
  Check,
  X,
  Trash2,
  Square,
  Database,
  Columns,
  Target,
  Lightbulb,
  CheckCircle,
  XCircle,
  Clock,
  Loader2,
  ChevronDown,
  ChevronUp,
  AlertCircle,
  FileSearch,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { Checkbox } from "./ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "./ui/dialog";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { AutoMLBreadcrumb } from "./AutoMLBreadcrumb";
import {
  Algorithm,
  AlgorithmCategory,
  AutoMLExperiment,
  AlgorithmRecommendation,
  ModelScore,
  getBestModel,
  getClassificationScores,
  getRegressionScores,
  getClusteringScores,
  TaskType,
  DatasetInfo,
} from "@/types/automl";
import { automlService } from "@/services/automlService";

// Mock data for demo
const mockAlgorithms: Algorithm[] = [
  {
    id: "1",
    name: "Random Forest",
    category: "ensemble",
    taskTypes: ["classification", "regression"],
    description: "An ensemble method that uses multiple decision trees to improve predictions.",
    hyperparameters: [
      { name: "n_estimators", type: "int" },
      { name: "max_depth", type: "int" },
      { name: "min_samples_split", type: "int" },
    ],
    pros: ["Handles non-linear relationships", "Resistant to overfitting", "Works well with high-dimensional data"],
    cons: ["Can be slow with large datasets", "Memory intensive", "Less interpretable"],
    complexity: "O(n * m * log(m))",
    gpuAccelerated: false,
    library: "scikit-learn",
  },
  {
    id: "2",
    name: "XGBoost",
    category: "boosting",
    taskTypes: ["classification", "regression"],
    description: "Extreme Gradient Boosting - highly efficient gradient boosting implementation.",
    hyperparameters: [
      { name: "learning_rate", type: "float" },
      { name: "n_estimators", type: "int" },
      { name: "max_depth", type: "int" },
    ],
    pros: ["State-of-the-art performance", "Handles missing values", "Built-in regularization"],
    cons: ["Requires careful tuning", "Can overfit on noisy data", "Memory intensive"],
    complexity: "O(K * n * d * log(n))",
    gpuAccelerated: true,
    library: "xgboost",
  },
  {
    id: "3",
    name: "LightGBM",
    category: "boosting",
    taskTypes: ["classification", "regression"],
    description: "Light Gradient Boosting Machine - fast, distributed gradient boosting framework.",
    hyperparameters: [
      { name: "num_leaves", type: "int" },
      { name: "learning_rate", type: "float" },
      { name: "n_estimators", type: "int" },
    ],
    pros: ["Faster training", "Lower memory usage", "Handles large datasets"],
    cons: ["Can overfit on small data", "Sensitive to noise", "Complex parameter tuning"],
    complexity: "O(n * d)",
    gpuAccelerated: true,
    library: "lightgbm",
  },
  {
    id: "4",
    name: "Neural Network (MLP)",
    category: "neural_network",
    taskTypes: ["classification", "regression"],
    description: "Multi-layer Perceptron neural network for complex pattern recognition.",
    hyperparameters: [
      { name: "hidden_layer_sizes", type: "tuple" },
      { name: "activation", type: "str" },
      { name: "learning_rate", type: "float" },
    ],
    pros: ["Handles non-linear relationships", "Universal approximator", "Scalable"],
    cons: ["Requires lots of data", "Black box model", "Computationally expensive"],
    complexity: "O(n * m * h * o * i)",
    gpuAccelerated: true,
    library: "pytorch",
  },
  {
    id: "5",
    name: "Support Vector Machine",
    category: "svm",
    taskTypes: ["classification", "regression"],
    description: "Maximum margin classifier using kernel trick for non-linear boundaries.",
    hyperparameters: [
      { name: "C", type: "float" },
      { name: "kernel", type: "str" },
      { name: "gamma", type: "float" },
    ],
    pros: ["Effective in high dimensions", "Memory efficient", "Versatile kernels"],
    cons: ["Slow on large datasets", "Sensitive to scaling", "No probability estimates"],
    complexity: "O(n² * d)",
    gpuAccelerated: true,
    library: "sklearn",
  },
  {
    id: "6",
    name: "K-Nearest Neighbors",
    category: "neighbors",
    taskTypes: ["classification", "regression", "clustering"],
    description: "Instance-based learning that classifies based on closest training examples.",
    hyperparameters: [
      { name: "n_neighbors", type: "int" },
      { name: "weights", type: "str" },
      { name: "metric", type: "str" },
    ],
    pros: ["Simple and intuitive", "No training phase", "Works with any distance"],
    cons: ["Slow prediction", "Sensitive to irrelevant features", "Memory intensive"],
    complexity: "O(n * d)",
    gpuAccelerated: false,
    library: "sklearn",
  },
  {
    id: "7",
    name: "Logistic Regression",
    category: "linear",
    taskTypes: ["classification"],
    description: "Linear model for binary and multiclass classification with probabilistic output.",
    hyperparameters: [
      { name: "C", type: "float" },
      { name: "penalty", type: "str" },
      { name: "solver", type: "str" },
    ],
    pros: ["Interpretable", "Fast training", "Probabilistic output"],
    cons: ["Assumes linear boundaries", "Limited complexity", "Feature engineering needed"],
    complexity: "O(n * d)",
    gpuAccelerated: false,
    library: "sklearn",
  },
  {
    id: "8",
    name: "KMEANS",
    category: "clustering",
    taskTypes: ["clustering"],
    description: "Partition-based clustering that minimizes within-cluster variance.",
    hyperparameters: [
      { name: "n_clusters", type: "int" },
      { name: "init", type: "str" },
      { name: "max_iter", type: "int" },
    ],
    pros: ["Simple and fast", "Scalable", "Easy to interpret"],
    cons: ["Requires k specification", "Sensitive to initialization", "Assumes spherical clusters"],
    complexity: "O(n * k * d * i)",
    gpuAccelerated: true,
    library: "sklearn",
  },
];

const mockExperiments: AutoMLExperiment[] = [
  {
    id: "exp1",
    name: "Customer Churn Prediction",
    datasetInfo: {
      name: "churn_data.csv",
      nSamples: 10000,
      nFeatures: 20,
      nClasses: 2,
      targetColumn: "churn",
      featureColumns: [],
      taskType: "classification",
      hasMissing: false,
      hasCategorical: true,
    },
    taskType: "classification",
    algorithmsToTry: ["Random Forest", "XGBoost", "LightGBM"],
    optimizationMetric: "f1",
    cvFolds: 5,
    maxTimeMinutes: 30,
    status: "completed",
    models: [
      {
        id: "m1",
        algorithmId: "2",
        algorithmName: "XGBoost",
        hyperparameters: { n_estimators: 100, max_depth: 6 },
        scores: { accuracy: 0.92, precision: 0.89, recall: 0.87, f1: 0.88, rocAuc: 0.94 },
        trainingTime: 45.2,
        createdAt: new Date(),
        recommendations: ["Consider feature engineering", "Try ensemble methods"],
      },
    ],
    bestModelId: "m1",
    createdAt: new Date(Date.now() - 86400000),
    completedAt: new Date(),
  },
  {
    id: "exp2",
    name: "House Price Prediction",
    datasetInfo: {
      name: "housing.csv",
      nSamples: 5000,
      nFeatures: 15,
      targetColumn: "price",
      featureColumns: [],
      taskType: "regression",
      hasMissing: true,
      hasCategorical: true,
    },
    taskType: "regression",
    algorithmsToTry: ["Random Forest", "XGBoost", "LightGBM", "Neural Network"],
    optimizationMetric: "r2",
    cvFolds: 5,
    status: "running",
    models: [
      {
        id: "m2",
        algorithmId: "1",
        algorithmName: "Random Forest",
        hyperparameters: { n_estimators: 100 },
        scores: { r2: 0.85, mse: 0.02, rmse: 0.14, mae: 0.11 },
        trainingTime: 30.5,
        createdAt: new Date(),
        recommendations: [],
      },
    ],
    createdAt: new Date(),
  },
];

type TabType = "algorithms" | "experiments" | "recommendations";

// Polling interval for running experiments (5 seconds)
const POLL_INTERVAL = 5000;

export const AutoMLContent = () => {
  const [activeTab, setActiveTab] = useState<TabType>("algorithms");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Data
  const [algorithms, setAlgorithms] = useState<Algorithm[]>([]);
  const [experiments, setExperiments] = useState<AutoMLExperiment[]>([]);
  const [recommendations, setRecommendations] = useState<AlgorithmRecommendation[]>([]);
  const [algorithmsByCategory, setAlgorithmsByCategory] = useState<Record<string, Algorithm[]>>({});

  // Selection
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [selectedTaskType, setSelectedTaskType] = useState<TaskType | null>(null);
  const [selectedAlgorithm, setSelectedAlgorithm] = useState<Algorithm | null>(null);

  // Filters
  const [gpuOnly, setGpuOnly] = useState(false);

  // Dialogs
  const [showCreateExperimentDialog, setShowCreateExperimentDialog] = useState(false);
  const [showRecommendationDialog, setShowRecommendationDialog] = useState(false);

  // Polling ref
  const pollIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Load data from API
  const loadData = useCallback(async () => {
    try {
      setError(null);
      const [algos, exps] = await Promise.all([
        automlService.getAlgorithms(),
        automlService.listExperiments(),
      ]);

      // Convert service types to component types
      const convertedAlgos: Algorithm[] = algos.map((a) => ({
        ...a,
        category: a.category as AlgorithmCategory,
        taskTypes: a.taskTypes as TaskType[],
        hyperparameters: a.hyperparameters.map((h) => ({
          name: h.name,
          type: h.type,
          default: h.default,
          min: h.min,
          max: h.max,
          options: h.options,
        })),
      }));

      const convertedExps: AutoMLExperiment[] = exps.map((e) => ({
        id: e.id,
        name: e.name,
        datasetInfo: {
          name: e.datasetPath.split("/").pop() || "",
          nSamples: 0,
          nFeatures: 0,
          targetColumn: e.targetColumn,
          featureColumns: [],
          taskType: e.taskType as TaskType,
          hasMissing: false,
          hasCategorical: false,
        },
        taskType: e.taskType as TaskType,
        algorithmsToTry: e.algorithmsToTry,
        optimizationMetric: e.optimizationMetric,
        cvFolds: e.cvFolds,
        maxTimeMinutes: e.maxTimeMinutes,
        status: e.status,
        models: e.models.map((m) => ({
          ...m,
          scores: m.scores as ModelScore,
        })),
        bestModelId: e.bestModelId,
        createdAt: e.createdAt,
        completedAt: e.completedAt,
      }));

      setAlgorithms(convertedAlgos);
      setExperiments(convertedExps);
    } catch (err) {
      console.error("Error loading AutoML data:", err);
      setError(err instanceof Error ? err.message : "Failed to load data");
      // Use mock data as fallback
      setAlgorithms(mockAlgorithms);
      setExperiments(mockExperiments);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    loadData();
  }, [loadData]);

  // Polling for running experiments
  useEffect(() => {
    const hasRunningExperiments = experiments.some((e) => e.status === "running");

    if (hasRunningExperiments) {
      pollIntervalRef.current = setInterval(() => {
        loadData();
      }, POLL_INTERVAL);
    } else if (pollIntervalRef.current) {
      clearInterval(pollIntervalRef.current);
      pollIntervalRef.current = null;
    }

    return () => {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current);
      }
    };
  }, [experiments, loadData]);

  // Group algorithms by category
  useEffect(() => {
    const byCategory: Record<string, Algorithm[]> = {};
    for (const algo of algorithms) {
      if (!byCategory[algo.category]) {
        byCategory[algo.category] = [];
      }
      byCategory[algo.category].push(algo);
    }
    setAlgorithmsByCategory(byCategory);
  }, [algorithms]);

  const handleRefresh = async () => {
    setIsLoading(true);
    await loadData();
  };

  const handleGetRecommendations = () => {
    setShowRecommendationDialog(true);
  };

  const handleCreateExperiment = () => {
    setShowCreateExperimentDialog(true);
  };

  const handleDeleteExperiment = async (id: string) => {
    try {
      await automlService.deleteExperiment(id);
      setExperiments((prev) => prev.filter((e) => e.id !== id));
    } catch (err) {
      console.error("Error deleting experiment:", err);
      // Still remove locally
      setExperiments((prev) => prev.filter((e) => e.id !== id));
    }
  };

  const handleStopExperiment = async (id: string) => {
    try {
      await automlService.stopExperiment(id);
      setExperiments((prev) =>
        prev.map((e) => (e.id === id ? { ...e, status: "stopped" as const } : e))
      );
    } catch (err) {
      console.error("Error stopping experiment:", err);
      setExperiments((prev) =>
        prev.map((e) => (e.id === id ? { ...e, status: "stopped" as const } : e))
      );
    }
  };

  const filteredAlgorithms = algorithms.filter((algo) => {
    if (gpuOnly && !algo.gpuAccelerated) return false;
    if (selectedCategory && algo.category !== selectedCategory) return false;
    if (selectedTaskType && !algo.taskTypes.includes(selectedTaskType)) return false;
    return true;
  });

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <AutoMLBreadcrumb
        algorithmCount={algorithms.length}
        experimentCount={experiments.length}
        onNewExperiment={handleCreateExperiment}
        onGetRecommendations={handleGetRecommendations}
        onRefresh={handleRefresh}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex flex-1 flex-col overflow-hidden">
          {/* Tabs */}
          <div className="flex border-b border-border bg-card">
            <TabButton
              active={activeTab === "algorithms"}
              onClick={() => setActiveTab("algorithms")}
              icon={<Cpu className="h-4 w-4" />}
              label="Algorithms"
              badge={algorithms.length}
            />
            <TabButton
              active={activeTab === "experiments"}
              onClick={() => setActiveTab("experiments")}
              icon={<FlaskConical className="h-4 w-4" />}
              label="Experiments"
              badge={experiments.length > 0 ? experiments.length : undefined}
            />
            <TabButton
              active={activeTab === "recommendations"}
              onClick={() => setActiveTab("recommendations")}
              icon={<Sparkles className="h-4 w-4" />}
              label="Recommendations"
            />
          </div>

          {/* Content */}
          <div className="flex-1 overflow-hidden">
            {isLoading ? (
              <div className="flex h-full items-center justify-center">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
              </div>
            ) : (
              <>
                {activeTab === "algorithms" && (
                  <AlgorithmsTab
                    algorithms={filteredAlgorithms}
                    algorithmsByCategory={algorithmsByCategory}
                    selectedCategory={selectedCategory}
                    onSelectCategory={setSelectedCategory}
                    selectedAlgorithm={selectedAlgorithm}
                    onSelectAlgorithm={setSelectedAlgorithm}
                    gpuOnly={gpuOnly}
                    onGpuOnlyChange={setGpuOnly}
                  />
                )}
                {activeTab === "experiments" && (
                  <ExperimentsTab
                    experiments={experiments}
                    onDelete={handleDeleteExperiment}
                    onStop={handleStopExperiment}
                    onCreate={handleCreateExperiment}
                  />
                )}
                {activeTab === "recommendations" && (
                  <RecommendationsTab
                    recommendations={recommendations}
                    onGetRecommendations={handleGetRecommendations}
                    onSelectAlgorithm={(algo) => {
                      setSelectedAlgorithm(algo);
                      setActiveTab("algorithms");
                    }}
                  />
                )}
              </>
            )}
          </div>
        </div>

        {/* Side panel */}
        <div className="flex w-80 flex-col border-l border-border bg-card">
          <SidePanel
            algorithms={algorithms}
            experiments={experiments}
            selectedAlgorithm={selectedAlgorithm}
            selectedTaskType={selectedTaskType}
            onSelectTaskType={setSelectedTaskType}
            onCreateExperiment={handleCreateExperiment}
            onGetRecommendations={handleGetRecommendations}
            onRefresh={handleRefresh}
          />
        </div>
      </div>

      {/* Create Experiment Dialog */}
      <CreateExperimentDialog
        open={showCreateExperimentDialog}
        onOpenChange={setShowCreateExperimentDialog}
        algorithms={algorithms}
        onSubmit={async (data) => {
          try {
            const newExp = await automlService.createExperiment({
              name: data.name,
              datasetPath: data.datasetPath,
              targetColumn: data.targetColumn,
              taskType: data.taskType,
              algorithms: data.algorithms,
              maxTimeMinutes: data.maxTimeMinutes,
            });

            const convertedExp: AutoMLExperiment = {
              id: newExp.id,
              name: newExp.name,
              datasetInfo: {
                name: newExp.datasetPath.split("/").pop() || "",
                nSamples: 0,
                nFeatures: 0,
                targetColumn: newExp.targetColumn,
                featureColumns: [],
                taskType: newExp.taskType as TaskType,
                hasMissing: false,
                hasCategorical: false,
              },
              taskType: newExp.taskType as TaskType,
              algorithmsToTry: newExp.algorithmsToTry,
              optimizationMetric: newExp.optimizationMetric,
              cvFolds: newExp.cvFolds,
              maxTimeMinutes: newExp.maxTimeMinutes,
              status: newExp.status,
              models: [],
              createdAt: newExp.createdAt,
            };

            setExperiments((prev) => [convertedExp, ...prev]);
            setShowCreateExperimentDialog(false);
            setActiveTab("experiments");
          } catch (err) {
            console.error("Error creating experiment:", err);
            // Fallback to local creation
            const newExperiment: AutoMLExperiment = {
              id: `exp${Date.now()}`,
              name: data.name,
              datasetInfo: {
                name: data.datasetPath.split("/").pop() || "",
                nSamples: 0,
                nFeatures: 0,
                targetColumn: data.targetColumn,
                featureColumns: [],
                taskType: data.taskType,
                hasMissing: false,
                hasCategorical: false,
              },
              taskType: data.taskType,
              algorithmsToTry: data.algorithms,
              optimizationMetric: "f1",
              cvFolds: 5,
              maxTimeMinutes: data.maxTimeMinutes,
              status: "running",
              models: [],
              createdAt: new Date(),
            };
            setExperiments((prev) => [newExperiment, ...prev]);
            setShowCreateExperimentDialog(false);
            setActiveTab("experiments");
          }
        }}
      />

      {/* Recommendation Dialog */}
      <RecommendationDialog
        open={showRecommendationDialog}
        onOpenChange={setShowRecommendationDialog}
        onSubmit={async (params) => {
          try {
            const recs = await automlService.getRecommendations({
              taskType: params.taskType,
              nSamples: params.nSamples,
              nFeatures: params.nFeatures,
              hasCategorical: params.hasCategorical,
              hasMissing: params.hasMissing,
              needInterpretability: params.needInterpretability,
              needSpeed: params.needSpeed,
              hasGpu: params.hasGpu,
            });

            const convertedRecs: AlgorithmRecommendation[] = recs.map((r) => ({
              algorithm: {
                ...r.algorithm,
                category: r.algorithm.category as AlgorithmCategory,
                taskTypes: r.algorithm.taskTypes as TaskType[],
                hyperparameters: r.algorithm.hyperparameters.map((h) => ({
                  name: h.name,
                  type: h.type,
                  default: h.default,
                  min: h.min,
                  max: h.max,
                  options: h.options,
                })),
              },
              score: r.score,
              reasons: r.reasons,
            }));

            setRecommendations(convertedRecs);
            setShowRecommendationDialog(false);
            setActiveTab("recommendations");
          } catch (err) {
            console.error("Error getting recommendations:", err);
            // Fallback to mock recommendations
            const recs: AlgorithmRecommendation[] = algorithms
              .filter((a) => a.taskTypes.includes(params.taskType))
              .slice(0, 5)
              .map((algo, idx) => ({
                algorithm: algo,
                score: 95 - idx * 10,
                reasons: [
                  `Best for ${params.taskType} with ${params.nSamples} samples`,
                  algo.gpuAccelerated ? "GPU acceleration available" : "CPU optimized",
                  `Handles ${params.nFeatures} features efficiently`,
                ],
              }));
            setRecommendations(recs);
            setShowRecommendationDialog(false);
            setActiveTab("recommendations");
          }
        }}
      />
    </div>
  );
};

// =============================================================================
// TAB BUTTON
// =============================================================================

interface TabButtonProps {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  badge?: number;
}

const TabButton = ({ active, onClick, icon, label, badge }: TabButtonProps) => (
  <button
    onClick={onClick}
    className={cn(
      "flex items-center gap-2 border-b-2 px-4 py-3 text-sm transition-colors",
      active
        ? "border-primary text-primary"
        : "border-transparent text-muted-foreground hover:text-foreground"
    )}
  >
    {icon}
    <span>{label}</span>
    {badge !== undefined && (
      <span
        className={cn(
          "rounded-full px-2 py-0.5 text-xs",
          active ? "bg-primary/15 text-primary" : "bg-muted text-muted-foreground"
        )}
      >
        {badge}
      </span>
    )}
  </button>
);

// =============================================================================
// ALGORITHMS TAB
// =============================================================================

interface AlgorithmsTabProps {
  algorithms: Algorithm[];
  algorithmsByCategory: Record<string, Algorithm[]>;
  selectedCategory: string | null;
  onSelectCategory: (category: string | null) => void;
  selectedAlgorithm: Algorithm | null;
  onSelectAlgorithm: (algorithm: Algorithm) => void;
  gpuOnly: boolean;
  onGpuOnlyChange: (value: boolean) => void;
}

const AlgorithmsTab = ({
  algorithms,
  algorithmsByCategory,
  selectedCategory,
  onSelectCategory,
  selectedAlgorithm,
  onSelectAlgorithm,
  gpuOnly,
  onGpuOnlyChange,
}: AlgorithmsTabProps) => {
  const getCategoryIcon = (category: string) => {
    const icons: Record<string, React.ReactNode> = {
      linear: <TrendingUp className="h-4 w-4" />,
      tree_based: <GitBranch className="h-4 w-4" />,
      ensemble: <Layers className="h-4 w-4" />,
      neural_network: <Brain className="h-4 w-4" />,
      svm: <Divide className="h-4 w-4" />,
      neighbors: <Users className="h-4 w-4" />,
      clustering: <Hexagon className="h-4 w-4" />,
      bayesian: <PieChart className="h-4 w-4" />,
      dimensionality: <Minimize2 className="h-4 w-4" />,
      boosting: <Rocket className="h-4 w-4" />,
      deep_learning: <Cpu className="h-4 w-4" />,
      transformer: <Sparkles className="h-4 w-4" />,
    };
    return icons[category] || <Box className="h-4 w-4" />;
  };

  const formatCategory = (category: string) => {
    return category
      .split("_")
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(" ");
  };

  const totalAlgorithms = Object.values(algorithmsByCategory).reduce(
    (sum, arr) => sum + arr.length,
    0
  );

  return (
    <div className="flex h-full">
      {/* Category list */}
      <div className="w-52 border-r border-border/50 overflow-auto">
        <div className="p-3">
          <div className="flex items-center gap-2">
            <Checkbox
              checked={gpuOnly}
              onCheckedChange={(checked) => onGpuOnlyChange(checked === true)}
            />
            <span className="text-xs">GPU Only</span>
          </div>
        </div>

        <div className="px-2 space-y-0.5">
          <button
            onClick={() => onSelectCategory(null)}
            className={cn(
              "flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors",
              selectedCategory === null
                ? "bg-primary/10 text-primary"
                : "hover:bg-muted"
            )}
          >
            <Box className="h-4 w-4" />
            <span className="flex-1 text-left">All Categories</span>
            <span className="rounded-full bg-muted px-2 py-0.5 text-xs">
              {totalAlgorithms}
            </span>
          </button>

          <div className="my-2 border-t border-border" />

          {Object.entries(algorithmsByCategory).map(([category, algos]) => (
            <button
              key={category}
              onClick={() => onSelectCategory(category)}
              className={cn(
                "flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors",
                selectedCategory === category
                  ? "bg-primary/10 text-primary font-medium"
                  : "hover:bg-muted"
              )}
            >
              {getCategoryIcon(category)}
              <span className="flex-1 text-left">{formatCategory(category)}</span>
              <span className="rounded-full bg-muted px-2 py-0.5 text-xs">
                {algos.length}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Algorithm list */}
      <div className="flex-1 overflow-auto p-4">
        <div className="space-y-2">
          {algorithms.map((algo) => (
            <AlgorithmCard
              key={algo.id}
              algorithm={algo}
              isSelected={selectedAlgorithm?.id === algo.id}
              onClick={() => onSelectAlgorithm(algo)}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// ALGORITHM CARD
// =============================================================================

interface AlgorithmCardProps {
  algorithm: Algorithm;
  isSelected: boolean;
  onClick: () => void;
}

const AlgorithmCard = ({ algorithm, isSelected, onClick }: AlgorithmCardProps) => (
  <div
    onClick={onClick}
    className={cn(
      "cursor-pointer rounded-lg border bg-card p-3 transition-all",
      isSelected ? "border-primary border-2 shadow-sm" : "border-border hover:border-primary/50"
    )}
  >
    <div className="flex items-start justify-between">
      <span className="font-semibold text-sm">{algorithm.name}</span>
      <div className="flex items-center gap-2">
        {algorithm.gpuAccelerated && (
          <span className="flex items-center gap-1 rounded bg-green-500/15 px-1.5 py-0.5 text-xs text-green-600">
            <Zap className="h-3 w-3" />
            GPU
          </span>
        )}
        <span className="rounded bg-primary/10 px-1.5 py-0.5 text-xs text-primary">
          {algorithm.library}
        </span>
      </div>
    </div>
    <p className="mt-1.5 text-xs text-muted-foreground line-clamp-2">
      {algorithm.description}
    </p>
    <div className="mt-2 flex flex-wrap gap-1">
      {algorithm.taskTypes.map((type) => (
        <span
          key={type}
          className="rounded bg-muted px-1.5 py-0.5 text-xs text-muted-foreground"
        >
          {type}
        </span>
      ))}
    </div>
  </div>
);

// =============================================================================
// EXPERIMENTS TAB
// =============================================================================

interface ExperimentsTabProps {
  experiments: AutoMLExperiment[];
  onDelete: (id: string) => void;
  onStop: (id: string) => void;
  onCreate: () => void;
}

const ExperimentsTab = ({ experiments, onDelete, onStop, onCreate }: ExperimentsTabProps) => {
  if (experiments.length === 0) {
    return (
      <div className="flex h-full flex-col items-center justify-center">
        <FlaskConical className="h-16 w-16 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">No experiments yet</p>
        <Button className="mt-4" onClick={onCreate}>
          <Plus className="mr-2 h-4 w-4" />
          Create Experiment
        </Button>
      </div>
    );
  }

  return (
    <div className="overflow-auto p-4">
      <div className="space-y-3">
        {experiments.map((exp) => (
          <ExperimentCard
            key={exp.id}
            experiment={exp}
            onDelete={() => onDelete(exp.id)}
            onStop={exp.status === "running" ? () => onStop(exp.id) : undefined}
          />
        ))}
      </div>
    </div>
  );
};

// =============================================================================
// EXPERIMENT CARD
// =============================================================================

interface ExperimentCardProps {
  experiment: AutoMLExperiment;
  onDelete: () => void;
  onStop?: () => void;
}

const ExperimentCard = ({ experiment, onDelete, onStop }: ExperimentCardProps) => {
  const [expanded, setExpanded] = useState(false);
  const bestModel = getBestModel(experiment);

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      running: "text-blue-500 bg-blue-500/15",
      completed: "text-green-500 bg-green-500/15",
      failed: "text-red-500 bg-red-500/15",
      stopped: "text-orange-500 bg-orange-500/15",
      pending: "text-muted-foreground bg-muted",
    };
    return colors[status] || colors.pending;
  };

  const getStatusIcon = (status: string) => {
    const icons: Record<string, React.ReactNode> = {
      running: <Loader2 className="h-3 w-3 animate-spin" />,
      completed: <CheckCircle className="h-3 w-3" />,
      failed: <XCircle className="h-3 w-3" />,
      stopped: <Square className="h-3 w-3" />,
      pending: <Clock className="h-3 w-3" />,
    };
    return icons[status] || icons.pending;
  };

  const getScoreMap = (taskType: string, scores: ModelScore) => {
    if (taskType === "regression") return getRegressionScores(scores);
    if (taskType === "clustering") return getClusteringScores(scores);
    return getClassificationScores(scores);
  };

  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="font-semibold">{experiment.name}</h3>
        </div>
        <div className="flex items-center gap-2">
          <span
            className={cn(
              "flex items-center gap-1 rounded-full px-2 py-1 text-xs font-medium",
              getStatusColor(experiment.status)
            )}
          >
            {getStatusIcon(experiment.status)}
            {experiment.status.toUpperCase()}
          </span>
          {onStop && (
            <Button size="sm" variant="ghost" onClick={onStop} className="h-8 w-8 p-0">
              <Square className="h-4 w-4 text-orange-500" />
            </Button>
          )}
          <Button size="sm" variant="ghost" onClick={onDelete} className="h-8 w-8 p-0">
            <Trash2 className="h-4 w-4 text-destructive" />
          </Button>
        </div>
      </div>

      {/* Dataset info */}
      <div className="mt-3 flex flex-wrap gap-2">
        <span className="flex items-center gap-1 rounded bg-muted px-2 py-1 text-xs">
          <Database className="h-3 w-3" />
          {experiment.datasetInfo.nSamples} samples
        </span>
        <span className="flex items-center gap-1 rounded bg-muted px-2 py-1 text-xs">
          <Columns className="h-3 w-3" />
          {experiment.datasetInfo.nFeatures} features
        </span>
        <span className="flex items-center gap-1 rounded bg-muted px-2 py-1 text-xs">
          <Target className="h-3 w-3" />
          {experiment.taskType}
        </span>
      </div>

      {/* Progress */}
      {(experiment.status === "running" || experiment.status === "completed") && (
        <div className="mt-3">
          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span>
              Models trained: {experiment.models.length}/{experiment.algorithmsToTry.length}
            </span>
            {bestModel && (
              <span className="text-primary font-medium">Best: {bestModel.algorithmName}</span>
            )}
          </div>
          <div className="mt-1 h-1.5 rounded-full bg-muted overflow-hidden">
            <div
              className="h-full bg-primary transition-all"
              style={{
                width: `${
                  experiment.algorithmsToTry.length > 0
                    ? (experiment.models.length / experiment.algorithmsToTry.length) * 100
                    : 0
                }%`,
              }}
            />
          </div>
        </div>
      )}

      {/* Best model scores */}
      {bestModel && (
        <div className="mt-3 flex flex-wrap gap-2">
          {Object.entries(getScoreMap(experiment.taskType, bestModel.scores))
            .filter(([, value]) => value !== undefined)
            .slice(0, 4)
            .map(([name, value]) => {
              const score = value || 0;
              const color =
                score > 0.8 ? "text-green-600 bg-green-500/10 border-green-500/30" :
                score > 0.6 ? "text-orange-600 bg-orange-500/10 border-orange-500/30" :
                "text-red-600 bg-red-500/10 border-red-500/30";
              return (
                <span
                  key={name}
                  className={cn("flex items-center gap-1 rounded border px-2 py-1 text-xs", color)}
                >
                  <span>{name}</span>
                  <span className="font-semibold">{score.toFixed(3)}</span>
                </span>
              );
            })}
        </div>
      )}

      {/* Recommendations */}
      {bestModel && bestModel.recommendations.length > 0 && (
        <div className="mt-3">
          <button
            onClick={() => setExpanded(!expanded)}
            className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
          >
            {expanded ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
            Recommendations ({bestModel.recommendations.length})
          </button>
          {expanded && (
            <div className="mt-2 space-y-1">
              {bestModel.recommendations.map((rec, idx) => (
                <div key={idx} className="flex items-start gap-2 text-xs">
                  <Lightbulb className="h-3.5 w-3.5 text-amber-500 mt-0.5" />
                  <span>{rec}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

// =============================================================================
// RECOMMENDATIONS TAB
// =============================================================================

interface RecommendationsTabProps {
  recommendations: AlgorithmRecommendation[];
  onGetRecommendations: () => void;
  onSelectAlgorithm: (algorithm: Algorithm) => void;
}

const RecommendationsTab = ({
  recommendations,
  onGetRecommendations,
  onSelectAlgorithm,
}: RecommendationsTabProps) => {
  if (recommendations.length === 0) {
    return (
      <div className="flex h-full flex-col items-center justify-center">
        <Sparkles className="h-16 w-16 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">Get AI-powered recommendations</p>
        <p className="mt-1 text-sm text-muted-foreground">Based on your data characteristics</p>
        <Button className="mt-4" onClick={onGetRecommendations}>
          <Sparkles className="mr-2 h-4 w-4" />
          Get Recommendations
        </Button>
      </div>
    );
  }

  return (
    <div className="overflow-auto p-4">
      <div className="space-y-3">
        {recommendations.map((rec, idx) => (
          <RecommendationCard
            key={rec.algorithm.id}
            recommendation={rec}
            rank={idx + 1}
            onSelect={() => onSelectAlgorithm(rec.algorithm)}
          />
        ))}
      </div>
    </div>
  );
};

// =============================================================================
// RECOMMENDATION CARD
// =============================================================================

interface RecommendationCardProps {
  recommendation: AlgorithmRecommendation;
  rank: number;
  onSelect: () => void;
}

const RecommendationCard = ({ recommendation, rank, onSelect }: RecommendationCardProps) => {
  const scoreColor =
    recommendation.score > 80 ? "text-green-500" :
    recommendation.score > 60 ? "text-orange-500" :
    "text-red-500";

  return (
    <div
      onClick={onSelect}
      className={cn(
        "cursor-pointer rounded-lg border bg-card p-4 transition-all hover:border-primary/50",
        rank === 1 ? "border-amber-500 border-2" : "border-border"
      )}
    >
      <div className="flex items-start gap-3">
        {/* Rank badge */}
        <div
          className={cn(
            "flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold",
            rank === 1 ? "bg-amber-500 text-white" : "bg-muted text-muted-foreground"
          )}
        >
          #{rank}
        </div>

        <div className="flex-1">
          <div className="flex items-center justify-between">
            <span className="font-semibold">{recommendation.algorithm.name}</span>
            <span className={cn("font-bold", scoreColor)}>{recommendation.score}%</span>
          </div>

          <div className="mt-2 flex flex-wrap gap-2">
            {recommendation.algorithm.gpuAccelerated && (
              <span className="flex items-center gap-1 rounded bg-green-500/15 px-1.5 py-0.5 text-xs text-green-600">
                <Zap className="h-3 w-3" />
                GPU
              </span>
            )}
            <span className="rounded bg-primary/10 px-1.5 py-0.5 text-xs text-primary">
              {recommendation.algorithm.library}
            </span>
          </div>

          <div className="mt-3 space-y-1">
            {recommendation.reasons.map((reason, idx) => (
              <div key={idx} className="flex items-start gap-2 text-xs text-muted-foreground">
                <Check className="h-3 w-3 text-green-500 mt-0.5" />
                <span>{reason}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// SIDE PANEL
// =============================================================================

interface SidePanelProps {
  algorithms: Algorithm[];
  experiments: AutoMLExperiment[];
  selectedAlgorithm: Algorithm | null;
  selectedTaskType: TaskType | null;
  onSelectTaskType: (type: TaskType | null) => void;
  onCreateExperiment: () => void;
  onGetRecommendations: () => void;
  onRefresh: () => void;
}

const SidePanel = ({
  algorithms,
  experiments,
  selectedAlgorithm,
  selectedTaskType,
  onSelectTaskType,
  onCreateExperiment,
  onGetRecommendations,
  onRefresh,
}: SidePanelProps) => {
  const gpuCount = algorithms.filter((a) => a.gpuAccelerated).length;
  const completedCount = experiments.filter((e) => e.status === "completed").length;

  const taskTypes: { type: TaskType | null; label: string }[] = [
    { type: null, label: "All" },
    { type: "classification", label: "Classification" },
    { type: "regression", label: "Regression" },
    { type: "clustering", label: "Clustering" },
    { type: "anomaly_detection", label: "Anomaly" },
    { type: "time_series", label: "Time Series" },
  ];

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-2 border-b border-border p-4">
        <Brain className="h-5 w-5 text-primary" />
        <span className="font-semibold">AutoML</span>
      </div>

      {/* Quick Stats */}
      <div className="p-4 space-y-2">
        <h4 className="text-xs font-semibold text-muted-foreground uppercase">Quick Stats</h4>
        <div className="space-y-2">
          <StatRow icon={<Cpu className="h-3.5 w-3.5" />} label="Algorithms" value={algorithms.length} />
          <StatRow icon={<Zap className="h-3.5 w-3.5" />} label="GPU Accelerated" value={gpuCount} />
          <StatRow icon={<FlaskConical className="h-3.5 w-3.5" />} label="Experiments" value={experiments.length} />
          <StatRow icon={<CheckCircle className="h-3.5 w-3.5" />} label="Completed" value={completedCount} />
        </div>
      </div>

      <div className="border-t border-border" />

      {/* Actions */}
      <div className="p-4 space-y-2">
        <h4 className="text-xs font-semibold text-muted-foreground uppercase">Actions</h4>
        <ActionButton icon={<Plus className="h-4 w-4" />} label="New Experiment" onClick={onCreateExperiment} />
        <ActionButton icon={<Sparkles className="h-4 w-4" />} label="Get Recommendations" onClick={onGetRecommendations} />
        <ActionButton icon={<RefreshCw className="h-4 w-4" />} label="Refresh" onClick={onRefresh} />
      </div>

      <div className="border-t border-border" />

      {/* Algorithm Details or Empty State */}
      <div className="flex-1 overflow-auto">
        {selectedAlgorithm ? (
          <AlgorithmDetails algorithm={selectedAlgorithm} />
        ) : (
          <div className="flex flex-col items-center justify-center h-full text-center p-4">
            <MousePointerClick className="h-8 w-8 text-muted-foreground/50" />
            <p className="mt-2 text-sm text-muted-foreground">Select an algorithm</p>
          </div>
        )}
      </div>

      {/* Task Type Filter */}
      <div className="border-t border-border p-4">
        <h4 className="text-xs font-semibold text-muted-foreground uppercase mb-2">Filter by Task</h4>
        <div className="flex flex-wrap gap-1.5">
          {taskTypes.map((t) => (
            <button
              key={t.label}
              onClick={() => onSelectTaskType(t.type)}
              className={cn(
                "rounded-full px-2.5 py-1 text-xs transition-colors",
                selectedTaskType === t.type
                  ? "bg-primary/20 text-primary"
                  : "bg-muted text-muted-foreground hover:bg-muted/80"
              )}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// STAT ROW
// =============================================================================

interface StatRowProps {
  icon: React.ReactNode;
  label: string;
  value: number | string;
}

const StatRow = ({ icon, label, value }: StatRowProps) => (
  <div className="flex items-center text-sm">
    <span className="text-muted-foreground">{icon}</span>
    <span className="ml-2 flex-1 text-muted-foreground">{label}</span>
    <span className="font-semibold">{value}</span>
  </div>
);

// =============================================================================
// ACTION BUTTON
// =============================================================================

interface ActionButtonProps {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
}

const ActionButton = ({ icon, label, onClick }: ActionButtonProps) => (
  <button
    onClick={onClick}
    className="flex w-full items-center gap-2 rounded-md border border-border px-3 py-2 text-sm transition-colors hover:bg-muted"
  >
    <span className="text-primary">{icon}</span>
    <span>{label}</span>
  </button>
);

// =============================================================================
// ALGORITHM DETAILS
// =============================================================================

interface AlgorithmDetailsProps {
  algorithm: Algorithm;
}

const AlgorithmDetails = ({ algorithm }: AlgorithmDetailsProps) => (
  <div className="p-4 space-y-4">
    <div className="flex items-center gap-2">
      {algorithm.gpuAccelerated && (
        <span className="flex items-center gap-1 rounded bg-green-500/15 px-1.5 py-0.5 text-xs text-green-600">
          <Zap className="h-3 w-3" />
          GPU
        </span>
      )}
      <span className="rounded bg-primary/10 px-1.5 py-0.5 text-xs text-primary">
        {algorithm.library}
      </span>
    </div>

    <div>
      <h3 className="font-semibold">{algorithm.name}</h3>
      <p className="mt-1 text-xs text-muted-foreground">{algorithm.description}</p>
    </div>

    <div>
      <p className="text-xs text-muted-foreground">Complexity: {algorithm.complexity}</p>
    </div>

    {/* Pros */}
    <div>
      <h4 className="text-xs font-semibold text-green-600 mb-1">Pros</h4>
      <div className="space-y-1">
        {algorithm.pros.map((pro, idx) => (
          <div key={idx} className="flex items-start gap-1.5 text-xs">
            <Check className="h-3 w-3 text-green-500 mt-0.5" />
            <span>{pro}</span>
          </div>
        ))}
      </div>
    </div>

    {/* Cons */}
    <div>
      <h4 className="text-xs font-semibold text-orange-600 mb-1">Cons</h4>
      <div className="space-y-1">
        {algorithm.cons.map((con, idx) => (
          <div key={idx} className="flex items-start gap-1.5 text-xs">
            <X className="h-3 w-3 text-orange-500 mt-0.5" />
            <span>{con}</span>
          </div>
        ))}
      </div>
    </div>

    {/* Hyperparameters */}
    <div>
      <h4 className="text-xs font-semibold mb-1">Hyperparameters</h4>
      <div className="space-y-1">
        {algorithm.hyperparameters.map((hp, idx) => (
          <div key={idx} className="flex items-center gap-2">
            <code className="rounded bg-muted px-1.5 py-0.5 text-xs">{hp.name}</code>
            <span className="text-xs text-muted-foreground">{hp.type}</span>
          </div>
        ))}
      </div>
    </div>
  </div>
);

// =============================================================================
// CREATE EXPERIMENT DIALOG
// =============================================================================

interface CreateExperimentDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  algorithms: Algorithm[];
  onSubmit: (data: {
    name: string;
    datasetPath: string;
    targetColumn: string;
    taskType: TaskType;
    algorithms: string[];
    maxTimeMinutes: number;
  }) => void;
}

interface FileInfo {
  name: string;
  path: string;
  file_type: "file" | "directory";
  size: number;
  modified_at: string;
  mime_type?: string;
}

const CreateExperimentDialog = ({
  open,
  onOpenChange,
  algorithms,
  onSubmit,
}: CreateExperimentDialogProps) => {
  const [name, setName] = useState("");
  const [datasetPath, setDatasetPath] = useState("");
  const [targetColumn, setTargetColumn] = useState("");
  const [taskType, setTaskType] = useState<TaskType>("classification");
  const [selectedAlgorithms, setSelectedAlgorithms] = useState<string[]>([]);
  const [maxTimeMinutes, setMaxTimeMinutes] = useState(30);

  // File browser state
  const [showFileBrowser, setShowFileBrowser] = useState(false);
  const [currentPath, setCurrentPath] = useState("");
  const [files, setFiles] = useState<FileInfo[]>([]);
  const [isLoadingFiles, setIsLoadingFiles] = useState(false);

  // Load files from API
  const loadFiles = async (path: string) => {
    setIsLoadingFiles(true);
    try {
      const response = await fetch(
        `http://${window.location.hostname}:8000/api/files${path ? `?path=${encodeURIComponent(path)}` : ""}`
      );
      const data = await response.json();
      setFiles(data.files || []);
      setCurrentPath(data.path || "");
    } catch (error) {
      console.error("Failed to load files:", error);
      setFiles([]);
    } finally {
      setIsLoadingFiles(false);
    }
  };

  // Handle file browser open
  const handleOpenFileBrowser = () => {
    setShowFileBrowser(true);
    loadFiles("");
  };

  // Handle directory navigation
  const handleNavigate = (file: FileInfo) => {
    if (file.file_type === "directory") {
      loadFiles(file.path);
    } else if (file.name.endsWith(".csv") || file.name.endsWith(".parquet")) {
      setDatasetPath(file.path);
      setShowFileBrowser(false);
    }
  };

  // Handle go up
  const handleGoUp = () => {
    const parentPath = currentPath.split("/").slice(0, -1).join("/");
    loadFiles(parentPath);
  };

  const handleSubmit = () => {
    if (!name || !datasetPath || !targetColumn) return;
    onSubmit({
      name,
      datasetPath,
      targetColumn,
      taskType,
      algorithms: selectedAlgorithms.length > 0 ? selectedAlgorithms : algorithms.map((a) => a.name),
      maxTimeMinutes,
    });
    setName("");
    setDatasetPath("");
    setTargetColumn("");
    setSelectedAlgorithms([]);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Create Experiment</DialogTitle>
          <DialogDescription>Configure your AutoML experiment</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <Label>Experiment Name</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="My Experiment"
            />
          </div>

          <div>
            <Label>Dataset Path</Label>
            <div className="flex gap-2">
              <Input
                value={datasetPath}
                onChange={(e) => setDatasetPath(e.target.value)}
                placeholder="Select a dataset file..."
                className="flex-1"
              />
              <Button
                type="button"
                variant="outline"
                size="icon"
                onClick={handleOpenFileBrowser}
              >
                <FileSearch className="h-4 w-4" />
              </Button>
            </div>

            {/* File Browser */}
            {showFileBrowser && (
              <div className="mt-2 rounded-lg border border-border bg-background max-h-48 overflow-auto">
                {/* Path and back button */}
                <div className="sticky top-0 flex items-center gap-2 border-b border-border bg-muted/50 px-2 py-1.5">
                  {currentPath && (
                    <button
                      onClick={handleGoUp}
                      className="rounded p-1 hover:bg-muted"
                    >
                      <ChevronUp className="h-4 w-4" />
                    </button>
                  )}
                  <span className="text-xs text-muted-foreground truncate flex-1">
                    /{currentPath || ""}
                  </span>
                  <button
                    onClick={() => setShowFileBrowser(false)}
                    className="rounded p-1 hover:bg-muted"
                  >
                    <X className="h-3 w-3" />
                  </button>
                </div>

                {/* File list */}
                {isLoadingFiles ? (
                  <div className="flex items-center justify-center p-4">
                    <Loader2 className="h-4 w-4 animate-spin" />
                  </div>
                ) : files.length === 0 ? (
                  <div className="p-4 text-center text-xs text-muted-foreground">
                    No files found
                  </div>
                ) : (
                  <div className="divide-y divide-border">
                    {files.map((file) => (
                      <button
                        key={file.path}
                        onClick={() => handleNavigate(file)}
                        className={cn(
                          "flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-muted",
                          file.file_type === "directory" && "text-primary",
                          (file.name.endsWith(".csv") || file.name.endsWith(".parquet")) && "text-green-600"
                        )}
                      >
                        {file.file_type === "directory" ? (
                          <Database className="h-4 w-4" />
                        ) : (
                          <FileSearch className="h-4 w-4" />
                        )}
                        <span className="flex-1 truncate">{file.name}</span>
                        {file.file_type === "file" && (
                          <span className="text-xs text-muted-foreground">
                            {(file.size / 1024).toFixed(1)} KB
                          </span>
                        )}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          <div>
            <Label>Target Column</Label>
            <Input
              value={targetColumn}
              onChange={(e) => setTargetColumn(e.target.value)}
              placeholder="target"
            />
          </div>

          <div>
            <Label>Task Type</Label>
            <Select value={taskType} onValueChange={(v) => setTaskType(v as TaskType)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="classification">Classification</SelectItem>
                <SelectItem value="regression">Regression</SelectItem>
                <SelectItem value="clustering">Clustering</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <Label>Max Time (minutes)</Label>
            <Input
              type="number"
              value={maxTimeMinutes}
              onChange={(e) => setMaxTimeMinutes(parseInt(e.target.value) || 30)}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit}>Create</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

// =============================================================================
// RECOMMENDATION DIALOG
// =============================================================================

interface RecommendationDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (params: {
    taskType: TaskType;
    nSamples: number;
    nFeatures: number;
    hasCategorical: boolean;
    hasMissing: boolean;
    needInterpretability: boolean;
    needSpeed: boolean;
    hasGpu: boolean;
  }) => void;
}

const RecommendationDialog = ({
  open,
  onOpenChange,
  onSubmit,
}: RecommendationDialogProps) => {
  const [taskType, setTaskType] = useState<TaskType>("classification");
  const [nSamples, setNSamples] = useState(1000);
  const [nFeatures, setNFeatures] = useState(20);
  const [hasCategorical, setHasCategorical] = useState(false);
  const [hasMissing, setHasMissing] = useState(false);
  const [needInterpretability, setNeedInterpretability] = useState(false);
  const [needSpeed, setNeedSpeed] = useState(false);
  const [hasGpu, setHasGpu] = useState(true);

  const handleSubmit = () => {
    onSubmit({
      taskType,
      nSamples,
      nFeatures,
      hasCategorical,
      hasMissing,
      needInterpretability,
      needSpeed,
      hasGpu,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Get Recommendations</DialogTitle>
          <DialogDescription>Describe your data to get AI-powered algorithm recommendations</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <Label>Task Type</Label>
            <Select value={taskType} onValueChange={(v) => setTaskType(v as TaskType)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="classification">Classification</SelectItem>
                <SelectItem value="regression">Regression</SelectItem>
                <SelectItem value="clustering">Clustering</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label>Number of Samples</Label>
              <Input
                type="number"
                value={nSamples}
                onChange={(e) => setNSamples(parseInt(e.target.value) || 0)}
              />
            </div>
            <div>
              <Label>Number of Features</Label>
              <Input
                type="number"
                value={nFeatures}
                onChange={(e) => setNFeatures(parseInt(e.target.value) || 0)}
              />
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Checkbox
                checked={hasCategorical}
                onCheckedChange={(c) => setHasCategorical(c === true)}
              />
              <span className="text-sm">Has categorical features</span>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                checked={hasMissing}
                onCheckedChange={(c) => setHasMissing(c === true)}
              />
              <span className="text-sm">Has missing values</span>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                checked={needInterpretability}
                onCheckedChange={(c) => setNeedInterpretability(c === true)}
              />
              <span className="text-sm">Need interpretability</span>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                checked={needSpeed}
                onCheckedChange={(c) => setNeedSpeed(c === true)}
              />
              <span className="text-sm">Need fast predictions</span>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                checked={hasGpu}
                onCheckedChange={(c) => setHasGpu(c === true)}
              />
              <span className="text-sm">GPU available</span>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit}>
            <Sparkles className="mr-2 h-4 w-4" />
            Get Recommendations
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
