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
  const executingCellIdRef = useRef<string | null>(null);

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

      // Get list of existing kernels
      const kernels = await kernelService.list();

      // Check if component was unmounted during async operation
      if (!isMountedRef.current) {
        isConnectingRef.current = false;
        return;
      }

      if (notebookId) {
        // Try to get existing kernel for this notebook
        const existingKernel = kernels.find((k) => k.notebookId === notebookId);

        if (existingKernel) {
          kernelInstance = existingKernel;
        } else {
          // No kernel for this notebook - try to reuse an idle kernel or create new
          const idleKernel = kernels.find((k) => k.status === "idle");

          if (idleKernel) {
            // Reuse idle kernel
            kernelInstance = idleKernel;
          } else if (kernels.length >= 5) {
            // Too many kernels, delete oldest ones before creating
            const sortedKernels = [...kernels].sort((a, b) =>
              new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime()
            );
            // Delete oldest kernels to make room
            for (let i = 0; i < Math.min(3, sortedKernels.length); i++) {
              try {
                await kernelService.delete(sortedKernels[i].id);
              } catch {
                // Ignore delete errors
              }
            }
            kernelInstance = await kernelService.create("python3", notebookId);
          } else {
            kernelInstance = await kernelService.create("python3", notebookId);
          }
        }
      } else {
        // For anonymous kernels (like Playground), try to reuse existing one first
        // Find an idle kernel without notebookId (anonymous)
        const idleKernel = kernels.find((k) => !k.notebookId && k.status === "idle");

        if (idleKernel) {
          kernelInstance = idleKernel;
        } else if (kernels.length >= 5) {
          // Too many kernels, delete oldest ones before creating
          const sortedKernels = [...kernels].sort((a, b) =>
            new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime()
          );
          for (let i = 0; i < Math.min(3, sortedKernels.length); i++) {
            try {
              await kernelService.delete(sortedKernels[i].id);
            } catch {
              // Ignore delete errors
            }
          }
          kernelInstance = await kernelService.create("python3");
        } else {
          // Create anonymous kernel
          kernelInstance = await kernelService.create("python3");
        }
      }

      // Check if component was unmounted during async operation
      if (!isMountedRef.current) {
        isConnectingRef.current = false;
        return;
      }

      setKernel(kernelInstance);

      // Connect WebSocket (non-blocking - we can still use REST API if it fails)
      const wsUrl = apiClient.getWebSocketUrl(`/ws/kernel/${kernelInstance.id}`);
      try {
        await websocketService.connect(wsUrl);

        // Check if component was unmounted during async operation
        if (!isMountedRef.current) {
          websocketService.disconnect();
          isConnectingRef.current = false;
          return;
        }

        setIsConnected(true);

        // Set up message handler for all messages
        websocketService.onMessage((message) => {
          // Handle different message types
          const msgType = message.msg_type || message.type;

          if (msgType === "stream" || msgType === "execute_result" || msgType === "display_data" || msgType === "error") {
            handleKernelOutput(message as unknown as KernelOutput);
          } else if (msgType === "status" || msgType === "execution_state") {
            // Handle status messages
            const execState = message.execution_state || message.content?.execution_state;
            if (execState) {
              handleExecutionState({ execution_state: execState as "idle" | "busy" | "starting" });
            }
          } else if (msgType === "execute_reply" || msgType === "execution_complete") {
            // Execution completed
            handleExecutionState({ execution_state: "idle" });
          } else if (msgType === "execution_start") {
            handleExecutionState({ execution_state: "busy" });
          }
        });
      } catch (wsError) {
        // WebSocket failed but kernel is ready - can still use REST API
        if (!isMountedRef.current) {
          isConnectingRef.current = false;
          return;
        }
      }

      // Kernel is ready regardless of WebSocket status
      setKernelStatus("idle");
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

  // Store callbacks in refs to avoid stale closures
  const onOutputRef = useRef(onOutput);
  const onExecutionCompleteRef = useRef(onExecutionComplete);
  onOutputRef.current = onOutput;
  onExecutionCompleteRef.current = onExecutionComplete;

  // Handle kernel output messages
  const handleKernelOutput = useCallback(
    (output: KernelOutput) => {
      // Get cellId from message or from ref
      const cellId = output.cell_id || output.parent_msg_id || executingCellIdRef.current;
      if (!cellId) return;

      const cellOutput: CellOutput = convertKernelOutput(output);

      // Buffer the output
      const currentBuffer = outputBufferRef.current.get(cellId) || [];
      currentBuffer.push(cellOutput);
      outputBufferRef.current.set(cellId, currentBuffer);

      // Notify listener
      if (onOutputRef.current) {
        onOutputRef.current(cellId, cellOutput);
      }
    },
    []
  );

  // Handle execution state changes
  const handleExecutionState = useCallback(
    (state: ExecutionState) => {
      if (state.execution_state === "busy") {
        setKernelStatus("busy");
      } else if (state.execution_state === "idle") {
        setKernelStatus("idle");

        // Complete execution using ref (not state, which may be stale in closure)
        const cellId = executingCellIdRef.current;
        if (cellId) {
          const resolve = executionResolveRef.current.get(cellId);
          if (resolve) {
            resolve();
            executionResolveRef.current.delete(cellId);
          }

          if (onExecutionCompleteRef.current) {
            onExecutionCompleteRef.current(cellId);
          }

          executingCellIdRef.current = null;
          setExecutingCellId(null);
        }
      }
    },
    []
  );

  // Convert kernel output to CellOutput format
  const convertKernelOutput = (output: KernelOutput & Record<string, unknown>): CellOutput => {
    const msgType = output.msg_type || output.output_type || output.type;

    switch (msgType) {
      case "stream":
        return {
          outputType: "stream",
          name: (output.name as string) || output.content?.name || "stdout",
          text: (output.text as string) || output.content?.text || "",
        };

      case "execute_result":
        return {
          outputType: "execute_result",
          data: (output.data as Record<string, unknown>) || output.content?.data,
          executionCount: (output.execution_count as number) || output.content?.execution_count,
        };

      case "display_data":
        return {
          outputType: "display_data",
          data: (output.data as Record<string, unknown>) || output.content?.data,
        };

      case "error":
        return {
          outputType: "error",
          ename: (output.ename as string) || output.content?.ename || "Error",
          evalue: (output.evalue as string) || output.content?.evalue || "",
          traceback: (output.traceback as string[]) || output.content?.traceback || [],
        };

      default:
        return {
          outputType: "stream",
          text: (output.text as string) || JSON.stringify(output.content || output),
        };
    }
  };

  // Execute code
  const execute = useCallback(
    async (cellId: string, code: string): Promise<void> => {
      if (!kernel) {
        throw new Error("Kernel not available");
      }

      // Clear output buffer for this cell
      outputBufferRef.current.set(cellId, []);
      executingCellIdRef.current = cellId;
      setExecutingCellId(cellId);
      setKernelStatus("busy");

      if (onExecutionStart) {
        onExecutionStart(cellId);
      }

      // If WebSocket is connected, use it for real-time output
      if (isConnected) {
        return new Promise((resolve, reject) => {
          // Store resolve function
          executionResolveRef.current.set(cellId, resolve);

          // Send execute request via WebSocket
          websocketService.execute(kernel.id, code, cellId);

          // Timeout after 5 minutes
          setTimeout(() => {
            if (executionResolveRef.current.has(cellId)) {
              executionResolveRef.current.delete(cellId);
              executingCellIdRef.current = null;
              setExecutingCellId(null);
              setKernelStatus("idle");
              reject(new Error("Execution timed out"));

              if (onExecutionError) {
                onExecutionError(cellId, "Execution timed out");
              }
            }
          }, 5 * 60 * 1000);
        });
      } else {
        // Fallback to REST API
        try {
          const response = await apiClient.post<{
            status: string;
            outputs: Array<{
              output_type: string;
              text?: string;
              data?: Record<string, unknown>;
              ename?: string;
              evalue?: string;
              traceback?: string[];
            }>;
          }>("/api/execute", {
            kernel_id: kernel.id,
            code,
            cell_id: cellId,
          });

          // Process outputs
          for (const output of response.outputs || []) {
            const cellOutput: CellOutput = {
              outputType: output.output_type as CellOutput["outputType"],
              text: output.text,
              data: output.data,
              ename: output.ename,
              evalue: output.evalue,
              traceback: output.traceback,
            };

            if (onOutput) {
              onOutput(cellId, cellOutput);
            }
          }

          if (onExecutionComplete) {
            onExecutionComplete(cellId);
          }
        } catch (error) {
          if (onExecutionError) {
            onExecutionError(cellId, error instanceof Error ? error.message : "Execution failed");
          }
          throw error;
        } finally {
          executingCellIdRef.current = null;
          setExecutingCellId(null);
          setKernelStatus("idle");
        }
      }
    },
    [kernel, isConnected, onExecutionStart, onExecutionComplete, onExecutionError, onOutput]
  );

  // Interrupt execution
  const interrupt = useCallback(async () => {
    if (!kernel) return;

    try {
      await kernelService.interrupt(kernel.id);
      websocketService.interrupt(kernel.id);

      executingCellIdRef.current = null;
      setExecutingCellId(null);
      setKernelStatus("idle");
    } catch (error) {
      console.error("Failed to interrupt kernel:", error);
    }
  }, [kernel]);

  // Restart kernel
  const restart = useCallback(async () => {
    if (!kernel) return;

    try {
      setKernelStatus("starting");
      const newKernel = await kernelService.restart(kernel.id);
      setKernel(newKernel);
      setKernelStatus("idle");
      executingCellIdRef.current = null;
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
    isConnectingRef.current = false; // Reset on mount

    return () => {
      isMountedRef.current = false;
      isConnectingRef.current = false; // Reset on unmount
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
