import { useState, useEffect } from "react";
import { Activity, ChevronDown, HelpCircle, Check, Cpu, Thermometer, HardDrive } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import { GPUStatus } from "@/services/gpuService";
import { useGPU } from "@/contexts/GPUContext";

interface Kernel {
  id: string;
  name: string;
  status: "idle" | "busy" | "starting" | "error" | "dead";
}

interface AppHeaderProps {
  title?: string;
  actions?: React.ReactNode;
  hideGpuStatus?: boolean;
}

export const AppHeader = ({ title, actions, hideGpuStatus = false }: AppHeaderProps) => {
  const { gpus, hasGpu: gpuAvailable } = useGPU();
  const [kernels, setKernels] = useState<Kernel[]>([]);
  const [selectedKernel, setSelectedKernel] = useState<Kernel | null>(null);

  useEffect(() => {
    // Simulated kernels load
    const loadKernels = async () => {
      // TODO: Replace with actual API call
      await new Promise((resolve) => setTimeout(resolve, 300));
      const mockKernels: Kernel[] = [
        { id: "1", name: "Python 3.10", status: "idle" },
        { id: "2", name: "Python 3.11", status: "busy" },
      ];
      setKernels(mockKernels);
      if (mockKernels.length > 0) {
        setSelectedKernel(mockKernels[0]);
      }
    };

    loadKernels();
  }, []);

  const getKernelStatusColor = (status: Kernel["status"]) => {
    switch (status) {
      case "idle":
        return "bg-success";
      case "busy":
        return "bg-yellow-500";
      case "starting":
        return "bg-blue-500";
      case "error":
      case "dead":
        return "bg-destructive";
      default:
        return "bg-muted-foreground";
    }
  };

  return (
    <header className="flex h-12 items-center border-b border-border bg-card px-4">
      {/* Title */}
      {title && (
        <h1 className="text-base font-semibold text-foreground">{title}</h1>
      )}

      <div className="flex-1" />

      {/* GPU Status - Show all GPUs (hidden on GPU Monitor page) */}
      {!hideGpuStatus && (
        <>
          <div className="flex items-center gap-1.5">
            {gpuAvailable ? (
              gpus.map((gpu) => (
                <GPUStatusBadge key={gpu.index} gpu={gpu} />
              ))
            ) : (
              <div className="flex items-center gap-1.5 rounded-md border border-muted-foreground/30 bg-muted px-2.5 py-1">
                <span className="h-1.5 w-1.5 rounded-full bg-muted-foreground" />
                <span className="text-xs font-medium text-muted-foreground">No GPU</span>
              </div>
            )}
          </div>
          <div className="w-4" />
        </>
      )}

      {/* Kernel Selector */}
      {kernels.length === 0 ? (
        <div className="flex items-center gap-1.5 rounded-md bg-muted px-2.5 py-1">
          <Activity className="h-3 w-3 text-muted-foreground" />
          <span className="text-xs font-medium text-muted-foreground">No Kernel</span>
        </div>
      ) : (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="flex items-center gap-1.5 rounded-md bg-muted px-2.5 py-1 transition-colors hover:bg-accent">
              <span
                className={cn(
                  "h-1.5 w-1.5 rounded-full",
                  selectedKernel ? getKernelStatusColor(selectedKernel.status) : "bg-muted-foreground"
                )}
              />
              <span className="text-xs font-medium text-foreground">
                {selectedKernel?.name || "Select Kernel"}
              </span>
              <ChevronDown className="h-3 w-3 text-muted-foreground" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48">
            {kernels.map((kernel) => {
              const isSelected = kernel.id === selectedKernel?.id;
              return (
                <DropdownMenuItem
                  key={kernel.id}
                  onClick={() => setSelectedKernel(kernel)}
                  className="flex items-center gap-2"
                >
                  <span className={cn("h-2 w-2 rounded-full", getKernelStatusColor(kernel.status))} />
                  <span className={cn("flex-1", isSelected && "font-semibold")}>
                    {kernel.name}
                  </span>
                  {isSelected && <Check className="h-3.5 w-3.5 text-primary" />}
                </DropdownMenuItem>
              );
            })}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* Custom Actions */}
      {actions && (
        <>
          <div className="w-4" />
          {actions}
        </>
      )}

      <div className="w-4" />

      {/* Help Button */}
      <HeaderIconButton icon={<HelpCircle className="h-4 w-4" />} onClick={() => {}} />
    </header>
  );
};

interface GPUStatusBadgeProps {
  gpu: GPUStatus;
}

const GPUStatusBadge = ({ gpu }: GPUStatusBadgeProps) => {
  const getStatusColor = (value: number, warning: number, danger: number) => {
    if (value >= danger) return "text-red-500";
    if (value >= warning) return "text-yellow-500";
    return "text-green-500";
  };

  const memPercent = gpu.memoryTotal > 0
    ? (gpu.memoryUsed / gpu.memoryTotal) * 100
    : 0;

  return (
    <div className="flex items-center gap-1.5 rounded-md border border-border bg-card px-2 py-1">
      {/* GPU Index */}
      <div className="flex items-center gap-1">
        <Cpu className="h-3 w-3 text-primary" />
        <span className="text-xs font-medium">{gpu.index}</span>
      </div>

      <div className="h-3 w-px bg-border" />

      {/* Utilization */}
      <div className="flex items-center gap-0.5" title="GPU Utilization">
        <Activity className={cn("h-3 w-3", getStatusColor(gpu.utilizationGpu, 70, 90))} />
        <span className={cn("text-xs", getStatusColor(gpu.utilizationGpu, 70, 90))}>
          {gpu.utilizationGpu}%
        </span>
      </div>

      {/* Temperature */}
      <div className="flex items-center gap-0.5" title="Temperature">
        <Thermometer className={cn("h-3 w-3", getStatusColor(gpu.temperature, 70, 85))} />
        <span className={cn("text-xs", getStatusColor(gpu.temperature, 70, 85))}>
          {gpu.temperature}°
        </span>
      </div>

      {/* Memory */}
      <div className="flex items-center gap-0.5" title="VRAM Usage">
        <HardDrive className={cn("h-3 w-3", getStatusColor(memPercent, 70, 90))} />
        <span className={cn("text-xs", getStatusColor(memPercent, 70, 90))}>
          {((gpu.memoryUsed || 0) / 1024).toFixed(0)}G
        </span>
      </div>
    </div>
  );
};

interface HeaderIconButtonProps {
  icon: React.ReactNode;
  onClick: () => void;
}

const HeaderIconButton = ({ icon, onClick }: HeaderIconButtonProps) => {
  return (
    <button
      onClick={onClick}
      className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
    >
      {icon}
    </button>
  );
};
