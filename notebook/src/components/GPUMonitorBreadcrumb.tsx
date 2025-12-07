import { Home, Cpu, RefreshCw, Thermometer, Activity, HardDrive } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";
import { cn } from "@/lib/utils";

interface GPUInfo {
  index: number;
  name: string;
  temperature: number;
  utilizationGpu: number;
  memoryUsed: number;
  memoryTotal: number;
}

interface GPUMonitorBreadcrumbProps {
  gpus: GPUInfo[];
  selectedIndex: number;
  onSelectGpu: (index: number) => void;
  onRefresh?: () => void;
}

export const GPUMonitorBreadcrumb = ({
  gpus,
  selectedIndex,
  onSelectGpu,
  onRefresh,
}: GPUMonitorBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "GPU Monitor", icon: <Cpu className="h-4 w-4" /> },
  ];

  const getStatusColor = (value: number, warning: number, danger: number) => {
    if (value >= danger) return "text-red-500";
    if (value >= warning) return "text-yellow-500";
    return "text-green-500";
  };

  const actions = (
    <div className="flex items-center gap-3">
      {/* GPU Cards */}
      <div className="flex items-center gap-2">
        {gpus.map((gpu) => {
          const memPercent = gpu.memoryTotal > 0
            ? (gpu.memoryUsed / gpu.memoryTotal) * 100
            : 0;
          const isSelected = gpu.index === selectedIndex;

          return (
            <button
              key={gpu.index}
              onClick={() => onSelectGpu(gpu.index)}
              className={cn(
                "flex items-center gap-2 px-2 py-1 rounded-lg border transition-all text-xs",
                isSelected
                  ? "border-primary bg-primary/10"
                  : "border-border bg-card hover:bg-muted"
              )}
            >
              <div className="flex items-center gap-1">
                <Cpu className={cn("h-3 w-3", isSelected ? "text-primary" : "text-muted-foreground")} />
                <span className={cn("font-medium", isSelected ? "text-primary" : "")}>
                  {gpu.index}
                </span>
              </div>

              <div className="flex items-center gap-2 border-l border-border pl-2">
                {/* Utilization */}
                <div className="flex items-center gap-0.5" title="GPU Utilization">
                  <Activity className={cn("h-3 w-3", getStatusColor(gpu.utilizationGpu, 70, 90))} />
                  <span className={getStatusColor(gpu.utilizationGpu, 70, 90)}>
                    {gpu.utilizationGpu}%
                  </span>
                </div>

                {/* Temperature */}
                <div className="flex items-center gap-0.5" title="Temperature">
                  <Thermometer className={cn("h-3 w-3", getStatusColor(gpu.temperature, 70, 85))} />
                  <span className={getStatusColor(gpu.temperature, 70, 85)}>
                    {gpu.temperature}°
                  </span>
                </div>

                {/* Memory */}
                <div className="flex items-center gap-0.5" title="VRAM Usage">
                  <HardDrive className={cn("h-3 w-3", getStatusColor(memPercent, 70, 90))} />
                  <span className={getStatusColor(memPercent, 70, 90)}>
                    {(gpu.memoryUsed / 1024).toFixed(0)}G
                  </span>
                </div>
              </div>
            </button>
          );
        })}
      </div>

      {/* Refresh Button */}
      <Button size="sm" variant="outline" onClick={onRefresh} className="gap-1.5">
        <RefreshCw className="h-4 w-4" />
        Refresh
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
