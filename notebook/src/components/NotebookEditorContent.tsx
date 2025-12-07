import { useState, useRef, useEffect } from "react";
import {
  Play,
  Plus,
  Trash2,
  ChevronUp,
  ChevronDown,
  ChevronRight,
  Code2,
  FileText,
  Copy,
  MoreHorizontal,
  Loader2,
  Check,
  GripVertical,
  Eye,
  Pencil,
  ArrowUp,
  ArrowDown,
  Minimize2,
  Maximize2,
  Clock,
  Info,
  Scissors,
  Eraser,
  SkipForward,
} from "lucide-react";
import { cn, copyToClipboard } from "@/lib/utils";
import { Cell, CellOutput, CellTag, CellMetadata } from "@/types/notebook";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import { MonacoCodeEditor } from "./notebook/MonacoCodeEditor";
import { MarkdownRenderer } from "./notebook/MarkdownRenderer";
import { CellOutputDisplay } from "./notebook/CellOutputDisplay";
import { CellTagsWidget } from "./notebook/CellTagsWidget";

interface NotebookEditorContentProps {
  cells: Cell[];
  selectedCellId: string | null;
  selectedCellIds?: Set<string>;
  onSelectCell: (id: string, isShiftHeld?: boolean) => void;
  onUpdateCell: (id: string, source: string) => void;
  onDeleteCell: (id: string) => void;
  onExecuteCell: (id: string) => void;
  onExecuteAndSelectNext?: (id: string) => void;
  onAddCell: (type: "code" | "markdown", afterCellId?: string) => void;
  onMoveCell?: (cellId: string, direction: "up" | "down") => void;
  onUpdateCellTags?: (cellId: string, tags: CellTag[]) => void;
  onRunAllAbove?: (cellId: string) => void;
  onRunAllBelow?: (cellId: string) => void;
  onToggleCollapse?: (cellId: string) => void;
  onChangeCellType?: (cellId: string, newType: "code" | "markdown") => void;
  onShowMetadata?: (cell: Cell) => void;
  onClearOutput?: (cellId: string) => void;
  onSplitCell?: (cellId: string, lineNumber: number) => void;
  kernelId?: string;
  splitViewOverlay?: React.ReactNode;
  isCommandMode?: boolean;
  isPresentationMode?: boolean;
  isZenMode?: boolean;
}

