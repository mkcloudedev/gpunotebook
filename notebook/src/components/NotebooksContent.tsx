import { useState, useEffect, useCallback, useRef } from "react";
import { useNavigate } from "react-router-dom";
import {
  FileCode,
  Plus,
  Upload,
  FileText,
  Brain,
  BarChart3,
  Image,
  Clock,
  MoreVertical,
  Play,
  Copy,
  Trash2,
  ChevronRight,
  Loader2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Notebook } from "@/types/notebook";
import { notebookService } from "@/services/notebookService";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "./ui/dialog";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { NotebooksBreadcrumb } from "./NotebooksBreadcrumb";

export const NotebooksContent = () => {
  const navigate = useNavigate();
  const [notebooks, setNotebooks] = useState<Notebook[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showTemplateDialog, setShowTemplateDialog] = useState(false);
  const [newNotebookName, setNewNotebookName] = useState("Untitled Notebook");
  const fileInputRef = useRef<HTMLInputElement>(null);

  const loadNotebooks = useCallback(async () => {
    setIsLoading(true);
    try {
      const list = await notebookService.list();
      // Convert service notebook to local Notebook type
      setNotebooks(list.map(n => ({
        id: n.id,
        name: n.name,
        cells: n.cells.map(c => ({
          id: c.id,
          cellType: c.cellType,
          source: c.source,
          outputs: c.outputs,
          executionCount: c.executionCount,
        })),
        createdAt: n.createdAt,
        updatedAt: n.updatedAt,
      })));
    } catch (error) {
      console.error("Failed to load notebooks:", error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadNotebooks();
  }, [loadNotebooks]);

  const formatDate = (date: Date) => {
    const diff = Date.now() - date.getTime();
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(hours / 24);

    if (hours < 1) return "Just now";
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;
    return `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
  };

  // Generate a default notebook name with date/time
  const generateNotebookName = () => {
    const now = new Date();
    const month = now.getMonth() + 1;
    const day = now.getDate();
    const hours = now.getHours();
    const minutes = now.getMinutes().toString().padStart(2, "0");
    return `Notebook ${month}/${day} ${hours}:${minutes}`;
  };

  const handleCreateNotebook = async () => {
    try {
      const name = newNotebookName || generateNotebookName();
      const newNotebook = await notebookService.create({ name });
      setShowCreateDialog(false);
      setNewNotebookName("Untitled Notebook");
      navigate(`/notebook/${newNotebook.id}`);
    } catch (error) {
      console.error("Failed to create notebook:", error);
    }
  };

  // Create notebook directly with auto-generated name
  const handleQuickCreateNotebook = async () => {
    try {
      const name = generateNotebookName();
      const newNotebook = await notebookService.create({ name });
      navigate(`/notebook/${newNotebook.id}`);
    } catch (error) {
      console.error("Failed to create notebook:", error);
    }
  };

  const handleOpenNotebook = (id: string) => {
    navigate(`/notebook/${id}`);
  };

  const handleDuplicateNotebook = async (notebook: Notebook) => {
    try {
      const duplicate = await notebookService.duplicate(notebook.id, `${notebook.name} (Copy)`);
      setNotebooks([{
        id: duplicate.id,
        name: duplicate.name,
        cells: duplicate.cells.map(c => ({
          id: c.id,
          cellType: c.cellType,
          source: c.source,
          outputs: c.outputs,
          executionCount: c.executionCount,
        })),
        createdAt: duplicate.createdAt,
        updatedAt: duplicate.updatedAt,
      }, ...notebooks]);
    } catch (error) {
      console.error("Failed to duplicate notebook:", error);
    }
  };

  const handleDeleteNotebook = async (id: string) => {
    try {
      await notebookService.delete(id);
      setNotebooks(notebooks.filter((n) => n.id !== id));
    } catch (error) {
      console.error("Failed to delete notebook:", error);
    }
  };

  // Import .ipynb file
  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Only accept .ipynb files
    if (!file.name.endsWith('.ipynb')) {
      alert('Please select a Jupyter notebook (.ipynb) file');
      return;
    }

    try {
      const imported = await notebookService.importFromFile(file);
      // Navigate to the imported notebook
      navigate(`/notebook/${imported.id}`);
    } catch (error) {
      console.error("Failed to import notebook:", error);
      alert('Failed to import notebook. Please check the file format.');
    }

    // Reset input so the same file can be selected again
    event.target.value = '';
  };

  const activeKernelCount = 2; // Mock
  const [searchQuery, setSearchQuery] = useState("");

  const filteredNotebooks = notebooks.filter((n) =>
    n.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Breadcrumb */}
      <NotebooksBreadcrumb
        onSearch={setSearchQuery}
        onImport={handleImportClick}
        onNew={handleQuickCreateNotebook}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex-1 overflow-auto p-4">
        {isLoading ? (
          <div className="flex h-full items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
          </div>
        ) : notebooks.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-lg border border-border bg-card p-12">
            <FileCode className="h-12 w-12 text-muted-foreground" />
            <p className="mt-4 font-medium text-foreground">No notebooks found</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Create your first notebook to get started
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredNotebooks.map((notebook) => (
              <NotebookRow
                key={notebook.id}
                notebook={notebook}
                formatDate={formatDate}
                onOpen={() => handleOpenNotebook(notebook.id)}
                onDuplicate={() => handleDuplicateNotebook(notebook)}
                onDelete={() => handleDeleteNotebook(notebook.id)}
              />
            ))}
          </div>
        )}
        </div>

      {/* Side Panel */}
      <div className="flex w-72 flex-col border-l border-border bg-card">
        {/* Header */}
        <div className="border-b border-border p-3">
          <span className="font-semibold text-foreground">Quick Actions</span>
        </div>

        {/* Actions */}
        <div className="flex-1 space-y-2 overflow-auto p-3">
          <QuickActionButton
            icon={<Plus className="h-4 w-4" />}
            iconColor="text-primary"
            title="New Notebook"
            description="Create a blank notebook"
            onClick={handleQuickCreateNotebook}
          />
          <QuickActionButton
            icon={<Upload className="h-4 w-4" />}
            iconColor="text-success"
            title="Import .ipynb"
            description="Upload Jupyter notebook"
            onClick={handleImportClick}
          />
          <QuickActionButton
            icon={<FileCode className="h-4 w-4" />}
            iconColor="text-purple-500"
            title="From Template"
            description="ML, Data Science, etc."
            onClick={() => setShowTemplateDialog(true)}
          />
        </div>

        {/* Kernel Status */}
        <div className="border-t border-border p-3">
          <div className="rounded-lg border-2 border-primary/30 bg-primary/5 p-3">
            <p className="text-sm font-medium text-foreground">Kernel Status</p>
            <div className="mt-2 flex items-center justify-between">
              <span className="text-xs text-muted-foreground">Python 3.11</span>
              <div className="flex items-center gap-1">
                <span
                  className={cn(
                    "h-2 w-2 rounded-full",
                    activeKernelCount > 0 ? "bg-success" : "bg-muted-foreground"
                  )}
                />
                <span
                  className={cn(
                    "text-xs",
                    activeKernelCount > 0 ? "text-success" : "text-muted-foreground"
                  )}
                >
                  {activeKernelCount > 0 ? "Ready" : "No kernels"}
                </span>
              </div>
            </div>
            <div className="mt-1 flex items-center justify-between">
              <span className="text-xs text-muted-foreground">Active</span>
              <span className="text-xs text-foreground">{activeKernelCount} kernels</span>
            </div>
          </div>
        </div>
      </div>

      {/* Create Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New Notebook</DialogTitle>
            <DialogDescription>Enter a name for your new notebook</DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <Input
              value={newNotebookName}
              onChange={(e) => setNewNotebookName(e.target.value)}
              placeholder="Notebook name"
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Enter" && newNotebookName) {
                  handleCreateNotebook();
                }
              }}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCreateDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateNotebook} disabled={!newNotebookName}>
              Create
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Template Dialog */}
      <Dialog open={showTemplateDialog} onOpenChange={setShowTemplateDialog}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Create from Template</DialogTitle>
            <DialogDescription>Choose a template to start with</DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-4">
            <TemplateOption
              icon={<Brain className="h-5 w-5" />}
              color="text-purple-500"
              bgColor="bg-purple-500/20"
              title="Machine Learning"
              description="PyTorch, model training, evaluation"
              onClick={() => {
                setShowTemplateDialog(false);
                navigate("/notebook/new-ml");
              }}
            />
            <TemplateOption
              icon={<BarChart3 className="h-5 w-5" />}
              color="text-blue-500"
              bgColor="bg-blue-500/20"
              title="Data Analysis"
              description="Pandas, NumPy, visualization"
              onClick={() => {
                setShowTemplateDialog(false);
                navigate("/notebook/new-data");
              }}
            />
            <TemplateOption
              icon={<Image className="h-5 w-5" />}
              color="text-green-500"
              bgColor="bg-green-500/20"
              title="Computer Vision"
              description="Image processing, OpenCV, PIL"
              onClick={() => {
                setShowTemplateDialog(false);
                navigate("/notebook/new-cv");
              }}
            />
            <TemplateOption
              icon={<FileText className="h-5 w-5" />}
              color="text-yellow-500"
              bgColor="bg-yellow-500/20"
              title="Blank Notebook"
              description="Start from scratch"
              onClick={() => {
                setShowTemplateDialog(false);
                handleCreateNotebook();
              }}
            />
          </div>
        </DialogContent>
      </Dialog>

      {/* Hidden file input for importing .ipynb files */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".ipynb"
        onChange={handleFileChange}
        className="hidden"
      />
      </div>
    </div>
  );
};

interface NotebookRowProps {
  notebook: Notebook;
  formatDate: (date: Date) => string;
  onOpen: () => void;
  onDuplicate: () => void;
  onDelete: () => void;
}

const NotebookRow = ({
  notebook,
  formatDate,
  onOpen,
  onDuplicate,
  onDelete,
}: NotebookRowProps) => {
  return (
    <div
      onClick={onOpen}
      className="group flex cursor-pointer items-center gap-3 rounded-lg border border-border bg-card p-4 transition-colors hover:border-primary/30"
    >
      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-500/20">
        <FileCode className="h-5 w-5 text-blue-500" />
      </div>
      <div className="flex-1">
        <p className="font-medium text-foreground">{notebook.name}</p>
        <div className="mt-1 flex items-center gap-3 text-xs text-muted-foreground">
          <div className="flex items-center gap-1">
            <span className="h-2 w-2 rounded-full bg-success" />
            <span>Python</span>
          </div>
          <span>{notebook.cells.length} cells</span>
          <div className="flex items-center gap-1">
            <Clock className="h-3 w-3" />
            <span>{formatDate(notebook.updatedAt)}</span>
          </div>
        </div>
      </div>
      <DropdownMenu>
        <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
          <button className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground">
            <MoreVertical className="h-4 w-4" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onOpen(); }}>
            <Play className="mr-2 h-4 w-4" />
            Run All
          </DropdownMenuItem>
          <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onDuplicate(); }}>
            <Copy className="mr-2 h-4 w-4" />
            Duplicate
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={(e) => { e.stopPropagation(); onDelete(); }}
            className="text-destructive focus:text-destructive"
          >
            <Trash2 className="mr-2 h-4 w-4" />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};

interface QuickActionButtonProps {
  icon: React.ReactNode;
  iconColor: string;
  title: string;
  description: string;
  onClick: () => void;
}

const QuickActionButton = ({
  icon,
  iconColor,
  title,
  description,
  onClick,
}: QuickActionButtonProps) => {
  return (
    <button
      onClick={onClick}
      className="flex w-full flex-col items-start gap-1 rounded-lg border border-border p-3 text-left transition-colors hover:border-primary/30 hover:bg-primary/5"
    >
      <div className="flex items-center gap-2">
        <span className={iconColor}>{icon}</span>
        <span className="text-sm font-medium text-foreground">{title}</span>
      </div>
      <span className="text-xs text-muted-foreground">{description}</span>
    </button>
  );
};

interface TemplateOptionProps {
  icon: React.ReactNode;
  color: string;
  bgColor: string;
  title: string;
  description: string;
  onClick: () => void;
}

const TemplateOption = ({
  icon,
  color,
  bgColor,
  title,
  description,
  onClick,
}: TemplateOptionProps) => {
  return (
    <button
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-lg border border-border bg-background p-3 transition-colors hover:border-primary/30 hover:bg-muted"
    >
      <div className={cn("flex h-10 w-10 items-center justify-center rounded-lg", bgColor)}>
        <span className={color}>{icon}</span>
      </div>
      <div className="flex-1 text-left">
        <p className="font-medium text-foreground">{title}</p>
        <p className="text-xs text-muted-foreground">{description}</p>
      </div>
      <ChevronRight className="h-4 w-4 text-muted-foreground" />
    </button>
  );
};
