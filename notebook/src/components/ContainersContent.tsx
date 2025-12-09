import { useState, useEffect, useCallback, useRef } from "react";
import {
  Play,
  Square,
  RotateCcw,
  Trash2,
  FileText,
  MoreVertical,
  Box,
  Layers,
  Download,
  Server,
  Cpu,
  HardDrive,
  Activity,
  Clock,
  Terminal,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ScrollArea } from "@/components/ui/scroll-area";
import { ContainersBreadcrumb } from "./ContainersBreadcrumb";
import {
  dockerService,
  Container,
  Image,
  ContainerStats,
  DockerSystemStatus,
  RunContainerRequest,
} from "@/services/dockerService";

// ==================== HELPER COMPONENTS ====================

const StatusBadge = ({ state }: { state: string }) => {
  const colors: Record<string, string> = {
    running: "bg-green-500/20 text-green-500",
    exited: "bg-red-500/20 text-red-500",
    paused: "bg-yellow-500/20 text-yellow-500",
    created: "bg-blue-500/20 text-blue-500",
    restarting: "bg-orange-500/20 text-orange-500",
  };

  return (
    <span
      className={`rounded px-1.5 py-0.5 text-[10px] font-medium uppercase ${colors[state] || "bg-gray-500/20 text-gray-500"}`}
    >
      {state}
    </span>
  );
};

const ContainerCard = ({
  container,
  isSelected,
  onSelect,
  onStart,
  onStop,
  onRestart,
  onRemove,
  onViewLogs,
}: {
  container: Container;
  isSelected: boolean;
  onSelect: () => void;
  onStart: () => void;
  onStop: () => void;
  onRestart: () => void;
  onRemove: () => void;
  onViewLogs: () => void;
}) => {
  const isRunning = container.state === "running";

  return (
    <div
      className={`rounded-lg border bg-card overflow-hidden cursor-pointer transition-colors ${
        isSelected ? "border-primary ring-1 ring-primary" : "border-border hover:border-primary/50"
      }`}
      onClick={onSelect}
    >
      <div className="flex items-center justify-between bg-secondary/50 px-3 py-2 border-b border-border">
        <div className="flex items-center gap-2 min-w-0">
          <Box className={`h-4 w-4 flex-shrink-0 ${isRunning ? "text-green-500" : "text-muted-foreground"}`} />
          <span className="text-sm font-medium truncate">{container.name}</span>
        </div>
        <div className="flex items-center gap-2">
          <StatusBadge state={container.state} />
          <DropdownMenu>
            <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
              <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                <MoreVertical className="h-3.5 w-3.5" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {isRunning ? (
                <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onStop(); }}>
                  <Square className="h-3.5 w-3.5 mr-2" />
                  Stop
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onStart(); }}>
                  <Play className="h-3.5 w-3.5 mr-2" />
                  Start
                </DropdownMenuItem>
              )}
              <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onRestart(); }}>
                <RotateCcw className="h-3.5 w-3.5 mr-2" />
                Restart
              </DropdownMenuItem>
              <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onViewLogs(); }}>
                <FileText className="h-3.5 w-3.5 mr-2" />
                View Logs
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                onClick={(e) => { e.stopPropagation(); onRemove(); }}
                className="text-destructive focus:text-destructive"
              >
                <Trash2 className="h-3.5 w-3.5 mr-2" />
                Remove
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
      <div className="p-3 space-y-2">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Layers className="h-3 w-3" />
          <span className="truncate">{container.image}</span>
        </div>
        {container.ports && (
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <Server className="h-3 w-3" />
            <span className="truncate">{container.ports || "No ports"}</span>
          </div>
        )}
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Clock className="h-3 w-3" />
          <span className="truncate">{container.status}</span>
        </div>
      </div>
    </div>
  );
};

