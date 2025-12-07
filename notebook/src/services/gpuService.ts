// GPU Service - Monitor GPU metrics

import apiClient from "./apiClient";

export interface GPUStatus {
  index: number;
  name: string;
  uuid: string;
  temperature: number;
  utilizationGpu: number;
  utilizationMemory: number;
  memoryUsed: number;
  memoryTotal: number;
  memoryFree: number;
  powerDraw: number;
  powerLimit: number;
  fanSpeed?: number;
  cudaVersion: string;
  driverVersion: string;
}

export interface GPUProcess {
  pid: number;
  name: string;
  memoryMb: number;
  gpuIndex: number;
}

export interface GPUSystemStatus {
  hasGpu: boolean;
  gpuCount: number;
  gpus: GPUStatus[];
  primaryGpu?: GPUStatus;
  processes: GPUProcess[];
  totalMemoryUsed: number;
  totalMemoryTotal: number;
  averageUtilization: number;
  cudaAvailable: boolean;
}

export interface GPUHistoryPoint {
  timestamp: Date;
  utilizationGpu: number;
  utilizationMemory: number;
  memoryUsed: number;
  temperature: number;
  powerDraw: number;
}

interface GPUStatusResponse {
  index: number;
  name: string;
  uuid: string;
  temperature_c: number;
  utilization_percent: number;
  memory_used_mb: number;
  memory_total_mb: number;
  memory_free_mb: number;
  power_draw_w: number;
  power_limit_w: number;
  fan_speed?: number;
  processes: Array<{
    pid: number;
    name: string;
    memory_used_mb: number;
    gpu_index: number;
  }>;
}

interface GPUSystemResponse {
  driver_version: string;
  cuda_version: string;
  gpu_count: number;
  gpus: GPUStatusResponse[];
}

class GPUService {
  private parseGPU(data: GPUStatusResponse, driverVersion: string, cudaVersion: string): GPUStatus {
    return {
      index: data.index ?? 0,
      name: data.name ?? "Unknown GPU",
      uuid: data.uuid ?? "",
      temperature: data.temperature_c ?? 0,
      utilizationGpu: data.utilization_percent ?? 0,
      utilizationMemory: 0, // Not provided by backend
      memoryUsed: data.memory_used_mb ?? 0,
      memoryTotal: data.memory_total_mb ?? 1, // Avoid division by zero
      memoryFree: data.memory_free_mb ?? 0,
      powerDraw: data.power_draw_w ?? 0,
      powerLimit: data.power_limit_w ?? 1, // Avoid division by zero
      fanSpeed: data.fan_speed,
      cudaVersion: cudaVersion ?? "",
      driverVersion: driverVersion ?? "",
    };
  }

  async getStatus(): Promise<GPUSystemStatus> {
    const response = await apiClient.get<GPUSystemResponse>("/api/gpu/status");

    const gpus = response.gpus.map((g) => this.parseGPU(g, response.driver_version, response.cuda_version));
    const primaryGpu = gpus.length > 0 ? gpus[0] : undefined;

    const totalMemoryUsed = gpus.reduce((sum, g) => sum + g.memoryUsed, 0);
    const totalMemoryTotal = gpus.reduce((sum, g) => sum + g.memoryTotal, 0);
    const averageUtilization =
      gpus.length > 0 ? gpus.reduce((sum, g) => sum + g.utilizationGpu, 0) / gpus.length : 0;

    // Collect all processes from all GPUs
    const allProcesses: GPUProcess[] = [];
    response.gpus.forEach((gpu, gpuIndex) => {
      if (gpu.processes) {
        gpu.processes.forEach((p) => {
          allProcesses.push({
            pid: p.pid,
            name: p.name,
            memoryMb: p.memory_used_mb || 0,
            gpuIndex: p.gpu_index ?? gpuIndex,
          });
        });
      }
    });

    return {
      hasGpu: response.gpu_count > 0,
      gpuCount: response.gpu_count,
      gpus,
      primaryGpu,
      processes: allProcesses,
      totalMemoryUsed,
      totalMemoryTotal,
      averageUtilization,
      cudaAvailable: response.gpu_count > 0,
    };
  }

  async getGPU(index: number): Promise<GPUStatus> {
    // Get full status to have driver/cuda versions
    const status = await this.getStatus();
    const gpu = status.gpus.find(g => g.index === index);
    if (!gpu) {
      throw new Error(`GPU ${index} not found`);
    }
    return gpu;
  }

  async getProcesses(): Promise<GPUProcess[]> {
    const response = await apiClient.get<
      Array<{
        pid: number;
        name: string;
        memory_mb: number;
        gpu_index: number;
      }>
    >("/api/gpu/processes");

    return response.map((p) => ({
      pid: p.pid,
      name: p.name,
      memoryMb: p.memory_mb,
      gpuIndex: p.gpu_index,
    }));
  }

  async getHistory(
    gpuIndex: number = 0,
    duration: "1h" | "6h" | "24h" | "7d" = "1h"
  ): Promise<GPUHistoryPoint[]> {
    const response = await apiClient.get<
      Array<{
        timestamp: string;
        utilization_gpu: number;
        utilization_memory: number;
        memory_used: number;
        temperature: number;
        power_draw: number;
      }>
    >(`/api/gpu/${gpuIndex}/history?duration=${duration}`);

    return response.map((p) => ({
      timestamp: new Date(p.timestamp),
      utilizationGpu: p.utilization_gpu,
      utilizationMemory: p.utilization_memory,
      memoryUsed: p.memory_used,
      temperature: p.temperature,
      powerDraw: p.power_draw,
    }));
  }

  // Poll for real-time updates
  startPolling(callback: (status: GPUSystemStatus) => void, interval: number = 2000): () => void {
    let active = true;

    const poll = async () => {
      if (!active) return;

      try {
        const status = await this.getStatus();
        if (active) {
          callback(status);
        }
      } catch (error) {
        console.error("Failed to poll GPU status:", error);
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

export const gpuService = new GPUService();
export default gpuService;
