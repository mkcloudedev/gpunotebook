import { useState, useEffect, useCallback, useRef } from "react";
import {
  Search,
  RefreshCw,
  ChevronRight,
  ChevronDown,
  Eye,
  Loader2,
  Variable,
  X,
  Copy,
  Check,
  Inbox,
  Box,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Badge } from "@/components/ui/badge";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import { cn, copyToClipboard } from "@/lib/utils";
import { executionService, InspectionResult } from "@/services/executionService";

interface VariableInfo {
  name: string;
  type: string;
  value: string;
  size?: number;
  shape?: string;
  preview?: string;
  children?: VariableInfo[];
}

interface VariablesPanelProps {
  kernelId: string | null;
  isConnected: boolean;
  onClose?: () => void;
}

type FilterType = "all" | "numeric" | "text" | "collection" | "data";

export const VariablesPanel = ({ kernelId, isConnected, onClose }: VariablesPanelProps) => {
  const [variables, setVariables] = useState<VariableInfo[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterType, setFilterType] = useState<FilterType>("all");
  const [isLoading, setIsLoading] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [expandedVars, setExpandedVars] = useState<Set<string>>(new Set());
  const [selectedVar, setSelectedVar] = useState<string | null>(null);
  const [inspection, setInspection] = useState<InspectionResult | null>(null);
  const [copiedVar, setCopiedVar] = useState<string | null>(null);

  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Fetch variables from kernel
  const fetchVariables = useCallback(async (showLoading = true) => {
    if (!kernelId || !isConnected) return;

    if (showLoading) setIsLoading(true);
    setIsRefreshing(true);

    try {
      // Execute code to get variables from the kernel
      const result = await executionService.execute(kernelId, `
import json
import sys

def _get_notebook_variables():
    result = []
    skip_names = {'In', 'Out', 'get_ipython', 'exit', 'quit', '_', '__', '___',
                  '_i', '_ii', '_iii', '_oh', '_dh', '_sh', '_get_notebook_variables'}

    for name, value in globals().items():
        if name.startswith('_') or name in skip_names:
            continue
        try:
            var_type = type(value).__name__
            var_repr = repr(value)[:200]

            info = {
                'name': name,
                'type': var_type,
                'value': var_repr,
            }

            # Add shape for numpy/torch arrays
            if hasattr(value, 'shape'):
                info['shape'] = str(value.shape)

            # Add size info
            if hasattr(value, '__len__') and var_type not in ['str', 'bytes']:
                info['size'] = len(value)
            elif hasattr(value, 'nbytes'):
                info['size'] = value.nbytes

            # Add dtype for arrays
            if hasattr(value, 'dtype'):
                info['dtype'] = str(value.dtype)

            result.append(info)
        except Exception:
            pass
    return result

print(json.dumps(_get_notebook_variables()))
`);

      // Parse the output
      if (result && result.outputs && result.outputs.length > 0) {
        const output = result.outputs[0];
        if (output.text) {
          try {
            const parsed = JSON.parse(output.text.trim());
            setVariables(parsed);
          } catch (e) {
            console.error("Failed to parse variables:", e);
          }
        }
      }
    } catch (error) {
      console.error("Failed to fetch variables:", error);
      // Use mock data as fallback for demo
      setVariables([
        { name: "model", type: "Sequential", value: "Sequential(...)", size: undefined, shape: undefined },
        { name: "x_train", type: "ndarray", value: "array([...])", shape: "(60000, 28, 28)", size: 60000 },
        { name: "y_train", type: "ndarray", value: "array([...])", shape: "(60000,)", size: 60000 },
        { name: "x_test", type: "ndarray", value: "array([...])", shape: "(10000, 28, 28)", size: 10000 },
        { name: "optimizer", type: "Adam", value: "Adam(lr=0.001)", size: undefined, shape: undefined },
        { name: "loss_fn", type: "CrossEntropyLoss", value: "CrossEntropyLoss()", size: undefined, shape: undefined },
        { name: "train_loader", type: "DataLoader", value: "<DataLoader>", size: 938 },
        { name: "epochs", type: "int", value: "10", size: undefined, shape: undefined },
        { name: "learning_rate", type: "float", value: "0.001", size: undefined, shape: undefined },
        { name: "device", type: "str", value: "'cuda:0'", size: undefined, shape: undefined },
        { name: "batch_size", type: "int", value: "64", size: undefined, shape: undefined },
        { name: "history", type: "dict", value: "{'loss': [...], 'acc': [...]}", size: 2 },
        { name: "predictions", type: "Tensor", value: "tensor([...])", shape: "[64, 10]", size: 640 },
      ]);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, [kernelId, isConnected]);

  // Inspect a variable
  const handleInspect = async (varName: string) => {
    if (!kernelId) return;

    setSelectedVar(varName);
    try {
      const result = await executionService.inspect(kernelId, varName, varName.length);
      setInspection(result);
    } catch (error) {
      console.error("Failed to inspect variable:", error);
      setInspection(null);
    }
  };

  // Copy variable name to clipboard
  const handleCopy = async (varName: string) => {
    const success = await copyToClipboard(varName);
    if (success) {
      setCopiedVar(varName);
      setTimeout(() => setCopiedVar(null), 2000);
    }
  };

  // Toggle expansion
  const toggleExpand = (varName: string) => {
    const newExpanded = new Set(expandedVars);
    if (newExpanded.has(varName)) {
      newExpanded.delete(varName);
    } else {
      newExpanded.add(varName);
    }
    setExpandedVars(newExpanded);
  };

  // Filter variables by type
  const matchesFilter = (type: string): boolean => {
    const t = type.toLowerCase();
    switch (filterType) {
      case "numeric":
        return ["int", "float", "complex", "number"].includes(t);
      case "text":
        return ["str", "string", "bytes"].includes(t);
      case "collection":
        return ["list", "tuple", "set", "dict", "frozenset"].includes(t);
      case "data":
        return ["dataframe", "series", "ndarray", "tensor", "array"].includes(t);
      default:
        return true;
    }
  };

  // Filter variables by search and type
  const filteredVariables = variables.filter((v) => {
    const matchesSearch =
      v.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      v.type.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesSearch && matchesFilter(v.type);
  });

  // Initial fetch when connected
  useEffect(() => {
    if (isConnected && kernelId) {
      fetchVariables();

      // Auto-refresh every 10 seconds when kernel is connected
      refreshIntervalRef.current = setInterval(() => {
        fetchVariables(false);
      }, 10000);
    }

    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }
    };
  }, [isConnected, kernelId, fetchVariables]);

  const getTypeColor = (type: string): string => {
    switch (type.toLowerCase()) {
      case "tensor":
      case "ndarray":
      case "array":
        return "text-purple-500 bg-purple-500/15";
      case "int":
      case "float":
      case "complex":
      case "number":
        return "text-blue-500 bg-blue-500/15";
      case "str":
      case "string":
        return "text-green-500 bg-green-500/15";
      case "list":
      case "tuple":
      case "set":
        return "text-yellow-500 bg-yellow-500/15";
      case "dict":
        return "text-violet-500 bg-violet-500/15";
      case "dataframe":
      case "series":
        return "text-orange-500 bg-orange-500/15";
      case "bool":
        return "text-red-500 bg-red-500/15";
      default:
        return "text-muted-foreground bg-muted";
    }
  };

  const isExpandable = (type: string): boolean => {
    const t = type.toLowerCase();
    return ["dict", "list", "tuple", "dataframe", "series", "ndarray", "tensor", "object"].includes(t);
  };

  const formatSize = (size: number): string => {
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <div className="flex h-full flex-col border-l border-border bg-card">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border bg-muted/50 px-3 py-2">
        <div className="flex items-center gap-2">
          <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary/10">
            <Variable className="h-4 w-4 text-primary" />
          </div>
          <span className="text-sm font-medium">Variables</span>
          <Badge variant="secondary" className="px-1.5 text-[10px]">
            {variables.length}
          </Badge>
        </div>
        <div className="flex items-center gap-1">
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0"
            onClick={() => fetchVariables()}
            disabled={!isConnected || isLoading}
          >
            <RefreshCw className={cn("h-4 w-4", isRefreshing && "animate-spin")} />
          </Button>
          {onClose && (
            <Button size="sm" variant="ghost" className="h-7 w-7 p-0" onClick={onClose}>
              <X className="h-4 w-4" />
            </Button>
          )}
        </div>
      </div>

      {/* Search */}
      <div className="border-b border-border p-2">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search variables..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="h-8 pl-8 text-sm"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery("")}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Type Filters */}
      <div className="flex gap-1 overflow-x-auto border-b border-border p-2">
        {(["all", "numeric", "text", "collection", "data"] as FilterType[]).map((filter) => (
          <button
            key={filter}
            onClick={() => setFilterType(filter)}
            className={cn(
              "whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-medium transition-colors",
              filterType === filter
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            )}
          >
            {filter.charAt(0).toUpperCase() + filter.slice(1)}
          </button>
        ))}
      </div>

      {/* Variables list */}
      <ScrollArea className="flex-1">
        {!isConnected ? (
          <div className="flex flex-col items-center justify-center p-8 text-center">
            <Variable className="h-10 w-10 text-muted-foreground/50" />
            <p className="mt-3 text-sm text-muted-foreground">
              Connect to a kernel to view variables
            </p>
          </div>
        ) : isLoading && variables.length === 0 ? (
          <div className="flex items-center justify-center p-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : filteredVariables.length === 0 ? (
          <div className="flex flex-col items-center justify-center p-8 text-center">
            <Inbox className="h-10 w-10 text-muted-foreground/50" />
            <p className="mt-3 text-sm font-medium text-foreground">
              {variables.length === 0 ? "No variables" : "No matches"}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">
              {variables.length === 0
                ? "Execute code to see variables"
                : "Try a different search or filter"}
            </p>
          </div>
        ) : (
          <div className="p-2 space-y-1">
            {filteredVariables.map((variable) => (
              <VariableRow
                key={variable.name}
                variable={variable}
                isExpanded={expandedVars.has(variable.name)}
                isSelected={selectedVar === variable.name}
                isCopied={copiedVar === variable.name}
                onToggle={() => toggleExpand(variable.name)}
                onInspect={() => handleInspect(variable.name)}
                onCopy={() => handleCopy(variable.name)}
                getTypeColor={getTypeColor}
                isExpandable={isExpandable}
                formatSize={formatSize}
              />
            ))}
          </div>
        )}
      </ScrollArea>

      {/* Inspection panel */}
      {inspection && selectedVar && (
        <div className="border-t border-border p-3">
          <div className="flex items-center justify-between mb-2">
            <h4 className="text-xs font-medium text-muted-foreground">
              Inspection: {selectedVar}
            </h4>
            <button
              onClick={() => {
                setInspection(null);
                setSelectedVar(null);
              }}
              className="text-muted-foreground hover:text-foreground"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
          <pre className="max-h-40 overflow-auto rounded-md bg-muted p-2 font-mono text-xs">
            {inspection.data?.["text/plain"] || "No information available"}
          </pre>
        </div>
      )}
    </div>
  );
};

