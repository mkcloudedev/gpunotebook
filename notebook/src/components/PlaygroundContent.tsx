import { useState, useEffect, useCallback } from "react";
import { Play, Square, Copy, Eraser, Terminal, Code2, ChevronDown, Loader2, Home, Sparkles, Trash2, Activity, Check, RotateCcw, Clock } from "lucide-react";
import { cn, copyToClipboard } from "@/lib/utils";
import { Button } from "./ui/button";
import { Breadcrumb } from "./Breadcrumb";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "./ui/tooltip";
import { MonacoCodeEditor } from "./notebook/MonacoCodeEditor";
import { useKernelExecution } from "@/hooks/useKernelExecution";
import { CellOutput } from "@/types/notebook";

const defaultCode = `import torch
import torch.nn as nn

# Check GPU availability
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")

# Create a simple tensor
x = torch.randn(3, 3).cuda()
print(f"Tensor on GPU: {x}")`;

const snippets = [
  { label: "GPU Info", code: "torch.cuda.get_device_properties(0)" },
  { label: "Memory Usage", code: "torch.cuda.memory_allocated()" },
  { label: "Clear Cache", code: "torch.cuda.empty_cache()" },
  { label: "Random Tensor", code: "torch.randn(3, 3).cuda()" },
  { label: "Import NumPy", code: "import numpy as np" },
  { label: "Import Pandas", code: "import pandas as pd" },
];

// Format output from kernel
const formatOutput = (output: CellOutput): string => {
  if (output.text) return output.text;
  if (output.ename && output.evalue) {
    const traceback = output.traceback?.join("\n") || "";
    return `${output.ename}: ${output.evalue}\n${traceback}`;
  }
  if (output.data) {
    if (typeof output.data["text/plain"] === "string") {
      return output.data["text/plain"];
    }
    return JSON.stringify(output.data, null, 2);
  }
  return "";
};

// Format duration
const formatDuration = (ms: number): string => {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
};

