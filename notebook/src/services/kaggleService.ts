// Kaggle Service - Integration with Kaggle API

import apiClient from "./apiClient";

export interface KaggleDataset {
  ref: string;
  title: string;
  owner: string;
  name: string;
  subtitle?: string;
  description?: string;
  downloadCount: number;
  voteCount: number;
  size: string;
  lastUpdated: Date;
  license?: string;
  tags?: string[];
}

export interface KaggleCompetition {
  ref: string;
  title: string;
  url: string;
  description: string;
  category: string;
  reward: string;
  teamCount: number;
  deadline: Date;
  userHasEntered: boolean;
  organizationName?: string;
  evaluationMetric?: string;
}

export interface KaggleKernel {
  ref: string;
  title: string;
  author: string;
  language: string;
  kernelType: string;
  totalVotes: number;
  lastRunTime: Date;
}

export interface KaggleSubmission {
  ref: string;
  fileName: string;
  date: Date;
  status: string;
  publicScore?: number;
  privateScore?: number;
}

interface KaggleDatasetResponse {
  ref: string;
  title: string;
  owner?: string;
  name?: string;
  subtitle?: string;
  description?: string;
  download_count?: number;
  downloadCount?: number;
  vote_count?: number;
  voteCount?: number;
  size: string;
  last_updated?: string;
  lastUpdated?: string;
  license?: string;
  tags?: string[];
  usabilityRating?: number;
}

interface KaggleCompetitionResponse {
  ref: string;
  title: string;
  url?: string;
  description?: string;
  category: string;
  reward: string;
  team_count?: number;
  teamCount?: number;
  deadline: string;
  user_has_entered?: boolean;
  userHasEntered?: boolean;
  organization_name?: string;
  evaluation_metric?: string;
}

class KaggleService {
  private parseDataset(data: KaggleDatasetResponse): KaggleDataset {
    // Parse owner/name from ref if not provided
    const refParts = data.ref?.split("/") || [];
    const owner = data.owner || refParts[0] || "";
    const name = data.name || refParts[1] || "";

    return {
      ref: data.ref,
      title: data.title,
      owner,
      name,
      subtitle: data.subtitle,
      description: data.description,
      downloadCount: data.download_count ?? data.downloadCount ?? 0,
      voteCount: data.vote_count ?? data.voteCount ?? 0,
      size: data.size,
      lastUpdated: new Date(data.last_updated || data.lastUpdated || Date.now()),
      license: data.license,
      tags: data.tags,
    };
  }

  private parseCompetition(data: KaggleCompetitionResponse): KaggleCompetition {
    return {
      ref: data.ref,
      title: data.title,
      url: data.url || `https://www.kaggle.com/c/${data.ref}`,
      description: data.description || "",
      category: data.category,
      reward: data.reward,
      teamCount: data.team_count ?? data.teamCount ?? 0,
      deadline: new Date(data.deadline),
      userHasEntered: data.user_has_entered ?? data.userHasEntered ?? false,
      organizationName: data.organization_name,
      evaluationMetric: data.evaluation_metric,
    };
  }

  // Check if Kaggle is configured
  async isConfigured(): Promise<boolean> {
    try {
      const response = await apiClient.get<{ configured: boolean }>("/api/kaggle/status");
      return response.configured;
    } catch {
      return false;
    }
  }

  // Get current user info
  async getUser(): Promise<{ username: string; displayName: string; tier: string } | null> {
    try {
      return await apiClient.get("/api/kaggle/user");
    } catch {
      return null;
    }
  }

  // Datasets
  async searchDatasets(query: string, page: number = 1): Promise<KaggleDataset[]> {
    const response = await apiClient.get<KaggleDatasetResponse[]>(
      `/api/kaggle/datasets/search?query=${encodeURIComponent(query)}&page=${page}`
    );
    return response.map((d) => this.parseDataset(d));
  }

  async listDatasets(page: number = 1, sortBy: string = "hottest"): Promise<KaggleDataset[]> {
    const response = await apiClient.get<{ datasets: KaggleDatasetResponse[]; total: number }>(
      `/api/kaggle/datasets/list?page=${page}&sort_by=${sortBy}`
    );
    return response.datasets.map((d) => this.parseDataset(d));
  }

