/**
 * Docker service for container and image management.
 */
import { apiClient } from "./apiClient";

// ==================== INTERFACES ====================

export interface Container {
  id: string;
  name: string;
  image: string;
  status: string;
  state: string;
  ports: string;
  created: string;
  size: string;
}

export interface ContainerState {
  status: string;
  running: boolean;
  paused: boolean;
  restarting: boolean;
  started_at: string;
  finished_at: string;
  exit_code: number;
}

export interface ContainerDetail {
  id: string;
  name: string;
  image: string;
  created: string;
  state: ContainerState;
  ports: Record<string, Array<{ HostIp: string; HostPort: string }>>;
  env: string[];
  cmd: string[];
  labels: Record<string, string>;
  mounts: Array<{
    Type: string;
    Source: string;
    Destination: string;
    Mode: string;
    RW: boolean;
  }>;
}

export interface ContainerStats {
  container_id: string;
  name: string;
  cpu_percent: string;
  memory_usage: string;
  memory_percent: string;
  network_io: string;
  block_io: string;
  pids: string;
}

export interface Image {
  id: string;
  repository: string;
  tag: string;
  created: string;
  size: string;
}

export interface DockerSystemInfo {
  containers: number;
  containers_running: number;
  containers_paused: number;
  containers_stopped: number;
  images: number;
  server_version: string;
  storage_driver: string;
  memory_total: number;
  cpus: number;
  os: string;
  kernel_version: string;
}

export interface DockerSystemStatus {
  disk_usage: Array<{
    Type: string;
    Size: string;
    Reclaimable: string;
    TotalCount: string;
    Active: string;
  }>;
  info: DockerSystemInfo | null;
}

export interface RunContainerRequest {
  image: string;
  name?: string;
  ports?: Record<string, string>;
  env?: Record<string, string>;
  volumes?: Record<string, string>;
  restart_policy?: string;
  command?: string;
}

// ==================== CONTAINER NOTEBOOK INTERFACES ====================

export interface NotebookContainer {
  container_id: string;
  name: string;
  image: string;
  status: string;
  created_at: string;
  kernel_type: string;
  workspace_path?: string;
  execution_count: number;
}

export interface ContainerExecutionResult {
  execution_id: string;
  container_id: string;
  status: string;
  outputs: Array<{
    output_type: string;
    name?: string;
    text?: string;
    ename?: string;
    evalue?: string;
    traceback?: string[];
  }>;
  error?: string;
  duration_ms: number;
}

export interface CreateNotebookContainerRequest {
  name?: string;
  image?: string;
  environment?: Record<string, string>;
  gpu?: boolean;
  memory_limit?: string;
  cpu_limit?: number;
}

export interface QuickExecuteRequest {
  code: string;
  image?: string;
  packages?: string[];
  timeout?: number;
  cleanup?: boolean;
}

export interface OperationResponse {
  success: boolean;
  message: string;
}

// ==================== SERVICE ====================

class DockerService {
  /**
   * Check if Docker is available.
   */
  async getStatus(): Promise<{ available: boolean }> {
    return apiClient.get("/api/docker/status");
  }

  /**
   * Get Docker system information.
   */
  async getSystemInfo(): Promise<DockerSystemStatus> {
    return apiClient.get("/api/docker/system");
  }

  // ==================== CONTAINERS ====================

  /**
   * List all containers.
   */
  async listContainers(all: boolean = true): Promise<Container[]> {
    return apiClient.get(`/api/docker/containers?all=${all}`);
  }

  /**
   * Get container details.
   */
  async getContainer(containerId: string): Promise<ContainerDetail> {
    return apiClient.get(`/api/docker/containers/${containerId}`);
  }

  /**
   * Get container stats.
   */
  async getContainerStats(containerId: string): Promise<ContainerStats> {
    return apiClient.get(`/api/docker/containers/${containerId}/stats`);
  }

  /**
   * Get container logs.
   */
  async getContainerLogs(
    containerId: string,
    tail: number = 100,
    timestamps: boolean = false
  ): Promise<{ logs: string }> {
    return apiClient.get(
      `/api/docker/containers/${containerId}/logs?tail=${tail}&timestamps=${timestamps}`
    );
  }

  /**
   * Start a container.
   */
  async startContainer(containerId: string): Promise<OperationResponse> {
    return apiClient.post(`/api/docker/containers/${containerId}/start`, {});
  }

  /**
   * Stop a container.
   */
  async stopContainer(
    containerId: string,
    timeout: number = 10
  ): Promise<OperationResponse> {
    return apiClient.post(
      `/api/docker/containers/${containerId}/stop?timeout=${timeout}`,
      {}
    );
  }

  /**
   * Restart a container.
   */
  async restartContainer(
    containerId: string,
    timeout: number = 10
  ): Promise<OperationResponse> {
    return apiClient.post(
      `/api/docker/containers/${containerId}/restart?timeout=${timeout}`,
      {}
    );
  }

  /**
   * Remove a container.
   */
  async removeContainer(
    containerId: string,
    force: boolean = false
  ): Promise<OperationResponse> {
    return apiClient.delete(
      `/api/docker/containers/${containerId}?force=${force}`
    );
  }

  /**
   * Run a new container.
   */
  async runContainer(request: RunContainerRequest): Promise<OperationResponse> {
    return apiClient.post("/api/docker/containers", request);
  }

