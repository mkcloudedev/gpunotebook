// Kernel Service - Manage IPython kernels

import apiClient from "./apiClient";

export interface Kernel {
  id: string;
  name: string;
  status: KernelStatus;
  notebookId?: string;
  lastActivity: Date;
  executionCount: number;
  connections: number;
}

export enum KernelStatus {
  IDLE = "idle",
  BUSY = "busy",
  STARTING = "starting",
  DEAD = "dead",
  RESTARTING = "restarting",
}

export interface KernelSpec {
  name: string;
  displayName: string;
  language: string;
  argv: string[];
  interruptMode?: string;
}

interface KernelResponse {
  id: string;
  name: string;
  status: string;
  notebook_id?: string;
  last_activity?: string;
  created_at?: string;
  execution_count?: number;
  connections?: number;
}

class KernelService {
  private parseKernel(data: KernelResponse): Kernel {
    return {
      id: data.id,
      name: data.name,
      status: data.status as KernelStatus,
      notebookId: data.notebook_id,
      lastActivity: new Date(data.last_activity || data.created_at || Date.now()),
      executionCount: data.execution_count || 0,
      connections: data.connections || 0,
    };
  }

  async list(): Promise<Kernel[]> {
    const response = await apiClient.get<KernelResponse[]>("/api/kernels");
    return response.map(this.parseKernel);
  }

  async get(id: string): Promise<Kernel> {
    const response = await apiClient.get<KernelResponse>(`/api/kernels/${id}`);
    return this.parseKernel(response);
  }

  async create(name: string = "python3", notebookId?: string): Promise<Kernel> {
    const response = await apiClient.post<KernelResponse>("/api/kernels", {
      name,
      notebook_id: notebookId,
    });
    return this.parseKernel(response);
  }

  async restart(id: string): Promise<Kernel> {
    const response = await apiClient.post<KernelResponse>(`/api/kernels/${id}/restart`, {});
    return this.parseKernel(response);
  }

  async interrupt(id: string): Promise<void> {
    await apiClient.post(`/api/kernels/${id}/interrupt`, {});
  }

  async shutdown(id: string): Promise<void> {
    await apiClient.delete(`/api/kernels/${id}`);
  }

  async shutdownAll(): Promise<void> {
    const kernels = await this.list();
    await Promise.all(kernels.map((k) => this.shutdown(k.id)));
  }

  async getSpecs(): Promise<Record<string, KernelSpec>> {
    return apiClient.get<Record<string, KernelSpec>>("/api/kernels/specs");
  }

  // Get or create kernel for a notebook
  async getOrCreateForNotebook(notebookId: string): Promise<Kernel> {
    const kernels = await this.list();
    const existing = kernels.find((k) => k.notebookId === notebookId && k.status !== KernelStatus.DEAD);

    if (existing) {
      return existing;
    }

    return this.create("python3", notebookId);
  }
}

export const kernelService = new KernelService();
export default kernelService;
