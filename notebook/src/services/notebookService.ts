// Notebook Service - CRUD operations for notebooks

import apiClient from "./apiClient";

export interface CellOutput {
  outputType: "stream" | "execute_result" | "display_data" | "error";
  text?: string;
  data?: Record<string, unknown>;
  ename?: string;
  evalue?: string;
  traceback?: string[];
}

export interface Cell {
  id: string;
  cellType: "code" | "markdown";
  source: string;
  outputs: CellOutput[];
  executionCount?: number;
  metadata?: Record<string, unknown>;
}

export interface Notebook {
  id: string;
  name: string;
  path: string;
  cells: Cell[];
  metadata: Record<string, unknown>;
  kernelSpec?: {
    name: string;
    displayName: string;
    language: string;
  };
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateNotebookParams {
  name: string;
  path?: string;
  templateId?: string;
}

export interface NotebookTemplate {
  id: string;
  name: string;
  description: string;
  cells: Cell[];
  category: string;
}

interface NotebookResponse {
  id: string;
  name: string;
  path?: string;
  cells: Array<{
    id: string;
    cell_type: string;
    source: string;
    outputs: Array<{
      output_type: string;
      text?: string;
      data?: Record<string, unknown>;
      ename?: string;
      evalue?: string;
      traceback?: string[];
    }>;
    execution_count?: number;
    metadata?: Record<string, unknown>;
  }>;
  metadata: Record<string, unknown> & {
    created_at?: string;
    modified_at?: string;
  };
  kernel_spec?: {
    name: string;
    display_name: string;
    language: string;
  };
  kernel_id?: string | null;
  created_at?: string;
  updated_at?: string;
}

class NotebookService {
  private parseNotebook(data: NotebookResponse): Notebook {
    // Get dates from metadata or root level (backend may use either)
    const createdAt = data.created_at || data.metadata?.created_at || new Date().toISOString();
    const updatedAt = data.updated_at || data.metadata?.modified_at || createdAt;

    return {
      id: data.id,
      name: data.name,
      path: data.path || "",
      cells: (data.cells || []).map((cell) => ({
        id: cell.id,
        cellType: cell.cell_type as "code" | "markdown",
        source: cell.source,
        outputs: (cell.outputs || []).map((o) => ({
          outputType: o.output_type as CellOutput["outputType"],
          text: o.text,
          data: o.data,
          ename: o.ename,
          evalue: o.evalue,
          traceback: o.traceback,
        })),
        executionCount: cell.execution_count,
        metadata: cell.metadata,
      })),
      metadata: data.metadata,
      kernelSpec: data.kernel_spec
        ? {
            name: data.kernel_spec.name,
            displayName: data.kernel_spec.display_name,
            language: data.kernel_spec.language,
          }
        : undefined,
      createdAt: new Date(createdAt),
      updatedAt: new Date(updatedAt),
    };
  }

  private serializeNotebook(notebook: Partial<Notebook>): Record<string, unknown> {
    return {
      name: notebook.name,
      path: notebook.path,
      cells: notebook.cells?.map((cell) => ({
        id: cell.id,
        cell_type: cell.cellType,
        source: cell.source,
        outputs: cell.outputs.map((o) => ({
          output_type: o.outputType,
          text: o.text,
          data: o.data,
          ename: o.ename,
          evalue: o.evalue,
          traceback: o.traceback,
        })),
        execution_count: cell.executionCount,
        metadata: cell.metadata,
      })),
      metadata: notebook.metadata,
    };
  }

  async list(): Promise<Notebook[]> {
    const response = await apiClient.get<NotebookResponse[]>("/api/notebooks");
    return response.map((n) => this.parseNotebook(n));
  }

  async get(id: string): Promise<Notebook> {
    const response = await apiClient.get<NotebookResponse>(`/api/notebooks/${id}`);
    return this.parseNotebook(response);
  }

