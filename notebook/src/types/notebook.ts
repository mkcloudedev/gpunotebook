export type CellType = "code" | "markdown";

export interface CellOutput {
  outputType: string;
  text?: string;
  data?: Record<string, unknown>;
  ename?: string;
  evalue?: string;
  traceback?: string[];
}

// Predefined tag types for cells
export type CellTagType =
  | "important"     // Important cell
  | "todo"          // TODO item
  | "skip"          // Skip during run all
  | "slow"          // Slow execution warning
  | "test"          // Test cell
  | "setup"         // Setup/initialization cell
  | "cleanup"       // Cleanup cell
  | "visualization" // Chart/plot cell
  | "dataLoad"      // Data loading cell
  | "model"         // ML model cell
  | "custom";       // Custom tag

// Tag for a cell
export interface CellTag {
  label: string;
  type: CellTagType;
  color: string; // Hex color string
}

// Predefined tags with default colors
export const PREDEFINED_TAGS: Record<Exclude<CellTagType, "custom">, CellTag> = {
  important: { label: "Important", type: "important", color: "#EF4444" },
  todo: { label: "TODO", type: "todo", color: "#F59E0B" },
  skip: { label: "Skip", type: "skip", color: "#6B7280" },
  slow: { label: "Slow", type: "slow", color: "#EC4899" },
  test: { label: "Test", type: "test", color: "#8B5CF6" },
  setup: { label: "Setup", type: "setup", color: "#10B981" },
  cleanup: { label: "Cleanup", type: "cleanup", color: "#14B8A6" },
  visualization: { label: "Visualization", type: "visualization", color: "#6366F1" },
  dataLoad: { label: "Data Load", type: "dataLoad", color: "#0EA5E9" },
  model: { label: "Model", type: "model", color: "#F97316" },
};

// Color options for custom tags
export const TAG_COLOR_OPTIONS = [
  "#3B82F6", // Blue
  "#EF4444", // Red
  "#F59E0B", // Amber
  "#10B981", // Green
  "#8B5CF6", // Purple
  "#EC4899", // Pink
  "#0EA5E9", // Sky
  "#F97316", // Orange
  "#14B8A6", // Teal
  "#6366F1", // Indigo
];

// Metadata for a cell
export interface CellMetadata {
  hidden: boolean;
  editable: boolean;
  deletable: boolean;
  name?: string;
  createdAt?: string;
  lastModified?: string;
  custom?: Record<string, unknown>;
}

// Default metadata
export const DEFAULT_CELL_METADATA: CellMetadata = {
  hidden: false,
  editable: true,
  deletable: true,
};

export interface Cell {
  id: string;
  cellType: CellType;
  source: string;
  outputs: CellOutput[];
  executionCount?: number;
  isExecuting?: boolean;
  tags?: CellTag[];
  isCollapsed?: boolean;
  executionStartTime?: number; // timestamp when execution started
  executionDuration?: number; // duration in ms
  metadata?: CellMetadata;
}

export interface Notebook {
  id: string;
  name: string;
  cells: Cell[];
  kernelId?: string;
  createdAt: Date;
  updatedAt: Date;
}

export type KernelStatus = "idle" | "busy" | "starting" | "restarting" | "error" | "dead";

export interface Kernel {
  id: string;
  name: string;
  status: KernelStatus;
  notebookId?: string;
}

export type AIProvider = "claude" | "openai" | "gemini";

export type MessageRole = "user" | "assistant" | "system";

export interface AIMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: Date;
}

export type AIToolType = "createCell" | "editCell" | "deleteCell" | "executeCode" | "readCellOutput" | "listCells";

export interface AIAction {
  tool: AIToolType;
  params: Record<string, unknown>;
}
