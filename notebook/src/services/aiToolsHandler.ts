// AI Tools Handler - Process AI actions like Flutter implementation
// Handles: createCell, editCell, deleteCell, executeCode, readCellOutput, listCells
// File tools: readFile, writeFile, listDirectory, deleteFile

import { Cell, CellOutput } from "@/types/notebook";
import { fileService } from "./fileService";
import { pipService } from "./pipService";
import { gpuService } from "./gpuService";
import { dockerService } from "./dockerService";

export type AIToolType =
  // Cell operations
  | "createCell"
  | "editCell"
  | "deleteCell"
  | "executeCode"
  | "readCellOutput"
  | "listCells"
  | "splitCell"
  | "mergeCells"
  | "moveCell"
  | "changeCellType"
  | "copyCells"
  | "cutCells"
  | "pasteCells"
  | "duplicateCell"
  | "updateTags"
  | "toggleCollapse"
  | "clearOutput"
  | "clearAllOutputs"
  // Execution control
  | "runAllCells"
  | "runAllAbove"
  | "runAllBelow"
  | "executeAndInsert"
  | "interruptExecution"
  | "restartKernel"
  // Navigation
  | "selectCell"
  | "goToCell"
  // Find/Replace
  | "findInNotebook"
  | "replaceInNotebook"
  // View modes
  | "togglePanel"
  | "toggleZenMode"
  | "togglePresentationMode"
  | "toggleSplitView"
  // Undo/Redo
  | "undo"
  | "redo"
  // Notebook operations
  | "saveNotebook"
  | "exportNotebook"
  | "createCheckpoint"
  | "restoreCheckpoint"
  | "getVariables"
  | "getCompletions"
  // File tools
  | "readFile"
  | "writeFile"
  | "listDirectory"
  | "deleteFile"
  | "createDirectory"
  // Package manager tools
  | "listPackages"
  | "installPackage"
  | "uninstallPackage"
  | "searchPackages"
  | "upgradePackage"
  | "getPackageInfo"
  | "checkOutdatedPackages"
  // Logs
  | "getExecutionLogs"
  | "clearExecutionLogs"
  // GPU
  | "getGpuStatus"
  // Container notebooks
  | "createContainer"
  | "listContainers"
  | "executeInContainer"
  | "stopContainer"
  | "removeContainer"
  | "installContainerPackage"
  | "listContainerPackages"
  | "quickExecuteInContainer";

export interface AIAction {
  tool: AIToolType;
  params: Record<string, unknown>;
}

export interface AIResponseWithActions {
  message: string;
  actions?: AIAction[];
}

export interface AIToolsCallbacks {
  // Cell operations
  onCreateCell: (code: string, position?: number | null) => void;
  onEditCell: (cellId: string, code: string) => void;
  onDeleteCell: (cellId: string) => void;
  onExecuteCell: (cellId: string) => void;
  onSplitCell?: (cellId: string, splitPoints: number[]) => void;
  onMergeCells?: (cellIds: string[]) => void;
  onMoveCell?: (cellId: string, direction: "up" | "down") => void;
  onChangeCellType?: (cellId: string, newType: "code" | "markdown") => void;
  onCopyCells?: (cellIds: string[]) => void;
  onCutCells?: (cellIds: string[]) => void;
  onPasteCells?: (afterCellId?: string) => void;
  onDuplicateCell?: (cellId: string) => void;
  onUpdateTags?: (cellId: string, tags: string[]) => void;
  onToggleCollapse?: (cellId: string) => void;
  onClearOutput?: (cellId: string) => void;
  onClearAllOutputs?: () => void;
  // Execution control
  onRunAllCells?: () => void;
  onRunAllAbove?: (cellId: string) => void;
  onRunAllBelow?: (cellId: string) => void;
  onExecuteAndInsert?: (cellId: string) => void;
  onInterrupt?: () => void;
  onRestart?: () => void;
  // Navigation
  onSelectCell?: (cellId: string) => void;
  onGoToCell?: (position: "first" | "last" | number) => void;
  // Find/Replace
  onFind?: (query: string, options?: { caseSensitive?: boolean; regex?: boolean; wholeWord?: boolean }) => Array<{ cellId: string; line: number; match: string }>;
  onReplace?: (query: string, replacement: string, options?: { caseSensitive?: boolean; regex?: boolean; wholeWord?: boolean; all?: boolean }) => number;
  // View modes
  onTogglePanel?: (panel: "variables" | "packages" | "logs" | "toc" | "findReplace") => void;
  onToggleZenMode?: () => void;
  onTogglePresentationMode?: () => void;
  onToggleSplitView?: () => void;
  // Undo/Redo
  onUndo?: () => void;
  onRedo?: () => void;
  canUndo?: () => boolean;
  canRedo?: () => boolean;
  // Notebook operations
  onSave?: () => void;
  onExport?: (format: "ipynb" | "python" | "html") => void;
  onCreateCheckpoint?: (name?: string) => void;
  onRestoreCheckpoint?: (checkpointId: string) => void;
  getVariables?: () => Promise<Array<{ name: string; type: string; value: string }>>;
  getCompletions?: (code: string, cursorPos: number) => Promise<string[]>;
  getCheckpoints?: () => Array<{ id: string; name: string; timestamp: Date }>;
  getCellClipboard?: () => Cell[];
  // Logs
  getExecutionLogs?: () => Array<{ id: string; timestamp: Date; type: string; message: string; cellId?: string }>;
  onClearLogs?: () => void;
  // State getters
  getCells: () => Cell[];
  getSelectedCellId: () => string | null;
  getSelectedCellIds?: () => string[];
}

export interface ActionResult {
  success: boolean;
  tool: AIToolType;
  message: string;
  data?: unknown;
}

/**
 * Parse AI response to extract message and actions
 * Handles both plain text and JSON responses
 */
export function parseAIResponse(content: string): AIResponseWithActions {
  // Try to parse as JSON first
  try {
    // Check if content contains JSON
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[1]);
      return {
        message: parsed.message || content.replace(jsonMatch[0], "").trim(),
        actions: parsed.actions,
      };
    }

    // Try direct JSON parse
    if (content.trim().startsWith("{")) {
      const parsed = JSON.parse(content);
      if (parsed.message || parsed.actions) {
        return {
          message: parsed.message || "",
          actions: parsed.actions,
        };
      }
    }
  } catch {
    // Not JSON, return as plain message
  }

  return { message: content };
}

/**
 * Get parameter value with flexible naming (like Flutter)
 * Supports: source/code, cell_id/cellId, etc.
 */
