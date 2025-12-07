import { useState, useEffect, useCallback, useRef } from "react";
import { useNavigate } from "react-router-dom";
import {
  Play,
  Maximize2,
  LayoutGrid,
  ChevronDown,
  FileCode,
  RefreshCw,
  Zap,
  X,
  Loader2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { HomeBreadcrumb } from "./HomeBreadcrumb";
import { gpuService, GPUSystemStatus } from "@/services/gpuService";
import { notebookService, Notebook as ServiceNotebook } from "@/services/notebookService";
import { kernelService, Kernel } from "@/services/kernelService";

interface GPUStatus {
  name: string;
  utilizationGpu: number;
  memoryUsedGB: number;
  memoryTotalGB: number;
  temperature: number;
  cudaVersion: string;
  driverVersion: string;
}

interface Notebook {
  id: string;
  name: string;
  cells: number;
  updatedAt: Date;
}

// Mock data for fallback
const mockGpuStatus: GPUStatus = {
  name: "NVIDIA RTX 4090",
  utilizationGpu: 45,
  memoryUsedGB: 12.5,
  memoryTotalGB: 24,
  temperature: 62,
  cudaVersion: "12.1",
  driverVersion: "535.104",
};

const mockNotebooks: Notebook[] = [
  { id: "1", name: "Image Classification", cells: 12, updatedAt: new Date(Date.now() - 3600000) },
  { id: "2", name: "Data Analysis", cells: 8, updatedAt: new Date(Date.now() - 86400000) },
  { id: "3", name: "NLP Training", cells: 15, updatedAt: new Date(Date.now() - 172800000) },
];

export const Dashboard = () => {
  const navigate = useNavigate();
  const [gpuStatus, setGpuStatus] = useState<GPUStatus | null>(null);
  const [notebooks, setNotebooks] = useState<Notebook[]>([]);
  const [kernels, setKernels] = useState<Kernel[]>([]);
  const [showWelcomeCard, setShowWelcomeCard] = useState(() => {
    // Check localStorage to see if user has dismissed the welcome card
    return localStorage.getItem("gpu-notebook-welcome-dismissed") !== "true";
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const stopGpuPollingRef = useRef<(() => void) | null>(null);

  // Convert service notebook to component notebook
  const convertNotebook = (n: ServiceNotebook): Notebook => ({
    id: n.id,
    name: n.name,
    cells: n.cells.length,
    updatedAt: n.updatedAt,
  });

  // Convert GPU system status to component GPU status
  const convertGpuStatus = (status: GPUSystemStatus): GPUStatus | null => {
    if (!status.hasGpu || !status.primaryGpu) return null;
    const gpu = status.primaryGpu;
    return {
      name: gpu.name,
      utilizationGpu: gpu.utilizationGpu,
      memoryUsedGB: gpu.memoryUsed / 1024, // Convert MB to GB
      memoryTotalGB: gpu.memoryTotal / 1024,
      temperature: gpu.temperature,
      cudaVersion: gpu.cudaVersion,
      driverVersion: gpu.driverVersion,
    };
  };

  // Load data from APIs
  const loadData = useCallback(async () => {
    try {
      setError(null);

      // Load notebooks and kernels in parallel
      const [notebookList, kernelList] = await Promise.all([
        notebookService.list(),
        kernelService.list(),
      ]);

      setNotebooks(notebookList.map(convertNotebook));
      setKernels(kernelList);
    } catch (err) {
      console.error("Error loading dashboard data:", err);
      setError(err instanceof Error ? err.message : "Failed to load data");
      // Use mock data as fallback
      setNotebooks(mockNotebooks);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    loadData();

    // Start GPU polling for real-time updates
    stopGpuPollingRef.current = gpuService.startPolling((status) => {
      const converted = convertGpuStatus(status);
      setGpuStatus(converted || mockGpuStatus);
    }, 3000);

    return () => {
      if (stopGpuPollingRef.current) {
        stopGpuPollingRef.current();
      }
    };
  }, [loadData]);

  const handleRefresh = async () => {
    setIsLoading(true);
    await loadData();
  };

  const handleOpenNotebook = (id: string) => {
    navigate(`/notebook/${id}`);
  };

  const activeKernelCount = kernels.filter(k => k.status !== "dead").length;

  if (isLoading && notebooks.length === 0) {
    return (
      <div className="flex flex-1 flex-col overflow-hidden">
        <HomeBreadcrumb
          notebookCount={0}
          kernelCount={0}
          onRefresh={handleRefresh}
        />
        <div className="flex-1 flex items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
            <p className="text-muted-foreground">Loading dashboard...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <HomeBreadcrumb
        notebookCount={notebooks.length}
        kernelCount={activeKernelCount}
        onRefresh={handleRefresh}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex-1 overflow-auto p-4">
          {/* Welcome Card */}
          {showWelcomeCard && (
            <WelcomeCard
              gpuStatus={gpuStatus}
              onClose={() => {
                setShowWelcomeCard(false);
                localStorage.setItem("gpu-notebook-welcome-dismissed", "true");
              }}
            />
          )}

          {/* Metrics Grid */}
          <div className="grid gap-4 grid-cols-2 lg:grid-cols-4 mt-4">
            <MetricCard
              title="GPU Utilization"
              code={["import torch", "# Check GPU availability", "device = torch.device('cuda')", "torch.cuda.get_device_name(0)"]}
              metric={gpuStatus ? `${gpuStatus.utilizationGpu}%` : "--"}
              isReady={gpuStatus !== null}
              taskCount={gpuStatus ? 1 : 0}
            />
            <MetricCard
              title="Memory Usage"
              code={["import torch", "allocated = torch.cuda.memory_", "  allocated() / 1e9"]}
              metric={gpuStatus ? `${gpuStatus.memoryUsedGB.toFixed(1)} GB` : "--"}
              isReady={gpuStatus !== null}
              taskCount={gpuStatus ? 1 : 0}
              subtitle={gpuStatus ? `of ${gpuStatus.memoryTotalGB.toFixed(0)} GB total` : undefined}
            />
            <MetricCard
              title="Active Kernels"
              code={["# IPython kernel status", "kernel.is_alive()"]}
              metric={`${activeKernelCount}`}
              isReady={true}
              taskCount={activeKernelCount}
              subtitle={activeKernelCount > 0 ? `${kernels.filter(k => k.status === "busy").length} busy` : "No active kernels"}
            />
            <MetricCard
              title="Notebooks"
              code={["# Recent notebooks", "notebooks = list_notebooks()"]}
              metric={`${notebooks.length}`}
              isReady={true}
              taskCount={notebooks.length}
              subtitle={notebooks.length > 0 ? `Last: ${notebooks[0].name}` : "No notebooks yet"}
            />
          </div>
        </div>

        {/* Side Panel */}
        <RecentNotebooksPanel
          notebooks={notebooks}
          gpuStatus={gpuStatus}
          onOpenNotebook={handleOpenNotebook}
          onRefresh={handleRefresh}
          isLoading={isLoading}
        />
      </div>
    </div>
  );
};

// =============================================================================
// WELCOME CARD
// =============================================================================

interface WelcomeCardProps {
  gpuStatus: GPUStatus | null;
  onClose: () => void;
}

const WelcomeCard = ({ gpuStatus, onClose }: WelcomeCardProps) => (
  <div className="rounded-lg border border-border bg-card overflow-hidden">
    {/* Header */}
    <div className="flex items-center justify-between bg-muted px-3 py-2">
      <code className="text-xs text-muted-foreground">%md</code>
      <button
        onClick={onClose}
        className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </div>

    {/* Content */}
    <div className="p-4">
      <h2 className="text-lg font-semibold">GPU Notebook - Quick Start</h2>
      <div className="mt-2 space-y-1 text-sm">
        <p>1. Create a new notebook or open existing</p>
        <p>2. Write Python code with GPU support</p>
        <p>3. Run cells with Shift+Enter</p>
      </div>

      <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
        <span className="text-xs text-muted-foreground">
          {gpuStatus
            ? `CUDA ${gpuStatus.cudaVersion} | Driver ${gpuStatus.driverVersion} | Python 3.11`
            : "Connecting to backend..."}
        </span>
        <span
          className={cn(
            "rounded px-2 py-0.5 text-xs font-medium",
            gpuStatus
              ? "bg-green-500/20 text-green-500"
              : "bg-amber-500/20 text-amber-500"
          )}
        >
          {gpuStatus ? "READY" : "CONNECTING"}
        </span>
      </div>
    </div>
  </div>
);

// =============================================================================
// METRIC CARD
// =============================================================================

interface MetricCardProps {
  title: string;
  code: string[];
  metric: string;
  isReady: boolean;
  taskCount?: number;
  subtitle?: string;
}

const MetricCard = ({ title, code, metric, isReady, taskCount, subtitle }: MetricCardProps) => {
  const renderCodeLine = (line: string, idx: number) => {
    if (line.startsWith("import") || line.startsWith("from")) {
      const parts = line.split(" ");
      return (
        <p key={idx} className="text-xs">
          <span className="text-purple-400">{parts[0]} </span>
          <span className="text-foreground">{parts.slice(1).join(" ")}</span>
        </p>
      );
    }
    if (line.startsWith("#")) {
      return (
        <p key={idx} className="text-xs text-muted-foreground">
          {line}
        </p>
      );
    }
    return (
      <p key={idx} className="text-xs text-foreground">
        {line}
      </p>
    );
  };

  return (
    <div className="rounded-lg border border-border bg-card overflow-hidden flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between bg-secondary/50 px-3 py-2 border-b border-border">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium truncate">{title}</span>
          <span
            className={cn(
              "rounded px-1.5 py-0.5 text-[10px] font-medium",
              isReady
                ? "bg-green-500/20 text-green-500"
                : "bg-amber-500/20 text-amber-500"
            )}
          >
            {isReady ? "READY" : "LOADING"}
          </span>
        </div>
        <div className="flex items-center gap-1 text-muted-foreground">
          <Play className="h-3.5 w-3.5" />
          <Maximize2 className="h-3.5 w-3.5" />
          <LayoutGrid className="h-3.5 w-3.5" />
        </div>
      </div>

      {/* Code block */}
      <div className="flex-1 bg-muted/50 p-3 font-mono">
        <p className="text-xs text-cyan-400 mb-1">%python</p>
        {code.map((line, idx) => renderCodeLine(line, idx))}
      </div>

      {/* Tasks */}
      {taskCount !== undefined && (
        <div className="flex items-center gap-1 px-3 py-2 border-t border-border">
          <ChevronDown className="h-4 w-4" />
          <span className="text-sm">Tasks ({taskCount})</span>
        </div>
      )}

      {/* Metric */}
      <div className="p-3">
        <p className="text-3xl font-bold">{metric}</p>
        {subtitle && (
          <p className="text-xs text-muted-foreground mt-1 truncate">{subtitle}</p>
        )}
      </div>
    </div>
  );
};

// =============================================================================
// RECENT NOTEBOOKS PANEL
// =============================================================================

interface RecentNotebooksPanelProps {
  notebooks: Notebook[];
  gpuStatus: GPUStatus | null;
  onOpenNotebook: (id: string) => void;
  onRefresh: () => void;
  isLoading?: boolean;
}

const RecentNotebooksPanel = ({
  notebooks,
  gpuStatus,
  onOpenNotebook,
  onRefresh,
  isLoading = false,
}: RecentNotebooksPanelProps) => {
  const formatDate = (date: Date) => {
    const diff = Date.now() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;
    return date.toLocaleDateString();
  };

  return (
    <div className="w-72 border-l border-border bg-card flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border p-3">
        <span className="font-semibold text-sm">Recent Notebooks</span>
        <button
          onClick={onRefresh}
          className="text-muted-foreground hover:text-foreground transition-colors"
          disabled={isLoading}
        >
          {isLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <RefreshCw className="h-4 w-4" />
          )}
        </button>
      </div>

      {/* Notebooks list */}
      <div className="flex-1 overflow-auto p-3">
        {notebooks.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-center">
            <FileCode className="h-8 w-8 text-muted-foreground" />
            <p className="mt-2 text-sm text-muted-foreground">No notebooks yet</p>
          </div>
        ) : (
          <div className="space-y-2">
            {notebooks.slice(0, 5).map((notebook) => (
              <button
                key={notebook.id}
                onClick={() => onOpenNotebook(notebook.id)}
                className="w-full rounded-lg border border-border p-3 text-left transition-colors hover:border-primary/30 hover:bg-primary/5"
              >
                <div className="flex items-start gap-2">
                  <FileCode className="h-4 w-4 text-primary mt-0.5" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{notebook.name}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                      {notebook.cells} cells
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {formatDate(notebook.updatedAt)}
                    </p>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* GPU Status */}
      <div className="border-t border-border p-3">
        <div className="rounded-lg border-2 border-primary/30 bg-primary/5 p-3">
          <div className="flex items-start gap-2">
            <Zap className="h-4 w-4 text-primary mt-0.5" />
            <div className="flex-1">
              <p className="text-sm font-medium">GPU Status</p>
              <div className="mt-2 space-y-1 text-xs">
                {gpuStatus ? (
                  <>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">{gpuStatus.name}</span>
                      <span className="text-green-500">{gpuStatus.utilizationGpu}%</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Memory</span>
                      <span>
                        {gpuStatus.memoryUsedGB.toFixed(0)}GB / {gpuStatus.memoryTotalGB.toFixed(0)}GB
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Temp</span>
                      <span
                        className={
                          gpuStatus.temperature < 70
                            ? "text-green-500"
                            : "text-amber-500"
                        }
                      >
                        {gpuStatus.temperature}°C
                      </span>
                    </div>
                  </>
                ) : (
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Status</span>
                    <span className="text-amber-500">Connecting...</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
