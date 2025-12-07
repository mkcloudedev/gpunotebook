import { useState, useRef, KeyboardEvent } from "react";
import { Play, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface NotebookCLIProps {
  onExecute: (code: string) => Promise<void>;
  isExecuting?: boolean;
  kernelStatus?: "idle" | "busy" | "starting" | "error" | "dead";
}

export const NotebookCLI = ({
  onExecute,
  isExecuting = false,
  kernelStatus = "idle",
}: NotebookCLIProps) => {
  const [code, setCode] = useState("");
  const [history, setHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleSubmit = async () => {
    const trimmedCode = code.trim();
    if (!trimmedCode || isExecuting) return;

    setHistory(prev => [trimmedCode, ...prev]);
    setHistoryIndex(-1);
    setCode("");

    await onExecute(trimmedCode);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (history.length > 0 && historyIndex < history.length - 1) {
        const newIndex = historyIndex + 1;
        setHistoryIndex(newIndex);
        setCode(history[newIndex]);
      }
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      if (historyIndex > 0) {
        const newIndex = historyIndex - 1;
        setHistoryIndex(newIndex);
        setCode(history[newIndex]);
      } else if (historyIndex === 0) {
        setHistoryIndex(-1);
        setCode("");
      }
    }
  };

  return (
    <div className="flex h-12 items-center border-t border-border bg-[#1e1e1e]">
      {/* Prompt */}
      <div className="flex h-12 w-12 items-center justify-center">
        <span className={cn(
          "font-mono text-sm font-bold",
          isExecuting ? "text-yellow-400" : "text-primary"
        )}>
          &gt;&gt;&gt;
        </span>
      </div>

      {/* Input */}
      <input
        ref={inputRef}
        type="text"
        value={code}
        onChange={(e) => setCode(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Enter Python code and press Enter to execute..."
        className="flex-1 h-full bg-transparent font-mono text-sm text-foreground placeholder:text-muted-foreground/50 outline-none px-2"
        disabled={isExecuting}
      />

      {/* Execute button */}
      <button
        onClick={handleSubmit}
        disabled={isExecuting || !code.trim()}
        className="flex h-12 w-12 items-center justify-center text-primary hover:bg-primary/10 disabled:opacity-50"
      >
        {isExecuting ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <Play className="h-4 w-4" />
        )}
      </button>
    </div>
  );
};

export default NotebookCLI;
