import { RefreshCw, Plus, Box, Layers } from "lucide-react";
import { Button } from "@/components/ui/button";

interface ContainersBreadcrumbProps {
  containersRunning: number;
  containersStopped: number;
  imagesCount: number;
  onRefresh: () => void;
  onNewContainer: () => void;
  isLoading?: boolean;
}

export const ContainersBreadcrumb = ({
  containersRunning,
  containersStopped,
  imagesCount,
  onRefresh,
  onNewContainer,
  isLoading = false,
}: ContainersBreadcrumbProps) => {
  return (
    <div className="flex items-center justify-between border-b border-border px-4 py-2 bg-background/50">
      <div className="flex items-center gap-4">
        <span className="text-sm font-medium">Docker Containers</span>
        <div className="flex items-center gap-3 text-xs text-muted-foreground">
          <div className="flex items-center gap-1.5">
            <Box className="h-3.5 w-3.5 text-green-500" />
            <span>{containersRunning} running</span>
          </div>
          <div className="flex items-center gap-1.5">
            <Box className="h-3.5 w-3.5 text-red-500" />
            <span>{containersStopped} stopped</span>
          </div>
          <div className="flex items-center gap-1.5">
            <Layers className="h-3.5 w-3.5 text-blue-500" />
            <span>{imagesCount} images</span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={onRefresh}
          disabled={isLoading}
          className="h-7 px-2"
        >
          <RefreshCw
            className={`h-3.5 w-3.5 mr-1.5 ${isLoading ? "animate-spin" : ""}`}
          />
          Refresh
        </Button>
        <Button size="sm" onClick={onNewContainer} className="h-7 px-3">
          <Plus className="h-3.5 w-3.5 mr-1.5" />
          New Container
        </Button>
      </div>
    </div>
  );
};
