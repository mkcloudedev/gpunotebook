// Execution Service - Execute code in kernels

import apiClient from "./apiClient";
import websocketService, { WebSocketMessage, WebSocketState } from "./websocketService";

export interface ExecutionRequest {
  kernelId: string;
  code: string;
  cellId?: string;
  silent?: boolean;
  storeHistory?: boolean;
  allowStdin?: boolean;
}

export interface ExecutionOutput {
  outputType: "stream" | "execute_result" | "display_data" | "error" | "status";
  text?: string;
  data?: Record<string, unknown>;
  ename?: string;
  evalue?: string;
  traceback?: string[];
  executionCount?: number;
  name?: string; // stdout, stderr
}

export enum ExecutionEventType {
  STARTED = "started",
  OUTPUT = "output",
  COMPLETED = "completed",
  ERROR = "error",
  INTERRUPTED = "interrupted",
}

export interface ExecutionEvent {
  type: ExecutionEventType;
  cellId?: string;
  output?: ExecutionOutput;
  executionCount?: number;
  status?: string;
}

export interface ExecutionResult {
  id: string;
  status: "ok" | "error" | "aborted";
  executionCount: number;
  outputs: ExecutionOutput[];
}

type OutputHandler = (output: ExecutionOutput, cellId?: string) => void;
type EventHandler = (event: ExecutionEvent) => void;

class ExecutionService {
  private outputHandlers: Set<OutputHandler> = new Set();
  private eventHandlers: Set<EventHandler> = new Set();
  private unsubscribeWs: (() => void) | null = null;

  constructor() {
    this.setupWebSocketListener();
  }

  private setupWebSocketListener(): void {
    if (this.unsubscribeWs) {
      this.unsubscribeWs();
    }

    this.unsubscribeWs = websocketService.onMessage((message) => {
      this.handleWebSocketMessage(message);
    });
  }

  private handleWebSocketMessage(message: WebSocketMessage): void {
    const type = message.type as string;
    const cellId = message.cell_id as string | undefined;

    switch (type) {
      case "execution_start":
        this.emitEvent({
          type: ExecutionEventType.STARTED,
          cellId,
        });
        break;

      case "output":
      case "stream":
        const output = this.parseOutput(message);
        this.emitOutput(output, cellId);
        this.emitEvent({
          type: ExecutionEventType.OUTPUT,
          cellId,
          output,
        });
        break;

      case "execute_result":
        const result = this.parseOutput(message);
        this.emitOutput(result, cellId);
        this.emitEvent({
          type: ExecutionEventType.OUTPUT,
          cellId,
          output: result,
        });
        break;

      case "error":
        const errorOutput = this.parseOutput(message);
        this.emitOutput(errorOutput, cellId);
        this.emitEvent({
          type: ExecutionEventType.ERROR,
          cellId,
          output: errorOutput,
        });
        break;

      case "execution_complete":
        this.emitEvent({
          type: ExecutionEventType.COMPLETED,
          cellId,
          executionCount: message.execution_count as number,
          status: message.status as string,
        });
        break;

      case "status":
        // Kernel status update
        break;
    }
  }

  private parseOutput(message: WebSocketMessage): ExecutionOutput {
    return {
      outputType: (message.output_type || message.type) as ExecutionOutput["outputType"],
      text: message.text as string | undefined,
      data: message.data as Record<string, unknown> | undefined,
      ename: message.ename as string | undefined,
      evalue: message.evalue as string | undefined,
      traceback: message.traceback as string[] | undefined,
      executionCount: message.execution_count as number | undefined,
      name: message.name as string | undefined,
    };
  }

  private emitOutput(output: ExecutionOutput, cellId?: string): void {
    this.outputHandlers.forEach((handler) => handler(output, cellId));
  }

  private emitEvent(event: ExecutionEvent): void {
    this.eventHandlers.forEach((handler) => handler(event));
  }

  // Connect to kernel WebSocket
  async connectToKernel(kernelId: string): Promise<void> {
    const url = apiClient.getWebSocketUrl(`/ws/kernel/${kernelId}`);
    await websocketService.connect(url);
  }

  // Disconnect from kernel
  disconnectFromKernel(): void {
    websocketService.disconnect();
  }

  // Execute code via REST API
  async execute(request: ExecutionRequest): Promise<ExecutionResult> {
    const response = await apiClient.post<{
      id: string;
      status: string;
      execution_count: number;
      outputs: Array<{
        output_type: string;
        text?: string;
        data?: Record<string, unknown>;
        ename?: string;
        evalue?: string;
        traceback?: string[];
      }>;
    }>("/api/execute", {
      kernel_id: request.kernelId,
      code: request.code,
      cell_id: request.cellId,
      silent: request.silent,
      store_history: request.storeHistory,
      allow_stdin: request.allowStdin,
    });

    return {
      id: response.id,
      status: response.status as "ok" | "error" | "aborted",
      executionCount: response.execution_count,
      outputs: response.outputs.map((o) => ({
        outputType: o.output_type as ExecutionOutput["outputType"],
        text: o.text,
        data: o.data,
        ename: o.ename,
        evalue: o.evalue,
        traceback: o.traceback,
      })),
    };
  }

  // Execute via WebSocket (streaming)
  executeViaWebSocket(kernelId: string, code: string, cellId: string): void {
    websocketService.sendExecute(kernelId, code, cellId);
  }

  // Cancel/interrupt execution
  async cancel(kernelId: string): Promise<void> {
    await apiClient.post(`/api/execute/${kernelId}/cancel`, {});
  }

  // Interrupt via WebSocket
  interruptViaWebSocket(kernelId: string): void {
    websocketService.sendInterrupt(kernelId);
  }

  // Get code completions
  async getCompletions(kernelId: string, code: string, cursorPos: number): Promise<string[]> {
    const response = await apiClient.post<{ matches: string[] }>("/api/complete", {
      kernel_id: kernelId,
      code,
      cursor_pos: cursorPos,
    });
    return response.matches;
  }

  // Inspect variable/object
  async inspect(kernelId: string, code: string, cursorPos: number): Promise<{ found: boolean; data: Record<string, unknown> }> {
    return apiClient.post(`/api/kernels/${kernelId}/inspect`, {
      code,
      cursor_pos: cursorPos,
    });
  }

  // Get all variables from kernel namespace
  async getVariables(kernelId: string): Promise<Array<{
    name: string;
    type: string;
    shape?: string;
    preview: string;
    size?: number;
  }>> {
    try {
      const response = await apiClient.get<{ variables: Array<{
        name: string;
        type: string;
        shape?: string;
        preview: string;
        size?: number;
      }> }>(`/api/kernels/${kernelId}/variables`);
      return response.variables || [];
    } catch (error) {
      console.error("Failed to get variables:", error);
      return [];
    }
  }

  // Event handlers
  onOutput(handler: OutputHandler): () => void {
    this.outputHandlers.add(handler);
    return () => this.outputHandlers.delete(handler);
  }

  onEvent(handler: EventHandler): () => void {
    this.eventHandlers.add(handler);
    return () => this.eventHandlers.delete(handler);
  }

  // Check WebSocket connection state
  get isConnected(): boolean {
    return websocketService.isConnected;
  }

  get connectionState(): WebSocketState {
    return websocketService.currentState;
  }
}

export const executionService = new ExecutionService();
export default executionService;
