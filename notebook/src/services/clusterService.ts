// Cluster Service - Manage distributed GPU nodes

import apiClient from "./apiClient";

export type NodeStatus = "online" | "offline" | "busy" | "error" | "unknown";

export interface ClusterNode {
  id: string;
  hostname: string;
  port: number;
  status: NodeStatus;
  gpuName: string;
  gpuMemory: number;
  gpuMemoryUsed: number;
  gpuUtilization: number;
  cpuCount: number;
  cpuUtilization: number;
  memoryTotal: number;
  memoryUsed: number;
  tags: string[];
  lastSeen: Date;
  createdAt: Date;
}

export interface NodeHealth {
  nodeId: string;
  healthy: boolean;
  latencyMs: number;
  gpuAvailable: boolean;
  kernelReady: boolean;
  errors: string[];
}

export interface ClusterStats {
  totalNodes: number;
  onlineNodes: number;
  busyNodes: number;
  offlineNodes: number;
  totalGpuMemory: number;
  usedGpuMemory: number;
  averageGpuUtilization: number;
  runningKernels: number;
}

export interface AddNodeParams {
  hostname: string;
  port: number;
  tags?: string[];
}

interface NodeResponse {
  id: string;
  hostname: string;
  port: number;
  status: string;
  gpu_name: string;
  gpu_memory: number;
  gpu_memory_used: number;
  gpu_utilization: number;
  cpu_count: number;
  cpu_utilization: number;
  memory_total: number;
  memory_used: number;
  tags: string[];
  last_seen: string;
  created_at: string;
}

class ClusterService {
  private parseNode(data: NodeResponse): ClusterNode {
    return {
      id: data.id,
      hostname: data.hostname,
      port: data.port,
      status: data.status as NodeStatus,
      gpuName: data.gpu_name,
      gpuMemory: data.gpu_memory,
      gpuMemoryUsed: data.gpu_memory_used,
      gpuUtilization: data.gpu_utilization,
      cpuCount: data.cpu_count,
      cpuUtilization: data.cpu_utilization,
      memoryTotal: data.memory_total,
      memoryUsed: data.memory_used,
      tags: data.tags,
      lastSeen: new Date(data.last_seen),
      createdAt: new Date(data.created_at),
    };
  }

  // Nodes
  async listNodes(): Promise<ClusterNode[]> {
    const response = await apiClient.get<NodeResponse[]>("/api/cluster/nodes");
    return response.map((n) => this.parseNode(n));
  }

  async getNode(id: string): Promise<ClusterNode> {
    const response = await apiClient.get<NodeResponse>(`/api/cluster/nodes/${id}`);
    return this.parseNode(response);
  }

  async addNode(params: AddNodeParams): Promise<ClusterNode> {
    const response = await apiClient.post<NodeResponse>("/api/cluster/nodes", {
      hostname: params.hostname,
      port: params.port,
      tags: params.tags,
    });
    return this.parseNode(response);
  }

  async removeNode(id: string): Promise<void> {
    await apiClient.delete(`/api/cluster/nodes/${id}`);
  }

  async updateNodeTags(id: string, tags: string[]): Promise<ClusterNode> {
    const response = await apiClient.patch<NodeResponse>(`/api/cluster/nodes/${id}`, { tags });
    return this.parseNode(response);
  }

  // Health checks
  async checkNodeHealth(id: string): Promise<NodeHealth> {
    const response = await apiClient.get<{
      node_id: string;
      healthy: boolean;
      latency_ms: number;
      gpu_available: boolean;
      kernel_ready: boolean;
      errors: string[];
    }>(`/api/cluster/nodes/${id}/health`);

    return {
      nodeId: response.node_id,
      healthy: response.healthy,
      latencyMs: response.latency_ms,
      gpuAvailable: response.gpu_available,
      kernelReady: response.kernel_ready,
      errors: response.errors,
    };
  }