  /**
   * Execute command in container.
   */
  async execCommand(
    containerId: string,
    command: string,
    workdir?: string
  ): Promise<{ success: boolean; stdout: string; stderr: string }> {
    return apiClient.post(`/api/docker/containers/${containerId}/exec`, {
      command,
      workdir,
    });
  }

  // ==================== IMAGES ====================

  /**
   * List all images.
   */
  async listImages(): Promise<Image[]> {
    return apiClient.get("/api/docker/images");
  }

  /**
   * Pull an image.
   */
  async pullImage(imageName: string): Promise<OperationResponse> {
    return apiClient.post(`/api/docker/images/pull?image=${encodeURIComponent(imageName)}`, {});
  }

  /**
   * Pull an image with streaming progress.
   */
  async *pullImageStream(imageName: string): AsyncGenerator<{ type: string; message?: string; success?: boolean }> {
    const response = await fetch(`/api/docker/images/pull/stream?image=${encodeURIComponent(imageName)}`, {
      method: "POST",
    });

    if (!response.ok) {
      throw new Error(`Failed to pull image: ${response.statusText}`);
    }

    const reader = response.body?.getReader();
    if (!reader) {
      throw new Error("No response body");
    }

    const decoder = new TextDecoder();
    let buffer = "";

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const data = line.slice(6);
            if (data === "[DONE]") {
              return;
            }
            try {
              yield JSON.parse(data);
            } catch {
              // Ignore parse errors
            }
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  /**
   * Remove an image.
   */
  async removeImage(
    imageId: string,
    force: boolean = false
  ): Promise<OperationResponse> {
    return apiClient.delete(`/api/docker/images/${imageId}?force=${force}`);
  }

  // ==================== POLLING ====================

  /**
   * Start polling for container stats.
   */
  startStatsPolling(
    containerId: string,
    callback: (stats: ContainerStats) => void,
    interval: number = 2000
  ): () => void {
    let active = true;

    const poll = async () => {
      if (!active) return;

      try {
        const stats = await this.getContainerStats(containerId);
        if (active) {
          callback(stats);
        }
      } catch {
        // Container might not be running
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

  // ==================== CONTAINER NOTEBOOKS ====================

  /**
   * Get available notebook container images.
   */
  async getNotebookImages(): Promise<{ images: Array<{ id: string; name: string; description: string }> }> {
    return apiClient.get("/api/container-notebooks/images");
  }

  /**
   * Create a new notebook container.
   */
  async createNotebookContainer(request: CreateNotebookContainerRequest): Promise<NotebookContainer> {
    return apiClient.post("/api/container-notebooks/containers", request);
  }

  /**
   * List all notebook containers.
   */
  async listNotebookContainers(): Promise<NotebookContainer[]> {
    return apiClient.get("/api/container-notebooks/containers");
  }

  /**
   * Get a specific notebook container.
   */
  async getNotebookContainer(containerId: string): Promise<NotebookContainer> {
    return apiClient.get(`/api/container-notebooks/containers/${containerId}`);
  }

  /**
   * Execute code in a notebook container.
   */
  async executeInContainer(containerId: string, code: string, timeout: number = 300): Promise<ContainerExecutionResult> {
    return apiClient.post(`/api/container-notebooks/containers/${containerId}/execute`, {
      code,
      timeout,
    });
  }

  /**
   * Start a notebook container.
   */
  async startNotebookContainer(containerId: string): Promise<OperationResponse> {
    return apiClient.post(`/api/container-notebooks/containers/${containerId}/start`, {});
  }

  /**
   * Stop a notebook container.
   */
  async stopNotebookContainer(containerId: string): Promise<OperationResponse> {
    return apiClient.post(`/api/container-notebooks/containers/${containerId}/stop`, {});
  }

  /**
   * Remove a notebook container.
   */
  async removeNotebookContainer(containerId: string, force: boolean = false): Promise<OperationResponse> {
    return apiClient.delete(`/api/container-notebooks/containers/${containerId}?force=${force}`);
  }

  /**
   * Install a package in a notebook container.
   */
  async installContainerPackage(containerId: string, packageName: string, upgrade: boolean = false): Promise<{ success: boolean; package: string; output: string }> {
    return apiClient.post(`/api/container-notebooks/containers/${containerId}/packages/install`, {
      package: packageName,
      upgrade,
    });
  }

  /**
   * List packages in a notebook container.
   */
  async listContainerPackages(containerId: string): Promise<{ packages: Array<{ name: string; version: string }> }> {
    return apiClient.get(`/api/container-notebooks/containers/${containerId}/packages`);
  }

  /**
   * Quick execute code in an ephemeral container.
   */
  async quickExecuteInContainer(request: QuickExecuteRequest): Promise<ContainerExecutionResult & { cleaned_up?: boolean }> {
    return apiClient.post("/api/container-notebooks/quick-execute", request);
  }

  /**
   * List files in a container.
   */
  async listContainerFiles(containerId: string, path: string = "/workspace"): Promise<{ path: string; files: Array<{ name: string; size: number; is_directory: boolean }> }> {
    return apiClient.get(`/api/container-notebooks/containers/${containerId}/files?path=${encodeURIComponent(path)}`);
  }
}

export const dockerService = new DockerService();
