import { useState, useEffect, useCallback } from "react";
import {
  Variable,
  RefreshCw,
  X,
  Search,
  ChevronRight,
  ChevronDown,
  Copy,
  Inbox,
  Box,
} from "lucide-react";
import { cn, copyToClipboard } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

// Variable data interface
export interface VariableInfo {
  name: string;
  type: string;
  shape?: string;
  preview: string;
  size?: number;
  children?: VariableInfo[];
}

interface VariableInspectorPanelProps {
  variables: VariableInfo[];
  onRefresh: () => void;
  onClose: () => void;
  isLoading?: boolean;
  autoRefresh?: boolean;
  onAutoRefreshChange?: (enabled: boolean) => void;
}

// Filter chip component
const FilterChip = ({
  label,
  value,
  selected,
  onSelect,
}: {
  label: string;
  value: string;
  selected: string;
  onSelect: (value: string) => void;
}) => (
  <button
    onClick={() => onSelect(value)}
    className={cn(
      "rounded-full px-2.5 py-1 text-[10px] font-medium transition-colors",
      selected === value
        ? "bg-primary text-primary-foreground"
        : "bg-muted text-muted-foreground hover:bg-muted/80"
    )}
  >
    {label}
  </button>
);

// Get color for variable type
const getTypeColor = (type: string): string => {
  switch (type.toLowerCase()) {
    case "int":
    case "float":
    case "complex":
      return "#3B82F6"; // blue
    case "str":
      return "#10B981"; // green
    case "list":
    case "tuple":
    case "set":
      return "#F59E0B"; // amber
    case "dict":
      return "#8B5CF6"; // purple
    case "dataframe":
    case "series":
      return "#F97316"; // orange
    case "ndarray":
    case "tensor":
      return "#06B6D4"; // cyan
    case "bool":
      return "#EF4444"; // red
    default:
      return "#6B7280"; // gray
  }
};

// Check if type is expandable
const isExpandable = (type: string): boolean => {
  const t = type.toLowerCase();
  return (
    t === "dict" ||
    t === "list" ||
    t === "tuple" ||
    t === "dataframe" ||
    t === "series" ||
    t === "ndarray" ||
    t === "tensor" ||
    t === "object"
  );
};

// Format bytes to human readable
const formatSize = (bytes: number): string => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