  async checkAllNodesHealth(): Promise<NodeHealth[]> {
    const nodes = await this.listNodes();
    const healthChecks = await Promise.allSettled(
      nodes.map((n) => this.checkNodeHealth(n.id))
    );

    return healthChecks
      .filter((r): r is PromiseFulfilledResult<NodeHealth> => r.status === "fulfilled")
      .map((r) => r.value);
  }

  // Stats
  async getStats(): Promise<ClusterStats> {
    const response = await apiClient.get<{
      total_nodes: number;
      online_nodes: number;
      busy_nodes: number;
      offline_nodes: number;
      total_gpu_memory: number;
      used_gpu_memory: number;
      average_gpu_utilization: number;
      running_kernels: number;
    }>("/api/cluster/stats");

    return {
      totalNodes: response.total_nodes,
      onlineNodes: response.online_nodes,
      busyNodes: response.busy_nodes,
      offlineNodes: response.offline_nodes,
      totalGpuMemory: response.total_gpu_memory,
      usedGpuMemory: response.used_gpu_memory,
      averageGpuUtilization: response.average_gpu_utilization,
      runningKernels: response.running_kernels,
    };
  }

  // Node selection
  async selectBestNode(tags?: string[]): Promise<ClusterNode | null> {
    try {
      const response = await apiClient.post<NodeResponse | null>("/api/cluster/select-node", {
        tags,
      });
      return response ? this.parseNode(response) : null;
    } catch {
      return null;
    }
  }

  async getNodesByTag(tag: string): Promise<ClusterNode[]> {
    const response = await apiClient.get<NodeResponse[]>(
      `/api/cluster/nodes?tag=${encodeURIComponent(tag)}`
    );
    return response.map((n) => this.parseNode(n));
  }

  // Kernel management on nodes
  async createKernelOnNode(nodeId: string, kernelName: string = "python3"): Promise<{
    kernelId: string;
    nodeId: string;
    wsUrl: string;
  }> {
    return apiClient.post(`/api/cluster/nodes/${nodeId}/kernels`, {
      kernel_name: kernelName,
    });
  }

  async shutdownKernelOnNode(nodeId: string, kernelId: string): Promise<void> {
    await apiClient.delete(`/api/cluster/nodes/${nodeId}/kernels/${kernelId}`);
  }

  // Auto-scaling (if supported)
  async getAutoScaleConfig(): Promise<{
    enabled: boolean;
    minNodes: number;
    maxNodes: number;
    scaleUpThreshold: number;
    scaleDownThreshold: number;
  }> {
    const response = await apiClient.get<{
      enabled: boolean;
      min_nodes: number;
      max_nodes: number;
      scale_up_threshold: number;
      scale_down_threshold: number;
    }>("/api/cluster/autoscale");

    return {
      enabled: response.enabled,
      minNodes: response.min_nodes,
      maxNodes: response.max_nodes,
      scaleUpThreshold: response.scale_up_threshold,
      scaleDownThreshold: response.scale_down_threshold,
    };
  }

  async updateAutoScaleConfig(config: {
    enabled?: boolean;
    minNodes?: number;
    maxNodes?: number;
    scaleUpThreshold?: number;
    scaleDownThreshold?: number;
  }): Promise<void> {
    await apiClient.put("/api/cluster/autoscale", {
      enabled: config.enabled,
      min_nodes: config.minNodes,
      max_nodes: config.maxNodes,
      scale_up_threshold: config.scaleUpThreshold,
      scale_down_threshold: config.scaleDownThreshold,
    });
  }

  // Polling for real-time updates
  startPolling(callback: (nodes: ClusterNode[]) => void, interval: number = 5000): () => void {
    let active = true;

    const poll = async () => {
      if (!active) return;

      try {
        const nodes = await this.listNodes();
        if (active) {
          callback(nodes);
        }
      } catch (error) {
        console.error("Failed to poll cluster nodes:", error);
      }

      if (active) {
        setTimeout(poll, interval);
      }
    };

    poll();

    return () => {
      active = false;
    };
  }
}

export const clusterService = new ClusterService();
export default clusterService;
