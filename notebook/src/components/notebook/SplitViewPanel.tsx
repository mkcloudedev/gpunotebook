import { useState, useCallback, useRef, useEffect } from "react";
import {
  Columns,
  GitCompare,
  ArrowLeftRight,
  Maximize2,
  X,
  Play,
  Code2,
  FileText,
  ChevronDown,
} from "lucide-react";
import Editor, { DiffEditor } from "@monaco-editor/react";
import { cn } from "@/lib/utils";
import { Cell } from "@/types/notebook";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CellOutputDisplay } from "./CellOutputDisplay";

interface SplitViewPanelProps {
  cells: Cell[];
  leftCellId: string | null;
  rightCellId: string | null;
  onSelectLeftCell: (cellId: string) => void;
  onSelectRightCell: (cellId: string) => void;
  onCellChange: (cellId: string, source: string) => void;
  onRunCell?: (cellId: string) => void;
  onClose: () => void;
}

type DiffLineType = "added" | "removed" | "unchanged";

interface DiffLine {
  lineNumber: number;
  content: string;
  type: DiffLineType;
}

export const SplitViewPanel = ({
  cells,
  leftCellId,
  rightCellId,
  onSelectLeftCell,
  onSelectRightCell,
  onCellChange,
  onRunCell,
  onClose,
}: SplitViewPanelProps) => {
  const [showDiff, setShowDiff] = useState(false);
  const [splitPosition, setSplitPosition] = useState(0.5);
  const containerRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);

  const leftCell = cells.find((c) => c.id === leftCellId);
  const rightCell = cells.find((c) => c.id === rightCellId);

  // Handle drag for resizing
  const handleMouseDown = useCallback(() => {
    isDragging.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isDragging.current || !containerRef.current) return;

      const rect = containerRef.current.getBoundingClientRect();
      const newPosition = (e.clientX - rect.left) / rect.width;
      setSplitPosition(Math.max(0.2, Math.min(0.8, newPosition)));
    };

    const handleMouseUp = () => {
      isDragging.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };

    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("mouseup", handleMouseUp);

    return () => {
      document.removeEventListener("mousemove", handleMouseMove);
      document.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  const swapCells = () => {
    if (leftCellId && rightCellId) {
      onSelectLeftCell(rightCellId);
      onSelectRightCell(leftCellId);
    }
  };

  const resetSplit = () => {
    setSplitPosition(0.5);
  };

  // Calculate diff between cells
  const calculateDiff = (): DiffLine[] => {
    if (!leftCell || !rightCell) return [];

    const leftLines = leftCell.source.split("\n");
    const rightLines = rightCell.source.split("\n");
    const maxLines = Math.max(leftLines.length, rightLines.length);
    const diffLines: DiffLine[] = [];

    for (let i = 0; i < maxLines; i++) {
      const leftLine = i < leftLines.length ? leftLines[i] : "";
      const rightLine = i < rightLines.length ? rightLines[i] : "";
      const isDifferent = leftLine !== rightLine;

      if (!isDifferent) {
        diffLines.push({
          lineNumber: i + 1,
          content: leftLine,
          type: "unchanged",
        });
      } else {
        if (leftLine) {
          diffLines.push({
            lineNumber: i + 1,
            content: leftLine,
            type: "removed",
          });
        }
        if (rightLine) {
          diffLines.push({
            lineNumber: i + 1,
            content: rightLine,
            type: "added",
          });
        }
      }
    }

    return diffLines;
  };

  const countDifferences = (additions: boolean): number => {
    if (!leftCell || !rightCell) return 0;

    const leftLines = leftCell.source.split("\n");
    const rightLines = rightCell.source.split("\n");
    const maxLines = Math.max(leftLines.length, rightLines.length);
    let count = 0;

    for (let i = 0; i < maxLines; i++) {
      const leftLine = i < leftLines.length ? leftLines[i] : "";
      const rightLine = i < rightLines.length ? rightLines[i] : "";

      if (leftLine !== rightLine) {
        if (additions && rightLine) count++;
        if (!additions && leftLine) count++;
      }
    }

    return count;
  };

  return (
    <div className="flex flex-col h-full rounded-lg border border-border bg-card overflow-hidden">
      {/* Header - compact */}
      <div className="flex items-center gap-2 px-3 py-1.5 bg-secondary/50 border-b border-border">
        <div className="flex items-center justify-center w-6 h-6 rounded bg-primary/10">
          <Columns className="h-3 w-3 text-primary" />
        </div>
        <span className="text-xs font-semibold text-foreground">Split View</span>

        <div className="flex-1" />

        {/* Toggle diff view */}
        <Button
          size="sm"
          variant={showDiff ? "default" : "ghost"}
          className="h-6 px-1.5 gap-1"
          onClick={() => setShowDiff(!showDiff)}
        >
          <GitCompare className="h-3 w-3" />
          <span className="text-[10px]">Diff</span>
        </Button>

        {/* Swap cells */}
        <Button
          size="sm"
          variant="ghost"
          className="h-6 w-6 p-0"
          onClick={swapCells}
          title="Swap Cells"
        >
          <ArrowLeftRight className="h-3 w-3" />
        </Button>

        {/* Reset split */}
        <Button
          size="sm"
          variant="ghost"
          className="h-6 w-6 p-0"
          onClick={resetSplit}
          title="Reset Split"
        >
          <Maximize2 className="h-3 w-3" />
        </Button>

        {/* Close */}
        <Button
          size="sm"
          variant="ghost"
          className="h-6 w-6 p-0"
          onClick={onClose}
          title="Close Split View"
        >
          <X className="h-3 w-3" />
        </Button>
      </div>

      {/* Split content */}
      <div ref={containerRef} className="flex flex-1 overflow-hidden">
        {/* Left panel */}
        <div
          className="flex flex-col overflow-hidden border-r border-border"
          style={{ width: `calc(${splitPosition * 100}% - 4px)` }}
        >
          <CellPanel
            cell={leftCell}
            cells={cells}
            isLeft={true}
            onSelect={onSelectLeftCell}
            onChange={(source) => leftCell && onCellChange(leftCell.id, source)}
            onRun={() => leftCell && onRunCell?.(leftCell.id)}
          />
        </div>

        {/* Resizable divider */}
        <div
          className="w-2 bg-border hover:bg-primary/50 cursor-col-resize flex items-center justify-center transition-colors"
          onMouseDown={handleMouseDown}
        >
          <div className="w-1 h-10 bg-muted-foreground/50 rounded-full" />
        </div>

        {/* Right panel */}
        <div
          className="flex flex-col overflow-hidden"
          style={{ width: `calc(${(1 - splitPosition) * 100}% - 4px)` }}
        >
          <CellPanel
            cell={rightCell}
            cells={cells}
            isLeft={false}
            onSelect={onSelectRightCell}
            onChange={(source) => rightCell && onCellChange(rightCell.id, source)}
            onRun={() => rightCell && onRunCell?.(rightCell.id)}
          />
        </div>
      </div>

      {/* Monaco Diff Editor view */}
      {showDiff && leftCell && rightCell && (
        <div className="h-64 border-t border-border bg-muted/30 flex flex-col">
          {/* Diff header */}
          <div className="flex items-center gap-2 px-4 py-2 bg-muted/50 border-b border-border">
            <GitCompare className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-xs font-medium text-foreground">Diff View</span>
            <span className="text-[10px] text-muted-foreground">
              {leftCell.id.slice(-8)} ↔ {rightCell.id.slice(-8)}
            </span>
            <div className="flex-1" />
            <DiffStats
              additions={countDifferences(true)}
              deletions={countDifferences(false)}
            />
          </div>

          {/* Monaco Diff Editor */}
          <div className="flex-1 overflow-hidden">
            <DiffEditor
              original={leftCell.source}
              modified={rightCell.source}
              language={leftCell.cellType === "code" ? "python" : "markdown"}
              theme="vs-dark"
              options={{
                readOnly: true,
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                lineNumbers: "on",
                lineNumbersMinChars: 3,
                fontSize: 11,
                fontFamily: "'JetBrains Mono', monospace",
                wordWrap: "on",
                automaticLayout: true,
                renderSideBySide: true,
                enableSplitViewResizing: true,
                renderOverviewRuler: false,
                diffWordWrap: "on",
                ignoreTrimWhitespace: false,
                renderIndicators: true,
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
};

// Cell Panel Component
interface CellPanelProps {
  cell: Cell | undefined;
  cells: Cell[];
  isLeft: boolean;
  onSelect: (cellId: string) => void;
  onChange: (source: string) => void;
  onRun: () => void;
}

const CellPanel = ({
  cell,
  cells,
  isLeft,
  onSelect,
  onChange,
  onRun,
}: CellPanelProps) => {
  return (
    <>
      {/* Cell selector header */}
      <div className="flex items-center gap-2 p-2 bg-muted/50 border-b border-border">
        <span
          className={cn(
            "px-2 py-0.5 text-[10px] font-bold rounded",
            isLeft
              ? "bg-primary/15 text-primary"
              : "bg-green-500/15 text-green-500"
          )}
        >
          {isLeft ? "LEFT" : "RIGHT"}
        </span>

        <Select value={cell?.id || ""} onValueChange={onSelect}>
          <SelectTrigger className="flex-1 h-8 text-xs">
            <SelectValue placeholder="Select cell..." />
          </SelectTrigger>
          <SelectContent>
            {cells.map((c, index) => {
              const preview = c.source.split("\n")[0];
              const truncated =
                preview.length > 30 ? `${preview.substring(0, 30)}...` : preview;

              return (
                <SelectItem key={c.id} value={c.id}>
                  <div className="flex items-center gap-2">
                    <span
                      className={cn(
                        "flex items-center justify-center w-5 h-5 rounded text-[10px] font-bold",
                        c.cellType === "code"
                          ? "bg-primary/15 text-primary"
                          : "bg-green-500/15 text-green-500"
                      )}
                    >
                      {index + 1}
                    </span>
                    <span className="text-xs truncate">
                      {truncated || "(empty)"}
                    </span>
                  </div>
                </SelectItem>
              );
            })}
          </SelectContent>
        </Select>

        {cell && (
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0 text-green-500"
            onClick={onRun}
            title="Run Cell"
          >
            <Play className="h-3.5 w-3.5" />
          </Button>
        )}
      </div>

      {/* Cell content */}
      {cell ? (
        <div className="flex flex-col flex-1 overflow-hidden">
          {/* Cell info bar */}
          <div className="flex items-center gap-2 px-3 py-1.5 bg-[#1e1e1e] text-xs text-muted-foreground">
            {cell.cellType === "code" ? (
              <Code2 className="h-3 w-3" />
            ) : (
              <FileText className="h-3 w-3" />
            )}
            <span>{cell.cellType === "code" ? "Code" : "Markdown"}</span>
            {cell.executionCount && (
              <span className="px-1.5 py-0.5 bg-muted rounded text-[10px]">
                [{cell.executionCount}]
              </span>
            )}
            <div className="flex-1" />
            <span>{cell.source.split("\n").length} lines</span>
          </div>

          {/* Editor */}
          <div className="flex-1 overflow-hidden">
            <Editor
              value={cell.source}
              onChange={(value) => onChange(value || "")}
              language={cell.cellType === "code" ? "python" : "markdown"}
              theme="vs-dark"
              options={{
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                lineNumbers: "on",
                lineNumbersMinChars: 3,
                fontSize: 12,
                fontFamily: "'JetBrains Mono', monospace",
                wordWrap: "on",
                automaticLayout: true,
                folding: true,
                padding: { top: 8, bottom: 8 },
              }}
            />
          </div>

          {/* Output (if any) */}
          {cell.outputs.length > 0 && (
            <div className="max-h-24 overflow-auto border-t border-border">
              <CellOutputDisplay outputs={cell.outputs} maxHeight={96} compact />
            </div>
          )}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center flex-1 text-muted-foreground">
          <Code2 className="h-12 w-12 opacity-30 mb-4" />
          <span className="text-sm">Select a cell</span>
          <span className="text-xs opacity-70 mt-1">
            Choose a cell from the dropdown above
          </span>
        </div>
      )}
    </>
  );
};

// Diff Stats Component
interface DiffStatsProps {
  additions: number;
  deletions: number;
}

const DiffStats = ({ additions, deletions }: DiffStatsProps) => (
  <div className="flex items-center gap-1">
    <span className="px-1.5 py-0.5 text-[10px] font-bold bg-green-500/15 text-green-500 rounded">
      +{additions}
    </span>
    <span className="px-1.5 py-0.5 text-[10px] font-bold bg-destructive/15 text-destructive rounded">
      -{deletions}
    </span>
  </div>
);

// Diff Line Component
interface DiffLineComponentProps {
  line: DiffLine;
}

const DiffLineComponent = ({ line }: DiffLineComponentProps) => {
  const getBgColor = () => {
    switch (line.type) {
      case "added":
        return "bg-green-500/10";
      case "removed":
        return "bg-destructive/10";
      default:
        return "";
    }
  };

  const getTextColor = () => {
    switch (line.type) {
      case "added":
        return "text-green-500";
      case "removed":
        return "text-destructive";
      default:
        return "text-foreground";
    }
  };

  const getPrefix = () => {
    switch (line.type) {
      case "added":
        return "+";
      case "removed":
        return "-";
      default:
        return " ";
    }
  };

  return (
    <div className={cn("flex px-2 py-0.5", getBgColor())}>
      <span className="w-8 text-muted-foreground text-right pr-2">
        {line.lineNumber}
      </span>
      <span className={cn("font-bold w-4", getTextColor())}>{getPrefix()}</span>
      <span className={getTextColor()}>{line.content}</span>
    </div>
  );
};

export default SplitViewPanel;
