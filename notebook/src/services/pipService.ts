// Pip Service - Python package management

import apiClient from "./apiClient";

export interface InstalledPackage {
  name: string;
  version: string;
  location: string;
  requires: string[];
  requiredBy: string[];
}

export interface PackageInfo {
  name: string;
  version: string;
  summary: string;
  author: string;
  authorEmail?: string;
  license: string;
  homePage?: string;
  projectUrl?: string;
  requiresPython?: string;
  keywords: string[];
  classifiers: string[];
}

export interface PackageSearchResult {
  name: string;
  version: string;
  summary: string;
  score?: number;
}

export interface InstallProgress {
  status: "downloading" | "installing" | "complete" | "error";
  package: string;
  progress: number;
  message: string;
}

export interface InstallResult {
  success: boolean;
  package: string;
  version?: string;
  message: string;
  duration: number;
}

export interface UninstallResult {
  success: boolean;
  package: string;
  message: string;
}

export interface RequirementsParseResult {
  packages: Array<{
    name: string;
    version?: string;
    extras?: string[];
    markers?: string;
  }>;
  errors: string[];
}

interface PackageResponse {
  name: string;
  version: string;
  location: string;
  requires: string[];
  required_by: string[];
}

interface PackageInfoResponse {
  name: string;
  version: string;
  summary: string;
  author: string;
  author_email?: string;
  license: string;
  home_page?: string;
  project_url?: string;
  requires_python?: string;
  keywords: string[];
  classifiers: string[];
}

class PipService {
  private parsePackage(data: PackageResponse): InstalledPackage {
    return {
      name: data.name,
      version: data.version,
      location: data.location,
      requires: data.requires,
      requiredBy: data.required_by,
    };
  }

  private parsePackageInfo(data: PackageInfoResponse): PackageInfo {
    return {
      name: data.name,
      version: data.version,
      summary: data.summary,
      author: data.author,
      authorEmail: data.author_email,
      license: data.license,
      homePage: data.home_page,
      projectUrl: data.project_url,
      requiresPython: data.requires_python,
      keywords: data.keywords,
      classifiers: data.classifiers,
    };
  }

  // List installed packages
  async listPackages(): Promise<InstalledPackage[]> {
    const response = await apiClient.get<PackageResponse[]>("/api/pip/packages");
    return response.map((p) => this.parsePackage(p));
  }

  // Get package info
  async getPackageInfo(name: string): Promise<PackageInfo> {
    const response = await apiClient.get<PackageInfoResponse>(
      `/api/pip/packages/${encodeURIComponent(name)}`
    );
    return this.parsePackageInfo(response);
  }

  // Search packages on PyPI
  async searchPackages(query: string, limit: number = 20): Promise<PackageSearchResult[]> {
    const response = await apiClient.get<PackageSearchResult[]>(
      `/api/pip/search?query=${encodeURIComponent(query)}&limit=${limit}`
    );
    return response;
  }

  // Install package
  async installPackage(
    name: string,
    version?: string,
    upgrade: boolean = false
  ): Promise<InstallResult> {
    const response = await apiClient.post<{
      success: boolean;
      package: string;
      version?: string;
      message: string;
      duration: number;
    }>("/api/pip/install", {
      package: name,
      version,
      upgrade,
    });

    return response;
  }

  // Install multiple packages
  async installPackages(
    packages: Array<{ name: string; version?: string }>
  ): Promise<InstallResult[]> {
    const response = await apiClient.post<InstallResult[]>("/api/pip/install-multiple", {
      packages,
    });
    return response;
  }

  // Install from requirements.txt
  async installFromRequirements(content: string): Promise<InstallResult[]> {
    const response = await apiClient.post<InstallResult[]>("/api/pip/install-requirements", {
      content,
    });
    return response;
  }

  // Install with streaming progress
  async *installWithProgress(name: string, version?: string): AsyncGenerator<InstallProgress> {
    const stream = apiClient.streamSSE("/api/pip/install/stream", {
      package: name,
      version,
    });

    for await (const chunk of stream) {
      try {
        const data = JSON.parse(chunk);
        yield {
          status: data.status,
          package: data.package,
          progress: data.progress,
          message: data.message,
        };
      } catch {
        // Skip non-JSON chunks
      }
    }
  }

