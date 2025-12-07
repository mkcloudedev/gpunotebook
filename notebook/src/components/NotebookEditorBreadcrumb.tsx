import {
  Home,
  FileCode,
  Play,
  Square,
  RotateCcw,
  Plus,
  FileText,
  Eraser,
  Save,
  Variable,
  Package,
  Columns,
  Keyboard,
  Upload,
  Download,
  ChevronDown,
  List,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "./ui/tooltip";
import { KernelSelector } from "./notebook/KernelSelector";

interface NotebookEditorBreadcrumbProps {
  notebookName: string;
  kernelStatus?: "idle" | "busy" | "starting" | "restarting" | "error" | "disconnected";
  kernelName?: string;
  onRunAll?: () => void;
  onStop?: () => void;
  onRestart?: () => void;
  onAddCode?: () => void;
  onAddMarkdown?: () => void;
  onClearOutputs?: () => void;
  onSave?: () => void;
  onToggleVariables?: () => void;
  onTogglePackages?: () => void;
  onToggleSplitView?: () => void;
  onToggleTableOfContents?: () => void;
  onShowShortcuts?: () => void;
  onUpload?: () => void;
  onExportPython?: () => void;
  onExportIpynb?: () => void;
  onExportHtml?: () => void;
  onSelectKernel?: (kernelName: string) => void;
  onDisconnectKernel?: () => void;
  showVariables?: boolean;
  showPackages?: boolean;
  showSplitView?: boolean;
  showTableOfContents?: boolean;
  isSplitViewActive?: boolean;
}

export const NotebookEditorBreadcrumb = ({
  notebookName,
  kernelStatus = "idle",
  kernelName = "Python 3",
  onRunAll,
  onStop,
  onRestart,
  onAddCode,
  onAddMarkdown,
  onClearOutputs,
  onSave,
  onToggleVariables,
  onTogglePackages,
  onToggleSplitView,
  onToggleTableOfContents,
  onShowShortcuts,
  onUpload,
  onExportPython,
  onExportIpynb,
  onExportHtml,
  onSelectKernel,
  onDisconnectKernel,
  showVariables = false,
  showPackages = false,
  showSplitView = false,
  showTableOfContents = false,
  isSplitViewActive = false,
}: NotebookEditorBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Notebooks", href: "/notebooks", icon: <FileCode className="h-4 w-4" /> },
    { label: notebookName },
  ];

  const actions = (
    <div className="flex items-center gap-1">
      {/* Kernel Selector */}
      <KernelSelector
        currentKernel={kernelName}
        kernelStatus={kernelStatus}
        onSelectKernel={onSelectKernel}
        onRestart={onRestart}
        onInterrupt={onStop}
        onDisconnect={onDisconnectKernel}
        compact
      />
    </div>
  );

  return (
    <div className="flex flex-col border-b border-border">
      <Breadcrumb items={breadcrumbItems} actions={actions} className="border-b-0" />

      {/* Compact Toolbar */}
      <div className="flex items-center gap-1 border-t border-border bg-card px-3 py-1">
        <ToolbarButton icon={<Play className="h-3.5 w-3.5" />} tooltip="Run All" onClick={onRunAll} />
        <ToolbarButton icon={<Square className="h-3.5 w-3.5" />} tooltip="Stop" onClick={onStop} />
        <ToolbarButton icon={<RotateCcw className="h-3.5 w-3.5" />} tooltip="Restart" onClick={onRestart} />

        <ToolbarDivider />

        <ToolbarButton icon={<Plus className="h-3.5 w-3.5" />} tooltip="Code" onClick={onAddCode} />
        <ToolbarButton icon={<FileText className="h-3.5 w-3.5" />} tooltip="Markdown" onClick={onAddMarkdown} />

        <ToolbarDivider />

        <ToolbarButton icon={<Eraser className="h-3.5 w-3.5" />} tooltip="Clear Outputs" onClick={onClearOutputs} />
        <ToolbarButton icon={<Save className="h-3.5 w-3.5" />} tooltip="Save" onClick={onSave} />

        <ToolbarDivider />

        <ToolbarButton
          icon={<List className="h-3.5 w-3.5" />}
          tooltip="Table of Contents"
          onClick={onToggleTableOfContents}
          isActive={showTableOfContents}
        />
        <ToolbarButton
          icon={<Variable className="h-3.5 w-3.5" />}
          tooltip="Variables"
          onClick={onToggleVariables}
          isActive={showVariables}
        />
        <ToolbarButton
          icon={<Package className="h-3.5 w-3.5" />}
          tooltip="Packages"
          onClick={onTogglePackages}
          isActive={showPackages}
        />
        <ToolbarButton
          icon={<Columns className="h-3.5 w-3.5" />}
          tooltip="Split View"
          onClick={onToggleSplitView}
          isActive={isSplitViewActive || showSplitView}
        />
        <ToolbarButton
          icon={<Keyboard className="h-3.5 w-3.5" />}
          tooltip="Keyboard Shortcuts (Ctrl+/)"
          onClick={onShowShortcuts}
        />

        <ToolbarDivider />

        <ToolbarButton icon={<Upload className="h-3.5 w-3.5" />} tooltip="Upload File" onClick={onUpload} />

        {/* Export Menu */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="flex items-center gap-1 rounded px-2 py-1 text-xs text-muted-foreground hover:bg-muted hover:text-foreground">
              <Download className="h-3.5 w-3.5" />
              Export
              <ChevronDown className="h-3 w-3" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start">
            <DropdownMenuItem onClick={onExportPython}>
              <FileCode className="mr-2 h-4 w-4 text-primary" />
              Export as Python (.py)
            </DropdownMenuItem>
            <DropdownMenuItem onClick={onExportIpynb}>
              <FileText className="mr-2 h-4 w-4 text-yellow-500" />
              Export as Jupyter (.ipynb)
            </DropdownMenuItem>
            <DropdownMenuItem onClick={onExportHtml}>
              <FileText className="mr-2 h-4 w-4 text-success" />
              Export as HTML (.html)
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        <div className="flex-1" />
      </div>
    </div>
  );
};

interface ToolbarButtonProps {
  icon: React.ReactNode;
  tooltip: string;
  onClick?: () => void;
  isActive?: boolean;
}

const ToolbarButton = ({ icon, tooltip, onClick, isActive }: ToolbarButtonProps) => {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          onClick={onClick}
          className={cn(
            "rounded p-1.5 transition-colors",
            isActive
              ? "bg-primary/20 text-primary"
              : "text-muted-foreground hover:bg-muted hover:text-foreground"
          )}
        >
          {icon}
        </button>
      </TooltipTrigger>
      <TooltipContent>
        <p>{tooltip}</p>
      </TooltipContent>
    </Tooltip>
  );
};

const ToolbarDivider = () => (
  <div className="mx-1 h-3.5 w-px bg-border" />
);
