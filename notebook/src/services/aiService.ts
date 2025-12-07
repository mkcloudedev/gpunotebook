// AI Service - Chat with Claude, OpenAI, Gemini

import apiClient from "./apiClient";

export type AIProvider = "claude" | "openai" | "gemini";

export interface AIMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  timestamp: Date;
  provider?: AIProvider;
  model?: string;
  tokenCount?: number;
}

export interface AIAction {
  tool: "executeCode" | "createCell" | "editCell" | "deleteCell" | "readCellOutput" | "listCells";
  params: Record<string, unknown>;
}

export interface AIResponse {
  id: string;
  message: string;
  actions?: AIAction[];
  tokenCount: number;
  model: string;
  finishReason: string;
}

export interface ChatRequest {
  provider: AIProvider;
  messages: Array<{
    role: "user" | "assistant" | "system";
    content: string;
  }>;
  systemPrompt?: string;
  maxTokens?: number;
  temperature?: number;
  notebookContext?: {
    notebookId: string;
    cells: Array<{
      id: string;
      type: string;
      source: string;
      outputs?: string[];
    }>;
    selectedCellId?: string;
  };
}

export interface PromptTemplate {
  id: string;
  name: string;
  description: string;
  prompt: string;
  category: string;
  variables?: string[];
}

export interface ProviderStatus {
  provider: AIProvider;
  configured: boolean;
  available: boolean;
  models: string[];
  defaultModel: string;
}

class AIService {
  // Send chat message (non-streaming)
  async chat(request: ChatRequest): Promise<AIResponse> {
    const response = await apiClient.post<{
      id?: string;
      content: string;
      message?: string;
      actions?: AIAction[];
      usage?: { input_tokens: number; output_tokens: number };
      token_count?: number;
      model: string;
      finish_reason: string;
    }>("/api/ai/chat", {
      provider: request.provider,
      messages: request.messages,
      system_prompt: request.systemPrompt,
      max_tokens: request.maxTokens,
      temperature: request.temperature,
      notebook_context: request.notebookContext,
    });

    return {
      id: response.id || Date.now().toString(),
      message: response.content || response.message || "",
      actions: response.actions,
      tokenCount: response.usage?.output_tokens || response.token_count || 0,
      model: response.model,
      finishReason: response.finish_reason,
    };
  }

  // Stream chat response (SSE)
  async *chatStream(request: ChatRequest): AsyncGenerator<string> {
    yield* apiClient.streamSSE("/api/ai/chat/stream", {
      provider: request.provider,
      messages: request.messages,
      system_prompt: request.systemPrompt,
      max_tokens: request.maxTokens,
      temperature: request.temperature,
      notebook_context: request.notebookContext,
    });
  }

  // Quick actions
  async explainCode(code: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Explain this code:\n\n\`\`\`python\n${code}\n\`\`\``,
        },
      ],
      systemPrompt: "You are a helpful coding assistant. Explain code clearly and concisely.",
    });
    return response.message;
  }

  async debugCode(code: string, error: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Debug this code:\n\n\`\`\`python\n${code}\n\`\`\`\n\nError:\n${error}`,
        },
      ],
      systemPrompt: "You are a debugging expert. Identify the issue and provide a fix.",
    });
    return response.message;
  }

  async optimizeCode(code: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Optimize this code for performance:\n\n\`\`\`python\n${code}\n\`\`\``,
        },
      ],
      systemPrompt: "You are a performance optimization expert. Suggest improvements.",
    });
    return response.message;
  }

  async generateCode(description: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Generate Python code for: ${description}`,
        },
      ],
      systemPrompt: "You are a Python expert. Generate clean, efficient code.",
    });
    return response.message;
  }

  async generateTests(code: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Generate unit tests for this code:\n\n\`\`\`python\n${code}\n\`\`\``,
        },
      ],
      systemPrompt: "You are a testing expert. Generate comprehensive unit tests using pytest.",
    });
    return response.message;
  }

  async documentCode(code: string, provider: AIProvider = "claude"): Promise<string> {
    const response = await this.chat({
      provider,
      messages: [
        {
          role: "user",
          content: `Add documentation to this code:\n\n\`\`\`python\n${code}\n\`\`\``,
        },
      ],
      systemPrompt: "You are a documentation expert. Add docstrings and comments.",
    });
    return response.message;
  }

  // Provider status
  async getProviderStatus(): Promise<ProviderStatus[]> {
    const response = await apiClient.get<
      Array<{
        provider: string;
        configured: boolean;
        available: boolean;
        models: string[];
        default_model: string;
      }>
    >("/api/ai/providers");

    return response.map((p) => ({
      provider: p.provider as AIProvider,
      configured: p.configured,
      available: p.available,
      models: p.models,
      defaultModel: p.default_model,
    }));
  }

  async testProvider(provider: AIProvider): Promise<boolean> {
    try {
      const response = await apiClient.post<{ success: boolean }>(`/api/ai/providers/${provider}/test`, {});
      return response.success;
    } catch {
      return false;
    }
  }

  // Prompt templates
  async getTemplates(): Promise<PromptTemplate[]> {
    return apiClient.get<PromptTemplate[]>("/api/ai/templates");
  }

  async saveTemplate(template: Omit<PromptTemplate, "id">): Promise<PromptTemplate> {
    return apiClient.post<PromptTemplate>("/api/ai/templates", template);
  }

  async deleteTemplate(id: string): Promise<void> {
    await apiClient.delete(`/api/ai/templates/${id}`);
  }

  // Token counting (estimate)
  estimateTokens(text: string): number {
    // Rough estimate: ~4 characters per token
    return Math.ceil(text.length / 4);
  }

  // Format token count
  formatTokenCount(count: number): string {
    if (count >= 1000000) {
      return `${(count / 1000000).toFixed(1)}M`;
    }
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}K`;
    }
    return count.toString();
  }
}

export const aiService = new AIService();
export default aiService;
