import { useState, useEffect } from "react";
import { Activity, ChevronDown, HelpCircle, Check } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import { gpuService } from "@/services/gpuService";

interface Kernel {
  id: string;
  name: string;
  status: "idle" | "busy" | "starting" | "error" | "dead";
}

interface AppHeaderProps {
  title?: string;
  actions?: React.ReactNode;
}

export const AppHeader = ({ title, actions }: AppHeaderProps) => {
  const [gpuName, setGpuName] = useState("GPU");
  const [gpuAvailable, setGpuAvailable] = useState(false);
  const [kernels, setKernels] = useState<Kernel[]>([]);
  const [selectedKernel, setSelectedKernel] = useState<Kernel | null>(null);

  useEffect(() => {
    // Load GPU status from backend
    const loadGpuStatus = async () => {
      try {
        const status = await gpuService.getStatus();
        if (status.primaryGpu) {
          setGpuName(status.primaryGpu.name);
          setGpuAvailable(true);
        } else if (status.gpus.length > 0) {
          setGpuName(status.gpus[0].name);
          setGpuAvailable(true);
        } else {
          setGpuName("No GPU");
          setGpuAvailable(false);
        }
      } catch (error) {
        console.error("Failed to load GPU status:", error);
        setGpuName("GPU Unavailable");
        setGpuAvailable(false);
      }
    };

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

    loadGpuStatus();
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

      {/* GPU Status */}
      <GPUStatus name={gpuName} available={gpuAvailable} />

      <div className="w-4" />

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

interface GPUStatusProps {
  name: string;
  available: boolean;
}

const GPUStatus = ({ name, available }: GPUStatusProps) => {
  return (
    <div
      className={cn(
        "flex items-center gap-1.5 rounded-md border px-2.5 py-1",
        available
          ? "border-success/30 bg-success/10"
          : "border-muted-foreground/30 bg-muted"
      )}
    >
      <span
        className={cn(
          "h-1.5 w-1.5 rounded-full",
          available ? "bg-success" : "bg-muted-foreground"
        )}
      />
      <span
        className={cn(
          "text-xs font-medium",
          available ? "text-success" : "text-muted-foreground"
        )}
      >
        {available ? name : "No GPU"}
      </span>
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
