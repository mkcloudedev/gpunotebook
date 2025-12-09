/**
 * Container selector component for notebook container execution.
 * Displays container status and allows switching between images.
 */
import { useState } from "react";
import {
  ChevronDown,
  Circle,
  Box,
  RefreshCw,
  Power,
  Download,
  Cpu,
  HardDrive,
  Loader2,
  Play,
  Square,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ContainerStatus } from "@/hooks/useContainerExecution";

export interface ContainerImage {
  id: string;
  name: string;
  description: string;
}

interface ContainerSelectorProps {
  status: ContainerStatus;
  currentImage: string;
  availableImages?: ContainerImage[];
  hasGpu?: boolean;
  useGpu?: boolean;
  isPulling?: boolean;
  pullProgress?: string;
  containerId?: string | null;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onSelectImage?: (imageId: string) => void;
  onToggleGpu?: () => void;
  compact?: boolean;
}

export const ContainerSelector = ({
  status,
  currentImage,
  availableImages = [],
  hasGpu = false,
  useGpu = false,
  isPulling = false,
  pullProgress = "",
  containerId,
  onConnect,
  onDisconnect,
  onSelectImage,
  onToggleGpu,
  compact = false,
}: ContainerSelectorProps) => {
  const getStatusColor = () => {
    switch (status) {
      case "idle":
      case "running":
        return "text-green-500";
      case "executing":
        return "text-amber-500 animate-pulse";
      case "checking":
      case "creating":
        return "text-blue-500 animate-pulse";
      case "pulling":
        return "text-purple-500 animate-pulse";
      case "stopped":
        return "text-gray-500";
      case "error":
        return "text-red-500";
      case "disconnected":
      default:
        return "text-muted-foreground";
    }
  };

  const getStatusText = () => {
    switch (status) {
      case "idle":
        return "Ready";
      case "running":
        return "Running";
      case "executing":
        return "Executing";
      case "checking":
        return "Checking...";
      case "creating":
        return "Creating...";
      case "pulling":
        return pullProgress || "Pulling...";
      case "stopped":
        return "Stopped";
      case "error":
        return "Error";
      case "disconnected":
      default:
        return "Disconnected";
    }
  };

  const getImageName = (imageId: string) => {
    const image = availableImages.find((img) => img.id === imageId);
    return image?.name || imageId;
  };

  const isConnected = status === "idle" || status === "running" || status === "executing";
  const isLoading = status === "checking" || status === "creating" || status === "pulling";

  if (compact) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm" className="h-6 gap-1 px-2">
            {isPulling ? (
              <Loader2 className="h-2 w-2 animate-spin" />
            ) : (
              <Box className={cn("h-2 w-2", getStatusColor())} />
            )}
            <span className="text-xs">Container</span>
            <ChevronDown className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-64">
          <div className="px-2 py-1.5">
            <div className="flex items-center gap-2">
              <Box className={cn("h-3 w-3", getStatusColor())} />
              <div>
                <div className="text-xs font-semibold">{getImageName(currentImage)}</div>
                <div className={cn("text-[10px]", getStatusColor())}>{getStatusText()}</div>
              </div>
            </div>
            {containerId && (
              <div className="mt-1 text-[10px] text-muted-foreground font-mono truncate">
                ID: {containerId.slice(0, 12)}
              </div>
            )}
          </div>

          {/* GPU Status */}
          {hasGpu && (
            <>
              <DropdownMenuSeparator />
              <div className="px-2 py-1">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5">
                    <Cpu className="h-3 w-3 text-green-500" />
                    <span className="text-xs">NVIDIA GPU Available</span>
                  </div>
                  <Button
                    size="sm"
                    variant={useGpu ? "default" : "outline"}
                    className="h-5 px-2 text-[10px]"
                    onClick={onToggleGpu}
                  >
                    {useGpu ? "Enabled" : "Enable"}
                  </Button>
                </div>
              </div>
            </>
          )}

          <DropdownMenuSeparator />

          {/* Available Images */}
          <div className="px-2 py-1 text-[10px] font-medium text-muted-foreground">
            Container Images
          </div>
          {availableImages.map((image) => (
            <DropdownMenuItem
              key={image.id}
              onClick={() => onSelectImage?.(image.id)}
              className="gap-2"
            >
              <HardDrive className="h-3 w-3" />
              <div className="flex-1">
                <span className="text-xs">{image.name}</span>
                {currentImage === image.id && (
                  <span className="ml-1 text-[10px] text-primary">(current)</span>
                )}
              </div>
            </DropdownMenuItem>
          ))}

          <DropdownMenuSeparator />

          {/* Container Actions */}
          {!isConnected && !isLoading && (
            <DropdownMenuItem onClick={onConnect} className="gap-2">
              <Play className="h-3 w-3 text-green-500" />
              <span className="text-xs">Connect Container</span>
            </DropdownMenuItem>
          )}
          {isConnected && (
            <DropdownMenuItem onClick={onDisconnect} className="gap-2 text-destructive">
              <Square className="h-3 w-3" />
              <span className="text-xs">Disconnect</span>
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" size="sm" className="h-7 gap-2">
            {isLoading ? (
              <Loader2 className="h-2.5 w-2.5 animate-spin" />
            ) : (
              <Box className={cn("h-2.5 w-2.5", getStatusColor())} />
            )}
            <span className="text-xs font-medium">{getImageName(currentImage)}</span>
            <span className={cn("text-[10px]", getStatusColor())}>
              ({getStatusText()})
            </span>
            {hasGpu && useGpu && (
              <Cpu className="h-3 w-3 text-green-500" />
            )}
            <ChevronDown className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-72">
          <div className="px-3 py-2 border-b border-border">
            <div className="flex items-center gap-2">
              <Box className={cn("h-4 w-4", getStatusColor())} />
              <div className="flex-1">
                <div className="text-sm font-semibold">{getImageName(currentImage)}</div>
                <div className={cn("text-xs", getStatusColor())}>{getStatusText()}</div>
              </div>
            </div>
            {containerId && (
              <div className="mt-2 text-[10px] text-muted-foreground font-mono">
                Container ID: {containerId.slice(0, 12)}
              </div>
            )}
            {isPulling && pullProgress && (
              <div className="mt-2 text-xs text-purple-500">
                <Download className="inline h-3 w-3 mr-1" />
                {pullProgress}
              </div>
            )}
          </div>

          {/* GPU Section */}
          {hasGpu && (
            <>
              <div className="px-3 py-2 border-b border-border bg-green-500/5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Cpu className="h-4 w-4 text-green-500" />
                    <div>
                      <div className="text-xs font-medium">NVIDIA GPU Detected</div>
                      <div className="text-[10px] text-muted-foreground">
                        GPU acceleration available
                      </div>
                    </div>
                  </div>
                  <Button
                    size="sm"
                    variant={useGpu ? "default" : "outline"}
                    className="h-6"
                    onClick={onToggleGpu}
                  >
                    {useGpu ? "Enabled" : "Enable"}
                  </Button>
                </div>
              </div>
            </>
          )}

          {/* Available Images */}
          <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground">
            Available Images
          </div>
          {availableImages.map((image) => (
            <DropdownMenuItem
              key={image.id}
              onClick={() => onSelectImage?.(image.id)}
              className="gap-3 py-2"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded bg-muted">
                <HardDrive className="h-4 w-4 text-primary" />
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">{image.name}</span>
                  {currentImage === image.id && (
                    <Circle className="h-2 w-2 fill-primary text-primary" />
                  )}
                </div>
                <div className="text-xs text-muted-foreground">{image.description}</div>
              </div>
            </DropdownMenuItem>
          ))}

          <DropdownMenuSeparator />

          {/* Actions */}
          <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground">
            Actions
          </div>
          {!isConnected && !isLoading && (
            <DropdownMenuItem onClick={onConnect} className="gap-2">
              <Play className="h-4 w-4 text-green-500" />
              <span>Connect Container</span>
            </DropdownMenuItem>
          )}
          {isLoading && (
            <DropdownMenuItem disabled className="gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span>Loading...</span>
            </DropdownMenuItem>
          )}
          {isConnected && (
            <>
              <DropdownMenuItem onClick={onDisconnect} className="gap-2">
                <Square className="h-4 w-4 text-amber-500" />
                <span>Stop Container</span>
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onDisconnect?.()} className="gap-2 text-destructive">
                <Power className="h-4 w-4" />
                <span>Disconnect & Remove</span>
              </DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};

export default ContainerSelector;
