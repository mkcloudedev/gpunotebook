import { createContext, useContext, useState, useEffect, useRef, ReactNode } from "react";
import { gpuService, GPUStatus, GPUProcess, GPUSystemStatus } from "@/services/gpuService";

interface GPUContextValue {
  gpus: GPUStatus[];
  processes: GPUProcess[];
  isLoading: boolean;
  error: string | null;
  hasGpu: boolean;
  refresh: () => Promise<void>;
}

const GPUContext = createContext<GPUContextValue | null>(null);

const POLL_INTERVAL = 2000;

export const GPUProvider = ({ children }: { children: ReactNode }) => {
  const [gpus, setGpus] = useState<GPUStatus[]>([]);
  const [processes, setProcesses] = useState<GPUProcess[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasGpu, setHasGpu] = useState(false);
  const stopPollingRef = useRef<(() => void) | null>(null);

  const handleStatusUpdate = (status: GPUSystemStatus) => {
    setGpus(status.gpus);
    setProcesses(status.processes);
    setHasGpu(status.hasGpu);
    setIsLoading(false);
    setError(null);
  };

  const refresh = async () => {
    try {
      const status = await gpuService.getStatus();
      handleStatusUpdate(status);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load GPU status");
      setIsLoading(false);
    }
  };

  useEffect(() => {
    const startPolling = async () => {
      try {
        // Initial load
        const status = await gpuService.getStatus();
        handleStatusUpdate(status);

        // Start polling
        stopPollingRef.current = gpuService.startPolling(handleStatusUpdate, POLL_INTERVAL);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load GPU status");
        setIsLoading(false);
      }
    };

    startPolling();

    return () => {
      if (stopPollingRef.current) {
        stopPollingRef.current();
      }
    };
  }, []);

  return (
    <GPUContext.Provider value={{ gpus, processes, isLoading, error, hasGpu, refresh }}>
      {children}
    </GPUContext.Provider>
  );
};

export const useGPU = () => {
  const context = useContext(GPUContext);
  if (!context) {
    throw new Error("useGPU must be used within a GPUProvider");
  }
  return context;
};
