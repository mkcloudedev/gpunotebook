import { useState, useEffect, useCallback, useRef } from "react";
import { useParams } from "react-router-dom";
import { cn } from "@/lib/utils";
import { NotebookEditorContent } from "@/components/NotebookEditorContent";
import { AIChatPanel } from "@/components/AIChatPanel";
import { NotebookEditorBreadcrumb } from "@/components/NotebookEditorBreadcrumb";
import { KeyboardShortcutsDialog } from "@/components/notebook/KeyboardShortcutsDialog";
import { PackageManagerPanel } from "@/components/notebook/PackageManagerPanel";
import { NotebookCLI } from "@/components/notebook/NotebookCLI";
import { ExecutionLogPanel, LogEntry } from "@/components/notebook/ExecutionLogPanel";
import { SplitViewPanel } from "@/components/notebook/SplitViewPanel";
import { FindReplacePanel } from "@/components/notebook/FindReplacePanel";
import { VariableInspectorPanel, VariableInfo } from "@/components/notebook/VariableInspectorPanel";
import { TableOfContents } from "@/components/notebook/TableOfContents";
import { Cell, Notebook, CellOutput, CellTag, CellMetadata } from "@/types/notebook";
import { CellMetadataDialog } from "@/components/notebook/CellMetadataDialog";
import { useKernelExecution } from "@/hooks/useKernelExecution";
import { useUndoRedo } from "@/hooks/useUndoRedo";
import { notebookService } from "@/services/notebookService";
import { executionService } from "@/services/executionService";
import { exportToIpynb, exportToPython, exportToHtml } from "@/utils/notebookExport";

// Mock notebook data (fallback)
const mockNotebook: Notebook = {
  id: "1",
  name: "GPU Training Example",
  cells: [
    {
      id: "cell-1",
      cellType: "code",
      source: `import torch
import torch.nn as nn

# Check GPU availability
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")`,
      outputs: [
        {
          outputType: "stream",
          text: "CUDA available: True\nGPU: NVIDIA GeForce RTX 4090",
        },
      ],
      executionCount: 1,
    },
    {
      id: "cell-2",
      cellType: "markdown",
      source: "## Model Definition\n\nThis is a simple neural network model for demonstration.",
      outputs: [],
    },
    {
      id: "cell-3",
      cellType: "code",
      source: `class SimpleModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        return self.fc2(x)

model = SimpleModel().cuda()
print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")`,
      outputs: [
        {
          outputType: "stream",
          text: "Model parameters: 101,770",
        },
      ],
      executionCount: 2,
    },
  ],
  createdAt: new Date(),
  updatedAt: new Date(),
};