  async create(params: CreateNotebookParams): Promise<Notebook> {
    const response = await apiClient.post<NotebookResponse>("/api/notebooks", {
      name: params.name,
      path: params.path,
      template_id: params.templateId,
    });
    return this.parseNotebook(response);
  }

  async update(id: string, notebook: Partial<Notebook>): Promise<Notebook> {
    const response = await apiClient.put<NotebookResponse>(
      `/api/notebooks/${id}`,
      this.serializeNotebook(notebook)
    );
    return this.parseNotebook(response);
  }

  async delete(id: string): Promise<void> {
    await apiClient.delete(`/api/notebooks/${id}`);
  }

  async duplicate(id: string, newName?: string): Promise<Notebook> {
    const response = await apiClient.post<NotebookResponse>(`/api/notebooks/${id}/duplicate`, {
      name: newName,
    });
    return this.parseNotebook(response);
  }

  async rename(id: string, newName: string): Promise<Notebook> {
    const response = await apiClient.patch<NotebookResponse>(`/api/notebooks/${id}`, {
      name: newName,
    });
    return this.parseNotebook(response);
  }

  // Cell operations
  async addCell(notebookId: string, cellType: "code" | "markdown", afterCellId?: string): Promise<Cell> {
    const response = await apiClient.post<{
      id: string;
      cell_type: string;
      source: string;
      outputs: Array<unknown>;
      execution_count?: number;
      metadata?: Record<string, unknown>;
    }>(`/api/notebooks/${notebookId}/cells`, {
      cell_type: cellType,
      after_cell_id: afterCellId,
    });

    return {
      id: response.id,
      cellType: response.cell_type as "code" | "markdown",
      source: response.source,
      outputs: [],
      executionCount: response.execution_count,
      metadata: response.metadata,
    };
  }

  async updateCell(notebookId: string, cellId: string, source: string): Promise<void> {
    await apiClient.patch(`/api/notebooks/${notebookId}/cells/${cellId}`, {
      source,
    });
  }

  async deleteCell(notebookId: string, cellId: string): Promise<void> {
    await apiClient.delete(`/api/notebooks/${notebookId}/cells/${cellId}`);
  }

  async moveCells(notebookId: string, cellIds: string[], afterCellId?: string): Promise<void> {
    await apiClient.post(`/api/notebooks/${notebookId}/cells/move`, {
      cell_ids: cellIds,
      after_cell_id: afterCellId,
    });
  }

  // Import/Export
  async importFromFile(file: File): Promise<Notebook> {
    const response = await apiClient.uploadFile<NotebookResponse>("/api/notebooks/import", file);
    return this.parseNotebook(response);
  }

  async exportToIpynb(id: string): Promise<Blob> {
    const response = await fetch(`${apiClient.getBaseUrl()}/api/notebooks/${id}/export/ipynb`);
    return response.blob();
  }

  async exportToPython(id: string): Promise<string> {
    return apiClient.get<string>(`/api/notebooks/${id}/export/python`);
  }

  async exportToHtml(id: string): Promise<string> {
    return apiClient.get<string>(`/api/notebooks/${id}/export/html`);
  }

  // Templates
  async getTemplates(): Promise<NotebookTemplate[]> {
    return apiClient.get<NotebookTemplate[]>("/api/notebooks/templates");
  }

  async createFromTemplate(templateId: string, name: string): Promise<Notebook> {
    const response = await apiClient.post<NotebookResponse>("/api/notebooks", {
      name,
      template_id: templateId,
    });
    return this.parseNotebook(response);
  }

  // Clear all outputs
  async clearOutputs(id: string): Promise<void> {
    await apiClient.post(`/api/notebooks/${id}/clear-outputs`, {});
  }

  // Run all cells
  async runAll(id: string): Promise<void> {
    await apiClient.post(`/api/notebooks/${id}/run-all`, {});
  }
}

export const notebookService = new NotebookService();
export default notebookService;
