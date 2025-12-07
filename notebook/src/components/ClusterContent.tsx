import { useState, useEffect, useCallback, useRef } from "react";
import {
  Server,
  Plus,
  RefreshCw,
  Trash2,
  Zap,
  Activity,
  Shuffle,
  Tag,
  CheckCircle,
  XCircle,
  Loader2,
  Copy,
  AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
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
import { ClusterBreadcrumb } from "./ClusterBreadcrumb";
import { clusterService, ClusterNode as ServiceNode, ClusterStats } from "@/services/clusterService";

interface ClusterNode {
  id: string;
  hostname: string;
  port: number;
  status: "online" | "offline" | "busy";
  gpuName: string;
  gpuMemory: number;
  gpuUtilization: number;
  tags: string[];
}

// Mock data for fallback
const mockNodes: ClusterNode[] = [
  {
    id: "node1",
    hostname: "gpu-server-1",
    port: 8888,
    status: "online",
    gpuName: "NVIDIA RTX 4090",
    gpuMemory: 24,
    gpuUtilization: 45,
    tags: ["production", "training"],
  },
  {
    id: "node2",
    hostname: "gpu-server-2",
    port: 8888,
    status: "busy",
    gpuName: "NVIDIA A100",
    gpuMemory: 80,
    gpuUtilization: 92,
    tags: ["production"],
  },
  {
    id: "node3",
    hostname: "gpu-server-3",
    port: 8888,
    status: "offline",
    gpuName: "NVIDIA RTX 3090",
    gpuMemory: 24,
    gpuUtilization: 0,
    tags: ["development"],
  },
];

export const ClusterContent = () => {
  const [nodes, setNodes] = useState<ClusterNode[]>([]);
  const [stats, setStats] = useState<ClusterStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddNodeDialog, setShowAddNodeDialog] = useState(false);
  const [newNodeHostname, setNewNodeHostname] = useState("");
  const [newNodePort, setNewNodePort] = useState("8888");

  const stopPollingRef = useRef<(() => void) | null>(null);

  // Convert service node to component node
  const convertNode = (n: ServiceNode): ClusterNode => ({
    id: n.id,
    hostname: n.hostname,
    port: n.port,
    status: n.status as "online" | "offline" | "busy",
    gpuName: n.gpuName,
    gpuMemory: n.gpuMemory,
    gpuUtilization: n.gpuUtilization,
    tags: n.tags,
  });

  // Load nodes from API
  const loadNodes = useCallback(async () => {
    try {
      setError(null);
      const [nodeList, clusterStats] = await Promise.all([
        clusterService.listNodes(),
        clusterService.getStats(),
      ]);

      setNodes(nodeList.map(convertNode));
      setStats(clusterStats);
    } catch (err) {
      console.error("Error loading cluster nodes:", err);
      setError(err instanceof Error ? err.message : "Failed to load nodes");
      // Use mock data as fallback
      setNodes(mockNodes);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Initial load and start polling
  useEffect(() => {
    loadNodes();

    // Start polling for real-time updates
    stopPollingRef.current = clusterService.startPolling((nodeList) => {
      setNodes(nodeList.map(convertNode));
    }, 5000);

    return () => {
      if (stopPollingRef.current) {
        stopPollingRef.current();
      }
    };
  }, [loadNodes]);

  const handleAddNode = async () => {
    if (newNodeHostname && newNodePort) {
      try {
        const newNode = await clusterService.addNode({
          hostname: newNodeHostname,
          port: parseInt(newNodePort),
        });
        setNodes([...nodes, convertNode(newNode)]);
      } catch (err) {
        console.error("Error adding node:", err);
        // Fallback to local addition
        const newNode: ClusterNode = {
          id: `node${Date.now()}`,
          hostname: newNodeHostname,
          port: parseInt(newNodePort),
          status: "offline",
          gpuName: "Unknown",
          gpuMemory: 0,
          gpuUtilization: 0,
          tags: [],
        };
        setNodes([...nodes, newNode]);
      }

      setNewNodeHostname("");
      setNewNodePort("8888");
      setShowAddNodeDialog(false);
    }
  };

  const handleDeleteNode = async (id: string) => {
    try {
      await clusterService.removeNode(id);
    } catch (err) {
      console.error("Error removing node:", err);
    }
    // Remove locally regardless
    setNodes(nodes.filter((n) => n.id !== id));
  };

  const handleRefresh = () => {
    setIsLoading(true);
    loadNodes();
  };

  const onlineCount = nodes.filter((n) => n.status === "online").length;
  const busyCount = nodes.filter((n) => n.status === "busy").length;

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <ClusterBreadcrumb
        nodeCount={nodes.length}
        onlineCount={onlineCount}
        onAddNode={() => setShowAddNodeDialog(true)}
      />

      <div className="flex-1 overflow-auto p-6">
        {/* Header */}
        <div className="mb-6">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10">
              <Server className="h-6 w-6 text-primary" />
            </div>
            <div>
              <h1 className="text-2xl font-bold">GPU Cluster</h1>
              <p className="text-muted-foreground">
                Manage distributed GPU nodes for notebook execution
              </p>
            </div>
          </div>
        </div>

        <div className="flex gap-6">
          {/* Cluster Panel */}
          <div className="w-96 rounded-xl border border-border bg-card">
            {/* Panel Header */}
            <div className="flex items-center justify-between border-b border-border p-4">
              <div className="flex items-center gap-2">
                <Server className="h-5 w-5 text-primary" />
                <span className="font-semibold">Cluster Nodes</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="rounded-full bg-green-500/20 px-2 py-0.5 text-xs text-green-500">
                  {onlineCount} online
                </span>
                {busyCount > 0 && (
                  <span className="rounded-full bg-amber-500/20 px-2 py-0.5 text-xs text-amber-500">
                    {busyCount} busy
                  </span>
                )}
              </div>
            </div>

            {/* Nodes List */}
            <div className="p-4 space-y-3">
              {nodes.length === 0 ? (
                <div className="text-center py-8">
                  <Server className="h-12 w-12 text-muted-foreground/50 mx-auto" />
                  <p className="mt-4 text-muted-foreground">No nodes configured</p>
                  <Button className="mt-4" onClick={() => setShowAddNodeDialog(true)}>
                    <Plus className="mr-2 h-4 w-4" />
                    Add Node
                  </Button>
                </div>
              ) : (
                <>
                  {nodes.map((node) => (
                    <NodeCard key={node.id} node={node} onDelete={() => handleDeleteNode(node.id)} />
                  ))}
                  <Button
                    variant="outline"
                    className="w-full mt-2"
                    onClick={() => setShowAddNodeDialog(true)}
                  >
                    <Plus className="mr-2 h-4 w-4" />
                    Add Node
                  </Button>
                </>
              )}
            </div>
          </div>

          {/* Getting Started / Features */}
          <div className="flex-1 rounded-xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold mb-4">Getting Started</h2>

            <div className="space-y-4">
              <GuideStep
                number={1}
                title="Setup Worker Nodes"
                description="Run the setup script on each GPU machine to install Jupyter Enterprise Gateway."
                code="sudo ./setup_worker.sh"
              />
              <GuideStep
                number={2}
                title="Add Nodes to Cluster"
                description='Click "Add Node" and enter the hostname/IP and port of each GPU machine.'
              />
              <GuideStep
                number={3}
                title="Select Node for Execution"
                description='When running notebooks, select a node from the dropdown or use "Auto" for automatic placement.'
              />
            </div>

            <div className="my-6 border-t border-border" />

            <h2 className="text-lg font-semibold mb-4">Features</h2>

            <div className="space-y-3">
              <FeatureItem
                icon={<Zap className="h-4 w-4" />}
                title="Auto Placement"
                description="Automatically selects the best available GPU node"
              />
              <FeatureItem
                icon={<Activity className="h-4 w-4" />}
                title="Health Monitoring"
                description="Real-time status and GPU metrics for all nodes"
              />
              <FeatureItem
                icon={<Shuffle className="h-4 w-4" />}
                title="Load Balancing"
                description="Distributes workloads across available nodes"
              />
              <FeatureItem
                icon={<Tag className="h-4 w-4" />}
                title="Tag-based Routing"
                description="Route kernels to specific nodes using tags"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Add Node Dialog */}
      <Dialog open={showAddNodeDialog} onOpenChange={setShowAddNodeDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Cluster Node</DialogTitle>
            <DialogDescription>
              Enter the hostname and port of the GPU machine running Jupyter Enterprise Gateway.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Hostname / IP Address</Label>
              <Input
                value={newNodeHostname}
                onChange={(e) => setNewNodeHostname(e.target.value)}
                placeholder="gpu-server-1 or 192.168.1.100"
              />
            </div>
            <div>
              <Label>Port</Label>
              <Input
                value={newNodePort}
                onChange={(e) => setNewNodePort(e.target.value)}
                placeholder="8888"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowAddNodeDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleAddNode}>Add Node</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

// =============================================================================
// NODE CARD
// =============================================================================

interface NodeCardProps {
  node: ClusterNode;
  onDelete: () => void;
}

const NodeCard = ({ node, onDelete }: NodeCardProps) => {
  const getStatusIcon = () => {
    switch (node.status) {
      case "online":
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case "busy":
        return <Loader2 className="h-4 w-4 text-amber-500 animate-spin" />;
      case "offline":
        return <XCircle className="h-4 w-4 text-red-500" />;
    }
  };

  const getStatusColor = () => {
    switch (node.status) {
      case "online":
        return "border-green-500/30 bg-green-500/5";
      case "busy":
        return "border-amber-500/30 bg-amber-500/5";
      case "offline":
        return "border-red-500/30 bg-red-500/5";
    }
  };

  return (
    <div className={cn("rounded-lg border p-3", getStatusColor())}>
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2">
          {getStatusIcon()}
          <div>
            <p className="font-medium text-sm">{node.hostname}</p>
            <p className="text-xs text-muted-foreground">:{node.port}</p>
          </div>
        </div>
        <Button
          variant="ghost"
          size="sm"
          className="h-7 w-7 p-0 text-muted-foreground hover:text-destructive"
          onClick={onDelete}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      {node.status !== "offline" && (
        <>
          <div className="mt-3 text-xs">
            <p className="text-muted-foreground">{node.gpuName}</p>
            <div className="flex items-center gap-2 mt-1">
              <span>{node.gpuMemory} GB</span>
              <span className="text-muted-foreground">|</span>
              <span className={node.gpuUtilization > 80 ? "text-amber-500" : "text-green-500"}>
                {node.gpuUtilization}% util
              </span>
            </div>
          </div>

          {node.tags.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-2">
              {node.tags.map((tag) => (
                <span key={tag} className="rounded bg-muted px-1.5 py-0.5 text-xs">
                  {tag}
                </span>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
};

// =============================================================================
// GUIDE STEP
// =============================================================================

interface GuideStepProps {
  number: number;
  title: string;
  description: string;
  code?: string;
}

const GuideStep = ({ number, title, description, code }: GuideStepProps) => (
  <div className="flex gap-3">
    <div className="flex h-7 w-7 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-foreground">
      {number}
    </div>
    <div className="flex-1">
      <p className="font-semibold">{title}</p>
      <p className="text-sm text-muted-foreground mt-1">{description}</p>
      {code && (
        <div className="mt-2 flex items-center gap-2 rounded-md bg-muted px-3 py-2">
          <code className="text-sm font-mono">{code}</code>
          <Button variant="ghost" size="sm" className="h-6 w-6 p-0 ml-auto">
            <Copy className="h-3.5 w-3.5" />
          </Button>
        </div>
      )}
    </div>
  </div>
);

// =============================================================================
// FEATURE ITEM
// =============================================================================

interface FeatureItemProps {
  icon: React.ReactNode;
  title: string;
  description: string;
}

const FeatureItem = ({ icon, title, description }: FeatureItemProps) => (
  <div className="flex items-center gap-3">
    <div className="flex h-8 w-8 items-center justify-center rounded-md bg-muted text-primary">
      {icon}
    </div>
    <div>
      <p className="text-sm font-medium">{title}</p>
      <p className="text-xs text-muted-foreground">{description}</p>
    </div>
  </div>
);