// Variable row component
const VariableRow = ({
  variable,
  isExpanded,
  onToggleExpand,
  onCopy,
}: {
  variable: VariableInfo;
  isExpanded: boolean;
  onToggleExpand: () => void;
  onCopy: (text: string) => void;
}) => {
  const typeColor = getTypeColor(variable.type);
  const canExpand =
    isExpandable(variable.type) ||
    (variable.children && variable.children.length > 0);

  return (
    <div className="rounded-md border border-border bg-background">
      {/* Main row */}
      <div
        className={cn(
          "flex flex-col gap-1 p-2.5",
          canExpand && "cursor-pointer hover:bg-muted/50"
        )}
        onClick={canExpand ? onToggleExpand : undefined}
      >
        <div className="flex items-center gap-1.5">
          {/* Expand icon */}
          {canExpand ? (
            isExpanded ? (
              <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
            ) : (
              <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />
            )
          ) : (
            <div className="w-3.5" />
          )}

          {/* Variable name */}
          <span className="flex-1 truncate font-mono text-xs font-semibold">
            {variable.name}
          </span>

          {/* Type badge */}
          <span
            className="rounded px-1.5 py-0.5 text-[10px] font-semibold"
            style={{
              backgroundColor: `${typeColor}20`,
              color: typeColor,
            }}
          >
            {variable.type}
          </span>
        </div>

        {/* Shape */}
        {variable.shape && (
          <div className="ml-5 flex items-center gap-1 text-[10px] text-muted-foreground">
            <Box className="h-2.5 w-2.5" />
            <span>{variable.shape}</span>
          </div>
        )}

        {/* Preview */}
        <div className="mt-1 flex items-start gap-1">
          <div
            className="flex-1 overflow-hidden rounded bg-muted/50 px-2 py-1 font-mono text-[11px] text-muted-foreground"
            style={{ wordBreak: "break-all" }}
          >
            {variable.preview}
          </div>
          <Button
            size="sm"
            variant="ghost"
            className="h-6 w-6 p-0 opacity-0 transition-opacity group-hover:opacity-100"
            onClick={(e) => {
              e.stopPropagation();
              onCopy(variable.preview);
            }}
          >
            <Copy className="h-3 w-3" />
          </Button>
        </div>

        {/* Size */}
        {variable.size !== undefined && variable.size > 0 && (
          <div className="ml-5 text-[10px] text-muted-foreground">
            Size: {formatSize(variable.size)}
          </div>
        )}
      </div>

      {/* Children (expanded) */}
      {isExpanded && variable.children && variable.children.length > 0 && (
        <div className="border-t border-border bg-muted/30 p-2 pl-6">
          {variable.children.map((child, idx) => (
            <div
              key={idx}
              className="flex items-center gap-2 py-1 text-[11px]"
            >
              <span className="font-mono font-medium text-muted-foreground">
                {child.name}:
              </span>
              <span
                className="rounded px-1 py-0.5 text-[9px] font-semibold"
                style={{
                  backgroundColor: `${getTypeColor(child.type)}20`,
                  color: getTypeColor(child.type),
                }}
              >
                {child.type}
              </span>
              <span className="truncate font-mono text-muted-foreground">
                {child.preview}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export const VariableInspectorPanel = ({
  variables,
  onRefresh,
  onClose,
  isLoading = false,
  autoRefresh = true,
  onAutoRefreshChange,
}: VariableInspectorPanelProps) => {
  const [searchQuery, setSearchQuery] = useState("");
  const [filterType, setFilterType] = useState("all");
  const [expandedVariables, setExpandedVariables] = useState<Set<string>>(
    new Set()
  );

  const toggleExpand = useCallback((name: string) => {
    setExpandedVariables((prev) => {
      const next = new Set(prev);
      if (next.has(name)) {
        next.delete(name);
      } else {
        next.add(name);
      }
      return next;
    });
  }, []);

  const handleCopy = useCallback((text: string) => {
    copyToClipboard(text);
  }, []);

  // Filter variables
  const filteredVariables = variables.filter((v) => {
    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      if (
        !v.name.toLowerCase().includes(query) &&
        !v.type.toLowerCase().includes(query)
      ) {
        return false;
      }
    }

    // Type filter
    if (filterType !== "all") {
      const t = v.type.toLowerCase();
      switch (filterType) {
        case "numeric":
          if (t !== "int" && t !== "float" && t !== "complex") return false;
          break;
        case "text":
          if (t !== "str") return false;
          break;
        case "collection":
          if (t !== "list" && t !== "tuple" && t !== "set" && t !== "dict")
            return false;
          break;
        case "data":
          if (
            t !== "dataframe" &&
            t !== "series" &&
            t !== "ndarray" &&
            t !== "tensor"
          )
            return false;
          break;
      }
    }

    return true;
  });

  return (
    <div className="flex h-full flex-col bg-card">
      {/* Header */}
      <div className="flex items-center gap-2 border-b border-border bg-secondary/50 px-3 py-2">
        <Variable className="h-4 w-4 text-primary" />
        <span className="text-sm font-semibold">Variables</span>
        <span className="rounded-full bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground">
          {variables.length}
        </span>
        <div className="flex-1" />
        {/* Auto-refresh toggle */}
        {onAutoRefreshChange && (
          <button
            onClick={() => onAutoRefreshChange(!autoRefresh)}
            className={cn(
              "flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium transition-colors",
              autoRefresh
                ? "bg-primary/10 text-primary"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            )}
            title={autoRefresh ? "Auto-refresh enabled" : "Auto-refresh disabled"}
          >
            <RefreshCw className={cn("h-2.5 w-2.5", autoRefresh && "animate-spin")} />
            Auto
          </button>
        )}
        <Button
          size="sm"
          variant="ghost"
          className="h-6 w-6 p-0"
          onClick={onRefresh}
          disabled={isLoading}
          title="Refresh variables"
        >
          <RefreshCw
            className={cn("h-3.5 w-3.5", isLoading && "animate-spin")}
          />
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

      {/* Search */}
      <div className="border-b border-border p-2">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search variables..."
            className="h-7 pl-7 text-xs"
          />
        </div>
      </div>

      {/* Filter chips */}
      <div className="flex gap-1.5 overflow-x-auto border-b border-border px-2 py-1.5">
        <FilterChip
          label="All"
          value="all"
          selected={filterType}
          onSelect={setFilterType}
        />
        <FilterChip
          label="Numeric"
          value="numeric"
          selected={filterType}
          onSelect={setFilterType}
        />
        <FilterChip
          label="Text"
          value="text"
          selected={filterType}
          onSelect={setFilterType}
        />
        <FilterChip
          label="Collection"
          value="collection"
          selected={filterType}
          onSelect={setFilterType}
        />
        <FilterChip
          label="Data"
          value="data"
          selected={filterType}
          onSelect={setFilterType}
        />
      </div>

      {/* Variables list */}
      <div className="flex-1 overflow-auto p-2">
        {filteredVariables.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-muted-foreground">
            <Inbox className="h-8 w-8" />
            <p className="mt-2 text-sm">
              {variables.length === 0 ? "No variables" : "No matches"}
            </p>
            <p className="text-xs">
              {variables.length === 0
                ? "Execute code to see variables"
                : "Try a different search"}
            </p>
          </div>
        ) : (
          <div className="space-y-2">
            {filteredVariables.map((variable) => (
              <VariableRow
                key={variable.name}
                variable={variable}
                isExpanded={expandedVariables.has(variable.name)}
                onToggleExpand={() => toggleExpand(variable.name)}
                onCopy={handleCopy}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default VariableInspectorPanel;
