// AI Tools Handler - Process AI actions like Flutter implementation
// Handles: createCell, editCell, deleteCell, executeCode, readCellOutput, listCells

import { Cell, CellOutput } from "@/types/notebook";

export type AIToolType =
  | "createCell"
  | "editCell"
  | "deleteCell"
  | "executeCode"
  | "readCellOutput"
  | "listCells";

export interface AIAction {
  tool: AIToolType;
  params: Record<string, unknown>;
}

export interface AIResponseWithActions {
  message: string;
  actions?: AIAction[];
}

export interface AIToolsCallbacks {
  onCreateCell: (code: string, position?: number | null) => void;
  onEditCell: (cellId: string, code: string) => void;
  onDeleteCell: (cellId: string) => void;
  onExecuteCell: (cellId: string) => void;
  getCells: () => Cell[];
  getSelectedCellId: () => string | null;
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
export function processAction(
  action: AIAction,
  callbacks: AIToolsCallbacks
): ActionResult {
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
export function processActions(
  actions: AIAction[],
  callbacks: AIToolsCallbacks
): ActionResult[] {
  return actions.map((action) => processAction(action, callbacks));
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
export const NOTEBOOK_SYSTEM_PROMPT = `You are an AI assistant integrated into GPU Notebook, a Python notebook environment with GPU acceleration. You can help users with:

1. Writing and explaining Python code
2. Debugging errors
3. Optimizing performance
4. Creating documentation

You have access to the following tools that you can use by including them in your response:

TOOLS:
- createCell: Create a new code cell
  Parameters: { "source": "code content", "position": optional_index }

- editCell: Edit an existing cell
  Parameters: { "cell_id": "id", "source": "new code" }

- deleteCell: Delete a cell
  Parameters: { "cell_id": "id" }

- executeCode: Execute a cell
  Parameters: { "cell_id": "id" } (optional, uses selected cell if not provided)

- readCellOutput: Read the output of a cell
  Parameters: { "cell_id": "id" }

- listCells: List all cells in the notebook
  Parameters: {}

To use tools, include a JSON block in your response like this:
\`\`\`json
{
  "message": "Your response message here",
  "actions": [
    { "tool": "createCell", "params": { "source": "print('Hello')" } }
  ]
}
\`\`\`

Always explain what you're doing before executing actions. Be helpful and concise.`;

export default {
  parseAIResponse,
  processAction,
  processActions,
  buildNotebookContext,
  NOTEBOOK_SYSTEM_PROMPT,
};
