import { Home, Cpu, RefreshCw } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface GPUMonitorBreadcrumbProps {
  gpuName?: string;
  onRefresh?: () => void;
}

export const GPUMonitorBreadcrumb = ({
  gpuName = "GPU Monitor",
  onRefresh,
}: GPUMonitorBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "GPU Monitor", icon: <Cpu className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* GPU Name */}
      <span className="text-xs text-muted-foreground">{gpuName}</span>

      {/* Refresh Button */}
      <Button size="sm" variant="outline" onClick={onRefresh} className="gap-1.5">
        <RefreshCw className="h-4 w-4" />
        Refresh
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
