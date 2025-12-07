import { useRef, useEffect, useState } from "react";
import { Terminal, Trash2, Minus, X, ArrowDownToLine, Pause, AlertCircle, CheckCircle, Info, AlertTriangle, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

export interface LogEntry {
  id: string;
  timestamp: Date;
  type: "stdout" | "stderr" | "error" | "info" | "success" | "warning";
  message: string;
  cellId?: string;
}

interface ExecutionLogPanelProps {
  logs: LogEntry[];
  isExecuting?: boolean;
  isMinimized?: boolean;
  onClear?: () => void;
  onClose?: () => void;
  onMinimize?: () => void;
}

export const ExecutionLogPanel = ({
  logs,
  isExecuting = false,
  isMinimized = false,
  onClear,
  onClose,
  onMinimize,
}: ExecutionLogPanelProps) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [autoScroll, setAutoScroll] = useState(true);

  // Auto-scroll to bottom when new logs arrive
  useEffect(() => {
    if (autoScroll && scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [logs, autoScroll]);

  const getLogIcon = (type: LogEntry["type"]) => {
    switch (type) {
      case "stderr":
      case "error":
        return <AlertCircle className="h-3.5 w-3.5" />;
      case "success":
        return <CheckCircle className="h-3.5 w-3.5" />;
      case "info":
        return <Info className="h-3.5 w-3.5" />;
      case "warning":
        return <AlertTriangle className="h-3.5 w-3.5" />;
      default:
        return <Terminal className="h-3.5 w-3.5" />;
    }
  };

  const getLogColor = (type: LogEntry["type"]) => {
    switch (type) {
      case "stderr":
      case "error":
        return "text-red-400";
      case "success":
        return "text-green-400";
      case "info":
        return "text-blue-400";
      case "warning":
        return "text-orange-400";
      default:
        return "text-foreground";
    }
  };

  const errorCount = logs.filter(l => l.type === "error" || l.type === "stderr").length;

  // Minimized view
  if (isMinimized) {
    return (
      <div className="absolute bottom-16 right-4 z-20">
        <button
          onClick={onMinimize}
          className="flex items-center gap-2 rounded-full border border-border bg-card px-4 py-2.5 shadow-lg hover:bg-muted transition-colors"
        >
          {isExecuting ? (
            <Loader2 className="h-4 w-4 animate-spin text-primary" />
          ) : (
            <Terminal className="h-4 w-4 text-muted-foreground" />
          )}
          <span className="text-sm text-foreground">Logs ({logs.length})</span>
          {errorCount > 0 && (
            <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1.5 text-xs font-bold text-white">
              {errorCount}
            </span>
          )}
        </button>
      </div>
    );
  }

  // Expanded view
  return (
    <div className="absolute bottom-16 right-4 z-20 w-[450px] rounded-xl border border-border bg-card shadow-2xl">
      {/* Header */}
      <div className="flex items-center gap-2 rounded-t-xl bg-muted px-3 py-2">
        {isExecuting ? (
          <Loader2 className="h-4 w-4 animate-spin text-primary" />
        ) : (
          <Terminal className="h-4 w-4 text-primary" />
        )}
        <span className="text-sm font-semibold text-foreground">Execution Logs</span>

        <div className="flex-1" />

        {/* Auto-scroll toggle */}
        <button
          onClick={() => setAutoScroll(!autoScroll)}
          className={cn(
            "rounded p-1.5 transition-colors",
            autoScroll ? "text-primary hover:bg-primary/10" : "text-muted-foreground hover:bg-muted"
          )}
          title={autoScroll ? "Disable auto-scroll" : "Enable auto-scroll"}
        >
          {autoScroll ? (
            <ArrowDownToLine className="h-3.5 w-3.5" />
          ) : (
            <Pause className="h-3.5 w-3.5" />
          )}
        </button>

        {/* Clear */}
        <button
          onClick={onClear}
          className="rounded p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          title="Clear logs"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>

        {/* Minimize */}
        <button
          onClick={onMinimize}
          className="rounded p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          title="Minimize"
        >
          <Minus className="h-3.5 w-3.5" />
        </button>

        {/* Close */}
        <button
          onClick={onClose}
          className="rounded p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          title="Close"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>

      {/* Logs list */}
      <div ref={scrollRef} className="h-[280px] overflow-auto p-2">
        {logs.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center gap-2">
            <Terminal className="h-8 w-8 text-muted-foreground/30" />
            <p className="text-sm text-muted-foreground">No logs yet</p>
            <p className="text-xs text-muted-foreground/70">Run a cell to see output here</p>
          </div>
        ) : (
          <div className="space-y-1">
            {logs.map((log) => (
              <LogEntryItem key={log.id} log={log} getIcon={getLogIcon} getColor={getLogColor} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

interface LogEntryItemProps {
  log: LogEntry;
  getIcon: (type: LogEntry["type"]) => React.ReactNode;
  getColor: (type: LogEntry["type"]) => string;
}

const LogEntryItem = ({ log, getIcon, getColor }: LogEntryItemProps) => {
  const timeStr = `${log.timestamp.getHours().toString().padStart(2, "0")}:${log.timestamp.getMinutes().toString().padStart(2, "0")}:${log.timestamp.getSeconds().toString().padStart(2, "0")}`;

  return (
    <div className="flex items-start gap-2 py-0.5">
      <span className="text-[10px] font-mono text-muted-foreground/50 min-w-[60px]">
        {timeStr}
      </span>
      <span className={cn("mt-0.5", getColor(log.type))}>
        {getIcon(log.type)}
      </span>
      <pre className={cn(
        "flex-1 text-xs font-mono whitespace-pre-wrap break-all",
        getColor(log.type)
      )}>
        {log.message}
      </pre>
    </div>
  );
};

export default ExecutionLogPanel;
