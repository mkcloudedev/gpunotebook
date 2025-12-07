// Settings Service - Persistent configuration

import apiClient from "./apiClient";

export interface APIKeys {
  claude?: string;
  openai?: string;
  gemini?: string;
  kaggle?: {
    username: string;
    key: string;
  };
}

export interface EditorSettings {
  theme: "dark" | "light" | "system";
  fontSize: number;
  tabSize: number;
  lineNumbers: boolean;
  wordWrap: boolean;
  autoSave: boolean;
  autoSaveInterval: number; // seconds
  minimap: boolean;
  bracketMatching: boolean;
}

export interface KernelSettings {
  defaultPython: string;
  gpuMemoryLimit: number; // percentage
  executionTimeout: number; // seconds
  autoRestartOnCrash: boolean;
}

export interface GeneralSettings {
  language: string;
  timezone: string;
  dateFormat: string;
  notifications: boolean;
}

export interface ClaudeCodeSettings {
  model: string;
  maxOutputTokens: number;
  enabled: boolean;
}

export interface AllSettings {
  apiKeys: APIKeys;
  editor: EditorSettings;
  kernel: KernelSettings;
  general: GeneralSettings;
  claudeCode: ClaudeCodeSettings;
}

const DEFAULT_SETTINGS: AllSettings = {
  apiKeys: {},
  editor: {
    theme: "dark",
    fontSize: 14,
    tabSize: 4,
    lineNumbers: true,
    wordWrap: true,
    autoSave: true,
    autoSaveInterval: 30,
    minimap: false,
    bracketMatching: true,
  },
  kernel: {
    defaultPython: "python3.11",
    gpuMemoryLimit: 80,
    executionTimeout: 300,
    autoRestartOnCrash: true,
  },
  general: {
    language: "en",
    timezone: "UTC",
    dateFormat: "YYYY-MM-DD",
    notifications: true,
  },
  claudeCode: {
    model: "claude-sonnet-4-20250514",
    maxOutputTokens: 32000,
    enabled: true,
  },
};

class SettingsService {
  private settings: AllSettings = DEFAULT_SETTINGS;
  private loaded = false;

  // Load settings from server
  async load(): Promise<AllSettings> {
    try {
      const response = await apiClient.get<{
        api_keys: {
          claude?: string;
          openai?: string;
          gemini?: string;
          kaggle?: { username: string; key: string };
        };
        editor: {
          theme: string;
          font_size: number;
          tab_size: number;
          line_numbers: boolean;
          word_wrap: boolean;
          auto_save: boolean;
          auto_save_interval: number;
          minimap: boolean;
          bracket_matching: boolean;
        };
        kernel: {
          default_python: string;
          gpu_memory_limit: number;
          execution_timeout: number;
          auto_restart_on_crash: boolean;
        };
        general: {
          language: string;
          timezone: string;
          date_format: string;
          notifications: boolean;
        };
        claude_code?: {
          model: string;
          max_output_tokens: number;
          enabled: boolean;
        };
      }>("/api/settings");

      this.settings = {
        apiKeys: {
          claude: response.api_keys.claude,
          openai: response.api_keys.openai,
          gemini: response.api_keys.gemini,
          kaggle: response.api_keys.kaggle,
        },
        editor: {
          theme: response.editor.theme as "dark" | "light" | "system",
          fontSize: response.editor.font_size,
          tabSize: response.editor.tab_size,
          lineNumbers: response.editor.line_numbers,
          wordWrap: response.editor.word_wrap,
          autoSave: response.editor.auto_save,
          autoSaveInterval: response.editor.auto_save_interval,
          minimap: response.editor.minimap,
          bracketMatching: response.editor.bracket_matching,
        },
        kernel: {
          defaultPython: response.kernel.default_python,
          gpuMemoryLimit: response.kernel.gpu_memory_limit,
          executionTimeout: response.kernel.execution_timeout,
          autoRestartOnCrash: response.kernel.auto_restart_on_crash,
        },
        general: {
          language: response.general.language,
          timezone: response.general.timezone,
          dateFormat: response.general.date_format,
          notifications: response.general.notifications,
        },
        claudeCode: {
          model: response.claude_code?.model || DEFAULT_SETTINGS.claudeCode.model,
          maxOutputTokens: response.claude_code?.max_output_tokens || DEFAULT_SETTINGS.claudeCode.maxOutputTokens,
          enabled: response.claude_code?.enabled ?? DEFAULT_SETTINGS.claudeCode.enabled,
        },
      };

      this.loaded = true;
      return this.settings;
    } catch (error) {
      console.error("Failed to load settings:", error);
      // Try to load from localStorage as fallback
      const localSettings = localStorage.getItem("notebook_settings");
      if (localSettings) {
        this.settings = JSON.parse(localSettings);
      }
      this.loaded = true;
      return this.settings;
    }
  }