  async getDataset(owner: string, name: string): Promise<KaggleDataset> {
    const response = await apiClient.get<KaggleDatasetResponse>(
      `/api/kaggle/datasets/${owner}/${name}`
    );
    return this.parseDataset(response);
  }

  async downloadDataset(ref: string, destinationPath: string): Promise<{ success: boolean; path: string }> {
    return apiClient.post("/api/kaggle/datasets/download", {
      ref,
      destination_path: destinationPath,
    });
  }

  // Competitions
  async listCompetitions(page: number = 1, category?: string): Promise<KaggleCompetition[]> {
    const url = category
      ? `/api/kaggle/competitions/list?page=${page}&category=${category}`
      : `/api/kaggle/competitions/list?page=${page}`;
    const response = await apiClient.get<{ competitions: KaggleCompetitionResponse[]; total: number }>(url);
    return response.competitions.map((c) => this.parseCompetition(c));
  }

  async searchCompetitions(query: string): Promise<KaggleCompetition[]> {
    const response = await apiClient.get<KaggleCompetitionResponse[]>(
      `/api/kaggle/competitions/search?query=${encodeURIComponent(query)}`
    );
    return response.map((c) => this.parseCompetition(c));
  }

  async getCompetition(ref: string): Promise<KaggleCompetition> {
    const response = await apiClient.get<KaggleCompetitionResponse>(
      `/api/kaggle/competitions/${ref}`
    );
    return this.parseCompetition(response);
  }

  async downloadCompetitionData(ref: string, destinationPath: string): Promise<{ success: boolean; path: string }> {
    return apiClient.post("/api/kaggle/competitions/download", {
      ref,
      destination_path: destinationPath,
    });
  }

  async submitToCompetition(ref: string, filePath: string, message?: string): Promise<KaggleSubmission> {
    const response = await apiClient.post<{
      ref: string;
      file_name: string;
      date: string;
      status: string;
      public_score?: number;
      private_score?: number;
    }>("/api/kaggle/competitions/submit", {
      ref,
      file_path: filePath,
      message,
    });

    return {
      ref: response.ref,
      fileName: response.file_name,
      date: new Date(response.date),
      status: response.status,
      publicScore: response.public_score,
      privateScore: response.private_score,
    };
  }

  async getSubmissions(competitionRef: string): Promise<KaggleSubmission[]> {
    const response = await apiClient.get<
      Array<{
        ref: string;
        file_name: string;
        date: string;
        status: string;
        public_score?: number;
        private_score?: number;
      }>
    >(`/api/kaggle/competitions/${competitionRef}/submissions`);

    return response.map((s) => ({
      ref: s.ref,
      fileName: s.file_name,
      date: new Date(s.date),
      status: s.status,
      publicScore: s.public_score,
      privateScore: s.private_score,
    }));
  }

  // Kernels/Notebooks
  async listKernels(page: number = 1, language?: string): Promise<KaggleKernel[]> {
    const url = language
      ? `/api/kaggle/kernels/list?page=${page}&language=${language}`
      : `/api/kaggle/kernels/list?page=${page}`;

    const response = await apiClient.get<{
      kernels: Array<{
        ref: string;
        title: string;
        author: string;
        language: string;
        lastRunTime: string;
        totalVotes: number;
      }>;
      total: number;
    }>(url);

    return response.kernels.map((k) => ({
      ref: k.ref,
      title: k.title,
      author: k.author,
      language: k.language,
      kernelType: "notebook",
      totalVotes: k.totalVotes,
      lastRunTime: new Date(k.lastRunTime),
    }));
  }

  async pullKernel(ref: string, destinationPath: string): Promise<{ success: boolean; path: string }> {
    return apiClient.post("/api/kaggle/kernels/pull", {
      ref,
      destination_path: destinationPath,
    });
  }
}

export const kaggleService = new KaggleService();
export default kaggleService;