export const PlaygroundContent = () => {
  const [code, setCode] = useState(defaultCode);
  const [outputs, setOutputs] = useState<CellOutput[]>([]);
  const [executionStartTime, setExecutionStartTime] = useState<number | null>(null);
  const [executionDuration, setExecutionDuration] = useState<number | null>(null);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [copied, setCopied] = useState(false);

  // Real kernel execution hook
  const {
    kernel,
    kernelStatus,
    isConnected,
    isExecuting,
    connect,
    disconnect,
    execute,
    interrupt,
    restart,
  } = useKernelExecution({
    onOutput: useCallback((cellId: string, output: CellOutput) => {
      if (cellId === "playground") {
        setOutputs((prev) => [...prev, output]);
      }
    }, []),
    onExecutionStart: useCallback((cellId: string) => {
      if (cellId === "playground") {
        setExecutionStartTime(Date.now());
        setExecutionDuration(null);
      }
    }, []),
    onExecutionComplete: useCallback((cellId: string) => {
      if (cellId === "playground") {
        setExecutionDuration(Date.now() - (executionStartTime || Date.now()));
      }
    }, [executionStartTime]),
    onExecutionError: useCallback((cellId: string, error: string) => {
      if (cellId === "playground") {
        setOutputs((prev) => [...prev, {
          outputType: "error",
          ename: "Error",
          evalue: error,
          traceback: [],
        }]);
        setExecutionDuration(Date.now() - (executionStartTime || Date.now()));
      }
    }, [executionStartTime]),
  });

  // Connect to kernel on mount
  useEffect(() => {
    connect().catch(console.error);
    return () => disconnect();
  }, []);

  // Live timer while executing
  useEffect(() => {
    if (isExecuting && executionStartTime) {
      const interval = setInterval(() => {
        setElapsedTime(Date.now() - executionStartTime);
      }, 100);
      return () => clearInterval(interval);
    } else {
      setElapsedTime(0);
    }
  }, [isExecuting, executionStartTime]);

  const handleRun = async () => {
    if (!kernel) {
      setOutputs([{
        outputType: "error",
        ename: "ConnectionError",
        evalue: "Kernel not available. Please wait...",
        traceback: [],
      }]);
      return;
    }

    setOutputs([]);
    try {
      await execute("playground", code);
    } catch (error) {
      console.error("Execution error:", error);
    }
  };

  const handleCopy = async () => {
    const success = await copyToClipboard(code);
    if (success) {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleClear = () => {
    setCode("");
  };

  const handleClearOutput = () => {
    setOutputs([]);
    setExecutionDuration(null);
  };

  const handleStop = async () => {
    await interrupt();
  };

  const handleRestart = async () => {
    setOutputs([]);
    await restart();
  };

  const insertSnippet = (snippetCode: string) => {
    setCode((prev) => prev + "\n" + snippetCode);
  };

  const getKernelStatusColor = () => {
    switch (kernelStatus) {
      case "idle":
        return "bg-success";
      case "busy":
        return "bg-yellow-500";
      case "starting":
        return "bg-blue-500";
      case "error":
        return "bg-destructive";
      case "disconnected":
        return "bg-muted-foreground";
      default:
        return "bg-muted-foreground";
    }
  };

  const getKernelStatusText = () => {
    switch (kernelStatus) {
      case "idle":
        return "Ready";
      case "busy":
        return "Busy";
      case "starting":
        return "Starting...";
      case "error":
        return "Error";
      case "disconnected":
        return "Disconnected";
      default:
        return "Unknown";
    }
  };

  // Combine outputs into display string
  const outputText = outputs.map(formatOutput).filter(Boolean).join("");

  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Playground", icon: <Sparkles className="h-4 w-4" /> },
  ];

  const breadcrumbActions = (
    <div className="flex items-center gap-2">
      {/* Action buttons */}
      <BreadcrumbAction
        icon={copied ? <Check className="h-4 w-4 text-success" /> : <Copy className="h-4 w-4" />}
        tooltip="Copy Code"
        onClick={handleCopy}
      />
      <BreadcrumbAction icon={<Eraser className="h-4 w-4" />} tooltip="Clear Code" onClick={handleClear} />
      <BreadcrumbAction icon={<Trash2 className="h-4 w-4" />} tooltip="Clear Output" onClick={handleClearOutput} />
      <BreadcrumbAction icon={<RotateCcw className="h-4 w-4" />} tooltip="Restart Kernel" onClick={handleRestart} />

      <div className="mx-2 h-4 w-px bg-border" />

      {/* Language indicator with colored dot */}
      <div className="flex items-center gap-1.5 rounded-md bg-muted px-2.5 py-1.5">
        <span
          className="h-2 w-2 rounded-full"
          style={{ backgroundColor: "#3572A5" }} // Python color
        />
        <span className="text-xs font-medium text-foreground">Python</span>
      </div>

      <div className="mx-2 h-4 w-px bg-border" />

      {/* Kernel Status */}
      <div className="flex items-center gap-1.5 rounded-md bg-muted px-2.5 py-1.5">
        <span className={cn("h-2 w-2 rounded-full", getKernelStatusColor())} />
        <span className="text-xs font-medium text-foreground">
          {getKernelStatusText()}
        </span>
        {isExecuting && (
          <span className="ml-1 flex items-center gap-1 rounded bg-primary/10 px-1.5 py-0.5 text-[10px] text-primary">
            <Clock className="h-2.5 w-2.5" />
            {formatDuration(elapsedTime)}
          </span>
        )}
      </div>

      <div className="mx-2 h-4 w-px bg-border" />

      {/* Run/Stop button */}
      <Button
        onClick={isExecuting ? handleStop : handleRun}
        size="sm"
        disabled={!kernel || kernelStatus === "starting"}
        className={cn(
          "gap-2",
          isExecuting
            ? "bg-destructive hover:bg-destructive/90"
            : "bg-success hover:bg-success/90"
        )}
      >
        {isExecuting ? (
          <>
            <Square className="h-4 w-4" />
            Stop
          </>
        ) : (
          <>
            <Play className="h-4 w-4" />
            Run
          </>
        )}
      </Button>
    </div>
  );

  return (
    <main className="flex flex-1 flex-col overflow-hidden">
      {/* Breadcrumb */}
      <Breadcrumb items={breadcrumbItems} actions={breadcrumbActions} />

      {/* Split panels: Editor | Output */}
      <div className="flex flex-1 overflow-hidden">
        {/* Editor panel */}
        <div className="flex flex-1 flex-col border-r border-border bg-[hsl(var(--muted))]">
          {/* Panel header */}
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <div className="flex items-center gap-2">
              <Code2 className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm font-medium text-foreground">Code</span>
            </div>
            <div className="flex items-center gap-1">
              <button
                onClick={handleCopy}
                className="rounded p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <Copy className="h-4 w-4" />
              </button>
              <button
                onClick={handleClear}
                className="rounded p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <Eraser className="h-4 w-4" />
              </button>
            </div>
          </div>
          {/* Code editor */}
          <div className="flex-1 overflow-hidden">
            <MonacoCodeEditor
              value={code}
              onChange={setCode}
              language="python"
              height="100%"
              onExecute={handleRun}
              placeholder="# Enter Python code..."
              noBorder
            />
          </div>
        </div>

        {/* Output panel */}
        <div className="flex flex-1 flex-col bg-card">
          {/* Panel header */}
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <div className="flex items-center gap-2">
              <Terminal className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm font-medium text-foreground">Output</span>
              {executionDuration !== null && (
                <span className="flex items-center gap-1 rounded bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground">
                  <Clock className="h-2.5 w-2.5" />
                  {formatDuration(executionDuration)}
                </span>
              )}
            </div>
            {outputs.length > 0 && (
              <button
                onClick={handleClearOutput}
                className="rounded p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <Eraser className="h-4 w-4" />
              </button>
            )}
          </div>
          {/* Output content */}
          <div className="flex-1 overflow-auto p-4">
            {isExecuting ? (
              <div className="flex h-full flex-col items-center justify-center gap-2">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
                <span className="text-sm text-muted-foreground">Executing...</span>
                {outputText && (
                  <pre className="mt-4 w-full font-mono text-sm text-foreground whitespace-pre-wrap">
                    {outputText}
                  </pre>
                )}
              </div>
            ) : outputText ? (
              <pre className="font-mono text-sm text-foreground whitespace-pre-wrap">
                {outputText}
              </pre>
            ) : (
              <div className="flex h-full flex-col items-center justify-center gap-4">
                <Terminal className="h-12 w-12 text-muted-foreground/30" />
                <p className="text-sm text-muted-foreground">
                  Run your code to see output here
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Footer - Quick Snippets */}
      <div className="border-t border-border bg-card px-4 py-3">
        <div className="flex items-center gap-3">
          <span className="text-xs font-medium text-muted-foreground">Quick Snippets</span>
          <div className="flex flex-wrap gap-2">
            {snippets.map((snippet) => (
              <SnippetChip
                key={snippet.label}
                label={snippet.label}
                onClick={() => insertSnippet(snippet.code)}
              />
            ))}
          </div>
        </div>
      </div>
    </main>
  );
};

interface SnippetChipProps {
  label: string;
  onClick: () => void;
}

const SnippetChip = ({ label, onClick }: SnippetChipProps) => {
  return (
    <button
      onClick={onClick}
      className="rounded-md border border-border bg-muted px-2.5 py-1 text-xs text-foreground transition-colors hover:border-primary/30 hover:bg-primary/10 hover:text-primary"
    >
      {label}
    </button>
  );
};

interface BreadcrumbActionProps {
  icon: React.ReactNode;
  tooltip: string;
  onClick: () => void;
}

const BreadcrumbAction = ({ icon, tooltip, onClick }: BreadcrumbActionProps) => {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          onClick={onClick}
          className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          {icon}
        </button>
      </TooltipTrigger>
      <TooltipContent>
        <p>{tooltip}</p>
      </TooltipContent>
    </Tooltip>
  );
};
