/**
 * Hook for managing container-based code execution.
 * Provides isolated Python execution with GPU support and auto-pull.
 */

import { useState, useEffect, useCallback, useRef } from "react";
import { dockerService, NotebookContainer, ContainerExecutionResult } from "@/services/dockerService";
import { gpuService } from "@/services/gpuService";

export type ContainerStatus =
  | "disconnected"
  | "checking"
  | "pulling"
  | "creating"
  | "running"
  | "executing"
  | "idle"
  | "stopped"
  | "error";

export interface ContainerExecutionState {
  // Container state
  status: ContainerStatus;
  container: NotebookContainer | null;
  containerId: string | null;
  containerName: string | null;

  // Image state
  currentImage: string;
  availableImages: Array<{ id: string; name: string; description: string }>;

  // GPU state
  hasGpu: boolean;
  gpuCount: number;
  useGpu: boolean;

  // Execution state
  isExecuting: boolean;
  lastError: string | null;
  executionCount: number;

  // Pull progress
  isPulling: boolean;
  pullProgress: string;
}

export interface UseContainerExecutionOptions {
  notebookId: string;
  autoConnect?: boolean;
  preferGpu?: boolean;
  defaultImage?: string;
}

export function useContainerExecution(options: UseContainerExecutionOptions) {
  const { notebookId, autoConnect = false, preferGpu = true, defaultImage } = options;

  const [state, setState] = useState<ContainerExecutionState>({
    status: "disconnected",
    container: null,
    containerId: null,
    containerName: null,
    currentImage: defaultImage || "python",
    availableImages: [],
    hasGpu: false,
    gpuCount: 0,
    useGpu: false,
    isExecuting: false,
    lastError: null,
    executionCount: 0,
    isPulling: false,
    pullProgress: "",
  });

  const containerRef = useRef<string | null>(null);
  const mountedRef = useRef(true);

  // Update state safely
  const updateState = useCallback((updates: Partial<ContainerExecutionState>) => {
    if (mountedRef.current) {
      setState(prev => ({ ...prev, ...updates }));
    }
  }, []);

  // Check GPU availability
  const checkGpu = useCallback(async () => {
    try {
      const gpuStatus = await gpuService.getStatus();
      const hasGpu = gpuStatus.hasGpu && gpuStatus.gpuCount > 0;

      updateState({
        hasGpu,
        gpuCount: gpuStatus.gpuCount,
        useGpu: preferGpu && hasGpu,
        currentImage: hasGpu && preferGpu ? "python-gpu" : (defaultImage || "python"),
      });

      return hasGpu;
    } catch {
      updateState({ hasGpu: false, gpuCount: 0, useGpu: false });
      return false;
    }
  }, [preferGpu, defaultImage, updateState]);

  // Load available images
  const loadImages = useCallback(async () => {
    try {
      const result = await dockerService.getNotebookImages();
      updateState({ availableImages: result.images });
    } catch {
      // Use default images
      updateState({
        availableImages: [
          { id: "python", name: "Python 3.11", description: "Basic Python environment" },
          { id: "python-ml", name: "Python ML", description: "NumPy, Pandas, SciPy" },
          { id: "datascience", name: "Data Science", description: "Full data science stack" },
          { id: "python-gpu", name: "Python GPU", description: "CUDA-enabled Python" },
          { id: "tensorflow", name: "TensorFlow", description: "TensorFlow with Jupyter" },
          { id: "pytorch", name: "PyTorch", description: "PyTorch environment" },
        ],
      });
    }
  }, [updateState]);

  // Check if image exists locally
  const checkImageExists = useCallback(async (imageName: string): Promise<boolean> => {
    try {
      const images = await dockerService.listImages();
      const imageMap: Record<string, string> = {
        "python": "python:3.11-slim",
        "python-ml": "jupyter/scipy-notebook",
        "datascience": "jupyter/datascience-notebook",
        "python-gpu": "nvidia/cuda:12.0-runtime-ubuntu22.04",
        "tensorflow": "tensorflow/tensorflow",
        "pytorch": "pytorch/pytorch",
      };

      const fullImageName = imageMap[imageName] || imageName;
      return images.some(img =>
        img.repository.includes(fullImageName.split(":")[0]) ||
        `${img.repository}:${img.tag}`.includes(fullImageName)
      );
    } catch {
      return false;
    }
  }, []);

  // Pull image if needed
  const pullImage = useCallback(async (imageName: string): Promise<boolean> => {
    const imageMap: Record<string, string> = {
      "python": "python:3.11-slim",
      "python-ml": "jupyter/scipy-notebook:latest",
      "datascience": "jupyter/datascience-notebook:latest",
      "python-gpu": "nvidia/cuda:12.0-runtime-ubuntu22.04",
      "tensorflow": "tensorflow/tensorflow:latest-jupyter",
      "pytorch": "pytorch/pytorch:latest",
    };

    const fullImageName = imageMap[imageName] || imageName;

    updateState({
      isPulling: true,
      pullProgress: `Pulling ${fullImageName}...`,
      status: "pulling",
    });

    try {
      await dockerService.pullImage(fullImageName);
      updateState({ isPulling: false, pullProgress: "" });
      return true;
    } catch (error) {
      updateState({
        isPulling: false,
        pullProgress: "",
        lastError: `Failed to pull image: ${error instanceof Error ? error.message : String(error)}`,
      });
      return false;
    }
  }, [updateState]);

  // Create container
  const createContainer = useCallback(async (imageName?: string): Promise<NotebookContainer | null> => {
    const image = imageName || state.currentImage;

    updateState({ status: "checking" });

    // Check if image exists, pull if needed
    const exists = await checkImageExists(image);
    if (!exists) {
      const pulled = await pullImage(image);
      if (!pulled) {
        updateState({ status: "error" });
        return null;
      }
    }

    updateState({ status: "creating" });

    try {
      const containerName = `notebook-${notebookId}-${Date.now()}`;

      const container = await dockerService.createNotebookContainer({
        name: containerName,
        image,
        gpu: state.useGpu && state.hasGpu,
        memory_limit: "4g",
        cpu_limit: 4,
      });

      containerRef.current = container.container_id;

      updateState({
        status: "idle",
        container,
        containerId: container.container_id,
        containerName: container.name,
        currentImage: image,
        lastError: null,
      });

      return container;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      updateState({
        status: "error",
        lastError: `Failed to create container: ${errorMsg}`,
      });
      return null;
    }
  }, [state.currentImage, state.useGpu, state.hasGpu, notebookId, checkImageExists, pullImage, updateState]);

  // Connect to existing or create new container
  const connect = useCallback(async (imageName?: string): Promise<boolean> => {
    if (state.status === "running" || state.status === "idle") {
      return true;
    }

    updateState({ status: "checking" });

    try {
      // Check for existing container for this notebook
      const containers = await dockerService.listNotebookContainers();
      const existing = containers.find(c =>
        c.name.includes(notebookId) &&
        (c.status === "running" || c.status === "idle")
      );

      if (existing) {
        containerRef.current = existing.container_id;
        updateState({
          status: "idle",
          container: existing,
          containerId: existing.container_id,
          containerName: existing.name,
          executionCount: existing.execution_count,
        });
        return true;
      }

      // Create new container
      const container = await createContainer(imageName);
      return container !== null;
    } catch (error) {
      updateState({
        status: "error",
        lastError: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }, [state.status, notebookId, createContainer, updateState]);

  // Disconnect and optionally remove container
  const disconnect = useCallback(async (remove: boolean = false) => {
    if (!containerRef.current) return;

    try {
      if (remove) {
        await dockerService.removeNotebookContainer(containerRef.current, true);
      } else {
        await dockerService.stopNotebookContainer(containerRef.current);
      }
    } catch {
      // Ignore errors during disconnect
    }

    containerRef.current = null;
    updateState({
      status: "disconnected",
      container: null,
      containerId: null,
      containerName: null,
    });
  }, [updateState]);

  // Execute code in container
  const execute = useCallback(async (
    code: string,
    timeout: number = 300
  ): Promise<ContainerExecutionResult | null> => {
    if (!containerRef.current) {
      // Auto-connect if not connected
      const connected = await connect();
      if (!connected || !containerRef.current) {
        return null;
      }
    }

    updateState({ status: "executing", isExecuting: true });

    try {
      const result = await dockerService.executeInContainer(
        containerRef.current,
        code,
        timeout
      );

      updateState({
        status: "idle",
        isExecuting: false,
        executionCount: state.executionCount + 1,
        lastError: result.status === "error" ? result.error || null : null,
      });

      return result;
    } catch (error) {
      updateState({
        status: "error",
        isExecuting: false,
        lastError: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }, [state.executionCount, connect, updateState]);

  // Quick execute (ephemeral container)
  const quickExecute = useCallback(async (
    code: string,
    packages?: string[],
    timeout: number = 300
  ): Promise<ContainerExecutionResult | null> => {
    updateState({ status: "executing", isExecuting: true });

    try {
      const result = await dockerService.quickExecuteInContainer({
        code,
        image: state.currentImage,
        packages,
        timeout,
        cleanup: true,
      });

      updateState({
        status: state.containerId ? "idle" : "disconnected",
        isExecuting: false,
      });

      return result;
    } catch (error) {
      updateState({
        status: "error",
        isExecuting: false,
        lastError: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }, [state.currentImage, state.containerId, updateState]);

  // Install package in container
  const installPackage = useCallback(async (
    packageName: string,
    upgrade: boolean = false
  ): Promise<boolean> => {
    if (!containerRef.current) return false;

    try {
      const result = await dockerService.installContainerPackage(
        containerRef.current,
        packageName,
        upgrade
      );
      return result.success;
    } catch {
      return false;
    }
  }, []);

  // Change image
  const setImage = useCallback(async (imageName: string) => {
    updateState({ currentImage: imageName });

    // If connected, need to recreate container
    if (containerRef.current) {
      await disconnect(true);
      await createContainer(imageName);
    }
  }, [disconnect, createContainer, updateState]);

  // Toggle GPU usage
  const toggleGpu = useCallback(async () => {
    if (!state.hasGpu) return;

    const newUseGpu = !state.useGpu;
    const newImage = newUseGpu ? "python-gpu" : "python";

    updateState({ useGpu: newUseGpu, currentImage: newImage });

    // If connected, need to recreate container
    if (containerRef.current) {
      await disconnect(true);
      await createContainer(newImage);
    }
  }, [state.hasGpu, state.useGpu, disconnect, createContainer, updateState]);

  // Initialize
  useEffect(() => {
    mountedRef.current = true;

    const init = async () => {
      await checkGpu();
      await loadImages();

      if (autoConnect) {
        await connect();
      }
    };

    init();

    return () => {
      mountedRef.current = false;
    };
  }, [autoConnect, checkGpu, loadImages]); // Don't include connect to avoid loop

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (containerRef.current) {
        // Stop container on unmount but don't remove
        dockerService.stopNotebookContainer(containerRef.current).catch(() => {});
      }
    };
  }, []);

  return {
    // State
    ...state,

    // Actions
    connect,
    disconnect,
    execute,
    quickExecute,
    installPackage,
    setImage,
    toggleGpu,
    createContainer,

    // Helpers
    isConnected: state.status === "idle" || state.status === "running",
    canExecute: (state.status === "idle" || state.status === "running") && !state.isExecuting,
  };
}

export default useContainerExecution;
