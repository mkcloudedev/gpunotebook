import { useState, useCallback, useEffect, useMemo } from "react";
import {
  List,
  ChevronRight,
  ChevronDown,
  X,
  Hash,
  Code2,
  FileText,
  RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Cell } from "@/types/notebook";

// Heading item from markdown cells
interface HeadingItem {
  id: string;
  cellId: string;
  level: number; // 1-6 for h1-h6
  text: string;
  cellIndex: number;
}

// Cell summary for non-markdown cells
interface CellSummary {
  cellId: string;
  cellIndex: number;
  type: "code" | "markdown";
  preview: string;
  hasOutput: boolean;
}

interface TableOfContentsProps {
  cells: Cell[];
  selectedCellId: string | null;
  onNavigateToCell: (cellId: string) => void;
  onClose: () => void;
}

// Extract headings from markdown content
const extractHeadings = (
  content: string,
  cellId: string,
  cellIndex: number
): HeadingItem[] => {
  const headings: HeadingItem[] = [];
  const lines = content.split("\n");

  lines.forEach((line, lineIndex) => {
    // Match markdown headings (# to ######)
    const match = line.match(/^(#{1,6})\s+(.+)$/);
    if (match) {
      headings.push({
        id: `${cellId}-heading-${lineIndex}`,
        cellId,
        level: match[1].length,
        text: match[2].trim(),
        cellIndex,
      });
    }
  });

  return headings;
};

// Get first line of code as preview
const getCodePreview = (source: string): string => {
  const firstLine = source.split("\n")[0] || "";
  return firstLine.slice(0, 50) + (firstLine.length > 50 ? "..." : "");
};

export const TableOfContents = ({
  cells,
  selectedCellId,
  onNavigateToCell,
  onClose,
}: TableOfContentsProps) => {
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    new Set(["headings", "cells"])
  );
  const [showOnlyHeadings, setShowOnlyHeadings] = useState(true);

  // Extract all headings and cell summaries
  const { headings, cellSummaries } = useMemo(() => {
    const allHeadings: HeadingItem[] = [];
    const allSummaries: CellSummary[] = [];

    cells.forEach((cell, index) => {
      if (cell.cellType === "markdown") {
        // Extract headings from markdown cells
        const cellHeadings = extractHeadings(cell.source, cell.id, index);
        allHeadings.push(...cellHeadings);

        // If no headings, add as a cell summary
        if (cellHeadings.length === 0) {
          allSummaries.push({
            cellId: cell.id,
            cellIndex: index,
            type: "markdown",
            preview: cell.source.split("\n")[0].slice(0, 40) || "(empty)",
            hasOutput: false,
          });
        }
      } else {
        // Code cells
        allSummaries.push({
          cellId: cell.id,
          cellIndex: index,
          type: "code",
          preview: getCodePreview(cell.source),
          hasOutput: cell.outputs.length > 0,
        });
      }
    });

    return { headings: allHeadings, cellSummaries: allSummaries };
  }, [cells]);

  const toggleSection = useCallback((section: string) => {
    setExpandedSections((prev) => {
      const next = new Set(prev);
      if (next.has(section)) {
        next.delete(section);
      } else {
        next.add(section);
      }
      return next;
    });
  }, []);

  // Get indent for heading level
  const getHeadingIndent = (level: number): string => {
    return `${(level - 1) * 12}px`;
  };

  return (
    <div className="flex h-full flex-col bg-card">
      {/* Header */}
      <div className="flex items-center gap-2 border-b border-border bg-secondary/50 px-3 py-2">
        <List className="h-4 w-4 text-primary" />
        <span className="text-sm font-semibold">Table of Contents</span>
        <div className="flex-1" />
        <Button
          size="sm"
          variant={showOnlyHeadings ? "default" : "ghost"}
          className="h-6 px-2 text-[10px]"
          onClick={() => setShowOnlyHeadings(!showOnlyHeadings)}
        >
          {showOnlyHeadings ? "Headings Only" : "All Cells"}
        </Button>
        <Button
          size="sm"
          variant="ghost"
          className="h-6 w-6 p-0"
          onClick={onClose}
        >
          <X className="h-3.5 w-3.5" />
        </Button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-2">
        {/* Headings Section */}
        {headings.length > 0 && (
          <div className="mb-4">
            <button
              className="flex w-full items-center gap-1 rounded px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-muted"
              onClick={() => toggleSection("headings")}
            >
              {expandedSections.has("headings") ? (
                <ChevronDown className="h-3 w-3" />
              ) : (
                <ChevronRight className="h-3 w-3" />
              )}
              <Hash className="h-3 w-3" />
              <span>Headings</span>
              <span className="ml-1 text-[10px] text-muted-foreground/70">
                ({headings.length})
              </span>
            </button>

            {expandedSections.has("headings") && (
              <div className="mt-1 space-y-0.5">
                {headings.map((heading) => (
                  <button
                    key={heading.id}
                    className={cn(
                      "flex w-full items-center rounded px-2 py-1 text-left text-xs transition-colors hover:bg-muted",
                      selectedCellId === heading.cellId
                        ? "bg-primary/10 text-primary"
                        : "text-foreground"
                    )}
                    style={{ paddingLeft: `calc(8px + ${getHeadingIndent(heading.level)})` }}
                    onClick={() => onNavigateToCell(heading.cellId)}
                  >
                    <span
                      className="mr-2 text-[9px] font-bold text-muted-foreground"
                    >
                      H{heading.level}
                    </span>
                    <span className="truncate">{heading.text}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* All Cells Section - only show when not in "headings only" mode */}
        {!showOnlyHeadings && cellSummaries.length > 0 && (
          <div>
            <button
              className="flex w-full items-center gap-1 rounded px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-muted"
              onClick={() => toggleSection("cells")}
            >
              {expandedSections.has("cells") ? (
                <ChevronDown className="h-3 w-3" />
              ) : (
                <ChevronRight className="h-3 w-3" />
              )}
              <FileText className="h-3 w-3" />
              <span>All Cells</span>
              <span className="ml-1 text-[10px] text-muted-foreground/70">
                ({cellSummaries.length})
              </span>
            </button>

            {expandedSections.has("cells") && (
              <div className="mt-1 space-y-0.5">
                {cellSummaries.map((cell) => (
                  <button
                    key={cell.cellId}
                    className={cn(
                      "flex w-full items-center gap-2 rounded px-2 py-1 text-left text-xs transition-colors hover:bg-muted",
                      selectedCellId === cell.cellId
                        ? "bg-primary/10 text-primary"
                        : "text-foreground"
                    )}
                    onClick={() => onNavigateToCell(cell.cellId)}
                  >
                    {cell.type === "code" ? (
                      <Code2 className="h-3 w-3 shrink-0 text-blue-500" />
                    ) : (
                      <FileText className="h-3 w-3 shrink-0 text-green-500" />
                    )}
                    <span className="text-[10px] text-muted-foreground">
                      [{cell.cellIndex + 1}]
                    </span>
                    <span className="flex-1 truncate font-mono text-[11px]">
                      {cell.preview || "(empty)"}
                    </span>
                    {cell.hasOutput && (
                      <span className="rounded bg-success/20 px-1 text-[9px] text-success">
                        out
                      </span>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Empty state */}
        {headings.length === 0 && (showOnlyHeadings || cellSummaries.length === 0) && (
          <div className="flex h-32 flex-col items-center justify-center text-muted-foreground">
            <Hash className="h-8 w-8" />
            <p className="mt-2 text-sm">No headings found</p>
            <p className="text-xs">
              Add markdown cells with # headings
            </p>
          </div>
        )}
      </div>

      {/* Footer with stats */}
      <div className="border-t border-border px-3 py-2 text-[10px] text-muted-foreground">
        {cells.length} cells • {headings.length} headings •{" "}
        {cells.filter((c) => c.cellType === "code").length} code •{" "}
        {cells.filter((c) => c.cellType === "markdown").length} markdown
      </div>
    </div>
  );
};

export default TableOfContents;
