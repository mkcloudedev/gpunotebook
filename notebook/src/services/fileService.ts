// File Service - File management operations

import apiClient from "./apiClient";

export interface FileInfo {
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
  modifiedAt: Date;
  createdAt: Date;
  mimeType?: string;
  extension?: string;
}

export interface StorageInfo {
  usedBytes: number;
  totalBytes: number;
  freeBytes: number;
  usedPercent: number;
}

export interface FileContent {
  path: string;
  content: string;
  encoding: string;
  mimeType: string;
}

export interface DatasetPreview {
  path: string;
  format: string;
  columns: string[];
  rows: Array<Record<string, unknown>>;
  totalRows: number;
  schema: Array<{
    name: string;
    type: string;
    nullable: boolean;
  }>;
}

interface FileInfoResponse {
  name: string;
  path: string;
  file_type: "file" | "directory";
  size: number;
  modified_at: string;
  mime_type?: string | null;
}

interface FileListResponse {
  path: string;
  files: FileInfoResponse[];
}

class FileService {
  private parseFileInfo(data: FileInfoResponse): FileInfo {
    return {
      name: data.name,
      path: data.path,
      isDirectory: data.file_type === "directory",
      size: data.size,
      modifiedAt: new Date(data.modified_at),
      createdAt: new Date(data.modified_at), // Backend doesn't provide created_at
      mimeType: data.mime_type || undefined,
      extension: data.name.includes(".") ? data.name.split(".").pop() : undefined,
    };
  }

  async list(path: string = ""): Promise<FileInfo[]> {
    const response = await apiClient.get<FileListResponse>(`/api/files${path ? `?path=${encodeURIComponent(path)}` : ""}`);
    return (response.files || []).map((f) => this.parseFileInfo(f));
  }

  async getInfo(path: string): Promise<FileInfo> {
    const response = await apiClient.get<FileInfoResponse>(`/api/files/info?path=${encodeURIComponent(path)}`);
    return this.parseFileInfo(response);
  }

  async createDirectory(path: string): Promise<FileInfo> {
    const response = await apiClient.post<FileInfoResponse>("/api/files/directory", { path });
    return this.parseFileInfo(response);
  }

  async upload(file: File, destinationPath: string): Promise<FileInfo> {
    const response = await apiClient.uploadFile<FileInfoResponse>("/api/files/upload", file, {
      path: destinationPath,
    });
    return this.parseFileInfo(response);
  }

  async uploadMultiple(files: File[], destinationPath: string): Promise<FileInfo[]> {
    const results: FileInfo[] = [];
    for (const file of files) {
      const result = await this.upload(file, destinationPath);
      results.push(result);
    }
    return results;
  }

  async delete(path: string): Promise<void> {
    await apiClient.delete(`/api/files?path=${encodeURIComponent(path)}`);
  }

  async deleteMultiple(paths: string[]): Promise<void> {
    await apiClient.post("/api/files/delete-multiple", { paths });
  }

  async rename(oldPath: string, newPath: string): Promise<FileInfo> {
    const response = await apiClient.post<FileInfoResponse>("/api/files/rename", {
      old_path: oldPath,
      new_path: newPath,
    });
    return this.parseFileInfo(response);
  }

  async move(sourcePath: string, destinationPath: string): Promise<FileInfo> {
    const response = await apiClient.post<FileInfoResponse>("/api/files/move", {
      source_path: sourcePath,
      destination_path: destinationPath,
    });
    return this.parseFileInfo(response);
  }

  async copy(sourcePath: string, destinationPath: string): Promise<FileInfo> {
    const response = await apiClient.post<FileInfoResponse>("/api/files/copy", {
      source_path: sourcePath,
      destination_path: destinationPath,
    });
    return this.parseFileInfo(response);
  }

  async read(path: string): Promise<FileContent> {
    const response = await apiClient.get<{
      path: string;
      content: string;
      encoding: string;
      mime_type: string;
    }>(`/api/files/read?path=${encodeURIComponent(path)}`);

    return {
      path: response.path,
      content: response.content,
      encoding: response.encoding,
      mimeType: response.mime_type,
    };
  }

  async write(path: string, content: string): Promise<FileInfo> {
    const response = await apiClient.post<FileInfoResponse>("/api/files/write", {
      path,
      content,
    });
    return this.parseFileInfo(response);
  }

  async getDownloadUrl(path: string): Promise<string> {
    return `${apiClient.getBaseUrl()}/api/files/download?path=${encodeURIComponent(path)}`;
  }

  async download(path: string): Promise<Blob> {
    const url = await this.getDownloadUrl(path);
    const response = await fetch(url);
    return response.blob();
  }

  async getStorageInfo(): Promise<StorageInfo> {
    const response = await apiClient.get<{
      used_bytes: number;
      total_bytes: number;
      free_bytes: number;
      used_percent: number;
    }>("/api/files/storage");

    return {
      usedBytes: response.used_bytes,
      totalBytes: response.total_bytes,
      freeBytes: response.free_bytes,
      usedPercent: response.used_percent,
    };
  }

  // Dataset operations
  async previewDataset(path: string, limit: number = 100): Promise<DatasetPreview> {
    const response = await apiClient.get<{
      path: string;
      format: string;
      columns: string[];
      rows: Array<Record<string, unknown>>;
      total_rows: number;
      schema: Array<{
        name: string;
        type: string;
        nullable: boolean;
      }>;
    }>(`/api/files/preview?path=${encodeURIComponent(path)}&limit=${limit}`);

    return {
      path: response.path,
      format: response.format,
      columns: response.columns,
      rows: response.rows,
      totalRows: response.total_rows,
      schema: response.schema,
    };
  }

  // Search files
  async search(query: string, path: string = "/"): Promise<FileInfo[]> {
    const response = await apiClient.get<FileInfoResponse[]>(
      `/api/files/search?query=${encodeURIComponent(query)}&path=${encodeURIComponent(path)}`
    );
    return response.map((f) => this.parseFileInfo(f));
  }

  // Get file type icon based on extension
  getFileType(filename: string): "python" | "image" | "data" | "notebook" | "text" | "other" {
    const ext = filename.split(".").pop()?.toLowerCase() || "";

    if (ext === "py") return "python";
    if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"].includes(ext)) return "image";
    if (["csv", "json", "xlsx", "xls", "parquet", "feather", "pickle", "pkl"].includes(ext)) return "data";
    if (ext === "ipynb") return "notebook";
    if (["txt", "md", "rst", "yaml", "yml", "toml", "ini", "cfg", "log"].includes(ext)) return "text";
    return "other";
  }

  // Format file size
  formatSize(bytes: number): string {
    if (bytes === 0) return "0 B";
    const k = 1024;
    const sizes = ["B", "KB", "MB", "GB", "TB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
  }
}

export const fileService = new FileService();
export default fileService;
