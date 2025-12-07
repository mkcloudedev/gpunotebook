import { useState, useEffect } from "react";
import { ChevronDown, Circle, Zap, RefreshCw, Power } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

export interface KernelSpec {
  name: string;
  displayName: string;
  language: string;
  version?: string;
}

interface KernelSelectorProps {
  currentKernel?: string;
  kernelStatus: "idle" | "busy" | "starting" | "restarting" | "error" | "disconnected";
  availableKernels?: KernelSpec[];
  onSelectKernel?: (kernelName: string) => void;
  onRestart?: () => void;
  onInterrupt?: () => void;
  onDisconnect?: () => void;
  compact?: boolean;
}

export const KernelSelector = ({
  currentKernel = "Python 3",
  kernelStatus = "disconnected",
  availableKernels,
  onSelectKernel,
  onRestart,
  onInterrupt,
  onDisconnect,
  compact = false,
}: KernelSelectorProps) => {
  const [kernels, setKernels] = useState<KernelSpec[]>(availableKernels || [
    { name: "python3", displayName: "Python 3", language: "python", version: "3.11" },
    { name: "python310", displayName: "Python 3.10", language: "python", version: "3.10" },
    { name: "ir", displayName: "R", language: "r", version: "4.2" },
    { name: "julia", displayName: "Julia", language: "julia", version: "1.9" },
  ]);

  const getStatusColor = () => {
    switch (kernelStatus) {
      case "idle":
        return "text-green-500";
      case "busy":
        return "text-amber-500 animate-pulse";
      case "starting":
      case "restarting":
        return "text-blue-500 animate-pulse";
      case "error":
        return "text-red-500";
      case "disconnected":
      default:
        return "text-muted-foreground";
    }
  };

  const getStatusText = () => {
    switch (kernelStatus) {
      case "idle":
        return "Ready";
      case "busy":
        return "Busy";
      case "starting":
        return "Starting...";
      case "restarting":
        return "Restarting...";
      case "error":
        return "Error";
      case "disconnected":
      default:
        return "Disconnected";
    }
  };

  if (compact) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm" className="h-6 gap-1 px-2">
            <Circle className={cn("h-2 w-2 fill-current", getStatusColor())} />
            <span className="text-xs">{currentKernel}</span>
            <ChevronDown className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-56">
          <div className="px-2 py-1.5">
            <div className="text-xs font-semibold">{currentKernel}</div>
            <div className={cn("text-[10px]", getStatusColor())}>{getStatusText()}</div>
          </div>
          <DropdownMenuSeparator />

          {/* Available Kernels */}
          <div className="px-2 py-1 text-[10px] font-medium text-muted-foreground">
            Switch Kernel
          </div>
          {kernels.map((kernel) => (
            <DropdownMenuItem
              key={kernel.name}
              onClick={() => onSelectKernel?.(kernel.name)}
              className="gap-2"
            >
              <Zap className="h-3 w-3" />
              <span className="text-xs">{kernel.displayName}</span>
              {kernel.version && (
                <span className="ml-auto text-[10px] text-muted-foreground">
                  v{kernel.version}
                </span>
              )}
            </DropdownMenuItem>
          ))}

          <DropdownMenuSeparator />

          {/* Kernel Actions */}
          {onRestart && (
            <DropdownMenuItem onClick={onRestart} className="gap-2">
              <RefreshCw className="h-3 w-3" />
              <span className="text-xs">Restart Kernel</span>
            </DropdownMenuItem>
          )}
          {onInterrupt && kernelStatus === "busy" && (
            <DropdownMenuItem onClick={onInterrupt} className="gap-2 text-amber-500">
              <Power className="h-3 w-3" />
              <span className="text-xs">Interrupt</span>
            </DropdownMenuItem>
          )}
          {onDisconnect && kernelStatus !== "disconnected" && (
            <DropdownMenuItem onClick={onDisconnect} className="gap-2 text-destructive">
              <Power className="h-3 w-3" />
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
            <Circle className={cn("h-2.5 w-2.5 fill-current", getStatusColor())} />
            <span className="text-xs font-medium">{currentKernel}</span>
            <span className={cn("text-[10px]", getStatusColor())}>
              ({getStatusText()})
            </span>
            <ChevronDown className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-64">
          <div className="px-3 py-2 border-b border-border">
            <div className="flex items-center gap-2">
              <Circle className={cn("h-3 w-3 fill-current", getStatusColor())} />
              <div>
                <div className="text-sm font-semibold">{currentKernel}</div>
                <div className={cn("text-xs", getStatusColor())}>{getStatusText()}</div>
              </div>
            </div>
          </div>

          {/* Available Kernels */}
          <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground">
            Available Kernels
          </div>
          {kernels.map((kernel) => (
            <DropdownMenuItem
              key={kernel.name}
              onClick={() => onSelectKernel?.(kernel.name)}
              className="gap-3 py-2"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded bg-muted">
                <Zap className="h-4 w-4 text-primary" />
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium">{kernel.displayName}</div>
                <div className="text-xs text-muted-foreground">
                  {kernel.language} {kernel.version && `• v${kernel.version}`}
                </div>
              </div>
            </DropdownMenuItem>
          ))}

          <DropdownMenuSeparator />

          {/* Kernel Actions */}
          <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground">
            Actions
          </div>
          {onRestart && (
            <DropdownMenuItem onClick={onRestart} className="gap-2">
              <RefreshCw className="h-4 w-4" />
              <span>Restart Kernel</span>
            </DropdownMenuItem>
          )}
          {onInterrupt && kernelStatus === "busy" && (
            <DropdownMenuItem onClick={onInterrupt} className="gap-2 text-amber-500">
              <Power className="h-4 w-4" />
              <span>Interrupt Execution</span>
            </DropdownMenuItem>
          )}
          {onDisconnect && kernelStatus !== "disconnected" && (
            <DropdownMenuItem onClick={onDisconnect} className="gap-2 text-destructive">
              <Power className="h-4 w-4" />
              <span>Disconnect</span>
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};

export default KernelSelector;
