import { useState, useEffect, useCallback, useRef } from "react";
import { kernelService, Kernel } from "@/services/kernelService";
import { websocketService, KernelOutput, ExecutionState } from "@/services/websocketService";
import apiClient from "@/services/apiClient";
import { CellOutput } from "@/types/notebook";

interface UseKernelExecutionOptions {
  notebookId?: string;
  onOutput?: (cellId: string, output: CellOutput) => void;
  onExecutionStart?: (cellId: string) => void;
  onExecutionComplete?: (cellId: string) => void;
  onExecutionError?: (cellId: string, error: string) => void;
}

interface UseKernelExecutionReturn {
  kernel: Kernel | null;
  kernelStatus: "idle" | "busy" | "starting" | "error" | "disconnected";
  isConnected: boolean;
  isExecuting: boolean;
  executingCellId: string | null;
  connect: () => Promise<void>;
  disconnect: () => void;
  execute: (cellId: string, code: string) => Promise<void>;
  interrupt: () => Promise<void>;
  restart: () => Promise<void>;
  getCompletions: (code: string, cursorPos: number) => Promise<string[]>;
}

export function useKernelExecution(
  options: UseKernelExecutionOptions = {}
): UseKernelExecutionReturn {
  const { notebookId, onOutput, onExecutionStart, onExecutionComplete, onExecutionError } =
    options;

  const [kernel, setKernel] = useState<Kernel | null>(null);
  const [kernelStatus, setKernelStatus] = useState<
    "idle" | "busy" | "starting" | "error" | "disconnected"
  >("disconnected");
  const [isConnected, setIsConnected] = useState(false);
  const [executingCellId, setExecutingCellId] = useState<string | null>(null);

  const outputBufferRef = useRef<Map<string, CellOutput[]>>(new Map());
  const executionResolveRef = useRef<Map<string, () => void>>(new Map());
  const isMountedRef = useRef(true);
  const isConnectingRef = useRef(false);

  // Connect to or create a kernel
  const connect = useCallback(async () => {
    // Prevent duplicate connections
    if (isConnectingRef.current) {
      return;
    }
    isConnectingRef.current = true;

    try {
      setKernelStatus("starting");

      // Try to find existing kernel or create new one
      let kernelInstance: Kernel;

      if (notebookId) {
        // Try to get existing kernel for notebook
        const kernels = await kernelService.list();

        // Check if component was unmounted during async operation
        if (!isMountedRef.current) {
          isConnectingRef.current = false;
          return;
        }

        const existingKernel = kernels.find((k) => k.notebookId === notebookId);

        if (existingKernel) {
          kernelInstance = existingKernel;
        } else {
          kernelInstance = await kernelService.create("python3", notebookId);
        }
      } else {
        // Create anonymous kernel
        kernelInstance = await kernelService.create("python3");
      }

      // Check if component was unmounted during async operation
      if (!isMountedRef.current) {
        isConnectingRef.current = false;
        return;
      }

      setKernel(kernelInstance);

      // Connect WebSocket
      const wsUrl = apiClient.getWebSocketUrl(`/ws/kernel/${kernelInstance.id}`);
      await websocketService.connect(wsUrl);

      // Check if component was unmounted during async operation
      if (!isMountedRef.current) {
        websocketService.disconnect();
        isConnectingRef.current = false;
        return;
      }

      setIsConnected(true);
      setKernelStatus("idle");

      // Set up message handler
      websocketService.onMessage("kernel_output", (output: KernelOutput) => {
        handleKernelOutput(output);
      });

      websocketService.onMessage("execution_state", (state: ExecutionState) => {
        handleExecutionState(state);
      });
    } catch (error) {
      // Ignore abort errors from component unmount
      if (error instanceof Error && error.name === "AbortError") {
        // Component was unmounted, ignore
      } else {
        console.error("Failed to connect to kernel:", error);
        if (isMountedRef.current) {
          setKernelStatus("error");
          setIsConnected(false);
        }
      }
    } finally {
      isConnectingRef.current = false;
    }
  }, [notebookId]);

  // Handle kernel output messages
  const handleKernelOutput = useCallback(
    (output: KernelOutput) => {
      const cellId = output.parent_msg_id || executingCellId;
      if (!cellId) return;

      const cellOutput: CellOutput = convertKernelOutput(output);

      // Buffer the output
      const currentBuffer = outputBufferRef.current.get(cellId) || [];
      currentBuffer.push(cellOutput);
      outputBufferRef.current.set(cellId, currentBuffer);

      // Notify listener
      if (onOutput) {
        onOutput(cellId, cellOutput);
      }
    },
    [executingCellId, onOutput]
  );

  // Handle execution state changes
  const handleExecutionState = useCallback(
    (state: ExecutionState) => {
      if (state.execution_state === "busy") {
        setKernelStatus("busy");
      } else if (state.execution_state === "idle") {
        setKernelStatus("idle");

        // Complete execution
        if (executingCellId) {
          const resolve = executionResolveRef.current.get(executingCellId);
          if (resolve) {
            resolve();
            executionResolveRef.current.delete(executingCellId);
          }

          if (onExecutionComplete) {
            onExecutionComplete(executingCellId);
          }

          setExecutingCellId(null);
        }
      }
    },
    [executingCellId, onExecutionComplete]
  );

  // Convert kernel output to CellOutput format
  const convertKernelOutput = (output: KernelOutput): CellOutput => {
    switch (output.msg_type) {
      case "stream":
        return {
          outputType: "stream",
          name: output.content?.name || "stdout",
          text: output.content?.text || "",
        };

      case "execute_result":
        return {
          outputType: "execute_result",
          data: output.content?.data,
          executionCount: output.content?.execution_count,
        };

      case "display_data":
        return {
          outputType: "display_data",
          data: output.content?.data,
        };

      case "error":
        return {
          outputType: "error",
          ename: output.content?.ename || "Error",
          evalue: output.content?.evalue || "",
          traceback: output.content?.traceback || [],
        };

      default:
        return {
          outputType: "stream",
          text: JSON.stringify(output.content),
        };
    }
  };

  // Execute code
  const execute = useCallback(
    async (cellId: string, code: string): Promise<void> => {
      if (!kernel || !isConnected) {
        throw new Error("Kernel not connected");
      }

      // Clear output buffer for this cell
      outputBufferRef.current.set(cellId, []);
      setExecutingCellId(cellId);

      if (onExecutionStart) {
        onExecutionStart(cellId);
      }

      return new Promise((resolve, reject) => {
        // Store resolve function
        executionResolveRef.current.set(cellId, resolve);

        // Send execute request via WebSocket
        websocketService.execute(kernel.id, code, cellId);

        // Timeout after 5 minutes
        setTimeout(() => {
          if (executionResolveRef.current.has(cellId)) {
            executionResolveRef.current.delete(cellId);
            setExecutingCellId(null);
            reject(new Error("Execution timed out"));

            if (onExecutionError) {
              onExecutionError(cellId, "Execution timed out");
            }
          }
        }, 5 * 60 * 1000);
      });
    },
    [kernel, isConnected, onExecutionStart, onExecutionError]
  );

  // Interrupt execution
  const interrupt = useCallback(async () => {
    if (!kernel) return;

    try {
      await kernelService.interrupt(kernel.id);
      websocketService.interrupt(kernel.id);

      if (executingCellId) {
        setExecutingCellId(null);
        setKernelStatus("idle");
      }
    } catch (error) {
      console.error("Failed to interrupt kernel:", error);
    }
  }, [kernel, executingCellId]);

  // Restart kernel
  const restart = useCallback(async () => {
    if (!kernel) return;

    try {
      setKernelStatus("starting");
      const newKernel = await kernelService.restart(kernel.id);
      setKernel(newKernel);
      setKernelStatus("idle");
      setExecutingCellId(null);
    } catch (error) {
      console.error("Failed to restart kernel:", error);
      setKernelStatus("error");
    }
  }, [kernel]);

  // Get code completions
  const getCompletions = useCallback(
    async (code: string, cursorPos: number): Promise<string[]> => {
      if (!kernel || !isConnected) {
        return [];
      }

      try {
        const result = await websocketService.complete(kernel.id, code, cursorPos);
        return result.matches || [];
      } catch (error) {
        console.error("Failed to get completions:", error);
        return [];
      }
    },
    [kernel, isConnected]
  );

  // Disconnect
  const disconnect = useCallback(() => {
    websocketService.disconnect();
    setIsConnected(false);
    setKernelStatus("disconnected");
    setKernel(null);
    setExecutingCellId(null);
  }, []);

  // Track mount state and cleanup on unmount
  useEffect(() => {
    isMountedRef.current = true;

    return () => {
      isMountedRef.current = false;
      websocketService.disconnect();
    };
  }, []);

  return {
    kernel,
    kernelStatus,
    isConnected,
    isExecuting: executingCellId !== null,
    executingCellId,
    connect,
    disconnect,
    execute,
    interrupt,
    restart,
    getCompletions,
  };
}

export default useKernelExecution;
