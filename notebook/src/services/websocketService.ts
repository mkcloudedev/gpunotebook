// WebSocket Service - Real-time connection for kernel communication

export enum WebSocketState {
  DISCONNECTED = "disconnected",
  CONNECTING = "connecting",
  CONNECTED = "connected",
  ERROR = "error",
}

export interface WebSocketMessage {
  type: string;
  [key: string]: unknown;
}

export interface KernelOutput {
  msg_type: string;
  parent_msg_id?: string;
  cell_id?: string;
  content?: {
    name?: string;
    text?: string;
    data?: Record<string, unknown>;
    execution_count?: number;
    ename?: string;
    evalue?: string;
    traceback?: string[];
  };
}

export interface ExecutionState {
  execution_state: "idle" | "busy" | "starting";
  kernel_id?: string;
}

type MessageHandler = (message: WebSocketMessage) => void;
type TypedMessageHandler<T> = (message: T) => void;
type StateHandler = (state: WebSocketState) => void;
type ErrorHandler = (error: Error) => void;

class WebSocketService {
  private socket: WebSocket | null = null;
  private state: WebSocketState = WebSocketState.DISCONNECTED;
  private url: string = "";
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;
  private messageHandlers: Set<MessageHandler> = new Set();
  private stateHandlers: Set<StateHandler> = new Set();
  private errorHandlers: Set<ErrorHandler> = new Set();
  private pendingMessages: WebSocketMessage[] = [];

  get isConnected(): boolean {
    return this.state === WebSocketState.CONNECTED;
  }

  get currentState(): WebSocketState {
    return this.state;
  }

  private updateState(newState: WebSocketState): void {
    this.state = newState;
    this.stateHandlers.forEach((handler) => handler(newState));
  }

  async connect(url: string): Promise<void> {
    if (this.state === WebSocketState.CONNECTING || this.state === WebSocketState.CONNECTED) {
      if (this.url === url) return;
      this.disconnect();
    }

    this.url = url;
    this.updateState(WebSocketState.CONNECTING);

    return new Promise((resolve, reject) => {
      try {
        this.socket = new WebSocket(url);

        this.socket.onopen = () => {
          this.updateState(WebSocketState.CONNECTED);
          this.reconnectAttempts = 0;

          // Send any pending messages
          while (this.pendingMessages.length > 0) {
            const msg = this.pendingMessages.shift();
            if (msg) this.send(msg);
          }

          resolve();
        };

        this.socket.onmessage = (event) => {
          try {
            const message = JSON.parse(event.data) as WebSocketMessage;
            this.messageHandlers.forEach((handler) => handler(message));
          } catch (error) {
            console.error("Failed to parse WebSocket message:", error);
          }
        };

        this.socket.onerror = (event) => {
          const error = new Error("WebSocket error");
          this.errorHandlers.forEach((handler) => handler(error));
          this.updateState(WebSocketState.ERROR);
        };

        this.socket.onclose = (event) => {
          this.updateState(WebSocketState.DISCONNECTED);

          // Attempt reconnection if not intentional close
          if (!event.wasClean && this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            setTimeout(() => {
              this.connect(this.url);
            }, this.reconnectDelay * this.reconnectAttempts);
          }
        };
      } catch (error) {
        this.updateState(WebSocketState.ERROR);
        reject(error);
      }
    });
  }

  disconnect(): void {
    if (this.socket) {
      this.socket.close(1000, "Client disconnect");
      this.socket = null;
    }
    this.updateState(WebSocketState.DISCONNECTED);
    this.reconnectAttempts = this.maxReconnectAttempts; // Prevent auto-reconnect
  }

  send(message: WebSocketMessage): void {
    if (this.state !== WebSocketState.CONNECTED || !this.socket) {
      this.pendingMessages.push(message);
      return;
    }

    try {
      this.socket.send(JSON.stringify(message));
    } catch (error) {
      console.error("Failed to send WebSocket message:", error);
      this.pendingMessages.push(message);
    }
  }

  // Execute code in kernel
  sendExecute(kernelId: string, code: string, cellId: string): void {
    this.send({
      type: "execute",
      kernel_id: kernelId,
      code,
      cell_id: cellId,
    });
  }

  // Alias for sendExecute
  execute(kernelId: string, code: string, cellId: string): void {
    this.sendExecute(kernelId, code, cellId);
  }

  // Interrupt kernel execution
  sendInterrupt(kernelId: string): void {
    this.send({
      type: "interrupt",
      kernel_id: kernelId,
    });
  }

  // Alias for sendInterrupt
  interrupt(kernelId: string): void {
    this.sendInterrupt(kernelId);
  }

  // Request code completion
  sendComplete(kernelId: string, code: string, cursorPos: number): void {
    this.send({
      type: "complete",
      kernel_id: kernelId,
      code,
      cursor_pos: cursorPos,
    });
  }

  // Async complete that returns a promise (for hook compatibility)
  async complete(kernelId: string, code: string, cursorPos: number): Promise<{ matches: string[] }> {
    return new Promise((resolve) => {
      const handler = this.onMessage("complete_reply", (message: WebSocketMessage) => {
        handler(); // unsubscribe
        resolve({ matches: (message.matches as string[]) || [] });
      });

      this.sendComplete(kernelId, code, cursorPos);

      // Timeout after 5 seconds
      setTimeout(() => {
        handler();
        resolve({ matches: [] });
      }, 5000);
    });
  }

  // Request variable inspection
  sendInspect(kernelId: string, code: string, cursorPos: number): void {
    this.send({
      type: "inspect",
      kernel_id: kernelId,
      code,
      cursor_pos: cursorPos,
    });
  }

  // Event handlers - supports typed message filtering
  onMessage(handler: MessageHandler): () => void;
  onMessage<T>(type: string, handler: TypedMessageHandler<T>): () => void;
  onMessage<T>(typeOrHandler: string | MessageHandler, handler?: TypedMessageHandler<T>): () => void {
    if (typeof typeOrHandler === "function") {
      // Simple handler for all messages
      this.messageHandlers.add(typeOrHandler);
      return () => this.messageHandlers.delete(typeOrHandler);
    } else {
      // Typed handler for specific message type
      const wrappedHandler: MessageHandler = (message) => {
        if (message.type === typeOrHandler || message.msg_type === typeOrHandler) {
          handler?.(message as T);
        }
      };
      this.messageHandlers.add(wrappedHandler);
      return () => this.messageHandlers.delete(wrappedHandler);
    }
  }

  onStateChange(handler: StateHandler): () => void {
    this.stateHandlers.add(handler);
    return () => this.stateHandlers.delete(handler);
  }

  onError(handler: ErrorHandler): () => void {
    this.errorHandlers.add(handler);
    return () => this.errorHandlers.delete(handler);
  }

  // Remove all handlers
  removeAllHandlers(): void {
    this.messageHandlers.clear();
    this.stateHandlers.clear();
    this.errorHandlers.clear();
  }
}

// Singleton instance
export const websocketService = new WebSocketService();

export default websocketService;