const ImageRow = ({
  image,
  onRemove,
}: {
  image: Image;
  onRemove: () => void;
}) => {
  return (
    <div className="flex items-center justify-between py-2 px-3 hover:bg-secondary/50 rounded-md">
      <div className="flex items-center gap-3 min-w-0 flex-1">
        <Layers className="h-4 w-4 text-blue-500 flex-shrink-0" />
        <div className="min-w-0 flex-1">
          <div className="text-sm font-medium truncate">
            {image.repository}:{image.tag}
          </div>
          <div className="text-xs text-muted-foreground">
            {image.size} • {image.id.substring(0, 12)}
          </div>
        </div>
      </div>
      <Button
        variant="ghost"
        size="sm"
        onClick={onRemove}
        className="h-7 w-7 p-0 text-muted-foreground hover:text-destructive"
      >
        <Trash2 className="h-3.5 w-3.5" />
      </Button>
    </div>
  );
};

// ==================== MAIN COMPONENT ====================

export const ContainersContent = () => {
  // State
  const [containers, setContainers] = useState<Container[]>([]);
  const [images, setImages] = useState<Image[]>([]);
  const [systemInfo, setSystemInfo] = useState<DockerSystemStatus | null>(null);
  const [selectedContainer, setSelectedContainer] = useState<Container | null>(null);
  const [selectedStats, setSelectedStats] = useState<ContainerStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [dockerAvailable, setDockerAvailable] = useState(true);

  // Dialogs
  const [showNewContainer, setShowNewContainer] = useState(false);
  const [showLogs, setShowLogs] = useState(false);
  const [showPullImage, setShowPullImage] = useState(false);
  const [logs, setLogs] = useState("");

  // Form state
  const [newContainerForm, setNewContainerForm] = useState<RunContainerRequest>({
    image: "",
    name: "",
    ports: {},
    restart_policy: "unless-stopped",
  });
  const [pullImageName, setPullImageName] = useState("");
  const [portsInput, setPortsInput] = useState("");

  // Pull progress state
  const [isPulling, setIsPulling] = useState(false);
  const [pullLogs, setPullLogs] = useState<string[]>([]);
  const [pullComplete, setPullComplete] = useState(false);
  const [pullError, setPullError] = useState<string | null>(null);
  const pullLogsRef = useRef<HTMLPreElement>(null);

  // Auto-scroll pull logs
  useEffect(() => {
    if (pullLogsRef.current) {
      pullLogsRef.current.scrollTop = pullLogsRef.current.scrollHeight;
    }
  }, [pullLogs]);

  // Load data
  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      const status = await dockerService.getStatus();
      setDockerAvailable(status.available);

      if (status.available) {
        const [containersList, imagesList, sysInfo] = await Promise.all([
          dockerService.listContainers(),
          dockerService.listImages(),
          dockerService.getSystemInfo(),
        ]);
        setContainers(containersList);
        setImages(imagesList);
        setSystemInfo(sysInfo);
      }
    } catch (error) {
      console.error("Failed to load Docker data:", error);
      setDockerAvailable(false);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Load stats for selected container
  useEffect(() => {
    if (!selectedContainer || selectedContainer.state !== "running") {
      setSelectedStats(null);
      return;
    }

    const unsubscribe = dockerService.startStatsPolling(
      selectedContainer.id,
      (stats) => setSelectedStats(stats),
      3000
    );

    return unsubscribe;
  }, [selectedContainer]);

  // Handlers
  const handleStartContainer = async (id: string) => {
    try {
      await dockerService.startContainer(id);
      loadData();
    } catch (error) {
      console.error("Failed to start container:", error);
    }
  };

  const handleStopContainer = async (id: string) => {
    try {
      await dockerService.stopContainer(id);
      loadData();
    } catch (error) {
      console.error("Failed to stop container:", error);
    }
  };

  const handleRestartContainer = async (id: string) => {
    try {
      await dockerService.restartContainer(id);
      loadData();
    } catch (error) {
      console.error("Failed to restart container:", error);
    }
  };

  const handleRemoveContainer = async (id: string) => {
    try {
      await dockerService.removeContainer(id, true);
      if (selectedContainer?.id === id) {
        setSelectedContainer(null);
      }
      loadData();
    } catch (error) {
      console.error("Failed to remove container:", error);
    }
  };

  const handleViewLogs = async (id: string) => {
    try {
      const result = await dockerService.getContainerLogs(id, 500);
      setLogs(result.logs);
      setShowLogs(true);
    } catch (error) {
      console.error("Failed to get logs:", error);
    }
  };

  const handleCreateContainer = async () => {
    try {
      // Parse ports
      const ports: Record<string, string> = {};
      if (portsInput) {
        portsInput.split(",").forEach((mapping) => {
          const [host, container] = mapping.trim().split(":");
          if (host && container) {
            ports[host] = container;
          }
        });
      }

      await dockerService.runContainer({
        ...newContainerForm,
        ports: Object.keys(ports).length > 0 ? ports : undefined,
      });
      setShowNewContainer(false);
      setNewContainerForm({ image: "", name: "", ports: {}, restart_policy: "unless-stopped" });
      setPortsInput("");
      loadData();
    } catch (error) {
      console.error("Failed to create container:", error);
    }
  };

  const handlePullImage = async () => {
    if (!pullImageName.trim()) return;

    setIsPulling(true);
    setPullLogs([]);
    setPullComplete(false);
    setPullError(null);

    try {
      for await (const event of dockerService.pullImageStream(pullImageName)) {
        if (event.type === "progress" && event.message) {
          setPullLogs((prev) => [...prev.slice(-100), event.message!]); // Keep last 100 lines
        } else if (event.type === "complete") {
          setPullComplete(true);
          setPullLogs((prev) => [...prev, `✓ ${event.message}`]);
          loadData();
        } else if (event.type === "error") {
          setPullError(event.message || "Unknown error");
          setPullLogs((prev) => [...prev, `✗ Error: ${event.message}`]);
        }
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : "Failed to pull image";
      setPullError(errorMsg);
      setPullLogs((prev) => [...prev, `✗ Error: ${errorMsg}`]);
    } finally {
      setIsPulling(false);
    }
  };

  const handleClosePullDialog = () => {
    if (!isPulling) {
      setShowPullImage(false);
      setPullImageName("");
      setPullLogs([]);
      setPullComplete(false);
      setPullError(null);
    }
  };

  const handleRemoveImage = async (id: string) => {
    try {
      await dockerService.removeImage(id, true);
      loadData();
    } catch (error) {
      console.error("Failed to remove image:", error);
    }
  };

  // Counts
  const runningCount = containers.filter((c) => c.state === "running").length;
  const stoppedCount = containers.length - runningCount;

  if (!dockerAvailable) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="text-center">
          <Box className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h2 className="text-lg font-medium mb-2">Docker Unavailable</h2>
          <p className="text-sm text-muted-foreground">
            Docker is not running or not accessible on this system.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <ContainersBreadcrumb
        containersRunning={runningCount}
        containersStopped={stoppedCount}
        imagesCount={images.length}
        onRefresh={loadData}
        onNewContainer={() => setShowNewContainer(true)}
        isLoading={isLoading}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main Content */}
        <div className="flex-1 overflow-auto p-4">
          <Tabs defaultValue="containers" className="h-full">
            <TabsList className="mb-4">
              <TabsTrigger value="containers" className="gap-2">
                <Box className="h-3.5 w-3.5" />
                Containers ({containers.length})
              </TabsTrigger>
              <TabsTrigger value="images" className="gap-2">
                <Layers className="h-3.5 w-3.5" />
                Images ({images.length})
              </TabsTrigger>
            </TabsList>

            <TabsContent value="containers" className="mt-0">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {containers.map((container) => (
                  <ContainerCard
                    key={container.id}
                    container={container}
                    isSelected={selectedContainer?.id === container.id}
                    onSelect={() => setSelectedContainer(container)}
                    onStart={() => handleStartContainer(container.id)}
                    onStop={() => handleStopContainer(container.id)}
                    onRestart={() => handleRestartContainer(container.id)}
                    onRemove={() => handleRemoveContainer(container.id)}
                    onViewLogs={() => handleViewLogs(container.id)}
                  />
                ))}
                {containers.length === 0 && !isLoading && (
                  <div className="col-span-full text-center py-12 text-muted-foreground">
                    No containers found. Create one to get started.
                  </div>
                )}
              </div>
            </TabsContent>

            <TabsContent value="images" className="mt-0">
              <div className="flex justify-end mb-4">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setShowPullImage(true)}
                >
                  <Download className="h-3.5 w-3.5 mr-2" />
                  Pull Image
                </Button>
              </div>
              <div className="rounded-lg border border-border bg-card">
                {images.map((image) => (
                  <ImageRow
                    key={image.id}
                    image={image}
                    onRemove={() => handleRemoveImage(image.id)}
                  />
                ))}
                {images.length === 0 && !isLoading && (
                  <div className="text-center py-12 text-muted-foreground">
                    No images found.
                  </div>
                )}
              </div>
            </TabsContent>
          </Tabs>
        </div>

        {/* Side Panel */}
        <div className="w-72 border-l border-border bg-card overflow-auto">
          {/* System Info */}
          <div className="p-3 border-b border-border">
            <h3 className="text-xs font-medium text-muted-foreground mb-3">
              DOCKER SYSTEM
            </h3>
            {systemInfo?.info && (
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">Version</span>
                  <span>{systemInfo.info.server_version}</span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">CPUs</span>
                  <span>{systemInfo.info.cpus}</span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">Memory</span>
                  <span>
                    {(systemInfo.info.memory_total / 1024 / 1024 / 1024).toFixed(0)} GB
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">OS</span>
                  <span className="truncate ml-2">{systemInfo.info.os}</span>
                </div>
              </div>
            )}
          </div>

          {/* Selected Container Stats */}
          {selectedContainer && (
            <div className="p-3 border-b border-border">
              <h3 className="text-xs font-medium text-muted-foreground mb-3">
                SELECTED: {selectedContainer.name.toUpperCase()}
              </h3>
              {selectedStats ? (
                <div className="space-y-3">
                  <div className="flex items-center gap-2">
                    <Cpu className="h-3.5 w-3.5 text-blue-500" />
                    <span className="text-xs text-muted-foreground">CPU</span>
                    <span className="text-xs ml-auto font-medium">
                      {selectedStats.cpu_percent}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <HardDrive className="h-3.5 w-3.5 text-green-500" />
                    <span className="text-xs text-muted-foreground">Memory</span>
                    <span className="text-xs ml-auto font-medium">
                      {selectedStats.memory_percent}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Activity className="h-3.5 w-3.5 text-purple-500" />
                    <span className="text-xs text-muted-foreground">Network</span>
                    <span className="text-xs ml-auto font-medium truncate max-w-[100px]">
                      {selectedStats.network_io}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Terminal className="h-3.5 w-3.5 text-orange-500" />
                    <span className="text-xs text-muted-foreground">PIDs</span>
                    <span className="text-xs ml-auto font-medium">
                      {selectedStats.pids}
                    </span>
                  </div>
                </div>
              ) : (
                <p className="text-xs text-muted-foreground">
                  {selectedContainer.state === "running"
                    ? "Loading stats..."
                    : "Container not running"}
                </p>
              )}
            </div>
          )}

          {/* Quick Actions */}
          <div className="p-3">
            <h3 className="text-xs font-medium text-muted-foreground mb-3">
              QUICK ACTIONS
            </h3>
            <div className="space-y-2">
              <Button
                variant="outline"
                size="sm"
                className="w-full justify-start"
                onClick={() => setShowNewContainer(true)}
              >
                <Box className="h-3.5 w-3.5 mr-2" />
                New Container
              </Button>
              <Button
                variant="outline"
                size="sm"
                className="w-full justify-start"
                onClick={() => setShowPullImage(true)}
              >
                <Download className="h-3.5 w-3.5 mr-2" />
                Pull Image
              </Button>
            </div>
          </div>
        </div>
      </div>

      {/* New Container Dialog */}
      <Dialog open={showNewContainer} onOpenChange={setShowNewContainer}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Container</DialogTitle>
            <DialogDescription>
              Run a new container from a Docker image.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="image">Image *</Label>
              <Input
                id="image"
                placeholder="nginx:latest"
                value={newContainerForm.image}
                onChange={(e) =>
                  setNewContainerForm({ ...newContainerForm, image: e.target.value })
                }
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="name">Container Name</Label>
              <Input
                id="name"
                placeholder="my-container"
                value={newContainerForm.name}
                onChange={(e) =>
                  setNewContainerForm({ ...newContainerForm, name: e.target.value })
                }
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ports">Ports (host:container, comma-separated)</Label>
              <Input
                id="ports"
                placeholder="8080:80, 443:443"
                value={portsInput}
                onChange={(e) => setPortsInput(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="command">Command (optional)</Label>
              <Input
                id="command"
                placeholder="/bin/sh -c 'echo hello'"
                value={newContainerForm.command || ""}
                onChange={(e) =>
                  setNewContainerForm({ ...newContainerForm, command: e.target.value })
                }
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowNewContainer(false)}>
              Cancel
            </Button>
            <Button
              onClick={handleCreateContainer}
              disabled={!newContainerForm.image}
            >
              Create
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Logs Dialog */}
      <Dialog open={showLogs} onOpenChange={setShowLogs}>
        <DialogContent className="max-w-3xl max-h-[80vh]">
          <DialogHeader>
            <DialogTitle>Container Logs</DialogTitle>
          </DialogHeader>
          <ScrollArea className="h-[60vh] rounded-md border bg-black p-4">
            <pre className="text-xs text-green-400 font-mono whitespace-pre-wrap">
              {logs || "No logs available"}
            </pre>
          </ScrollArea>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowLogs(false)}>
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Pull Image Dialog */}
      <Dialog open={showPullImage} onOpenChange={handleClosePullDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Pull Docker Image</DialogTitle>
            <DialogDescription>
              Download an image from Docker Hub or another registry.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="pullImage">Image Name</Label>
              <Input
                id="pullImage"
                placeholder="nginx:latest or ubuntu:22.04"
                value={pullImageName}
                onChange={(e) => setPullImageName(e.target.value)}
                disabled={isPulling}
              />
            </div>

            {/* Pull Progress Logs */}
            {(isPulling || pullLogs.length > 0) && (
              <div className="space-y-2">
                <Label>Pull Progress</Label>
                <div
                  ref={pullLogsRef}
                  className="h-[300px] overflow-auto rounded-md border bg-black p-3"
                >
                  <pre className="text-xs font-mono text-green-400 whitespace-pre-wrap">
                    {pullLogs.length > 0 ? pullLogs.join("\n") : "Starting pull..."}
                  </pre>
                </div>
                {isPulling && (
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <div className="h-2 w-2 rounded-full bg-blue-500 animate-pulse" />
                    Pulling image...
                  </div>
                )}
                {pullComplete && (
                  <div className="flex items-center gap-2 text-sm text-green-500">
                    <div className="h-2 w-2 rounded-full bg-green-500" />
                    Pull complete!
                  </div>
                )}
                {pullError && (
                  <div className="flex items-center gap-2 text-sm text-destructive">
                    <div className="h-2 w-2 rounded-full bg-destructive" />
                    {pullError}
                  </div>
                )}
              </div>
            )}
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={handleClosePullDialog}
              disabled={isPulling}
            >
              {pullComplete ? "Done" : "Cancel"}
            </Button>
            {!pullComplete && (
              <Button
                onClick={handlePullImage}
                disabled={!pullImageName.trim() || isPulling}
              >
                {isPulling ? "Pulling..." : "Pull"}
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};