function getParam<T>(params: Record<string, unknown>, ...keys: string[]): T | undefined {
  for (const key of keys) {
    if (params[key] !== undefined) {
      return params[key] as T;
    }
  }
  return undefined;
}

/**
 * Process a single AI action
 */
export async function processAction(
  action: AIAction,
  callbacks: AIToolsCallbacks
): Promise<ActionResult> {
  const { tool, params } = action;

  try {
    switch (tool) {
      case "createCell": {
        const source = getParam<string>(params, "source", "code", "content");
        const position = getParam<number>(params, "position", "index");

        if (!source) {
          return {
            success: false,
            tool,
            message: "Missing source/code parameter for createCell",
          };
        }

        callbacks.onCreateCell(source, position ?? null);
        return {
          success: true,
          tool,
          message: `Created new cell${position !== undefined ? ` at position ${position}` : ""}`,
        };
      }

      case "editCell": {
        const cellId = getParam<string>(params, "cell_id", "cellId", "id");
        const source = getParam<string>(params, "source", "code", "content");

        if (!cellId) {
          return {
            success: false,
            tool,
            message: "Missing cell_id parameter for editCell",
          };
        }

        if (!source) {
          return {
            success: false,
            tool,
            message: "Missing source/code parameter for editCell",
          };
        }

        // Verify cell exists
        const cells = callbacks.getCells();
        const cellExists = cells.some((c) => c.id === cellId);
        if (!cellExists) {
          return {
            success: false,
            tool,
            message: `Cell with id ${cellId} not found`,
          };
        }

        callbacks.onEditCell(cellId, source);
        return {
          success: true,
          tool,
          message: `Updated cell ${cellId}`,
        };
      }

      case "deleteCell": {
        const cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          return {
            success: false,
            tool,
            message: "Missing cell_id parameter for deleteCell",
          };
        }

        // Verify cell exists
        const cells = callbacks.getCells();
        const cellExists = cells.some((c) => c.id === cellId);
        if (!cellExists) {
          return {
            success: false,
            tool,
            message: `Cell with id ${cellId} not found`,
          };
        }

        callbacks.onDeleteCell(cellId);
        return {
          success: true,
          tool,
          message: `Deleted cell ${cellId}`,
        };
      }

      case "executeCode": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        // If no cellId provided, use selected cell
        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return {
            success: false,
            tool,
            message: "No cell specified and no cell selected",
          };
        }

        // Verify cell exists and is code type
        const cells = callbacks.getCells();
        const cell = cells.find((c) => c.id === cellId);
        if (!cell) {
          return {
            success: false,
            tool,
            message: `Cell with id ${cellId} not found`,
          };
        }

        if (cell.cellType !== "code") {
          return {
            success: false,
            tool,
            message: `Cell ${cellId} is not a code cell`,
          };
        }

        callbacks.onExecuteCell(cellId);
        return {
          success: true,
          tool,
          message: `Executing cell ${cellId}`,
        };
      }

      case "readCellOutput": {
        const cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          return {
            success: false,
            tool,
            message: "Missing cell_id parameter for readCellOutput",
          };
        }

        const cells = callbacks.getCells();
        const cell = cells.find((c) => c.id === cellId);
        if (!cell) {
          return {
            success: false,
            tool,
            message: `Cell with id ${cellId} not found`,
          };
        }

        const outputText = cell.outputs
          .map((o) => formatOutput(o))
          .join("\n");

        return {
          success: true,
          tool,
          message: `Output of cell ${cellId}`,
          data: {
            cellId,
            outputs: cell.outputs,
            outputText: outputText || "(no output)",
          },
        };
      }

      case "listCells": {
        const cells = callbacks.getCells();
        const selectedId = callbacks.getSelectedCellId();

        const cellList = cells.map((cell, index) => ({
          index,
          id: cell.id,
          type: cell.cellType,
          preview: cell.source.split("\n")[0].slice(0, 50),
          lineCount: cell.source.split("\n").length,
          isSelected: cell.id === selectedId,
          hasOutput: cell.outputs.length > 0,
          executionCount: cell.executionCount,
        }));

        return {
          success: true,
          tool,
          message: `Found ${cells.length} cells`,
          data: {
            count: cells.length,
            selectedCellId: selectedId,
            cells: cellList,
          },
        };
      }

      case "splitCell": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");
        const parts = getParam<string[]>(params, "parts", "chunks", "sections");
        const splitAt = getParam<number[]>(params, "split_at", "splitAt", "lines");

        // If no cellId provided, use selected cell
        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return {
            success: false,
            tool,
            message: "No cell specified and no cell selected",
          };
        }

        const cells = callbacks.getCells();
        const cell = cells.find((c) => c.id === cellId);
        if (!cell) {
          return {
            success: false,
            tool,
            message: `Cell with id ${cellId} not found`,
          };
        }

        if (cell.cellType !== "code") {
          return {
            success: false,
            tool,
            message: `Cell ${cellId} is not a code cell`,
          };
        }

        // If parts are provided directly, create cells with those parts
        if (parts && parts.length > 1) {
          const cellIndex = cells.findIndex((c) => c.id === cellId);

          // Delete original cell and create new ones
          callbacks.onDeleteCell(cellId);

          // Create cells in reverse order so positions work correctly
          for (let i = parts.length - 1; i >= 0; i--) {
            callbacks.onCreateCell(parts[i].trim(), cellIndex);
          }

          return {
            success: true,
            tool,
            message: `Split cell into ${parts.length} cells`,
            data: { originalCellId: cellId, newCellCount: parts.length },
          };
        }

        // If split_at line numbers are provided
        if (splitAt && splitAt.length > 0) {
          const lines = cell.source.split("\n");
          const newParts: string[] = [];
          let lastIndex = 0;

          for (const lineNum of splitAt.sort((a, b) => a - b)) {
            if (lineNum > 0 && lineNum < lines.length) {
              newParts.push(lines.slice(lastIndex, lineNum).join("\n"));
              lastIndex = lineNum;
            }
          }
          newParts.push(lines.slice(lastIndex).join("\n"));

          const cellIndex = cells.findIndex((c) => c.id === cellId);
          callbacks.onDeleteCell(cellId);

          for (let i = newParts.length - 1; i >= 0; i--) {
            if (newParts[i].trim()) {
              callbacks.onCreateCell(newParts[i], cellIndex);
            }
          }

          return {
            success: true,
            tool,
            message: `Split cell at lines ${splitAt.join(", ")} into ${newParts.filter(p => p.trim()).length} cells`,
            data: { originalCellId: cellId, splitLines: splitAt },
          };
        }

        return {
          success: false,
          tool,
          message: "Provide either 'parts' array with code chunks or 'split_at' with line numbers",
        };
      }

      case "mergeCells": {
        const cellIds = getParam<string[]>(params, "cell_ids", "cellIds", "ids");

        if (!cellIds || cellIds.length < 2) {
          return {
            success: false,
            tool,
            message: "Need at least 2 cell IDs to merge",
          };
        }

        const cells = callbacks.getCells();
        const cellsToMerge: Cell[] = [];

        // Validate all cells exist and are code cells
        for (const id of cellIds) {
          const cell = cells.find((c) => c.id === id);
          if (!cell) {
            return {
              success: false,
              tool,
              message: `Cell with id ${id} not found`,
            };
          }
          if (cell.cellType !== "code") {
            return {
              success: false,
              tool,
              message: `Cell ${id} is not a code cell`,
            };
          }
          cellsToMerge.push(cell);
        }

        // Get position of first cell
        const firstCellIndex = cells.findIndex((c) => c.id === cellIds[0]);

        // Merge content
        const mergedContent = cellsToMerge.map((c) => c.source).join("\n\n");

        // Delete all cells
        for (const id of cellIds) {
          callbacks.onDeleteCell(id);
        }

        // Create merged cell at first position
        callbacks.onCreateCell(mergedContent, firstCellIndex);

        return {
          success: true,
          tool,
          message: `Merged ${cellIds.length} cells into one`,
          data: { mergedCellIds: cellIds },
        };
      }

      case "moveCell": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");
        const direction = getParam<string>(params, "direction", "dir");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!direction || (direction !== "up" && direction !== "down")) {
          return { success: false, tool, message: "Direction must be 'up' or 'down'" };
        }

        if (!callbacks.onMoveCell) {
          return { success: false, tool, message: "Move cell not supported" };
        }

        callbacks.onMoveCell(cellId, direction as "up" | "down");
        return { success: true, tool, message: `Moved cell ${direction}` };
      }

      case "changeCellType": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");
        const newType = getParam<string>(params, "type", "cell_type", "newType");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!newType || (newType !== "code" && newType !== "markdown")) {
          return { success: false, tool, message: "Type must be 'code' or 'markdown'" };
        }

        if (!callbacks.onChangeCellType) {
          return { success: false, tool, message: "Change cell type not supported" };
        }

        callbacks.onChangeCellType(cellId, newType as "code" | "markdown");
        return { success: true, tool, message: `Changed cell to ${newType}` };
      }

      case "copyCells": {
        const cellIds = getParam<string[]>(params, "cell_ids", "cellIds", "ids");

        if (!cellIds || cellIds.length === 0) {
          // Copy selected cell
          const selectedId = callbacks.getSelectedCellId();
          if (!selectedId) {
            return { success: false, tool, message: "No cells to copy" };
          }
          if (callbacks.onCopyCells) {
            callbacks.onCopyCells([selectedId]);
          }
          return { success: true, tool, message: "Copied 1 cell" };
        }

        if (!callbacks.onCopyCells) {
          return { success: false, tool, message: "Copy cells not supported" };
        }

        callbacks.onCopyCells(cellIds);
        return { success: true, tool, message: `Copied ${cellIds.length} cells` };
      }

      case "pasteCells": {
        const afterCellId = getParam<string>(params, "after_cell_id", "afterCellId", "after");

        if (!callbacks.onPasteCells) {
          return { success: false, tool, message: "Paste cells not supported" };
        }

        callbacks.onPasteCells(afterCellId);
        return { success: true, tool, message: "Pasted cells" };
      }

      case "updateTags": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");
        const tags = getParam<string[]>(params, "tags", "labels");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!tags) {
          return { success: false, tool, message: "Tags array required" };
        }

        if (!callbacks.onUpdateTags) {
          return { success: false, tool, message: "Update tags not supported" };
        }

        callbacks.onUpdateTags(cellId, tags);
        return { success: true, tool, message: `Updated tags: ${tags.join(", ")}` };
      }

      case "toggleCollapse": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onToggleCollapse) {
          return { success: false, tool, message: "Toggle collapse not supported" };
        }

        callbacks.onToggleCollapse(cellId);
        return { success: true, tool, message: "Toggled cell collapse" };
      }

      case "clearOutput": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onClearOutput) {
          return { success: false, tool, message: "Clear output not supported" };
        }

        callbacks.onClearOutput(cellId);
        return { success: true, tool, message: "Cleared cell output" };
      }

      case "clearAllOutputs": {
        if (!callbacks.onClearAllOutputs) {
          return { success: false, tool, message: "Clear all outputs not supported" };
        }

        callbacks.onClearAllOutputs();
        return { success: true, tool, message: "Cleared all outputs" };
      }

      // ==================== EXECUTION CONTROL ====================

      case "runAllCells": {
        if (!callbacks.onRunAllCells) {
          return { success: false, tool, message: "Run all cells not supported" };
        }

        callbacks.onRunAllCells();
        return { success: true, tool, message: "Running all cells" };
      }

      case "runAllAbove": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onRunAllAbove) {
          return { success: false, tool, message: "Run all above not supported" };
        }

        callbacks.onRunAllAbove(cellId);
        return { success: true, tool, message: "Running all cells above" };
      }

      case "runAllBelow": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onRunAllBelow) {
          return { success: false, tool, message: "Run all below not supported" };
        }

        callbacks.onRunAllBelow(cellId);
        return { success: true, tool, message: "Running all cells below" };
      }

      case "interruptExecution": {
        if (!callbacks.onInterrupt) {
          return { success: false, tool, message: "Interrupt not supported" };
        }

        callbacks.onInterrupt();
        return { success: true, tool, message: "Interrupted execution" };
      }

      case "restartKernel": {
        if (!callbacks.onRestart) {
          return { success: false, tool, message: "Restart not supported" };
        }

        callbacks.onRestart();
        return { success: true, tool, message: "Restarting kernel" };
      }

      // ==================== NOTEBOOK OPERATIONS ====================

      case "saveNotebook": {
        if (!callbacks.onSave) {
          return { success: false, tool, message: "Save not supported" };
        }

        callbacks.onSave();
        return { success: true, tool, message: "Notebook saved" };
      }

      case "exportNotebook": {
        const format = getParam<string>(params, "format", "type") || "ipynb";

        if (!["ipynb", "python", "html"].includes(format)) {
          return { success: false, tool, message: "Format must be 'ipynb', 'python', or 'html'" };
        }

        if (!callbacks.onExport) {
          return { success: false, tool, message: "Export not supported" };
        }

        callbacks.onExport(format as "ipynb" | "python" | "html");
        return { success: true, tool, message: `Exported as ${format}` };
      }

      case "createCheckpoint": {
        const name = getParam<string>(params, "name", "label");

        if (!callbacks.onCreateCheckpoint) {
          return { success: false, tool, message: "Checkpoints not supported" };
        }

        callbacks.onCreateCheckpoint(name);
        return { success: true, tool, message: `Checkpoint created${name ? `: ${name}` : ""}` };
      }

      case "restoreCheckpoint": {
        const checkpointId = getParam<string>(params, "checkpoint_id", "checkpointId", "id");

        if (!checkpointId) {
          return { success: false, tool, message: "Checkpoint ID required" };
        }

        if (!callbacks.onRestoreCheckpoint) {
          return { success: false, tool, message: "Checkpoints not supported" };
        }

        callbacks.onRestoreCheckpoint(checkpointId);
        return { success: true, tool, message: "Checkpoint restored" };
      }

      case "getVariables": {
        if (!callbacks.getVariables) {
          return { success: false, tool, message: "Variable inspection not supported" };
        }

        const variables = await callbacks.getVariables();
        return {
          success: true,
          tool,
          message: `Found ${variables.length} variables`,
          data: { variables },
        };
      }

      case "getCompletions": {
        const code = getParam<string>(params, "code", "text", "source");
        const cursorPos = getParam<number>(params, "cursor_pos", "cursorPos", "position");

        if (!code) {
          return { success: false, tool, message: "Code required for completions" };
        }

        if (!callbacks.getCompletions) {
          return { success: false, tool, message: "Completions not supported" };
        }

        const completions = await callbacks.getCompletions(code, cursorPos ?? code.length);
        return {
          success: true,
          tool,
          message: `Found ${completions.length} completions`,
          data: { completions },
        };
      }

      // ==================== CELL EXTRA OPERATIONS ====================

      case "cutCells": {
        const cellIds = getParam<string[]>(params, "cell_ids", "cellIds", "ids");

        if (!callbacks.onCutCells) {
          return { success: false, tool, message: "Cut cells not supported" };
        }

        if (!cellIds || cellIds.length === 0) {
          const selectedId = callbacks.getSelectedCellId();
          if (!selectedId) {
            return { success: false, tool, message: "No cells to cut" };
          }
          callbacks.onCutCells([selectedId]);
          return { success: true, tool, message: "Cut 1 cell" };
        }

        callbacks.onCutCells(cellIds);
        return { success: true, tool, message: `Cut ${cellIds.length} cells` };
      }

      case "duplicateCell": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onDuplicateCell) {
          // Fallback: copy cell content and create new cell
          const cells = callbacks.getCells();
          const cell = cells.find((c) => c.id === cellId);
          if (!cell) {
            return { success: false, tool, message: `Cell ${cellId} not found` };
          }
          const cellIndex = cells.findIndex((c) => c.id === cellId);
          callbacks.onCreateCell(cell.source, cellIndex + 1);
          return { success: true, tool, message: "Duplicated cell" };
        }

        callbacks.onDuplicateCell(cellId);
        return { success: true, tool, message: "Duplicated cell" };
      }

      case "executeAndInsert": {
        let cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          cellId = callbacks.getSelectedCellId() ?? undefined;
        }

        if (!cellId) {
          return { success: false, tool, message: "No cell specified" };
        }

        if (!callbacks.onExecuteAndInsert) {
          // Fallback: execute then create cell
          callbacks.onExecuteCell(cellId);
          const cells = callbacks.getCells();
          const cellIndex = cells.findIndex((c) => c.id === cellId);
          callbacks.onCreateCell("", cellIndex + 1);
          return { success: true, tool, message: "Executed and inserted new cell" };
        }

        callbacks.onExecuteAndInsert(cellId);
        return { success: true, tool, message: "Executed and inserted new cell" };
      }

      // ==================== NAVIGATION ====================

      case "selectCell": {
        const cellId = getParam<string>(params, "cell_id", "cellId", "id");

        if (!cellId) {
          return { success: false, tool, message: "Cell ID required" };
        }

        if (!callbacks.onSelectCell) {
          return { success: false, tool, message: "Select cell not supported" };
        }

        const cells = callbacks.getCells();
        if (!cells.find((c) => c.id === cellId)) {
          return { success: false, tool, message: `Cell ${cellId} not found` };
        }

        callbacks.onSelectCell(cellId);
        return { success: true, tool, message: `Selected cell ${cellId}` };
      }

      case "goToCell": {
        const position = getParam<string | number>(params, "position", "pos", "target");

        if (!callbacks.onGoToCell) {
          return { success: false, tool, message: "Navigation not supported" };
        }

        if (position === "first" || position === "last") {
          callbacks.onGoToCell(position);
          return { success: true, tool, message: `Navigated to ${position} cell` };
        }

        if (typeof position === "number") {
          callbacks.onGoToCell(position);
          return { success: true, tool, message: `Navigated to cell ${position}` };
        }

        return { success: false, tool, message: "Position must be 'first', 'last', or a number" };
      }

      // ==================== FIND/REPLACE ====================

      case "findInNotebook": {
        const query = getParam<string>(params, "query", "search", "text", "find");
        const caseSensitive = getParam<boolean>(params, "case_sensitive", "caseSensitive");
        const regex = getParam<boolean>(params, "regex", "useRegex");
        const wholeWord = getParam<boolean>(params, "whole_word", "wholeWord");

        if (!query) {
          return { success: false, tool, message: "Search query required" };
        }

        // If callback not provided, do search manually
        if (callbacks.onFind) {
          const matches = callbacks.onFind(query, { caseSensitive, regex, wholeWord });
          return {
            success: true,
            tool,
            message: `Found ${matches.length} matches`,
            data: { matches, query },
          };
        }

        // Manual search fallback
        const cells = callbacks.getCells();
        const matches: Array<{ cellId: string; cellIndex: number; line: number; match: string }> = [];

        cells.forEach((cell, cellIndex) => {
          const lines = cell.source.split("\n");
          lines.forEach((line, lineIndex) => {
            let searchRegex: RegExp;
            try {
              if (regex) {
                searchRegex = new RegExp(query, caseSensitive ? "g" : "gi");
              } else {
                const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
                const pattern = wholeWord ? `\\b${escaped}\\b` : escaped;
                searchRegex = new RegExp(pattern, caseSensitive ? "g" : "gi");
              }
            } catch {
              return;
            }

            if (searchRegex.test(line)) {
              matches.push({
                cellId: cell.id,
                cellIndex,
                line: lineIndex + 1,
                match: line.trim().slice(0, 100),
              });
            }
          });
        });

        return {
          success: true,
          tool,
          message: `Found ${matches.length} matches for "${query}"`,
          data: { matches, query },
        };
      }

      case "replaceInNotebook": {
        const query = getParam<string>(params, "query", "search", "find");
        const replacement = getParam<string>(params, "replacement", "replace", "with");
        const caseSensitive = getParam<boolean>(params, "case_sensitive", "caseSensitive");
        const regex = getParam<boolean>(params, "regex", "useRegex");
        const wholeWord = getParam<boolean>(params, "whole_word", "wholeWord");
        const all = getParam<boolean>(params, "all", "replaceAll") ?? true;

        if (!query) {
          return { success: false, tool, message: "Search query required" };
        }

        if (replacement === undefined) {
          return { success: false, tool, message: "Replacement text required" };
        }

        if (callbacks.onReplace) {
          const count = callbacks.onReplace(query, replacement, { caseSensitive, regex, wholeWord, all });
          return { success: true, tool, message: `Replaced ${count} occurrences` };
        }

        // Manual replace fallback
        const cells = callbacks.getCells();
        let totalReplacements = 0;

        cells.forEach((cell) => {
          let searchRegex: RegExp;
          try {
            if (regex) {
              searchRegex = new RegExp(query, caseSensitive ? "g" : "gi");
            } else {
              const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
              const pattern = wholeWord ? `\\b${escaped}\\b` : escaped;
              searchRegex = new RegExp(pattern, caseSensitive ? "g" : "gi");
            }
          } catch {
            return;
          }

          const matches = cell.source.match(searchRegex);
          if (matches && matches.length > 0) {
            const newSource = cell.source.replace(searchRegex, replacement);
            if (newSource !== cell.source) {
              callbacks.onEditCell(cell.id, newSource);
              totalReplacements += matches.length;
            }
          }
        });

        return {
          success: true,
          tool,
          message: `Replaced ${totalReplacements} occurrences`,
          data: { replacements: totalReplacements, query, replacement },
        };
      }

      // ==================== VIEW MODES ====================

      case "togglePanel": {
        const panel = getParam<string>(params, "panel", "name");

        if (!panel) {
          return { success: false, tool, message: "Panel name required" };
        }

        const validPanels = ["variables", "packages", "logs", "toc", "findReplace"];
        if (!validPanels.includes(panel)) {
          return { success: false, tool, message: `Panel must be one of: ${validPanels.join(", ")}` };
        }

        if (!callbacks.onTogglePanel) {
          return { success: false, tool, message: "Toggle panel not supported" };
        }

        callbacks.onTogglePanel(panel as "variables" | "packages" | "logs" | "toc" | "findReplace");
        return { success: true, tool, message: `Toggled ${panel} panel` };
      }

      case "toggleZenMode": {
        if (!callbacks.onToggleZenMode) {
          return { success: false, tool, message: "Zen mode not supported" };
        }

        callbacks.onToggleZenMode();
        return { success: true, tool, message: "Toggled zen mode" };
      }

      case "togglePresentationMode": {
        if (!callbacks.onTogglePresentationMode) {
          return { success: false, tool, message: "Presentation mode not supported" };
        }

        callbacks.onTogglePresentationMode();
        return { success: true, tool, message: "Toggled presentation mode" };
      }

      case "toggleSplitView": {
        if (!callbacks.onToggleSplitView) {
          return { success: false, tool, message: "Split view not supported" };
        }

        callbacks.onToggleSplitView();
        return { success: true, tool, message: "Toggled split view" };
      }

      // ==================== UNDO/REDO ====================

      case "undo": {
        if (!callbacks.onUndo) {
          return { success: false, tool, message: "Undo not supported" };
        }

        if (callbacks.canUndo && !callbacks.canUndo()) {
          return { success: false, tool, message: "Nothing to undo" };
        }

        callbacks.onUndo();
        return { success: true, tool, message: "Undone" };
      }

      case "redo": {
        if (!callbacks.onRedo) {
          return { success: false, tool, message: "Redo not supported" };
        }

        if (callbacks.canRedo && !callbacks.canRedo()) {
          return { success: false, tool, message: "Nothing to redo" };
        }

        callbacks.onRedo();
        return { success: true, tool, message: "Redone" };
      }

      // ==================== FILE TOOLS ====================

      case "readFile": {
        const path = getParam<string>(params, "path", "file_path", "filepath");

        if (!path) {
          return {
            success: false,
            tool,
            message: "Missing path parameter for readFile",
          };
        }

        const fileContent = await fileService.read(path);
        return {
          success: true,
          tool,
          message: `Read file: ${path}`,
          data: {
            path: fileContent.path,
            content: fileContent.content,
            encoding: fileContent.encoding,
          },
        };
      }

      case "writeFile": {
        const path = getParam<string>(params, "path", "file_path", "filepath");
        const content = getParam<string>(params, "content", "data", "text");

        if (!path) {
          return {
            success: false,
            tool,
            message: "Missing path parameter for writeFile",
          };
        }

        if (content === undefined) {
          return {
            success: false,
            tool,
            message: "Missing content parameter for writeFile",
          };
        }

        await fileService.write(path, content);
        return {
          success: true,
          tool,
          message: `Written file: ${path}`,
          data: { path },
        };
      }

      case "listDirectory": {
        const path = getParam<string>(params, "path", "directory", "dir") || "";

        const files = await fileService.list(path);
        const fileList = files.map((f) => ({
          name: f.name,
          path: f.path,
          isDirectory: f.isDirectory,
          size: f.size,
          modifiedAt: f.modifiedAt.toISOString(),
        }));

        return {
          success: true,
          tool,
          message: `Listed ${files.length} items in ${path || "/"}`,
          data: {
            path: path || "/",
            count: files.length,
            files: fileList,
          },
        };
      }

      case "deleteFile": {
        const path = getParam<string>(params, "path", "file_path", "filepath");

        if (!path) {
          return {
            success: false,
            tool,
            message: "Missing path parameter for deleteFile",
          };
        }

        await fileService.delete(path);
        return {
          success: true,
          tool,
          message: `Deleted: ${path}`,
          data: { path },
        };
      }

      case "createDirectory": {
        const path = getParam<string>(params, "path", "directory", "dir");

        if (!path) {
          return {
            success: false,
            tool,
            message: "Missing path parameter for createDirectory",
          };
        }

        await fileService.createDirectory(path);
        return {
          success: true,
          tool,
          message: `Created directory: ${path}`,
          data: { path },
        };
      }

      // ==================== PACKAGE MANAGER TOOLS ====================

      case "listPackages": {
        const packages = await pipService.listPackages();
        const packageList = packages.map((p) => ({
          name: p.name,
          version: p.version,
          location: p.location,
        }));

        return {
          success: true,
          tool,
          message: `Found ${packages.length} installed packages`,
          data: {
            count: packages.length,
            packages: packageList,
          },
        };
      }

      case "installPackage": {
        const packageName = getParam<string>(params, "package", "name", "pkg");
        const version = getParam<string>(params, "version", "ver");
        const upgrade = getParam<boolean>(params, "upgrade", "update") ?? false;

        if (!packageName) {
          return {
            success: false,
            tool,
            message: "Missing package name for installPackage",
          };
        }

        const result = await pipService.installPackage(packageName, version, upgrade);
        return {
          success: result.success,
          tool,
          message: result.message,
          data: {
            package: result.package,
            version: result.version,
            duration: result.duration,
          },
        };
      }

      case "uninstallPackage": {
        const packageName = getParam<string>(params, "package", "name", "pkg");

        if (!packageName) {
          return {
            success: false,
            tool,
            message: "Missing package name for uninstallPackage",
          };
        }

        const result = await pipService.uninstallPackage(packageName);
        return {
          success: result.success,
          tool,
          message: result.message,
          data: { package: result.package },
        };
      }

      case "searchPackages": {
        const query = getParam<string>(params, "query", "search", "q");
        const limit = getParam<number>(params, "limit", "max") ?? 10;

        if (!query) {
          return {
            success: false,
            tool,
            message: "Missing query for searchPackages",
          };
        }

        const results = await pipService.searchPackages(query, limit);
        return {
          success: true,
          tool,
          message: `Found ${results.length} packages matching "${query}"`,
          data: {
            query,
            count: results.length,
            packages: results,
          },
        };
      }

      case "upgradePackage": {
        const packageName = getParam<string>(params, "package", "name", "pkg");

        if (!packageName) {
          return {
            success: false,
            tool,
            message: "Missing package name for upgradePackage",
          };
        }

        const result = await pipService.upgradePackage(packageName);
        return {
          success: result.success,
          tool,
          message: result.message,
          data: {
            package: result.package,
            version: result.version,
          },
        };
      }

      case "getPackageInfo": {
        const packageName = getParam<string>(params, "package", "name", "pkg");

        if (!packageName) {
          return {
            success: false,
            tool,
            message: "Missing package name for getPackageInfo",
          };
        }

        try {
          const info = await pipService.getPackageInfo(packageName);
          return {
            success: true,
            tool,
            message: `Package info for ${packageName}`,
            data: {
              name: info.name,
              version: info.version,
              summary: info.summary,
              author: info.author,
              license: info.license,
              homePage: info.homePage,
            },
          };
        } catch {
          return {
            success: false,
            tool,
            message: `Package ${packageName} not found`,
          };
        }
      }

      case "checkOutdatedPackages": {
        const outdated = await pipService.checkOutdated();
        return {
          success: true,
          tool,
          message: `Found ${outdated.length} outdated packages`,
          data: {
            count: outdated.length,
            packages: outdated,
          },
        };
      }

      // ==================== EXECUTION LOGS ====================

      case "getExecutionLogs": {
        if (!callbacks.getExecutionLogs) {
          return { success: false, tool, message: "Execution logs not available" };
        }

        const logs = callbacks.getExecutionLogs();
        const limit = getParam<number>(params, "limit", "max") ?? 50;
        const typeFilter = getParam<string>(params, "type", "filter");

        let filteredLogs = logs;
        if (typeFilter) {
          filteredLogs = logs.filter((l) => l.type === typeFilter);
        }

        // Get last N logs
        const recentLogs = filteredLogs.slice(-limit).map((log) => ({
          id: log.id,
          timestamp: log.timestamp.toISOString(),
          type: log.type,
          message: log.message,
          cellId: log.cellId,
        }));

        return {
          success: true,
          tool,
          message: `Found ${recentLogs.length} execution logs`,
          data: {
            count: recentLogs.length,
            totalCount: logs.length,
            logs: recentLogs,
          },
        };
      }

      case "clearExecutionLogs": {
        if (!callbacks.onClearLogs) {
          return { success: false, tool, message: "Clear logs not supported" };
        }

        callbacks.onClearLogs();
        return {
          success: true,
          tool,
          message: "Execution logs cleared",
        };
      }

      // ==================== GPU TOOLS ====================

      case "getGpuStatus": {
        try {
          const status = await gpuService.getStatus();

          const gpuSummary = status.gpus.map((gpu) => ({
            index: gpu.index,
            name: gpu.name,
            temperature: gpu.temperature,
            utilizationPercent: gpu.utilizationGpu,
            memoryUsedMB: gpu.memoryUsed,
            memoryTotalMB: gpu.memoryTotal,
            memoryUsedGB: (gpu.memoryUsed / 1024).toFixed(1),
            memoryTotalGB: (gpu.memoryTotal / 1024).toFixed(1),
            memoryPercent: gpu.memoryTotal > 0
              ? ((gpu.memoryUsed / gpu.memoryTotal) * 100).toFixed(1)
              : "0",
            powerDrawW: gpu.powerDraw,
            powerLimitW: gpu.powerLimit,
            driverVersion: gpu.driverVersion,
            cudaVersion: gpu.cudaVersion,
          }));

          const processesSummary = status.processes.map((p) => ({
            pid: p.pid,
            name: p.name,
            gpuIndex: p.gpuIndex,
            memoryMB: p.memoryMb,
          }));

          return {
            success: true,
            tool,
            message: `Found ${status.gpuCount} GPU(s)`,
            data: {
              gpuCount: status.gpuCount,
              hasGpu: status.hasGpu,
              cudaAvailable: status.cudaAvailable,
              totalMemoryUsedMB: status.totalMemoryUsed,
              totalMemoryTotalMB: status.totalMemoryTotal,
              averageUtilization: status.averageUtilization.toFixed(1),
              gpus: gpuSummary,
              processes: processesSummary,
            },
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to get GPU status: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      // ==================== CONTAINER NOTEBOOK TOOLS ====================

      case "createContainer": {
        try {
          const name = params.name as string | undefined;
          const image = (params.image as string) || "python";
          const gpu = (params.gpu as boolean) || false;
          const memoryLimit = (params.memory_limit as string) || "2g";

          const container = await dockerService.createNotebookContainer({
            name,
            image,
            gpu,
            memory_limit: memoryLimit,
          });

          return {
            success: true,
            tool,
            message: `Created container "${container.name}" (${container.container_id})`,
            data: container,
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to create container: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "listContainers": {
        try {
          const containers = await dockerService.listNotebookContainers();
          return {
            success: true,
            tool,
            message: `Found ${containers.length} notebook container(s)`,
            data: containers.map(c => ({
              id: c.container_id,
              name: c.name,
              image: c.image,
              status: c.status,
              executionCount: c.execution_count,
            })),
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to list containers: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "executeInContainer": {
        try {
          const containerId = (params.container_id || params.containerId) as string;
          const code = (params.code || params.source) as string;
          const timeout = (params.timeout as number) || 300;

          if (!containerId || !code) {
            return {
              success: false,
              tool,
              message: "container_id and code are required",
            };
          }

          const result = await dockerService.executeInContainer(containerId, code, timeout);

          // Format outputs for readability
          const outputText = result.outputs
            .map(o => {
              if (o.output_type === "stream" && o.text) return o.text;
              if (o.output_type === "error") return `Error: ${o.ename}: ${o.evalue}`;
              return "";
            })
            .filter(Boolean)
            .join("");

          return {
            success: result.status === "success",
            tool,
            message: result.status === "success"
              ? `Executed in ${result.duration_ms}ms`
              : `Execution failed: ${result.error}`,
            data: {
              execution_id: result.execution_id,
              status: result.status,
              duration_ms: result.duration_ms,
              output: outputText,
              outputs: result.outputs,
            },
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to execute: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "stopContainer": {
        try {
          const containerId = (params.container_id || params.containerId) as string;
          if (!containerId) {
            return { success: false, tool, message: "container_id is required" };
          }

          await dockerService.stopNotebookContainer(containerId);
          return {
            success: true,
            tool,
            message: `Container ${containerId} stopped`,
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to stop container: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "removeContainer": {
        try {
          const containerId = (params.container_id || params.containerId) as string;
          const force = (params.force as boolean) || false;

          if (!containerId) {
            return { success: false, tool, message: "container_id is required" };
          }

          await dockerService.removeNotebookContainer(containerId, force);
          return {
            success: true,
            tool,
            message: `Container ${containerId} removed`,
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to remove container: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "installContainerPackage": {
        try {
          const containerId = (params.container_id || params.containerId) as string;
          const packageName = (params.package || params.packageName) as string;
          const upgrade = (params.upgrade as boolean) || false;

          if (!containerId || !packageName) {
            return { success: false, tool, message: "container_id and package are required" };
          }

          const result = await dockerService.installContainerPackage(containerId, packageName, upgrade);
          return {
            success: result.success,
            tool,
            message: result.success
              ? `Installed ${packageName} in container`
              : `Failed to install: ${result.output}`,
            data: result,
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to install package: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "listContainerPackages": {
        try {
          const containerId = (params.container_id || params.containerId) as string;
          if (!containerId) {
            return { success: false, tool, message: "container_id is required" };
          }

          const result = await dockerService.listContainerPackages(containerId);
          return {
            success: true,
            tool,
            message: `Found ${result.packages.length} packages`,
            data: result.packages,
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to list packages: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      case "quickExecuteInContainer": {
        try {
          const code = (params.code || params.source) as string;
          const image = (params.image as string) || "python";
          const packages = params.packages as string[] | undefined;
          const timeout = (params.timeout as number) || 300;
          const cleanup = params.cleanup !== false; // Default true

          if (!code) {
            return { success: false, tool, message: "code is required" };
          }

          const result = await dockerService.quickExecuteInContainer({
            code,
            image,
            packages,
            timeout,
            cleanup,
          });

          const outputText = result.outputs
            .map(o => {
              if (o.output_type === "stream" && o.text) return o.text;
              if (o.output_type === "error") return `Error: ${o.ename}: ${o.evalue}`;
              return "";
            })
            .filter(Boolean)
            .join("");

          return {
            success: result.status === "success",
            tool,
            message: result.status === "success"
              ? `Quick execution completed in ${result.duration_ms}ms${result.cleaned_up ? " (container cleaned up)" : ""}`
              : `Execution failed: ${result.error}`,
            data: {
              execution_id: result.execution_id,
              status: result.status,
              duration_ms: result.duration_ms,
              output: outputText,
              cleaned_up: result.cleaned_up,
            },
          };
        } catch (error) {
          return {
            success: false,
            tool,
            message: `Failed to execute: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
      }

      default:
        return {
          success: false,
          tool,
          message: `Unknown tool: ${tool}`,
        };
    }
  } catch (error) {
    return {
      success: false,
      tool,
      message: `Error executing ${tool}: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}

/**
 * Process multiple AI actions
 */
export async function processActions(
  actions: AIAction[],
  callbacks: AIToolsCallbacks
): Promise<ActionResult[]> {
  const results: ActionResult[] = [];
  for (const action of actions) {
    const result = await processAction(action, callbacks);
    results.push(result);
  }
  return results;
}

/**
 * Format cell output to text
 */
function formatOutput(output: CellOutput): string {
  if (output.text) {
    return output.text;
  }
  if (output.ename && output.evalue) {
    return `${output.ename}: ${output.evalue}`;
  }
  if (output.data) {
    return JSON.stringify(output.data);
  }
  return "";
}

/**
 * Build notebook context for AI requests
 */
export function buildNotebookContext(
  notebookId: string,
  cells: Cell[],
  selectedCellId: string | null
): {
  notebookId: string;
  cells: Array<{
    id: string;
    type: string;
    source: string;
    outputs?: string[];
  }>;
  selectedCellId?: string;
} {
  return {
    notebookId,
    cells: cells.map((cell) => ({
      id: cell.id,
      type: cell.cellType,
      source: cell.source,
      outputs: cell.outputs.map((o) => formatOutput(o)).filter(Boolean),
    })),
    selectedCellId: selectedCellId ?? undefined,
  };
}

/**
 * System prompt for notebook AI assistant with tool capabilities
 */
export const NOTEBOOK_SYSTEM_PROMPT = `You are an AI assistant integrated into GPU Notebook, a Python notebook environment with GPU acceleration.

AVAILABLE TOOLS:

CELL OPERATIONS:
- createCell { "source": "code", "position": index } - Create a new cell with code at position
- editCell { "cell_id": "id", "source": "new code" } - Replace cell content
- deleteCell { "cell_id": "id" } - Delete a cell
- splitCell { "cell_id": "id", "parts": ["complete code 1", "complete code 2", ...] }
  IMPORTANT: When splitting code, each part MUST contain the COMPLETE code for that cell.
  Do NOT truncate or abbreviate. Include ALL imports, functions, and code in each part.
  Example: To split into 3 cells, provide 3 complete code strings in the "parts" array.
- mergeCells { "cell_ids": ["id1", "id2"] } - Merge multiple cells into one
- moveCell { "cell_id": "id", "direction": "up"|"down" }
- changeCellType { "cell_id": "id", "type": "code"|"markdown" }
- copyCells { "cell_ids": ["id1", "id2"] }
- cutCells { "cell_ids": ["id1", "id2"] }
- pasteCells { "after_cell_id": "id" }
- duplicateCell { "cell_id": "id" }
- updateTags { "cell_id": "id", "tags": ["tag1", "tag2"] }
- toggleCollapse { "cell_id": "id" }
- clearOutput { "cell_id": "id" }
- clearAllOutputs {}
- listCells {}
- readCellOutput { "cell_id": "id" }

EXECUTION CONTROL:
- executeCode { "cell_id": "id" }
- executeAndInsert { "cell_id": "id" } - run and create new cell below
- runAllCells {}
- runAllAbove { "cell_id": "id" }
- runAllBelow { "cell_id": "id" }
- interruptExecution {}
- restartKernel {}

NAVIGATION:
- selectCell { "cell_id": "id" }
- goToCell { "position": "first"|"last"|index }

FIND/REPLACE:
- findInNotebook { "query": "text", "case_sensitive": bool, "regex": bool, "whole_word": bool }
- replaceInNotebook { "query": "find", "replacement": "replace", "all": true }

VIEW MODES:
- togglePanel { "panel": "variables"|"packages"|"logs"|"toc"|"findReplace" }
- toggleZenMode {}
- togglePresentationMode {}
- toggleSplitView {}

UNDO/REDO:
- undo {}
- redo {}

NOTEBOOK OPERATIONS:
- saveNotebook {}
- exportNotebook { "format": "ipynb"|"python"|"html" }
- createCheckpoint { "name": "optional name" }
- restoreCheckpoint { "checkpoint_id": "id" }
- getVariables {}
- getCompletions { "code": "partial code", "cursor_pos": position }

FILE OPERATIONS:
- readFile: Read file { "path": "file.py" }
- writeFile: Write file { "path": "file.py", "content": "..." }
- listDirectory: List files { "path": "folder" }
- deleteFile: Delete file { "path": "file.py" }
- createDirectory: Create folder { "path": "new_folder" }

PACKAGE MANAGER (pip):
- listPackages {} - List all installed packages
- installPackage { "package": "numpy", "version": "1.24.0" } - Install a package
- uninstallPackage { "package": "numpy" } - Uninstall a package
- searchPackages { "query": "machine learning", "limit": 10 } - Search PyPI
- upgradePackage { "package": "numpy" } - Upgrade to latest version
- getPackageInfo { "package": "numpy" } - Get package details
- checkOutdatedPackages {} - List packages with updates available

VARIABLES (from getVariables tool):
- getVariables {} - Get all defined variables in kernel with their types and values

EXECUTION LOGS:
- getExecutionLogs { "limit": 50, "type": "error" } - Get execution logs (types: stdout, stderr, error, info, success, warning)
- clearExecutionLogs {} - Clear all execution logs

GPU MONITORING:
- getGpuStatus {} - Get full GPU status including:
  - GPU count, names, temperatures
  - Utilization percentage for each GPU
  - VRAM usage (used/total in MB and GB)
  - Power draw and limits
  - CUDA/driver versions
  - Running processes with memory usage per GPU

CONTAINER NOTEBOOKS (Docker-based isolated execution):
- createContainer { "name": "my-env", "image": "python", "gpu": false, "memory_limit": "2g" }
  Images: python (slim), python-ml (numpy/pandas/scipy), datascience, tensorflow, pytorch, python-gpu (CUDA)
- listContainers {} - List all notebook containers with status
- executeInContainer { "container_id": "abc123", "code": "print('hello')", "timeout": 300 }
  Execute Python code in isolated container, returns output
- stopContainer { "container_id": "abc123" }
- removeContainer { "container_id": "abc123", "force": false }
- installContainerPackage { "container_id": "abc123", "package": "requests", "upgrade": false }
- listContainerPackages { "container_id": "abc123" }
- quickExecuteInContainer { "code": "print('test')", "image": "python", "packages": ["requests"], "cleanup": true }
  Creates ephemeral container, runs code, optionally cleans up. Great for one-off isolated execution.

To use tools, include JSON in your response:
\`\`\`json
{
  "message": "Description of what I'm doing",
  "actions": [
    { "tool": "toolName", "params": { ... } }
  ]
}
\`\`\`

IMPORTANT GUIDELINES:
1. When splitting code into multiple cells, use the splitCell tool with COMPLETE code in each "parts" element.
   Each part should be fully functional code - do NOT use ellipsis (...) or comments like "# rest of code".
   Include the ENTIRE code for each cell, even if it seems repetitive.

2. When creating multiple cells, use multiple createCell actions, one for each cell.

3. For large code blocks, you can use multiple actions:
   \`\`\`json
   {
     "message": "Creating 3 cells with your code",
     "actions": [
       { "tool": "createCell", "params": { "source": "# Cell 1: Imports\\nimport torch\\nimport numpy as np", "position": 0 } },
       { "tool": "createCell", "params": { "source": "# Cell 2: Model definition\\nclass MyModel(nn.Module):\\n    def __init__(self):\\n        super().__init__()\\n        self.fc = nn.Linear(10, 5)", "position": 1 } },
       { "tool": "createCell", "params": { "source": "# Cell 3: Training\\nmodel = MyModel()\\nprint(model)", "position": 2 } }
     ]
   }
   \`\`\`

Be helpful and provide complete, working code. Never truncate or abbreviate code.`;

export default {
  parseAIResponse,
  processAction,
  processActions,
  buildNotebookContext,
  NOTEBOOK_SYSTEM_PROMPT,
};
