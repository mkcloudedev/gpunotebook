/**
 * Dataset service for data operations and web scraping.
 */
import { apiClient } from "./apiClient";

// ==================== INTERFACES ====================

export interface DatasetInfo {
  name: string;
  path: string;
  size: number;
  format: string;
  modified_at: string;
}

export interface ColumnInfo {
  name: string;
  dtype: string;
  null_count: number;
  unique_count: number;
  min?: number;
  max?: number;
  mean?: number;
}

export interface DatasetPreview {
  path: string;
  rows: number;
  total_rows: number;
  columns: number;
  schema: ColumnInfo[];
  data: Record<string, unknown>[];
}

export interface DatasetStats {
  path: string;
  name: string;
  format: string;
  size: number;
  modified_at: string;
  stats: {
    rows: number;
    columns: number;
    memory_usage: number;
    null_count: number;
    duplicate_rows: number;
  };
  columns: ColumnInfo[];
}

export interface CleaningOperation {
  id: string;
  name: string;
  description: string;
}

export interface CleanResult {
  original_rows: number;
  final_rows: number;
  rows_removed: number;
  changes: string[];
  output_path: string;
}

export interface SplitResult {
  train_path: string;
  test_path: string;
  train_rows: number;
  test_rows: number;
  train_ratio: number;
  shuffled: boolean;
}

export interface MergeResult {
  output_path: string;
  rows: number;
  columns: number;
  merged_files: number;
}

export interface ExportResult {
  output_path: string;
  format: string;
  rows: number;
  size: number;
}

// ==================== SCRAPER INTERFACES ====================

export interface ScraperAgent {
  id: string;
  name: string;
  description: string;
}

export interface UserAgent {
  id: string;
  name: string;
  value: string;
}

export interface ScrapeConfig {
  url: string;
  agentType: string;
  userAgent: string;
  selectors?: Record<string, string>;
  outputName: string;
  outputFormat?: string;
  waitForSelector?: string;
  scrollPage?: boolean;
  timeout?: number;
}

export interface ScrapeResult {
  success: boolean;
  url: string;
  rows_extracted?: number;
  columns?: string[];
  output_path?: string;
  fetch_time?: number;
  error?: string;
}

export interface TableData {
  index: number;
  headers: string[];
  rows: string[][];
  row_count: number;
}

export interface LinkData {
  url: string;
  text: string;
  title?: string;
}

// ==================== SERVICE ====================

class DatasetService {
  // ==================== DATASET OPERATIONS ====================

  async listDatasets(): Promise<DatasetInfo[]> {
    const response = await apiClient.get<{ datasets: DatasetInfo[] }>(
      "/api/datasets"
    );
    return response.datasets || [];
  }

  async previewDataset(
    path: string,
    rows: number = 100,
    offset: number = 0
  ): Promise<DatasetPreview> {
    return apiClient.get(
      `/api/datasets/preview?path=${encodeURIComponent(path)}&rows=${rows}&offset=${offset}`
    );
  }

  async getDatasetInfo(path: string): Promise<DatasetStats> {
    return apiClient.get(
      `/api/datasets/info?path=${encodeURIComponent(path)}`
    );
  }

  async getCleaningOperations(): Promise<CleaningOperation[]> {
    const response = await apiClient.get<{ operations: CleaningOperation[] }>(
      "/api/datasets/operations"
    );
    return response.operations || [];
  }

  async cleanDataset(
    path: string,
    operations: string[],
    outputPath?: string
  ): Promise<CleanResult> {
    return apiClient.post("/api/datasets/clean", {
      path,
      operations,
      output_path: outputPath,
    });
  }

  async splitDataset(
    path: string,
    trainRatio: number = 0.8,
    shuffle: boolean = true,
    randomSeed: number = 42
  ): Promise<SplitResult> {
    return apiClient.post("/api/datasets/split", {
      path,
      train_ratio: trainRatio,
      shuffle,
      random_seed: randomSeed,
    });
  }

  async mergeDatasets(
    paths: string[],
    outputPath: string,
    mergeType: "concat" | "join" = "concat",
    joinOn?: string
  ): Promise<MergeResult> {
    return apiClient.post("/api/datasets/merge", {
      paths,
      output_path: outputPath,
      merge_type: mergeType,
      join_on: joinOn,
    });
  }

  async exportDataset(
    path: string,
    format: string,
    outputPath?: string
  ): Promise<ExportResult> {
    return apiClient.post("/api/datasets/export", {
      path,
      output_format: format,
      output_path: outputPath,
    });
  }

  // ==================== SCRAPER OPERATIONS ====================

  async getScraperAgents(): Promise<{
    agentTypes: ScraperAgent[];
    userAgents: UserAgent[];
  }> {
    const response = await apiClient.get<{
      agent_types: ScraperAgent[];
      user_agents: UserAgent[];
    }>("/api/datasets/scraper/agents");
    return {
      agentTypes: response.agent_types || [],
      userAgents: response.user_agents || [],
    };
  }

  async scrapeUrl(config: ScrapeConfig): Promise<ScrapeResult> {
    return apiClient.post("/api/datasets/scraper/scrape", {
      url: config.url,
      agent_type: config.agentType,
      user_agent: config.userAgent,
      selectors: config.selectors,
      output_name: config.outputName,
      output_format: config.outputFormat || "csv",
      wait_for_selector: config.waitForSelector,
      scroll_page: config.scrollPage || false,
      timeout: config.timeout || 30,
    });
  }

  async extractTables(
    url: string,
    agentType: string = "basic",
    userAgent: string = "chrome_windows"
  ): Promise<{ url: string; tables_found: number; tables: TableData[] }> {
    return apiClient.post(
      `/api/datasets/scraper/extract-tables?url=${encodeURIComponent(url)}&agent_type=${agentType}&user_agent=${userAgent}`,
      {}
    );
  }

  async extractLinks(
    url: string,
    filterPattern?: string,
    agentType: string = "basic",
    userAgent: string = "chrome_windows"
  ): Promise<{ url: string; links_found: number; links: LinkData[] }> {
    let endpoint = `/api/datasets/scraper/extract-links?url=${encodeURIComponent(url)}&agent_type=${agentType}&user_agent=${userAgent}`;
    if (filterPattern) {
      endpoint += `&filter_pattern=${encodeURIComponent(filterPattern)}`;
    }
    return apiClient.post(endpoint, {});
  }

  async crawlSite(
    startUrl: string,
    maxPages: number = 10,
    urlPattern?: string,
    selectors?: Record<string, string>,
    agentType: string = "basic"
  ): Promise<{
    pages_crawled: number;
    data_extracted: number;
    urls_visited: string[];
  }> {
    return apiClient.post("/api/datasets/scraper/crawl", {
      start_url: startUrl,
      max_pages: maxPages,
      url_pattern: urlPattern,
      selectors,
      agent_type: agentType,
    });
  }

  // Legacy scrape with AI
  async scrapeWithAI(
    url: string,
    outputName: string,
    selector?: string,
    extractType: string = "auto"
  ): Promise<{
    success: boolean;
    message: string;
    output_path: string;
    rows_extracted: number;
    columns_extracted?: string[];
    ai_analysis?: string;
  }> {
    return apiClient.post("/api/datasets/scrape", {
      url,
      selector: selector || "",
      output_name: outputName,
      use_ai_agent: true,
      extract_type: extractType,
    });
  }
}

export const datasetService = new DatasetService();