export const NotebookEditorPage = () => {
  const { id } = useParams();
  const [notebook, setNotebook] = useState<Notebook | null>(null);
  const {
    state: cells,
    set: setCells,
    undo,
    redo,
    canUndo,
    canRedo,
    reset: resetCells,
  } = useUndoRedo<Cell[]>([], { maxHistorySize: 50, debounceMs: 500 });
  const [selectedCellId, setSelectedCellId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [executionCountRef] = useState<{ current: number }>({ current: 0 });
  const [showShortcuts, setShowShortcuts] = useState(false);
  const [showPackageManager, setShowPackageManager] = useState(false);
  const [cliOutputs, setCliOutputs] = useState<CellOutput[]>([]);
  const [isCliExecuting, setIsCliExecuting] = useState(false);
  const [showSplitView, setShowSplitView] = useState(false);

  // Execution logs
  const [executionLogs, setExecutionLogs] = useState<LogEntry[]>([]);
  const [showExecutionLogs, setShowExecutionLogs] = useState(false);
  const [logsMinimized, setLogsMinimized] = useState(true);
  const [splitLeftCellId, setSplitLeftCellId] = useState<string | null>(null);
  const [splitRightCellId, setSplitRightCellId] = useState<string | null>(null);
  const [showFindReplace, setShowFindReplace] = useState(false);

  // Variable Inspector state
  const [showVariables, setShowVariables] = useState(false);
  const [variables, setVariables] = useState<VariableInfo[]>([]);
  const [isLoadingVariables, setIsLoadingVariables] = useState(false);
  const [autoRefreshVariables, setAutoRefreshVariables] = useState(true);
  const refreshVariablesRef = useRef<() => void>(() => {});
  const showVariablesRef = useRef(showVariables);
  const autoRefreshVariablesRef = useRef(autoRefreshVariables);

  // Table of Contents state
  const [showTableOfContents, setShowTableOfContents] = useState(false);

  // Cell Metadata dialog state
  const [metadataCell, setMetadataCell] = useState<Cell | null>(null);

  // Command Mode state (like Jupyter - Esc to enter, Enter to exit)
  const [isCommandMode, setIsCommandMode] = useState(false);

  // Collapsed cells
  const [collapsedCells, setCollapsedCells] = useState<Set<string>>(new Set());

  // Quick Tag Menu state
  const [showQuickTagMenu, setShowQuickTagMenu] = useState(false);
  const [quickTagPosition, setQuickTagPosition] = useState({ x: 0, y: 0 });

  // Max log entries
  const MAX_LOG_ENTRIES = 500;

  // Multi-cell selection
  const [selectedCellIds, setSelectedCellIds] = useState<Set<string>>(new Set());

  // Cell clipboard for copy/paste
  const [cellClipboard, setCellClipboard] = useState<Cell[]>([]);

  // Zen Mode (distraction-free)
  const [isZenMode, setIsZenMode] = useState(false);

  // Presentation Mode (outputs only)
  const [isPresentationMode, setIsPresentationMode] = useState(false);

  // Checkpoints
  const [checkpoints, setCheckpoints] = useState<{ id: string; name: string; cells: Cell[]; timestamp: Date }[]>([]);
  const [showCheckpointsDialog, setShowCheckpointsDialog] = useState(false);

  // Kernel execution hook
  const {
    kernel,
    kernelStatus,
    isConnected,
    isExecuting,
    executingCellId,
    connect,
    disconnect,
    execute,
    interrupt,
    restart,
    getCompletions,
  } = useKernelExecution({
    notebookId: id,
    onOutput: handleCellOutput,
    onExecutionStart: handleExecutionStart,
    onExecutionComplete: handleExecutionComplete,
    onExecutionError: handleExecutionError,
  });

  // Add log entry helper
  const addLog = useCallback((type: LogEntry["type"], message: string, cellId?: string) => {
    const newLog: LogEntry = {
      id: `log-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
      type,
      message,
      cellId,
    };
    setExecutionLogs(prev => {
      const newLogs = [...prev, newLog];
      // Limit to MAX_LOG_ENTRIES
      if (newLogs.length > MAX_LOG_ENTRIES) {
        return newLogs.slice(-MAX_LOG_ENTRIES);
      }
      return newLogs;
    });
  }, []);

  // Handle cell output from kernel
  function handleCellOutput(cellId: string, output: CellOutput) {
    // Add to execution logs
    if (output.text) {
      addLog(output.outputType === "error" ? "stderr" : "stdout", output.text, cellId);
    }

    // Check if this is a CLI execution - don't update cells
    if (cellId.startsWith("cli-temp-")) {
      return;
    }

    setCells((prevCells) =>
      prevCells.map((c) =>
        c.id === cellId ? { ...c, outputs: [...c.outputs, output] } : c
      )
    );
  }

  // Handle execution start
  function handleExecutionStart(cellId: string) {
    // Auto-show logs when execution starts
    setShowExecutionLogs(true);
    setLogsMinimized(false);
    addLog("info", "Execution started", cellId);

    // Ignore CLI executions for cell state
    if (cellId.startsWith("cli-temp-")) {
      setIsCliExecuting(true);
      return;
    }

    const startTime = Date.now();
    setCells((prevCells) =>
      prevCells.map((c) =>
        c.id === cellId
          ? { ...c, isExecuting: true, outputs: [], executionStartTime: startTime, executionDuration: undefined }
          : c
      )
    );
  }

  // Handle execution complete
  function handleExecutionComplete(cellId: string) {
    addLog("success", "Execution completed", cellId);

    // Ignore CLI executions for cell state
    if (cellId.startsWith("cli-temp-")) {
      setIsCliExecuting(false);
      // Still refresh variables for CLI executions if panel is open and auto-refresh is enabled
      if (showVariablesRef.current && autoRefreshVariablesRef.current) {
        refreshVariablesRef.current?.();
      }
      return;
    }

    executionCountRef.current += 1;
    const endTime = Date.now();
    setCells((prevCells) =>
      prevCells.map((c) => {
        if (c.id === cellId) {
          const duration = c.executionStartTime ? endTime - c.executionStartTime : undefined;
          return {
            ...c,
            isExecuting: false,
            executionCount: executionCountRef.current,
            executionDuration: duration,
          };
        }
        return c;
      })
    );

    // Auto-refresh variables if enabled and panel is open
    if (showVariablesRef.current && autoRefreshVariablesRef.current) {
      refreshVariablesRef.current?.();
    }
  }

  // Handle execution error
  function handleExecutionError(cellId: string, error: string) {
    addLog("error", error, cellId);

    // Handle CLI execution errors
    if (cellId.startsWith("cli-temp-")) {
      setIsCliExecuting(false);
      return;
    }

    const endTime = Date.now();
    setCells((prevCells) =>
      prevCells.map((c) => {
        if (c.id === cellId) {
          const duration = c.executionStartTime ? endTime - c.executionStartTime : undefined;
          return {
            ...c,
            isExecuting: false,
            executionDuration: duration,
            outputs: [
              ...c.outputs,
              {
                outputType: "error",
                ename: "ExecutionError",
                evalue: error,
                traceback: [],
              },
            ],
          };
        }
        return c;
      })
    );
  }

  // Load notebook
  useEffect(() => {
    const loadNotebook = async () => {
      setIsLoading(true);
      try {
        if (id) {
          const loadedNotebook = await notebookService.get(id);
          setNotebook(loadedNotebook);
          resetCells(loadedNotebook.cells); // Use reset to clear undo history
          if (loadedNotebook.cells.length > 0) {
            setSelectedCellId(loadedNotebook.cells[0].id);
          }

          // Find max execution count
          const maxCount = loadedNotebook.cells.reduce(
            (max, cell) => Math.max(max, cell.executionCount || 0),
            0
          );
          executionCountRef.current = maxCount;
        }
      } catch (error) {
        console.error("Failed to load notebook, using mock data:", error);
        // Fallback to mock data
        setNotebook(mockNotebook);
        resetCells(mockNotebook.cells); // Use reset to clear undo history
        if (mockNotebook.cells.length > 0) {
          setSelectedCellId(mockNotebook.cells[0].id);
        }
      } finally {
        setIsLoading(false);
      }
    };

    loadNotebook();
  }, [id]);

  // Connect to kernel when notebook loads
  useEffect(() => {
    if (notebook && !isConnected) {
      connect().catch(console.error);
    }

    return () => {
      disconnect();
    };
  }, [notebook]);

  // Save notebook
  const handleSave = useCallback(async () => {
    if (!notebook || !id) return;

    setIsSaving(true);
    try {
      await notebookService.update(id, {
        name: notebook.name,
        cells: cells,
      });
    } catch (error) {
      console.error("Failed to save notebook:", error);
    } finally {
      setIsSaving(false);
    }
  }, [notebook, id, cells]);

  // Helper: Insert cell above selected
  const handleInsertCellAbove = useCallback((type: "code" | "markdown" = "code") => {
    if (!selectedCellId) return;
    const index = cells.findIndex((c) => c.id === selectedCellId);
    if (index === -1) return;

    const newCell: Cell = {
      id: `cell-${Date.now()}`,
      cellType: type,
      source: "",
      outputs: [],
    };
    const newCells = [...cells];
    newCells.splice(index, 0, newCell);
    setCells(newCells);
    setSelectedCellId(newCell.id);
  }, [selectedCellId, cells, setCells]);

  // Helper: Insert cell below selected
  const handleInsertCellBelow = useCallback((type: "code" | "markdown" = "code") => {
    const index = selectedCellId
      ? cells.findIndex((c) => c.id === selectedCellId)
      : cells.length - 1;

    const newCell: Cell = {
      id: `cell-${Date.now()}`,
      cellType: type,
      source: "",
      outputs: [],
    };
    const newCells = [...cells];
    newCells.splice(index + 1, 0, newCell);
    setCells(newCells);
    setSelectedCellId(newCell.id);
  }, [selectedCellId, cells, setCells]);

  // Helper: Copy cell
  const handleCopyCell = useCallback(() => {
    if (!selectedCellId) return;
    const cell = cells.find((c) => c.id === selectedCellId);
    if (!cell) return;

    const index = cells.findIndex((c) => c.id === selectedCellId);
    const newCell: Cell = {
      ...cell,
      id: `cell-${Date.now()}`,
      outputs: [],
      executionCount: undefined,
    };
    const newCells = [...cells];
    newCells.splice(index + 1, 0, newCell);
    setCells(newCells);
    setSelectedCellId(newCell.id);
  }, [selectedCellId, cells, setCells]);

  // Helper: Select previous/next cell
  const handleSelectPreviousCell = useCallback(() => {
    if (!selectedCellId || cells.length === 0) return;
    const index = cells.findIndex((c) => c.id === selectedCellId);
    if (index > 0) {
      setSelectedCellId(cells[index - 1].id);
    }
  }, [selectedCellId, cells]);

  const handleSelectNextCell = useCallback(() => {
    if (!selectedCellId || cells.length === 0) return;
    const index = cells.findIndex((c) => c.id === selectedCellId);
    if (index < cells.length - 1) {
      setSelectedCellId(cells[index + 1].id);
    }
  }, [selectedCellId, cells]);

  // Cell operations (defined before keyboard shortcuts useEffect)
  const handleToggleCollapse = useCallback((cellId: string) => {
    setCells(prev => prev.map((c) =>
      c.id === cellId ? { ...c, isCollapsed: !c.isCollapsed } : c
    ));
  }, []);

  const handleChangeCellType = useCallback((cellId: string, newType: "code" | "markdown") => {
    setCells(prev => prev.map((c) =>
      c.id === cellId
        ? { ...c, cellType: newType, outputs: newType === "markdown" ? [] : c.outputs }
        : c
    ));
  }, []);

  const handleDeleteCell = useCallback((cellId: string) => {
    setCells(prev => {
      const newCells = prev.filter((c) => c.id !== cellId);
      return newCells;
    });
    setSelectedCellId(prev => prev === cellId ? null : prev);
  }, []);

  // Toggle split view (defined before keyboard shortcuts useEffect)
  const handleToggleSplitView = useCallback(() => {
    if (!showSplitView) {
      // Opening split view - set initial cells
      if (cells.length >= 2) {
        setSplitLeftCellId(cells[0].id);
        setSplitRightCellId(cells[1].id);
      } else if (cells.length === 1) {
        setSplitLeftCellId(cells[0].id);
        setSplitRightCellId(null);
      }
    }
    setShowSplitView(!showSplitView);
  }, [showSplitView, cells]);

  // === NEW FEATURES ===

  // 1. Run and Select Next (Shift+Enter behavior)
  const handleExecuteAndSelectNext = useCallback(async (cellId: string) => {
    const cell = cells.find((c) => c.id === cellId);
    if (!cell || cell.cellType !== "code") return;

    // Execute the cell
    if (isConnected) {
      try {
        await execute(cellId, cell.source);
      } catch (error) {
        console.error("Execution failed:", error);
      }
    }

    // Select next cell or create new one
    const index = cells.findIndex((c) => c.id === cellId);
    if (index < cells.length - 1) {
      setSelectedCellId(cells[index + 1].id);
    } else {
      // Create new cell at end
      const newCell: Cell = {
        id: `cell-${Date.now()}`,
        cellType: "code",
        source: "",
        outputs: [],
      };
      setCells([...cells, newCell]);
      setSelectedCellId(newCell.id);
    }
  }, [cells, isConnected, execute, setCells]);

  // 2. Cell Merge - merge selected cell with next
  const handleMergeCellBelow = useCallback(() => {
    if (!selectedCellId) return;
    const index = cells.findIndex((c) => c.id === selectedCellId);
    if (index === -1 || index >= cells.length - 1) return;

    const currentCell = cells[index];
    const nextCell = cells[index + 1];

    // Only merge cells of same type
    if (currentCell.cellType !== nextCell.cellType) return;

    const mergedCell: Cell = {
      ...currentCell,
      source: currentCell.source + "\n\n" + nextCell.source,
      outputs: [...currentCell.outputs, ...nextCell.outputs],
    };

    const newCells = [...cells];
    newCells[index] = mergedCell;
    newCells.splice(index + 1, 1);
    setCells(newCells);
  }, [selectedCellId, cells, setCells]);

  // 3. Cell Split - split cell at cursor (line number)
  const handleSplitCell = useCallback((cellId: string, lineNumber: number) => {
    const cellIndex = cells.findIndex((c) => c.id === cellId);
    if (cellIndex === -1) return;

    const cell = cells[cellIndex];
    const lines = cell.source.split("\n");
    const topSource = lines.slice(0, lineNumber).join("\n");
    const bottomSource = lines.slice(lineNumber).join("\n");

    const topCell: Cell = { ...cell, source: topSource, outputs: [] };
    const bottomCell: Cell = {
      id: `cell-${Date.now()}`,
      cellType: cell.cellType,
      source: bottomSource,
      outputs: cell.outputs,
    };

    const newCells = [...cells];
    newCells[cellIndex] = topCell;
    newCells.splice(cellIndex + 1, 0, bottomCell);
    setCells(newCells);
    setSelectedCellId(bottomCell.id);
  }, [cells, setCells]);

  // 4. Multi-cell selection with Shift+Click
  const handleMultiSelectCell = useCallback((cellId: string, isShiftHeld: boolean) => {
    if (!isShiftHeld || !selectedCellId) {
      // Single select
      setSelectedCellIds(new Set([cellId]));
      setSelectedCellId(cellId);
      return;
    }

    // Range select
    const startIndex = cells.findIndex((c) => c.id === selectedCellId);
    const endIndex = cells.findIndex((c) => c.id === cellId);
    if (startIndex === -1 || endIndex === -1) return;

    const minIndex = Math.min(startIndex, endIndex);
    const maxIndex = Math.max(startIndex, endIndex);
    const selectedIds = new Set<string>();
    for (let i = minIndex; i <= maxIndex; i++) {
      selectedIds.add(cells[i].id);
    }
    setSelectedCellIds(selectedIds);
  }, [selectedCellId, cells]);

  // 5. Copy selected cells
  const handleCopyCells = useCallback(() => {
    const cellsToCopy = selectedCellIds.size > 0
      ? cells.filter((c) => selectedCellIds.has(c.id))
      : selectedCellId
        ? cells.filter((c) => c.id === selectedCellId)
        : [];

    if (cellsToCopy.length > 0) {
      setCellClipboard(cellsToCopy);
      addLog("info", `Copied ${cellsToCopy.length} cell(s) to clipboard`);
    }
  }, [selectedCellIds, selectedCellId, cells, addLog]);

  // 6. Cut selected cells
  const handleCutCells = useCallback(() => {
    const cellsToCut = selectedCellIds.size > 0
      ? cells.filter((c) => selectedCellIds.has(c.id))
      : selectedCellId
        ? cells.filter((c) => c.id === selectedCellId)
        : [];

    if (cellsToCut.length > 0) {
      setCellClipboard(cellsToCut);
      const idsToRemove = new Set(cellsToCut.map((c) => c.id));
      setCells(cells.filter((c) => !idsToRemove.has(c.id)));
      setSelectedCellIds(new Set());
      addLog("info", `Cut ${cellsToCut.length} cell(s)`);
    }
  }, [selectedCellIds, selectedCellId, cells, setCells, addLog]);

  // 7. Paste cells
  const handlePasteCells = useCallback(() => {
    if (cellClipboard.length === 0) return;

    const insertIndex = selectedCellId
      ? cells.findIndex((c) => c.id === selectedCellId) + 1
      : cells.length;

    const newCells = cellClipboard.map((c) => ({
      ...c,
      id: `cell-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      outputs: [],
      executionCount: undefined,
    }));

    const updatedCells = [...cells];
    updatedCells.splice(insertIndex, 0, ...newCells);
    setCells(updatedCells);
    setSelectedCellId(newCells[0].id);
    addLog("info", `Pasted ${newCells.length} cell(s)`);
  }, [cellClipboard, selectedCellId, cells, setCells, addLog]);

  // 8. Clear individual cell output
  const handleClearCellOutput = useCallback((cellId: string) => {
    setCells(cells.map((c) =>
      c.id === cellId ? { ...c, outputs: [], executionCount: undefined } : c
    ));
  }, [cells, setCells]);

  // 9. Delete selected cells (bulk)
  const handleDeleteSelectedCells = useCallback(() => {
    if (selectedCellIds.size === 0 && !selectedCellId) return;

    const idsToRemove = selectedCellIds.size > 0
      ? selectedCellIds
      : new Set([selectedCellId!]);

    setCells(cells.filter((c) => !idsToRemove.has(c.id)));
    setSelectedCellIds(new Set());
    setSelectedCellId(null);
  }, [selectedCellIds, selectedCellId, cells, setCells]);

  // 10. Checkpoints
  const handleCreateCheckpoint = useCallback((name?: string) => {
    const checkpoint = {
      id: `checkpoint-${Date.now()}`,
      name: name || `Checkpoint ${checkpoints.length + 1}`,
      cells: JSON.parse(JSON.stringify(cells)),
      timestamp: new Date(),
    };
    setCheckpoints([...checkpoints, checkpoint]);
    addLog("info", `Created checkpoint: ${checkpoint.name}`);
  }, [cells, checkpoints, addLog]);

  const handleRestoreCheckpoint = useCallback((checkpointId: string) => {
    const checkpoint = checkpoints.find((c) => c.id === checkpointId);
    if (checkpoint) {
      setCells(JSON.parse(JSON.stringify(checkpoint.cells)));
      addLog("info", `Restored checkpoint: ${checkpoint.name}`);
    }
  }, [checkpoints, setCells, addLog]);

  const handleDeleteCheckpoint = useCallback((checkpointId: string) => {
    setCheckpoints(checkpoints.filter((c) => c.id !== checkpointId));
  }, [checkpoints]);

  // 11. Toggle Zen Mode
  const handleToggleZenMode = useCallback(() => {
    setIsZenMode(!isZenMode);
    if (!isZenMode) {
      // Entering zen mode - hide all panels
      setShowVariables(false);
      setShowPackageManager(false);
      setShowTableOfContents(false);
      setShowExecutionLogs(false);
    }
  }, [isZenMode]);

  // 12. Toggle Presentation Mode
  const handleTogglePresentationMode = useCallback(() => {
    setIsPresentationMode(!isPresentationMode);
  }, [isPresentationMode]);

  // Keyboard shortcuts: Command Mode (Jupyter-like) + Ctrl shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const isCtrlOrCmd = e.ctrlKey || e.metaKey;
      const isAlt = e.altKey;
      const target = e.target as HTMLElement;
      const isEditing = target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;

      // === GLOBAL SHORTCUTS (work anywhere) ===

      // Ctrl+F: Find & Replace
      if (isCtrlOrCmd && e.key === "f") {
        e.preventDefault();
        setShowFindReplace(true);
        return;
      }

      // Ctrl+Shift+Z or Ctrl+Y: Redo
      if (isCtrlOrCmd && e.shiftKey && e.key === "z") {
        e.preventDefault();
        if (canRedo) redo();
        return;
      }

      // Ctrl+Z: Undo
      if (isCtrlOrCmd && e.key === "z" && !e.shiftKey) {
        e.preventDefault();
        if (canUndo) undo();
        return;
      }

      // Ctrl+Y: Redo (alternative)
      if (isCtrlOrCmd && e.key === "y") {
        e.preventDefault();
        if (canRedo) redo();
        return;
      }

      // Ctrl+/: Show keyboard shortcuts
      if (isCtrlOrCmd && e.key === "/") {
        e.preventDefault();
        setShowShortcuts(true);
        return;
      }

      // Ctrl+Shift+C: Copy cells
      if (isCtrlOrCmd && e.shiftKey && e.key === "c") {
        e.preventDefault();
        handleCopyCells();
        return;
      }

      // Ctrl+Shift+X: Cut cells
      if (isCtrlOrCmd && e.shiftKey && e.key === "x") {
        e.preventDefault();
        handleCutCells();
        return;
      }

      // Ctrl+Shift+V: Paste cells
      if (isCtrlOrCmd && e.shiftKey && e.key === "v") {
        e.preventDefault();
        handlePasteCells();
        return;
      }

      // Ctrl+Shift+M: Merge cell below
      if (isCtrlOrCmd && e.shiftKey && e.key === "m") {
        e.preventDefault();
        handleMergeCellBelow();
        return;
      }

      // Ctrl+Shift+S: Create checkpoint
      if (isCtrlOrCmd && e.shiftKey && e.key === "s") {
        e.preventDefault();
        handleCreateCheckpoint();
        return;
      }

      // F11 or Ctrl+Shift+F: Toggle Zen Mode
      if (e.key === "F11" || (isCtrlOrCmd && e.shiftKey && e.key === "f")) {
        e.preventDefault();
        handleToggleZenMode();
        return;
      }

      // Ctrl+Shift+P: Toggle Presentation Mode
      if (isCtrlOrCmd && e.shiftKey && e.key === "p") {
        e.preventDefault();
        handleTogglePresentationMode();
        return;
      }

      // === CTRL+ALT SHORTCUTS (panel toggles) ===
      if (isCtrlOrCmd && isAlt) {
        switch (e.key.toLowerCase()) {
          case "v": // Toggle Variables
            e.preventDefault();
            setShowVariables(prev => !prev);
            return;
          case "p": // Toggle Packages
            e.preventDefault();
            setShowPackageManager(prev => !prev);
            return;
          case "o": // Toggle Outline/TOC
            e.preventDefault();
            setShowTableOfContents(prev => !prev);
            return;
          case "l": // Toggle Logs
            e.preventDefault();
            setShowExecutionLogs(prev => !prev);
            return;
        }
      }

      // Ctrl+\: Toggle Split View
      if (isCtrlOrCmd && e.key === "\\") {
        e.preventDefault();
        handleToggleSplitView();
        return;
      }

      // === ESCAPE: Enter Command Mode ===
      if (e.key === "Escape") {
        e.preventDefault();
        setIsCommandMode(true);
        setShowQuickTagMenu(false);
        // Blur any focused element
        (document.activeElement as HTMLElement)?.blur();
        return;
      }

      // === ENTER: Exit Command Mode (when in command mode) ===
      if (e.key === "Enter" && isCommandMode && !isCtrlOrCmd && !e.shiftKey) {
        e.preventDefault();
        setIsCommandMode(false);
        return;
      }

      // === COMMAND MODE SHORTCUTS (only when in command mode) ===
      if (isCommandMode && !isEditing) {
        switch (e.key.toLowerCase()) {
          case "a": // Insert cell above
            e.preventDefault();
            handleInsertCellAbove("code");
            break;
          case "b": // Insert cell below
            e.preventDefault();
            handleInsertCellBelow("code");
            break;
          case "x": // Delete cell
            e.preventDefault();
            if (selectedCellId) {
              handleDeleteCell(selectedCellId);
            }
            break;
          case "m": // Change to markdown
            e.preventDefault();
            if (selectedCellId) {
              handleChangeCellType(selectedCellId, "markdown");
            }
            break;
          case "y": // Change to code
            e.preventDefault();
            if (selectedCellId) {
              handleChangeCellType(selectedCellId, "code");
            }
            break;
          case "c": // Copy cell
            e.preventDefault();
            handleCopyCell();
            break;
          case "o": // Toggle collapse
            e.preventDefault();
            if (selectedCellId) {
              handleToggleCollapse(selectedCellId);
            }
            break;
          case "t": // Quick tag menu
            e.preventDefault();
            if (selectedCellId) {
              // Position menu near selected cell
              const cellEl = document.querySelector(`[data-cell-id="${selectedCellId}"]`);
              if (cellEl) {
                const rect = cellEl.getBoundingClientRect();
                setQuickTagPosition({ x: rect.left + 50, y: rect.top + 30 });
              }
              setShowQuickTagMenu(true);
            }
            break;
          case "arrowup":
          case "k": // Select previous cell
            e.preventDefault();
            handleSelectPreviousCell();
            break;
          case "arrowdown":
          case "j": // Select next cell
            e.preventDefault();
            handleSelectNextCell();
            break;
          case "d": // Delete cell (double d like vim - but we do single for simplicity)
            if (e.repeat) {
              e.preventDefault();
              if (selectedCellId) {
                handleDeleteCell(selectedCellId);
              }
            }
            break;
        }
        return;
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [
    canUndo, canRedo, undo, redo,
    isCommandMode, selectedCellId, cells,
    handleInsertCellAbove, handleInsertCellBelow, handleCopyCell,
    handleSelectPreviousCell, handleSelectNextCell,
    handleDeleteCell, handleChangeCellType, handleToggleCollapse,
    handleToggleSplitView,
    handleCopyCells, handleCutCells, handlePasteCells,
    handleMergeCellBelow, handleCreateCheckpoint,
    handleToggleZenMode, handleTogglePresentationMode,
  ]);

  // Auto-save
  useEffect(() => {
    const autoSaveInterval = setInterval(() => {
      if (notebook && id && cells.length > 0) {
        handleSave();
      }
    }, 30000); // Auto-save every 30 seconds

    return () => clearInterval(autoSaveInterval);
  }, [handleSave, notebook, id, cells]);

  const handleCreateCell = (code: string, position?: number | null) => {
    const newCell: Cell = {
      id: `cell-${Date.now()}`,
      cellType: "code",
      source: code,
      outputs: [],
    };

    if (position !== undefined && position !== null) {
      const newCells = [...cells];
      newCells.splice(position, 0, newCell);
      setCells(newCells);
    } else {
      setCells([...cells, newCell]);
    }
    setSelectedCellId(newCell.id);
  };

  const handleEditCell = (cellId: string, code: string) => {
    setCells(cells.map((c) => (c.id === cellId ? { ...c, source: code } : c)));
  };

  const handleUpdateCellTags = (cellId: string, tags: CellTag[]) => {
    setCells(cells.map((c) => (c.id === cellId ? { ...c, tags } : c)));
  };

  const handleUpdateCellMetadata = (cellId: string, metadata: CellMetadata) => {
    setCells(cells.map((c) => (c.id === cellId ? { ...c, metadata } : c)));
  };

  const handleExecuteCell = async (cellId: string) => {
    const cell = cells.find((c) => c.id === cellId);
    if (!cell || cell.cellType !== "code") return;

    if (isConnected) {
      // Use real kernel execution
      try {
        await execute(cellId, cell.source);
      } catch (error) {
        console.error("Execution failed:", error);
      }
    } else {
      // Fallback to simulated execution
      setCells(
        cells.map((c) =>
          c.id === cellId ? { ...c, isExecuting: true, outputs: [] } : c
        )
      );

      setTimeout(() => {
        executionCountRef.current += 1;
        setCells((prevCells) =>
          prevCells.map((c) =>
            c.id === cellId
              ? {
                  ...c,
                  isExecuting: false,
                  outputs: [
                    {
                      outputType: "stream",
                      text: "[Simulated] Execution completed. Connect to a kernel for real execution.",
                    },
                  ],
                  executionCount: executionCountRef.current,
                }
              : c
          )
        );
      }, 1000);
    }
  };

  const handleAddCell = (type: "code" | "markdown", afterCellId?: string) => {
    const newCell: Cell = {
      id: `cell-${Date.now()}`,
      cellType: type,
      source: type === "code" ? "" : "# New Markdown Cell",
      outputs: [],
    };

    if (afterCellId) {
      const index = cells.findIndex((c) => c.id === afterCellId);
      const newCells = [...cells];
      newCells.splice(index + 1, 0, newCell);
      setCells(newCells);
    } else {
      setCells([...cells, newCell]);
    }
    setSelectedCellId(newCell.id);
  };

  const handleRunAll = async () => {
    for (const cell of cells) {
      if (cell.cellType === "code") {
        await handleExecuteCell(cell.id);
      }
    }
  };

  const handleRunAllAbove = async (cellId: string) => {
    const index = cells.findIndex((c) => c.id === cellId);
    if (index <= 0) return;

    for (let i = 0; i < index; i++) {
      const cell = cells[i];
      if (cell.cellType === "code" && !cell.tags?.some(t => t.type === "skip")) {
        await handleExecuteCell(cell.id);
      }
    }
  };

  const handleRunAllBelow = async (cellId: string) => {
    const index = cells.findIndex((c) => c.id === cellId);
    if (index === -1 || index >= cells.length - 1) return;

    for (let i = index + 1; i < cells.length; i++) {
      const cell = cells[i];
      if (cell.cellType === "code" && !cell.tags?.some(t => t.type === "skip")) {
        await handleExecuteCell(cell.id);
      }
    }
  };

  const handleClearAllOutputs = () => {
    setCells(cells.map((c) => ({ ...c, outputs: [], executionCount: undefined })));
    executionCountRef.current = 0;
  };

  const handleMoveCell = (cellId: string, direction: "up" | "down") => {
    const index = cells.findIndex((c) => c.id === cellId);
    if (index === -1) return;

    const newIndex = direction === "up" ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= cells.length) return;

    const newCells = [...cells];
    const [movedCell] = newCells.splice(index, 1);
    newCells.splice(newIndex, 0, movedCell);
    setCells(newCells);
  };

  const handleStop = () => {
    interrupt();
  };

  const handleRestart = async () => {
    handleClearAllOutputs();
    await restart();
  };

  // CLI execution handler
  const handleCliExecute = useCallback(async (code: string) => {
    if (!isConnected) {
      setCliOutputs([{
        outputType: "error",
        ename: "KernelError",
        evalue: "Not connected to kernel. Please wait for connection.",
        traceback: []
      }]);
      return;
    }

    setIsCliExecuting(true);
    setCliOutputs([]);

    try {
      // Create a temporary cell ID for CLI execution
      const cliCellId = `cli-temp-${Date.now()}`;

      // Execute using the kernel
      await execute(cliCellId, code);
    } catch (error) {
      setCliOutputs([{
        outputType: "error",
        ename: "ExecutionError",
        evalue: String(error),
        traceback: []
      }]);
    } finally {
      setIsCliExecuting(false);
    }
  }, [isConnected, execute]);

  // Handle CLI output
  const handleCliOutput = useCallback((cellId: string, output: CellOutput) => {
    if (cellId.startsWith("cli-temp-")) {
      setCliOutputs(prev => [...prev, output]);
    }
  }, []);

  // Refresh variables from kernel
  const refreshVariables = useCallback(async () => {
    if (!kernel?.id || !isConnected) return;

    setIsLoadingVariables(true);
    try {
      const vars = await executionService.getVariables(kernel.id);
      setVariables(vars);
    } catch (error) {
      console.error("Failed to get variables:", error);
    } finally {
      setIsLoadingVariables(false);
    }
  }, [kernel?.id, isConnected]);

  // Keep refs in sync for use in callbacks
  useEffect(() => {
    refreshVariablesRef.current = refreshVariables;
  }, [refreshVariables]);

  useEffect(() => {
    showVariablesRef.current = showVariables;
  }, [showVariables]);

  useEffect(() => {
    autoRefreshVariablesRef.current = autoRefreshVariables;
  }, [autoRefreshVariables]);

  // Toggle variables panel
  const handleToggleVariables = useCallback(() => {
    if (!showVariables) {
      // Refresh variables when opening panel
      refreshVariables();
    }
    setShowVariables(!showVariables);
  }, [showVariables, refreshVariables]);

  // Upload handler - import .py file as code cells
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleUpload = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Only accept .py files
    if (!file.name.endsWith('.py')) {
      alert('Please select a Python (.py) file');
      return;
    }

    try {
      const content = await file.text();

      // Split by common Python cell markers or by double newlines
      const cellMarkers = /^# %%|^# In\[|^# <codecell>/gm;
      let cellSources: string[];

      if (cellMarkers.test(content)) {
        // Split by cell markers
        cellSources = content.split(cellMarkers).filter(s => s.trim());
      } else {
        // Split by function/class definitions or just use as single cell
        const chunks = content.split(/\n\n(?=def |class |import |from |#)/);
        cellSources = chunks.filter(s => s.trim());
      }

      // Create new cells from the Python file content
      const newCells: Cell[] = cellSources.map((source, index) => ({
        id: `cell-imported-${Date.now()}-${index}`,
        cellType: "code" as const,
        source: source.trim(),
        outputs: [],
      }));

      // Add cells to the notebook
      if (newCells.length > 0) {
        setCells([...cells, ...newCells]);
        addLog("info", `Imported ${newCells.length} cells from ${file.name}`);
      }
    } catch (error) {
      console.error('Error reading file:', error);
      addLog("error", `Failed to import ${file.name}: ${error}`);
    }

    // Reset input so the same file can be selected again
    event.target.value = '';
  };

  // Export handlers
  const handleExportIpynb = () => {
    if (notebook) {
      exportToIpynb({ ...notebook, cells });
    }
  };

  const handleExportPython = () => {
    if (notebook) {
      exportToPython({ ...notebook, cells });
    }
  };

  const handleExportHtml = () => {
    if (notebook) {
      exportToHtml({ ...notebook, cells });
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      </div>
    );
  }

  return (
    <div className={cn("flex flex-1 overflow-hidden", isZenMode && "zen-mode-active")}>
      {/* Main content area */}
      <div className="flex flex-1 flex-col overflow-hidden">
        {/* Breadcrumb with toolbar - hidden in Zen Mode */}
        {!isZenMode && (
          <NotebookEditorBreadcrumb
            notebookName={notebook?.name || "Notebook"}
            kernelStatus={kernelStatus}
            onRunAll={handleRunAll}
            onStop={handleStop}
            onRestart={handleRestart}
            onAddCode={() => handleAddCell("code")}
            onAddMarkdown={() => handleAddCell("markdown")}
            onClearOutputs={handleClearAllOutputs}
            onSave={handleSave}
            onToggleVariables={handleToggleVariables}
            onTogglePackages={() => setShowPackageManager(!showPackageManager)}
            onToggleTableOfContents={() => setShowTableOfContents(!showTableOfContents)}
            showVariables={showVariables}
            showTableOfContents={showTableOfContents}
            onToggleSplitView={handleToggleSplitView}
            onShowShortcuts={() => setShowShortcuts(true)}
            onUpload={handleUpload}
            onExportPython={handleExportPython}
            onExportIpynb={handleExportIpynb}
            onExportHtml={handleExportHtml}
            isSplitViewActive={showSplitView}
            showPackages={showPackageManager}
          />
        )}

        {/* Find & Replace Panel */}
        {showFindReplace && (
          <FindReplacePanel
            cells={cells}
            onClose={() => setShowFindReplace(false)}
            onNavigateToCell={setSelectedCellId}
            onReplaceInCell={handleEditCell}
          />
        )}

        {/* Editor area with optional Package Manager panel */}
        <div className="flex flex-1 overflow-hidden relative">
          {/* Notebook Editor */}
          <div className="flex flex-1 flex-col overflow-hidden">
            {/* Cells editor */}
            <NotebookEditorContent
              cells={cells}
              selectedCellId={selectedCellId}
              selectedCellIds={selectedCellIds}
              onSelectCell={(id, isShift) => {
                if (isShift) {
                  handleMultiSelectCell(id, true);
                } else {
                  setSelectedCellId(id);
                  setSelectedCellIds(new Set([id]));
                }
                // Exit command mode when selecting a cell to edit
                if (id && !isCommandMode) {
                  setIsCommandMode(false);
                }
              }}
              onUpdateCell={handleEditCell}
              onDeleteCell={handleDeleteCell}
              onExecuteCell={handleExecuteCell}
              onExecuteAndSelectNext={handleExecuteAndSelectNext}
              onAddCell={handleAddCell}
              onMoveCell={handleMoveCell}
              onUpdateCellTags={handleUpdateCellTags}
              onRunAllAbove={handleRunAllAbove}
              onRunAllBelow={handleRunAllBelow}
              onToggleCollapse={handleToggleCollapse}
              onChangeCellType={handleChangeCellType}
              onShowMetadata={setMetadataCell}
              onClearOutput={handleClearCellOutput}
              onSplitCell={handleSplitCell}
              kernelId={kernel?.id}
              isCommandMode={isCommandMode}
              isPresentationMode={isPresentationMode}
              isZenMode={isZenMode}
              splitViewOverlay={
                showSplitView ? (
                  <div className="h-[450px] shadow-2xl rounded-t-lg overflow-hidden border border-border border-b-0 bg-card">
                    <SplitViewPanel
                      cells={cells}
                      leftCellId={splitLeftCellId}
                      rightCellId={splitRightCellId}
                      onSelectLeftCell={setSplitLeftCellId}
                      onSelectRightCell={setSplitRightCellId}
                      onCellChange={handleEditCell}
                      onRunCell={handleExecuteCell}
                      onClose={() => setShowSplitView(false)}
                    />
                  </div>
                ) : undefined
              }
            />
          </div>

          {/* Table of Contents Panel (side panel) */}
          {showTableOfContents && (
            <div className="w-72 border-l border-border flex flex-col bg-card">
              <TableOfContents
                cells={cells}
                selectedCellId={selectedCellId}
                onNavigateToCell={setSelectedCellId}
                onClose={() => setShowTableOfContents(false)}
              />
            </div>
          )}

          {/* Variable Inspector Panel (side panel) */}
          {showVariables && (
            <div className="w-80 border-l border-border flex flex-col bg-card">
              <VariableInspectorPanel
                variables={variables}
                onRefresh={refreshVariables}
                onClose={() => setShowVariables(false)}
                isLoading={isLoadingVariables}
                autoRefresh={autoRefreshVariables}
                onAutoRefreshChange={setAutoRefreshVariables}
              />
            </div>
          )}

          {/* Package Manager Panel (side panel, not modal) */}
          {showPackageManager && (
            <div className="w-80 border-l border-border flex flex-col bg-card">
              <PackageManagerPanel
                isOpen={true}
                onClose={() => setShowPackageManager(false)}
              />
            </div>
          )}

          {/* Execution Log Panel (floating) */}
          {showExecutionLogs && (
            <ExecutionLogPanel
              logs={executionLogs}
              isExecuting={kernelStatus === "busy"}
              isMinimized={logsMinimized}
              onClear={() => setExecutionLogs([])}
              onClose={() => setShowExecutionLogs(false)}
              onMinimize={() => setLogsMinimized(!logsMinimized)}
            />
          )}
        </div>

        {/* Python Console CLI - hidden in Zen Mode */}
        {!isZenMode && (
          <NotebookCLI
            onExecute={handleCliExecute}
            isExecuting={isCliExecuting}
            kernelStatus={kernelStatus}
            outputs={cliOutputs}
            onClearOutputs={() => setCliOutputs([])}
          />
        )}
      </div>

      {/* Right: AI Panel - full height, hidden in Zen Mode */}
      {!isZenMode && (
        <AIChatPanel
          notebookId={id || ""}
          getCells={() => cells}
          getSelectedCellId={() => selectedCellId}
          onCreateCell={handleCreateCell}
          onEditCell={handleEditCell}
          onDeleteCell={handleDeleteCell}
          onExecuteCell={handleExecuteCell}
        />
      )}

      {/* Zen Mode Exit Button */}
      {isZenMode && (
        <button
          onClick={handleToggleZenMode}
          className="fixed top-4 right-4 z-50 flex items-center gap-2 rounded-lg bg-muted/80 backdrop-blur px-3 py-1.5 text-xs text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
        >
          Press F11 to exit Zen Mode
        </button>
      )}

      {/* Modals */}
      <KeyboardShortcutsDialog
        open={showShortcuts}
        onOpenChange={setShowShortcuts}
      />

      {/* Cell Metadata Dialog */}
      {metadataCell && (
        <CellMetadataDialog
          cell={metadataCell}
          open={!!metadataCell}
          onOpenChange={(open) => !open && setMetadataCell(null)}
          onSave={handleUpdateCellMetadata}
        />
      )}

      {/* Hidden file input for uploading .py files */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".py"
        onChange={handleFileChange}
        className="hidden"
      />

      {/* Command Mode Indicator */}
      {isCommandMode && (
        <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-primary-foreground shadow-lg">
          <span className="text-sm font-medium">Command Mode</span>
          <span className="text-xs opacity-75">(Press Enter to edit)</span>
        </div>
      )}

      {/* Quick Tag Menu */}
      {showQuickTagMenu && selectedCellId && (
        <div
          className="fixed z-50 rounded-lg border border-border bg-card p-2 shadow-xl"
          style={{ left: quickTagPosition.x, top: quickTagPosition.y }}
        >
          <div className="text-xs font-medium text-muted-foreground mb-2 px-2">Add Tag</div>
          <div className="grid grid-cols-2 gap-1">
            {[
              { type: "important", label: "Important", color: "bg-red-500" },
              { type: "skip", label: "Skip", color: "bg-gray-500" },
              { type: "todo", label: "TODO", color: "bg-yellow-500" },
              { type: "review", label: "Review", color: "bg-blue-500" },
              { type: "slow", label: "Slow", color: "bg-orange-500" },
              { type: "gpu", label: "GPU", color: "bg-green-500" },
              { type: "output", label: "Output", color: "bg-purple-500" },
              { type: "test", label: "Test", color: "bg-cyan-500" },
            ].map((tag) => {
              const cell = cells.find((c) => c.id === selectedCellId);
              const hasTag = cell?.tags?.some((t) => t.type === tag.type);
              return (
                <button
                  key={tag.type}
                  onClick={() => {
                    const cell = cells.find((c) => c.id === selectedCellId);
                    if (!cell) return;
                    const currentTags = cell.tags || [];
                    let newTags: CellTag[];
                    if (hasTag) {
                      newTags = currentTags.filter((t) => t.type !== tag.type);
                    } else {
                      newTags = [...currentTags, { type: tag.type as CellTag["type"], label: tag.label }];
                    }
                    handleUpdateCellTags(selectedCellId, newTags);
                    setShowQuickTagMenu(false);
                  }}
                  className={`flex items-center gap-2 rounded px-2 py-1.5 text-xs hover:bg-muted ${
                    hasTag ? "bg-muted" : ""
                  }`}
                >
                  <span className={`h-2 w-2 rounded-full ${tag.color}`} />
                  {tag.label}
                  {hasTag && <span className="text-green-500">✓</span>}
                </button>
              );
            })}
          </div>
          <button
            onClick={() => setShowQuickTagMenu(false)}
            className="mt-2 w-full rounded bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-muted/80"
          >
            Close (Esc)
          </button>
        </div>
      )}
    </div>
  );
};