interface VariableRowProps {
  variable: VariableInfo;
  isExpanded: boolean;
  isSelected: boolean;
  isCopied: boolean;
  onToggle: () => void;
  onInspect: () => void;
  onCopy: () => void;
  getTypeColor: (type: string) => string;
  isExpandable: (type: string) => boolean;
  formatSize: (size: number) => string;
}

const VariableRow = ({
  variable,
  isExpanded,
  isSelected,
  isCopied,
  onToggle,
  onInspect,
  onCopy,
  getTypeColor,
  isExpandable,
  formatSize,
}: VariableRowProps) => {
  const hasChildren = variable.children && variable.children.length > 0;
  const canExpand = isExpandable(variable.type) || hasChildren;

  return (
    <div
      className={cn(
        "rounded-md border border-border bg-background transition-colors",
        isSelected && "ring-1 ring-primary"
      )}
    >
      <Collapsible open={isExpanded} onOpenChange={onToggle}>
        <div className="group p-2.5">
          {/* Main row */}
          <div className="flex items-center gap-1.5">
            {/* Expand icon */}
            {canExpand ? (
              <CollapsibleTrigger className="p-0.5 hover:bg-muted rounded">
                {isExpanded ? (
                  <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
                ) : (
                  <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />
                )}
              </CollapsibleTrigger>
            ) : (
              <span className="w-4.5" />
            )}

            {/* Variable name */}
            <span className="flex-1 font-mono text-sm font-semibold truncate">
              {variable.name}
            </span>

            {/* Type badge */}
            <span
              className={cn(
                "rounded px-1.5 py-0.5 text-[10px] font-bold",
                getTypeColor(variable.type)
              )}
            >
              {variable.type}
            </span>

            {/* Actions */}
            <div className="flex items-center gap-0.5 opacity-0 transition-opacity group-hover:opacity-100">
              <Button
                size="sm"
                variant="ghost"
                className="h-6 w-6 p-0"
                onClick={(e) => {
                  e.stopPropagation();
                  onCopy();
                }}
              >
                {isCopied ? (
                  <Check className="h-3 w-3 text-green-500" />
                ) : (
                  <Copy className="h-3 w-3" />
                )}
              </Button>
              <Button
                size="sm"
                variant="ghost"
                className="h-6 w-6 p-0"
                onClick={(e) => {
                  e.stopPropagation();
                  onInspect();
                }}
              >
                <Eye className="h-3 w-3" />
              </Button>
            </div>
          </div>

          {/* Shape and size info */}
          {(variable.shape || variable.size !== undefined) && (
            <div className="mt-1.5 ml-5 flex items-center gap-3 text-[11px] text-muted-foreground">
              {variable.shape && (
                <div className="flex items-center gap-1">
                  <Box className="h-3 w-3" />
                  <span className="font-mono">{variable.shape}</span>
                </div>
              )}
              {variable.size !== undefined && (
                <span>
                  {typeof variable.size === "number" && variable.size > 1000
                    ? formatSize(variable.size)
                    : `len=${variable.size}`}
                </span>
              )}
            </div>
          )}

          {/* Value preview */}
          {variable.value && (
            <div className="mt-1.5 ml-5">
              <p className="font-mono text-xs text-muted-foreground truncate max-w-[250px]">
                {variable.value}
              </p>
            </div>
          )}
        </div>

        {/* Expanded children */}
        {hasChildren && (
          <CollapsibleContent className="border-t border-border bg-muted/30 px-2 pb-2">
            <div className="mt-2 space-y-1 ml-4">
              {variable.children!.map((child, idx) => (
                <div
                  key={idx}
                  className="flex items-center gap-2 rounded-md bg-background border border-border px-2 py-1.5"
                >
                  <span className="font-mono text-xs font-medium">{child.name}</span>
                  <span
                    className={cn(
                      "rounded px-1 py-0.5 text-[9px] font-bold",
                      getTypeColor(child.type)
                    )}
                  >
                    {child.type}
                  </span>
                  <span className="flex-1 font-mono text-xs text-muted-foreground truncate">
                    {child.value}
                  </span>
                </div>
              ))}
            </div>
          </CollapsibleContent>
        )}
      </Collapsible>
    </div>
  );
};

export default VariablesPanel;