export const NotebookEditorContent = ({
  cells,
  selectedCellId,
  selectedCellIds = new Set(),
  onSelectCell,
  onUpdateCell,
  onDeleteCell,
  onExecuteCell,
  onExecuteAndSelectNext,
  onAddCell,
  onMoveCell,
  onUpdateCellTags,
  onRunAllAbove,
  onRunAllBelow,
  onToggleCollapse,
  onChangeCellType,
  onShowMetadata,
  onClearOutput,
  onSplitCell,
  kernelId,
  splitViewOverlay,
  isCommandMode = false,
  isPresentationMode = false,
  isZenMode = false,
}: NotebookEditorContentProps) => {
  // Drag and drop state
  const [draggedCellId, setDraggedCellId] = useState<string | null>(null);
  const [dragOverCellId, setDragOverCellId] = useState<string | null>(null);

  const containerRef = useRef<HTMLDivElement>(null);

  const handleDragStart = (cellId: string) => {
    setDraggedCellId(cellId);
  };

  const handleDragOver = (e: React.DragEvent, cellId: string) => {
    e.preventDefault();
    setDragOverCellId(cellId);
  };

  const handleDragEnd = () => {
    setDraggedCellId(null);
    setDragOverCellId(null);
  };

  const handleDrop = (e: React.DragEvent, targetCellId: string) => {
    e.preventDefault();
    if (draggedCellId && draggedCellId !== targetCellId && onMoveCell) {
      // Determine direction based on position
      const draggedIndex = cells.findIndex((c) => c.id === draggedCellId);
      const targetIndex = cells.findIndex((c) => c.id === targetCellId);

      if (draggedIndex < targetIndex) {
        onMoveCell(draggedCellId, "down");
      } else {
        onMoveCell(draggedCellId, "up");
      }
    }
    handleDragEnd();
  };

  return (
    <div
      ref={containerRef}
      tabIndex={0}
      className={cn(
        "flex flex-1 flex-col overflow-hidden outline-none",
        isCommandMode && "ring-2 ring-blue-500/30",
        isZenMode && "bg-background"
      )}
    >
      {/* Command Mode Indicator */}
      {isCommandMode && !isZenMode && (
        <div className="flex items-center gap-2 bg-blue-500/10 border-b border-blue-500/20 px-4 py-1">
          <span className="text-[10px] font-medium text-blue-500">COMMAND MODE</span>
          <span className="text-[10px] text-muted-foreground">
            Press <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono">Enter</kbd> to edit •
            <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono ml-1">j/k</kbd> navigate •
            <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono ml-1">a/b</kbd> add cell •
            <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono ml-1">x</kbd> delete •
            <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono ml-1">Shift+Enter</kbd> run & next
          </span>
        </div>
      )}

      {/* Presentation Mode Indicator */}
      {isPresentationMode && !isZenMode && (
        <div className="flex items-center gap-2 bg-purple-500/10 border-b border-purple-500/20 px-4 py-1">
          <span className="text-[10px] font-medium text-purple-500">PRESENTATION MODE</span>
          <span className="text-[10px] text-muted-foreground">
            Code hidden • Press <kbd className="px-1 py-0.5 bg-muted rounded text-[9px] font-mono">Ctrl+Shift+P</kbd> to exit
          </span>
        </div>
      )}

      {/* Cells */}
      <div className={cn("flex-1 overflow-auto p-4", isZenMode && "p-8")}>
        {cells.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-border p-12">
            <Code2 className="h-12 w-12 text-muted-foreground/50" />
            <p className="mt-4 text-sm text-muted-foreground">
              No cells yet. Add a code or markdown cell to get started.
            </p>
            <div className="mt-4 flex gap-2">
              <Button size="sm" onClick={() => onAddCell("code")}>
                <Plus className="mr-1 h-4 w-4" />
                Add Code Cell
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => onAddCell("markdown")}
              >
                <Plus className="mr-1 h-4 w-4" />
                Add Markdown
              </Button>
            </div>
          </div>
        ) : (
          <div className={cn("mx-auto max-w-5xl space-y-1 relative", isZenMode && "max-w-4xl")}>
            {cells.map((cell, index) => (
              <CellComponent
                key={cell.id}
                cell={cell}
                index={index}
                isSelected={selectedCellId === cell.id}
                isMultiSelected={selectedCellIds.has(cell.id)}
                isDragging={draggedCellId === cell.id}
                isDragOver={dragOverCellId === cell.id}
                onSelect={(e) => onSelectCell(cell.id, e?.shiftKey)}
                onUpdate={(source) => onUpdateCell(cell.id, source)}
                onDelete={() => onDeleteCell(cell.id)}
                onExecute={() => onExecuteCell(cell.id)}
                onExecuteAndNext={() => onExecuteAndSelectNext?.(cell.id)}
                onAddCellBelow={(type) => onAddCell(type, cell.id)}
                onMoveUp={() => onMoveCell?.(cell.id, "up")}
                onMoveDown={() => onMoveCell?.(cell.id, "down")}
                onUpdateTags={(tags) => onUpdateCellTags?.(cell.id, tags)}
                onRunAllAbove={() => onRunAllAbove?.(cell.id)}
                onRunAllBelow={() => onRunAllBelow?.(cell.id)}
                onToggleCollapse={() => onToggleCollapse?.(cell.id)}
                onShowMetadata={() => onShowMetadata?.(cell)}
                onClearOutput={() => onClearOutput?.(cell.id)}
                onSplitCell={(line) => onSplitCell?.(cell.id, line)}
                onDragStart={() => handleDragStart(cell.id)}
                onDragOver={(e) => handleDragOver(e, cell.id)}
                onDragEnd={handleDragEnd}
                onDrop={(e) => handleDrop(e, cell.id)}
                canMoveUp={index > 0}
                canMoveDown={index < cells.length - 1}
                kernelId={kernelId}
                isPresentationMode={isPresentationMode}
                isZenMode={isZenMode}
              />
            ))}
            {/* Split View Overlay */}
            {splitViewOverlay && (
              <div className="sticky bottom-0 z-10">
                {splitViewOverlay}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

interface CellComponentProps {
  cell: Cell;
  index: number;
  isSelected: boolean;
  isMultiSelected?: boolean;
  isDragging: boolean;
  isDragOver: boolean;
  onSelect: (e?: React.MouseEvent) => void;
  onUpdate: (source: string) => void;
  onDelete: () => void;
  onExecute: () => void;
  onExecuteAndNext?: () => void;
  onAddCellBelow: (type: "code" | "markdown") => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onUpdateTags?: (tags: CellTag[]) => void;
  onRunAllAbove?: () => void;
  onRunAllBelow?: () => void;
  onToggleCollapse?: () => void;
  onShowMetadata?: () => void;
  onClearOutput?: () => void;
  onSplitCell?: (lineNumber: number) => void;
  onDragStart: () => void;
  onDragOver: (e: React.DragEvent) => void;
  onDragEnd: () => void;
  onDrop: (e: React.DragEvent) => void;
  canMoveUp: boolean;
  canMoveDown: boolean;
  kernelId?: string;
  isPresentationMode?: boolean;
  isZenMode?: boolean;
}

// Format duration in human readable format
const formatDuration = (ms: number): string => {
  if (ms < 1000) {
    return `${ms}ms`;
  } else if (ms < 60000) {
    return `${(ms / 1000).toFixed(1)}s`;
  } else {
    const mins = Math.floor(ms / 60000);
    const secs = ((ms % 60000) / 1000).toFixed(0);
    return `${mins}m ${secs}s`;
  }
};

const CellComponent = ({
  cell,
  index,
  isSelected,
  isMultiSelected = false,
  isDragging,
  isDragOver,
  onSelect,
  onUpdate,
  onDelete,
  onExecute,
  onExecuteAndNext,
  onAddCellBelow,
  onMoveUp,
  onMoveDown,
  onUpdateTags,
  onRunAllAbove,
  onRunAllBelow,
  onToggleCollapse,
  onShowMetadata,
  onClearOutput,
  onSplitCell,
  onDragStart,
  onDragOver,
  onDragEnd,
  onDrop,
  canMoveUp,
  canMoveDown,
  kernelId,
  isPresentationMode = false,
  isZenMode = false,
}: CellComponentProps) => {
  const [isEditing, setIsEditing] = useState(cell.cellType === "code");
  const [copied, setCopied] = useState(false);
  const [elapsedTime, setElapsedTime] = useState<number>(0);
  const isCode = cell.cellType === "code";
  const isMarkdown = cell.cellType === "markdown";
  const cellTags = cell.tags || [];

  // Live timer while executing
  useEffect(() => {
    if (cell.isExecuting && cell.executionStartTime) {
      const interval = setInterval(() => {
        setElapsedTime(Date.now() - cell.executionStartTime!);
      }, 100);
      return () => clearInterval(interval);
    } else if (!cell.isExecuting) {
      setElapsedTime(0);
    }
  }, [cell.isExecuting, cell.executionStartTime]);

  const handleCopy = async () => {
    const success = await copyToClipboard(cell.source);
    if (success) {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleExecuteAndMove = () => {
    onExecute();
  };

  const handleAddTag = (tag: CellTag) => {
    if (onUpdateTags) {
      onUpdateTags([...cellTags, tag]);
    }
  };

  const handleRemoveTag = (tagToRemove: CellTag) => {
    if (onUpdateTags) {
      onUpdateTags(cellTags.filter(
        (t) => !(t.type === tagToRemove.type && t.label === tagToRemove.label)
      ));
    }
  };

  // In presentation mode, hide code cells (show only outputs or markdown)
  if (isPresentationMode && isCode && cell.outputs.length === 0) {
    return null;
  }

  return (
    <div
      data-cell-id={cell.id}
      draggable={!isZenMode}
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDragEnd={onDragEnd}
      onDrop={onDrop}
      onClick={onSelect}
      className={cn(
        "group relative rounded border bg-card transition-all",
        isSelected
          ? "border-primary ring-1 ring-primary/20"
          : isMultiSelected
            ? "border-blue-400 ring-1 ring-blue-400/20 bg-blue-50/5"
            : "border-border hover:border-primary/50",
        isDragging && "opacity-50",
        isDragOver && "border-primary border-dashed",
        isPresentationMode && isCode && "border-transparent"
      )}
    >
      {/* Drag handle */}
      <div
        className="absolute -left-5 top-1/2 -translate-y-1/2 cursor-grab opacity-0 group-hover:opacity-100"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <GripVertical className="h-4 w-4 text-muted-foreground" />
      </div>

      {/* Cell Header - Compact */}
      <div className="flex items-center gap-1.5 border-b border-border px-2 py-1">
        {/* Collapse toggle button */}
        {onToggleCollapse && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              onToggleCollapse();
            }}
            className="flex h-4 w-4 items-center justify-center rounded text-muted-foreground hover:bg-muted hover:text-foreground"
          >
            {cell.isCollapsed ? (
              <ChevronRight className="h-3 w-3" />
            ) : (
              <ChevronDown className="h-3 w-3" />
            )}
          </button>
        )}

        <div className="flex items-center gap-1.5">
          {isCode ? (
            <>
              <Code2 className="h-3 w-3 text-blue-500" />
              <span className="text-[10px] font-mono text-muted-foreground">
                [{cell.executionCount ?? " "}]
              </span>
            </>
          ) : (
            <FileText className="h-3 w-3 text-green-500" />
          )}
          <span className="text-[10px] font-medium text-muted-foreground">
            {isCode ? "Python" : "Markdown"}
          </span>
        </div>

        {/* Cell Tags */}
        <div className="ml-2" onClick={(e) => e.stopPropagation()}>
          <CellTagsWidget
            tags={cellTags}
            onAddTag={handleAddTag}
            onRemoveTag={handleRemoveTag}
            isEditable={!!onUpdateTags}
          />
        </div>

        <div className="flex-1" />

        <div className="flex items-center gap-0.5">
          {/* Run button for code cells */}
          {isCode && (
            <Button
              size="sm"
              variant="ghost"
              className="h-5 px-1.5 gap-0.5"
              onClick={(e) => {
                e.stopPropagation();
                onExecute();
              }}
              disabled={cell.isExecuting}
            >
              {cell.isExecuting ? (
                <Loader2 className="h-3 w-3 animate-spin" />
              ) : (
                <>
                  <Play className="h-3 w-3 text-success" />
                  <span className="text-[10px]">Run</span>
                </>
              )}
            </Button>
          )}

          {/* Toggle edit/preview for markdown */}
          {isMarkdown && (
            <Button
              size="sm"
              variant="ghost"
              className="h-5 w-5 p-0"
              onClick={(e) => {
                e.stopPropagation();
                setIsEditing(!isEditing);
              }}
            >
              {isEditing ? (
                <Eye className="h-3 w-3" />
              ) : (
                <Pencil className="h-3 w-3" />
              )}
            </Button>
          )}

          {/* Hidden controls that appear on hover */}
          <div className="flex items-center gap-0.5 opacity-0 transition-opacity group-hover:opacity-100">
            <Button
              size="sm"
              variant="ghost"
              className="h-5 w-5 p-0"
              onClick={(e) => {
                e.stopPropagation();
                onMoveUp();
              }}
              disabled={!canMoveUp}
            >
              <ChevronUp className="h-3 w-3" />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              className="h-5 w-5 p-0"
              onClick={(e) => {
                e.stopPropagation();
                onMoveDown();
              }}
              disabled={!canMoveDown}
            >
              <ChevronDown className="h-3 w-3" />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              className="h-5 w-5 p-0"
              onClick={(e) => {
                e.stopPropagation();
                handleCopy();
              }}
            >
              {copied ? (
                <Check className="h-3 w-3 text-success" />
              ) : (
                <Copy className="h-3 w-3" />
              )}
            </Button>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-5 w-5 p-0"
                  onClick={(e) => e.stopPropagation()}
                >
                  <MoreHorizontal className="h-3 w-3" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => onAddCellBelow("code")}>
                  <Code2 className="mr-2 h-3 w-3" />
                  <span className="text-xs">Add Code Below</span>
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => onAddCellBelow("markdown")}>
                  <FileText className="mr-2 h-3 w-3" />
                  <span className="text-xs">Add Markdown Below</span>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                {isCode && onRunAllAbove && (
                  <DropdownMenuItem onClick={onRunAllAbove} disabled={!canMoveUp}>
                    <ArrowUp className="mr-2 h-3 w-3" />
                    <Play className="mr-1 h-2.5 w-2.5 text-success" />
                    <span className="text-xs">Run All Above</span>
                  </DropdownMenuItem>
                )}
                {isCode && onRunAllBelow && (
                  <DropdownMenuItem onClick={onRunAllBelow} disabled={!canMoveDown}>
                    <ArrowDown className="mr-2 h-3 w-3" />
                    <Play className="mr-1 h-2.5 w-2.5 text-success" />
                    <span className="text-xs">Run All Below</span>
                  </DropdownMenuItem>
                )}
                {isCode && (onRunAllAbove || onRunAllBelow) && <DropdownMenuSeparator />}
                {isCode && onExecuteAndNext && (
                  <DropdownMenuItem onClick={onExecuteAndNext}>
                    <SkipForward className="mr-2 h-3 w-3" />
                    <span className="text-xs">Run & Select Next</span>
                    <span className="ml-auto text-[10px] text-muted-foreground">Shift+Enter</span>
                  </DropdownMenuItem>
                )}
                {isCode && onClearOutput && cell.outputs.length > 0 && (
                  <DropdownMenuItem onClick={onClearOutput}>
                    <Eraser className="mr-2 h-3 w-3" />
                    <span className="text-xs">Clear Output</span>
                  </DropdownMenuItem>
                )}
                {onSplitCell && (
                  <DropdownMenuItem onClick={() => {
                    // Split at middle by default (could be improved with cursor position)
                    const lines = cell.source.split("\n").length;
                    onSplitCell(Math.floor(lines / 2));
                  }}>
                    <Scissors className="mr-2 h-3 w-3" />
                    <span className="text-xs">Split Cell</span>
                  </DropdownMenuItem>
                )}
                {(onExecuteAndNext || onClearOutput || onSplitCell) && <DropdownMenuSeparator />}
                {onShowMetadata && (
                  <DropdownMenuItem onClick={onShowMetadata}>
                    <Info className="mr-2 h-3 w-3" />
                    <span className="text-xs">Cell Metadata</span>
                  </DropdownMenuItem>
                )}
                {onShowMetadata && <DropdownMenuSeparator />}
                <DropdownMenuItem
                  onClick={onDelete}
                  className="text-destructive"
                >
                  <Trash2 className="mr-2 h-3 w-3" />
                  <span className="text-xs">Delete Cell</span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>

      {/* Cell Content */}
      {cell.isCollapsed ? (
        // Collapsed view - show preview
        <div
          className="flex items-center gap-2 px-3 py-2 text-xs text-muted-foreground cursor-pointer hover:bg-muted/50"
          onClick={(e) => {
            e.stopPropagation();
            onToggleCollapse?.();
          }}
        >
          <span className="font-mono truncate flex-1">
            {cell.source.split("\n")[0].slice(0, 80) || "(empty)"}
            {cell.source.split("\n").length > 1 && "..."}
          </span>
          <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded">
            {cell.source.split("\n").length} lines
          </span>
        </div>
      ) : (
        <div className="relative">
          {isCode ? (
            <MonacoCodeEditor
              value={cell.source}
              onChange={onUpdate}
              language="python"
              onExecute={onExecute}
              onFocus={onSelect}
              placeholder="# Enter Python code here..."
              kernelId={kernelId}
            />
          ) : isEditing ? (
            <MonacoCodeEditor
              value={cell.source}
              onChange={onUpdate}
              language="markdown"
              onFocus={onSelect}
              placeholder="# Enter Markdown here..."
            />
          ) : (
            <div
              className="min-h-[40px] px-3 py-2 cursor-text"
              onClick={() => setIsEditing(true)}
            >
              <MarkdownRenderer content={cell.source} />
            </div>
          )}
        </div>
      )}

      {/* Cell Output - hidden when collapsed */}
      {isCode && !cell.isCollapsed && <CellOutputDisplay outputs={cell.outputs} />}

      {/* Executing indicator with live timer */}
      {cell.isExecuting && (
        <div className="flex items-center gap-2 border-t border-border bg-primary/5 px-2 py-1">
          <Loader2 className="h-3 w-3 animate-spin text-primary" />
          <span className="text-[10px] text-muted-foreground">Executing...</span>
          <div className="flex items-center gap-1.5 rounded bg-primary/10 px-1.5 py-0.5">
            <Clock className="h-2.5 w-2.5 text-primary" />
            <span className="font-mono text-[10px] text-primary">
              {formatDuration(elapsedTime)}
            </span>
          </div>
          <div className="flex-1" />
          <Button
            size="sm"
            variant="ghost"
            className="h-5 text-[10px] text-destructive"
            onClick={(e) => {
              e.stopPropagation();
              // TODO: Implement interrupt
            }}
          >
            Interrupt
          </Button>
        </div>
      )}

      {/* Execution duration after completion */}
      {!cell.isExecuting && cell.executionDuration !== undefined && cell.executionDuration > 0 && (
        <div className="flex items-center gap-1.5 border-t border-border bg-muted/30 px-2 py-1">
          <Clock className="h-2.5 w-2.5 text-muted-foreground" />
          <span className="text-[10px] text-muted-foreground">
            Completed in {formatDuration(cell.executionDuration)}
          </span>
        </div>
      )}
    </div>
  );
};

export default NotebookEditorContent;