  // Uninstall package
  async uninstallPackage(name: string): Promise<UninstallResult> {
    const response = await apiClient.post<UninstallResult>("/api/pip/uninstall", {
      package: name,
    });
    return response;
  }

  // Uninstall multiple packages
  async uninstallPackages(names: string[]): Promise<UninstallResult[]> {
    const response = await apiClient.post<UninstallResult[]>("/api/pip/uninstall-multiple", {
      packages: names,
    });
    return response;
  }

  // Upgrade package
  async upgradePackage(name: string): Promise<InstallResult> {
    return this.installPackage(name, undefined, true);
  }

  // Check for outdated packages
  async checkOutdated(): Promise<
    Array<{
      name: string;
      currentVersion: string;
      latestVersion: string;
    }>
  > {
    const response = await apiClient.get<
      Array<{
        name: string;
        current_version: string;
        latest_version: string;
      }>
    >("/api/pip/outdated");

    return response.map((p) => ({
      name: p.name,
      currentVersion: p.current_version,
      latestVersion: p.latest_version,
    }));
  }

  // Generate requirements.txt
  async generateRequirements(): Promise<string> {
    const response = await apiClient.get<{ content: string }>("/api/pip/requirements");
    return response.content;
  }

  // Parse requirements.txt content
  async parseRequirements(content: string): Promise<RequirementsParseResult> {
    const response = await apiClient.post<{
      packages: Array<{
        name: string;
        version?: string;
        extras?: string[];
        markers?: string;
      }>;
      errors: string[];
    }>("/api/pip/parse-requirements", { content });

    return response;
  }

  // Check if package is installed
  async isInstalled(name: string): Promise<boolean> {
    try {
      await this.getPackageInfo(name);
      return true;
    } catch {
      return false;
    }
  }

  // Get package dependencies tree
  async getDependencyTree(name: string): Promise<{
    name: string;
    version: string;
    dependencies: Array<{
      name: string;
      version: string;
      required: string;
    }>;
  }> {
    const response = await apiClient.get<{
      name: string;
      version: string;
      dependencies: Array<{
        name: string;
        version: string;
        required: string;
      }>;
    }>(`/api/pip/packages/${encodeURIComponent(name)}/dependencies`);

    return response;
  }

  // Get PyPI package info (without installing)
  async getPyPIInfo(name: string): Promise<{
    name: string;
    version: string;
    summary: string;
    author: string;
    license: string;
    homePage?: string;
    projectUrls: Record<string, string>;
    releases: string[];
  }> {
    const response = await apiClient.get<{
      name: string;
      version: string;
      summary: string;
      author: string;
      license: string;
      home_page?: string;
      project_urls: Record<string, string>;
      releases: string[];
    }>(`/api/pip/pypi/${encodeURIComponent(name)}`);

    return {
      name: response.name,
      version: response.version,
      summary: response.summary,
      author: response.author,
      license: response.license,
      homePage: response.home_page,
      projectUrls: response.project_urls,
      releases: response.releases,
    };
  }

  // Create virtual environment
  async createVenv(path: string, pythonVersion?: string): Promise<{
    success: boolean;
    path: string;
    pythonVersion: string;
  }> {
    const response = await apiClient.post<{
      success: boolean;
      path: string;
      python_version: string;
    }>("/api/pip/venv/create", {
      path,
      python_version: pythonVersion,
    });

    return {
      success: response.success,
      path: response.path,
      pythonVersion: response.python_version,
    };
  }

  // List virtual environments
  async listVenvs(): Promise<
    Array<{
      name: string;
      path: string;
      pythonVersion: string;
      packagesCount: number;
    }>
  > {
    const response = await apiClient.get<
      Array<{
        name: string;
        path: string;
        python_version: string;
        packages_count: number;
      }>
    >("/api/pip/venv/list");

    return response.map((v) => ({
      name: v.name,
      path: v.path,
      pythonVersion: v.python_version,
      packagesCount: v.packages_count,
    }));
  }

  // Get pip version
  async getVersion(): Promise<string> {
    const response = await apiClient.get<{ version: string }>("/api/pip/version");
    return response.version;
  }

  // Check pip config
  async getConfig(): Promise<Record<string, string>> {
    const response = await apiClient.get<Record<string, string>>("/api/pip/config");
    return response;
  }
}

export const pipService = new PipService();
export default pipService;