  // Save settings to server
  async save(settings: Partial<AllSettings>): Promise<void> {
    this.settings = { ...this.settings, ...settings };

    try {
      await apiClient.put("/api/settings", {
        api_keys: {
          claude: this.settings.apiKeys.claude,
          openai: this.settings.apiKeys.openai,
          gemini: this.settings.apiKeys.gemini,
          kaggle: this.settings.apiKeys.kaggle,
        },
        editor: {
          theme: this.settings.editor.theme,
          font_size: this.settings.editor.fontSize,
          tab_size: this.settings.editor.tabSize,
          line_numbers: this.settings.editor.lineNumbers,
          word_wrap: this.settings.editor.wordWrap,
          auto_save: this.settings.editor.autoSave,
          auto_save_interval: this.settings.editor.autoSaveInterval,
          minimap: this.settings.editor.minimap,
          bracket_matching: this.settings.editor.bracketMatching,
        },
        kernel: {
          default_python: this.settings.kernel.defaultPython,
          gpu_memory_limit: this.settings.kernel.gpuMemoryLimit,
          execution_timeout: this.settings.kernel.executionTimeout,
          auto_restart_on_crash: this.settings.kernel.autoRestartOnCrash,
        },
        general: {
          language: this.settings.general.language,
          timezone: this.settings.general.timezone,
          date_format: this.settings.general.dateFormat,
          notifications: this.settings.general.notifications,
        },
        claude_code: {
          model: this.settings.claudeCode.model,
          max_output_tokens: this.settings.claudeCode.maxOutputTokens,
          enabled: this.settings.claudeCode.enabled,
        },
      });
    } catch (error) {
      console.error("Failed to save settings to server:", error);
    }

    // Also save to localStorage as backup
    localStorage.setItem("notebook_settings", JSON.stringify(this.settings));
  }

  // Get current settings
  get(): AllSettings {
    if (!this.loaded) {
      // Try to load from localStorage synchronously
      const localSettings = localStorage.getItem("notebook_settings");
      if (localSettings) {
        this.settings = JSON.parse(localSettings);
      }
    }
    return this.settings;
  }

  // Update specific section
  async updateApiKeys(keys: Partial<APIKeys>): Promise<void> {
    await this.save({
      apiKeys: { ...this.settings.apiKeys, ...keys },
    });
  }

  async updateEditor(settings: Partial<EditorSettings>): Promise<void> {
    await this.save({
      editor: { ...this.settings.editor, ...settings },
    });
  }

  async updateKernel(settings: Partial<KernelSettings>): Promise<void> {
    await this.save({
      kernel: { ...this.settings.kernel, ...settings },
    });
  }

  async updateGeneral(settings: Partial<GeneralSettings>): Promise<void> {
    await this.save({
      general: { ...this.settings.general, ...settings },
    });
  }

  async updateClaudeCode(settings: Partial<ClaudeCodeSettings>): Promise<void> {
    await this.save({
      claudeCode: { ...this.settings.claudeCode, ...settings },
    });
  }

  // Validate API key
  async validateApiKey(provider: "claude" | "openai" | "gemini", key: string): Promise<boolean> {
    try {
      const response = await apiClient.post<{ valid: boolean }>(`/api/settings/validate-key`, {
        provider,
        key,
      });
      return response.valid;
    } catch {
      return false;
    }
  }

  // Reset to defaults
  async reset(): Promise<void> {
    this.settings = DEFAULT_SETTINGS;
    await this.save(this.settings);
  }
}

export const settingsService = new SettingsService();
export default settingsService;
