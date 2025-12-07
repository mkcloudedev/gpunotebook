import { useState, useEffect, useCallback, useRef } from "react";
import {
  Folder,
  FolderOpen,
  Database,
  FileCode,
  FileImage,
  FileText,
  File,
  Upload,
  FolderPlus,
  HardDrive,
  Clock,
  MoreVertical,
  Eye,
  Download,
  Trash2,
  ChevronRight,
  RefreshCw,
  Sparkles,
  Globe,
  FilePlus,
  Filter,
  Split,
  Combine,
  FileDown,
  Loader2,
  AlertCircle,
  Check,
  X,
  Bot,
  Chrome,
  Settings2,
  Table,
  Link2,
  Play,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
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
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "./ui/dialog";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";
import { Checkbox } from "./ui/checkbox";
import { ScrollArea } from "./ui/scroll-area";
import { FilesBreadcrumb } from "./FilesBreadcrumb";
import { fileService, FileInfo, StorageInfo as ServiceStorageInfo } from "@/services/fileService";
import { datasetService, DatasetInfo as ServiceDatasetInfo, ScraperAgent, UserAgent } from "@/services/datasetService";

type FileType = "directory" | "python" | "image" | "data" | "other";

interface FileItem {
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
  modifiedAt: Date;
}

interface DatasetInfo {
  name: string;
  path: string;
  size: number;
  format: string;
  modifiedAt: Date;
}

interface StorageInfo {
  usedGB: number;
  totalGB: number;
  percent: number;
}

// Mock data for fallback
const mockFiles: FileItem[] = [
  { name: "models", path: "models", isDirectory: true, size: 0, modifiedAt: new Date() },
  { name: "data", path: "data", isDirectory: true, size: 0, modifiedAt: new Date() },
  { name: "train.py", path: "train.py", isDirectory: false, size: 4521, modifiedAt: new Date() },
  { name: "inference.py", path: "inference.py", isDirectory: false, size: 2841, modifiedAt: new Date() },
  { name: "results.png", path: "results.png", isDirectory: false, size: 145000, modifiedAt: new Date() },
  { name: "dataset.csv", path: "dataset.csv", isDirectory: false, size: 524288, modifiedAt: new Date() },
];

const mockDatasets: DatasetInfo[] = [
  { name: "train_data.csv", path: "datasets/train_data.csv", size: 1048576, format: "CSV", modifiedAt: new Date() },
  { name: "test_data.csv", path: "datasets/test_data.csv", size: 262144, format: "CSV", modifiedAt: new Date() },
  { name: "model_output.parquet", path: "datasets/model_output.parquet", size: 2097152, format: "PARQUET", modifiedAt: new Date() },
];

const mockStorage: StorageInfo = { usedGB: 2.4, totalGB: 50, percent: 4.8 };

type TabType = "files" | "datasets";

export const FilesContent = () => {
  const [activeTab, setActiveTab] = useState<TabType>("files");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [files, setFiles] = useState<FileItem[]>([]);
  const [datasets, setDatasets] = useState<DatasetInfo[]>([]);
  const [storageInfo, setStorageInfo] = useState<StorageInfo>(mockStorage);
  const [currentPath, setCurrentPath] = useState<string[]>([]);

  // Dialogs
  const [showNewFolderDialog, setShowNewFolderDialog] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");

  // Dataset dialogs (shared between DatasetsTab and DatasetsSidePanel)
  const [showDatasetSplitDialog, setShowDatasetSplitDialog] = useState(false);
  const [showDatasetMergeDialog, setShowDatasetMergeDialog] = useState(false);
  const [showDatasetExportDialog, setShowDatasetExportDialog] = useState(false);
  const [showDatasetCleanDialog, setShowDatasetCleanDialog] = useState(false);

  // Upload ref
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Convert FileInfo to FileItem
  const convertToFileItem = (info: FileInfo): FileItem => ({
    name: info.name,
    path: info.path,
    isDirectory: info.isDirectory,
    size: info.size,
    modifiedAt: info.modifiedAt,
  });

  // Load files from API
  const loadFiles = useCallback(async (path: string = "/") => {
    setIsLoading(true);
    setError(null);
    try {
      const fileList = await fileService.list(path);
      setFiles(fileList.map(convertToFileItem));

      // Load storage info
      try {
        const storage = await fileService.getStorageInfo();
        setStorageInfo({
          usedGB: storage.usedBytes / (1024 * 1024 * 1024),
          totalGB: storage.totalBytes / (1024 * 1024 * 1024),
          percent: storage.usedPercent,
        });
      } catch (e) {
        console.log("Storage info not available");
      }

      // Load datasets using datasetService
      try {
        const datasetList = await datasetService.listDatasets();
        setDatasets(datasetList.map((d) => ({
          name: d.name,
          path: d.path,
          size: d.size,
          format: d.format,
          modifiedAt: new Date(d.modified_at),
        })));
      } catch (e) {
        console.log("Dataset service not available, using file filter");
        // Fallback to filtering files by extension
        const allFiles = await fileService.list("/");
        const dataFiles = allFiles.filter((f) => {
          const ext = f.name.split(".").pop()?.toLowerCase() || "";
          return ["csv", "parquet", "json", "xlsx", "feather"].includes(ext);
        });
        setDatasets(dataFiles.map((f) => ({
          name: f.name,
          path: f.path,
          size: f.size,
          format: (f.extension || f.name.split(".").pop() || "").toUpperCase(),
          modifiedAt: f.modifiedAt,
        })));
      }
    } catch (err) {
      console.error("Error loading files:", err);
      setError(err instanceof Error ? err.message : "Failed to load files");
      // Use mock data as fallback
      setFiles(mockFiles);
      setDatasets(mockDatasets);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    loadFiles(currentPath.length > 0 ? "/" + currentPath.join("/") : "/");
  }, [currentPath, loadFiles]);

  const handleNavigate = (file: FileItem) => {
    if (file.isDirectory) {
      setCurrentPath([...currentPath, file.name]);
    }
  };

  const handleNavigateUp = (index: number) => {
    if (index === -1) {
      setCurrentPath([]);
    } else {
      setCurrentPath(currentPath.slice(0, index + 1));
    }
  };

  const handleCreateFolder = async () => {
    if (newFolderName) {
      const folderPath = currentPath.length > 0
        ? `/${currentPath.join("/")}/${newFolderName}`
        : `/${newFolderName}`;

      try {
        await fileService.createDirectory(folderPath);
        await loadFiles(currentPath.length > 0 ? "/" + currentPath.join("/") : "/");
      } catch (err) {
        console.error("Error creating folder:", err);
        // Fallback to local creation
        const newFolder: FileItem = {
          name: newFolderName,
          path: folderPath,
          isDirectory: true,
          size: 0,
          modifiedAt: new Date(),
        };
        setFiles([newFolder, ...files]);
      }

      setNewFolderName("");
      setShowNewFolderDialog(false);
    }
  };

  const handleDeleteFile = async (file: FileItem) => {
    try {
      await fileService.delete(file.path);
      setFiles(files.filter((f) => f.path !== file.path));
    } catch (err) {
      console.error("Error deleting file:", err);
      // Still remove locally
      setFiles(files.filter((f) => f.path !== file.path));
    }
  };

  const handleDownload = async (file: FileItem) => {
    try {
      const url = await fileService.getDownloadUrl(file.path);
      window.open(url, "_blank");
    } catch (err) {
      console.error("Error downloading file:", err);
    }
  };

  const handleUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const uploadedFiles = event.target.files;
    if (!uploadedFiles || uploadedFiles.length === 0) return;

    const destPath = currentPath.length > 0 ? "/" + currentPath.join("/") : "/";

    try {
      await fileService.uploadMultiple(Array.from(uploadedFiles), destPath);
      await loadFiles(destPath);
    } catch (err) {
      console.error("Error uploading files:", err);
    }

    // Reset input
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleRefresh = () => {
    loadFiles(currentPath.length > 0 ? "/" + currentPath.join("/") : "/");
  };

  const getFileType = (file: FileItem): FileType => {
    if (file.isDirectory) return "directory";
    const ext = file.name.split(".").pop()?.toLowerCase() || "";
    if (ext === "py") return "python";
    if (["png", "jpg", "jpeg", "gif", "webp"].includes(ext)) return "image";
    if (["csv", "json", "xlsx", "parquet"].includes(ext)) return "data";
    return "other";
  };

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <FilesBreadcrumb
        onNewFolder={() => setShowNewFolderDialog(true)}
        onUpload={() => {}}
        onRefresh={handleRefresh}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex flex-1 flex-col overflow-hidden">
          {/* Tabs */}
          <div className="flex border-b border-border bg-card">
            <TabButton
              active={activeTab === "files"}
              onClick={() => setActiveTab("files")}
              icon={<Folder className="h-4 w-4" />}
              label="Files"
            />
            <TabButton
              active={activeTab === "datasets"}
              onClick={() => setActiveTab("datasets")}
              icon={<Database className="h-4 w-4" />}
              label="Datasets"
              badge={datasets.length}
            />
          </div>

          {/* Content */}
          <div className="flex-1 overflow-hidden">
            {isLoading ? (
              <div className="flex h-full items-center justify-center">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
              </div>
            ) : (
              <>
                {activeTab === "files" && (
                  <FilesTab
                    files={files}
                    currentPath={currentPath}
                    onNavigate={handleNavigate}
                    onNavigateUp={handleNavigateUp}
                    onDelete={handleDeleteFile}
                    getFileType={getFileType}
                  />
                )}
                {activeTab === "datasets" && (
                  <DatasetsTab
                    datasets={datasets}
                    onRefresh={handleRefresh}
                    showSplitDialog={showDatasetSplitDialog}
                    setShowSplitDialog={setShowDatasetSplitDialog}
                    showMergeDialog={showDatasetMergeDialog}
                    setShowMergeDialog={setShowDatasetMergeDialog}
                    showExportDialog={showDatasetExportDialog}
                    setShowExportDialog={setShowDatasetExportDialog}
                    showCleanDialog={showDatasetCleanDialog}
                    setShowCleanDialog={setShowDatasetCleanDialog}
                  />
                )}
              </>
            )}
          </div>
        </div>

        {/* Side panel */}
        <div className="w-72 border-l border-border bg-card flex flex-col">
          {activeTab === "files" ? (
            <FilesSidePanel storageInfo={storageInfo} />
          ) : (
            <DatasetsSidePanel
              datasets={datasets}
              onSplit={() => setShowDatasetSplitDialog(true)}
              onMerge={() => setShowDatasetMergeDialog(true)}
              onExport={() => setShowDatasetExportDialog(true)}
              onClean={() => setShowDatasetCleanDialog(true)}
            />
          )}
        </div>
      </div>

      {/* New Folder Dialog */}
      <Dialog open={showNewFolderDialog} onOpenChange={setShowNewFolderDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New Folder</DialogTitle>
            <DialogDescription>Create a new folder in the current directory</DialogDescription>
          </DialogHeader>
          <div>
            <Label>Folder Name</Label>
            <Input
              value={newFolderName}
              onChange={(e) => setNewFolderName(e.target.value)}
              placeholder="my-folder"
              onKeyDown={(e) => e.key === "Enter" && handleCreateFolder()}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowNewFolderDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateFolder}>Create</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

// =============================================================================
// TAB BUTTON
// =============================================================================

interface TabButtonProps {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  badge?: number;
}

const TabButton = ({ active, onClick, icon, label, badge }: TabButtonProps) => (
  <button
    onClick={onClick}
    className={cn(
      "flex items-center gap-2 border-b-2 px-4 py-3 text-sm transition-colors",
      active
        ? "border-primary text-primary"
        : "border-transparent text-muted-foreground hover:text-foreground"
    )}
  >
    {icon}
    <span>{label}</span>
    {badge !== undefined && badge > 0 && (
      <span
        className={cn(
          "rounded-full px-2 py-0.5 text-xs",
          active ? "bg-primary/15 text-primary" : "bg-muted text-muted-foreground"
        )}
      >
        {badge}
      </span>
    )}
  </button>
);

// =============================================================================
// FILES TAB
// =============================================================================

interface FilesTabProps {
  files: FileItem[];
  currentPath: string[];
  onNavigate: (file: FileItem) => void;
  onNavigateUp: (index: number) => void;
  onDelete: (file: FileItem) => void;
  getFileType: (file: FileItem) => FileType;
}

const FilesTab = ({ files, currentPath, onNavigate, onNavigateUp, onDelete, getFileType }: FilesTabProps) => {
  if (files.length === 0) {
    return (
      <div className="flex h-full flex-col items-center justify-center">
        <FolderOpen className="h-16 w-16 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">No files yet</p>
        <p className="text-sm text-muted-foreground">Upload files to get started</p>
      </div>
    );
  }

  return (
    <div className="overflow-auto p-4">
      {/* Breadcrumb */}
      <div className="flex items-center gap-1 mb-4">
        <button
          onClick={() => onNavigateUp(-1)}
          className={cn(
            "flex items-center gap-1 text-sm",
            currentPath.length === 0 ? "font-medium text-foreground" : "text-muted-foreground hover:text-foreground"
          )}
        >
          <Folder className="h-4 w-4" />
          workspace
        </button>
        {currentPath.map((path, idx) => (
          <div key={idx} className="flex items-center">
            <ChevronRight className="h-4 w-4 text-muted-foreground" />
            <button
              onClick={() => onNavigateUp(idx)}
              className={cn(
                "text-sm px-1",
                idx === currentPath.length - 1 ? "font-medium text-foreground" : "text-muted-foreground hover:text-foreground"
              )}
            >
              {path}
            </button>
          </div>
        ))}
      </div>

      {/* Files grid */}
      <div className="grid gap-3 grid-cols-1 lg:grid-cols-2">
        {files.map((file) => (
          <FileRow
            key={file.path}
            file={file}
            fileType={getFileType(file)}
            onNavigate={() => onNavigate(file)}
            onDelete={() => onDelete(file)}
          />
        ))}
      </div>
    </div>
  );
};

// =============================================================================
// FILE ROW
// =============================================================================

interface FileRowProps {
  file: FileItem;
  fileType: FileType;
  onNavigate: () => void;
  onDelete: () => void;
}

const FileRow = ({ file, fileType, onNavigate, onDelete }: FileRowProps) => {
  const getFileIcon = () => {
    switch (fileType) {
      case "directory": return <Folder className="h-5 w-5" />;
      case "python": return <FileCode className="h-5 w-5" />;
      case "image": return <FileImage className="h-5 w-5" />;
      case "data": return <FileText className="h-5 w-5" />;
      default: return <File className="h-5 w-5" />;
    }
  };

  const getFileColor = () => {
    switch (fileType) {
      case "directory": return "text-yellow-500";
      case "python": return "text-blue-500";
      case "image": return "text-purple-500";
      case "data": return "text-green-500";
      default: return "text-muted-foreground";
    }
  };

  const formatSize = (bytes: number) => {
    if (bytes === 0) return "-";
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  };

  const formatDate = (date: Date) => {
    const diff = Date.now() - date.getTime();
    const hours = Math.floor(diff / 3600000);
    if (hours < 1) return "Just now";
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;
    return date.toLocaleDateString();
  };

  return (
    <div
      onClick={onNavigate}
      className="flex items-center gap-3 rounded-lg border border-border bg-card p-4 cursor-pointer transition-colors hover:border-primary/50"
    >
      <div className={cn("flex h-10 w-10 items-center justify-center rounded-lg bg-muted", getFileColor())}>
        {getFileIcon()}
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-medium truncate">{file.name}</p>
        <div className="flex items-center gap-3 text-xs text-muted-foreground mt-1">
          <span>{formatSize(file.size)}</span>
          <span className="flex items-center gap-1">
            <Clock className="h-3 w-3" />
            {formatDate(file.modifiedAt)}
          </span>
        </div>
      </div>
      <DropdownMenu>
        <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
          <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem>
            <Eye className="mr-2 h-4 w-4" />
            Preview
          </DropdownMenuItem>
          <DropdownMenuItem>
            <Download className="mr-2 h-4 w-4" />
            Download
          </DropdownMenuItem>
          <DropdownMenuItem onClick={(e) => { e.stopPropagation(); onDelete(); }} className="text-destructive">
            <Trash2 className="mr-2 h-4 w-4" />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};

// =============================================================================
// DATASETS TAB
// =============================================================================

interface DatasetsTabProps {
  datasets: DatasetInfo[];
  onRefresh: () => void;
  showSplitDialog: boolean;
  setShowSplitDialog: (show: boolean) => void;
  showMergeDialog: boolean;
  setShowMergeDialog: (show: boolean) => void;
  showExportDialog: boolean;
  setShowExportDialog: (show: boolean) => void;
  showCleanDialog: boolean;
  setShowCleanDialog: (show: boolean) => void;
}

const DatasetsTab = ({
  datasets,
  onRefresh,
  showSplitDialog,
  setShowSplitDialog,
  showMergeDialog,
  setShowMergeDialog,
  showExportDialog,
  setShowExportDialog,
  showCleanDialog,
  setShowCleanDialog
}: DatasetsTabProps) => {
  const [selectedDataset, setSelectedDataset] = useState<DatasetInfo | null>(null);
  const [showScrapeDialog, setShowScrapeDialog] = useState(false);
  const [showPreviewDialog, setShowPreviewDialog] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [previewData, setPreviewData] = useState<{ columns: string[]; rows: Record<string, unknown>[] } | null>(null);

  // Upload ref
  const uploadInputRef = useRef<HTMLInputElement>(null);

  // Scraper state
  const [scraperAgents, setScraperAgents] = useState<ScraperAgent[]>([]);
  const [userAgents, setUserAgents] = useState<UserAgent[]>([]);
  const [scrapeUrl, setScrapeUrl] = useState("");
  const [scrapeAgent, setScrapeAgent] = useState("basic");
  const [scrapeUserAgent, setScrapeUserAgent] = useState("chrome_windows");
  const [scrapeOutputName, setScrapeOutputName] = useState("");
  const [scrapeUseAI, setScrapeUseAI] = useState(true);
  const [scrapeWaitSelector, setScrapeWaitSelector] = useState("");
  const [scrapeScrollPage, setScrapeScrollPage] = useState(false);

  // Clean state
  const [cleanOperations, setCleanOperations] = useState<string[]>([]);
  const availableOperations = [
    { id: "remove_duplicates", name: "Remove Duplicates" },
    { id: "remove_null_rows", name: "Remove Null Rows" },
    { id: "fill_null_mean", name: "Fill Nulls with Mean" },
    { id: "fill_null_zero", name: "Fill Nulls with Zero" },
    { id: "strip_whitespace", name: "Strip Whitespace" },
    { id: "lowercase", name: "Convert to Lowercase" },
  ];

  // Split state
  const [splitRatio, setSplitRatio] = useState("0.8");
  const [splitShuffle, setSplitShuffle] = useState(true);

  // Export state
  const [exportFormat, setExportFormat] = useState("csv");

  // Merge state
  const [mergeDatasets, setMergeDatasets] = useState<string[]>([]);
  const [mergeOutputName, setMergeOutputName] = useState("");

  // Upload handler
  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsLoading(true);
    try {
      for (const file of Array.from(files)) {
        await fileService.upload(file, "datasets");
      }
      onRefresh();
    } catch (err) {
      console.error("Upload failed:", err);
    } finally {
      setIsLoading(false);
      if (uploadInputRef.current) {
        uploadInputRef.current.value = "";
      }
    }
  };

  // Load scraper agents
  useEffect(() => {
    const loadAgents = async () => {
      try {
        const result = await datasetService.getScraperAgents();
        setScraperAgents(result.agentTypes);
        setUserAgents(result.userAgents);
      } catch (e) {
        console.log("Could not load scraper agents");
      }
    };
    loadAgents();
  }, []);

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  };

  const getFormatColor = (format: string) => {
    switch (format.toUpperCase()) {
      case "CSV": return "text-green-500 bg-green-500/10";
      case "XLSX": case "XLS": return "text-blue-500 bg-blue-500/10";
      case "JSON": return "text-orange-500 bg-orange-500/10";
      case "PARQUET": return "text-purple-500 bg-purple-500/10";
      default: return "text-muted-foreground bg-muted";
    }
  };

  const handlePreview = async (dataset: DatasetInfo) => {
    setSelectedDataset(dataset);
    setIsLoading(true);
    try {
      const preview = await datasetService.previewDataset(dataset.path, 50);
      setPreviewData({ columns: preview.schema.map(s => s.name), rows: preview.data });
      setShowPreviewDialog(true);
    } catch (e) {
      console.error("Preview failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleClean = async () => {
    if (!selectedDataset || cleanOperations.length === 0) return;
    setIsLoading(true);
    try {
      await datasetService.cleanDataset(selectedDataset.path, cleanOperations);
      setShowCleanDialog(false);
      setCleanOperations([]);
      onRefresh();
    } catch (e) {
      console.error("Clean failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleScrape = async () => {
    if (!scrapeUrl || !scrapeOutputName) return;
    setIsLoading(true);
    try {
      if (scrapeUseAI) {
        await datasetService.scrapeWithAI(scrapeUrl, scrapeOutputName);
      } else {
        await datasetService.scrapeUrl({
          url: scrapeUrl,
          agentType: scrapeAgent,
          userAgent: scrapeUserAgent,
          outputName: scrapeOutputName,
          waitForSelector: scrapeWaitSelector || undefined,
          scrollPage: scrapeScrollPage,
        });
      }
      setShowScrapeDialog(false);
      setScrapeUrl("");
      setScrapeOutputName("");
      onRefresh();
    } catch (e) {
      console.error("Scrape failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSplit = async () => {
    if (!selectedDataset) return;
    setIsLoading(true);
    try {
      await datasetService.splitDataset(selectedDataset.path, parseFloat(splitRatio), splitShuffle);
      setShowSplitDialog(false);
      onRefresh();
    } catch (e) {
      console.error("Split failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleExport = async () => {
    if (!selectedDataset) return;
    setIsLoading(true);
    try {
      await datasetService.exportDataset(selectedDataset.path, exportFormat);
      setShowExportDialog(false);
      onRefresh();
    } catch (e) {
      console.error("Export failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleMerge = async () => {
    if (mergeDatasets.length < 2 || !mergeOutputName) return;
    setIsLoading(true);
    try {
      await datasetService.mergeDatasets(mergeDatasets, `datasets/${mergeOutputName}.csv`);
      setShowMergeDialog(false);
      setMergeDatasets([]);
      setMergeOutputName("");
      onRefresh();
    } catch (e) {
      console.error("Merge failed:", e);
    } finally {
      setIsLoading(false);
    }
  };

  const toggleMergeDataset = (path: string) => {
    setMergeDatasets(prev =>
      prev.includes(path) ? prev.filter(p => p !== path) : [...prev, path]
    );
  };

  const toggleCleanOperation = (id: string) => {
    setCleanOperations(prev =>
      prev.includes(id) ? prev.filter(o => o !== id) : [...prev, id]
    );
  };

  return (
    <div className="overflow-auto p-4">
      {/* Action Cards */}
      <div className="flex flex-wrap gap-3 mb-6">
        <ActionCard
          icon={<Upload className="h-5 w-5" />}
          label="Upload Dataset"
          description="Import CSV, Excel, Parquet"
          color="text-primary"
          onClick={() => uploadInputRef.current?.click()}
        />
        <input
          ref={uploadInputRef}
          type="file"
          className="hidden"
          accept=".csv,.xlsx,.xls,.json,.parquet,.feather"
          multiple
          onChange={handleUpload}
        />
        <ActionCard
          icon={<Globe className="h-5 w-5" />}
          label="Web Scraping"
          description="Extract data from web"
          color="text-purple-500"
          onClick={() => setShowScrapeDialog(true)}
        />
        <ActionCard
          icon={<Sparkles className="h-5 w-5" />}
          label="Clean Data"
          description="Remove duplicates, nulls"
          color="text-orange-500"
          onClick={() => {
            if (datasets.length > 0) {
              setSelectedDataset(datasets[0]);
            }
            setShowCleanDialog(true);
          }}
        />
        <ActionCard
          icon={<Split className="h-5 w-5" />}
          label="Train/Test Split"
          description="Split for ML"
          color="text-blue-500"
          onClick={() => {
            if (datasets.length > 0) {
              setSelectedDataset(datasets[0]);
            }
            setShowSplitDialog(true);
          }}
        />
        <ActionCard
          icon={<Combine className="h-5 w-5" />}
          label="Merge Datasets"
          description="Combine multiple files"
          color="text-cyan-500"
          onClick={() => setShowMergeDialog(true)}
        />
        <ActionCard
          icon={<FileDown className="h-5 w-5" />}
          label="Export"
          description="Download in other format"
          color="text-green-500"
          onClick={() => {
            if (datasets.length > 0) {
              setSelectedDataset(datasets[0]);
            }
            setShowExportDialog(true);
          }}
        />
      </div>

      {/* Datasets list */}
      {datasets.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12">
          <Database className="h-12 w-12 text-muted-foreground/50" />
          <p className="mt-4 text-muted-foreground">No datasets yet</p>
          <p className="text-sm text-muted-foreground">Upload or scrape data to get started</p>
        </div>
      ) : (
        <div className="space-y-2">
          <p className="text-sm font-medium">{datasets.length} Datasets</p>
          {datasets.map((dataset) => (
            <div
              key={dataset.path}
              className="flex items-center gap-3 rounded-lg border border-border bg-card p-3 hover:border-primary/30 transition-colors cursor-pointer"
              onClick={() => setSelectedDataset(dataset)}
            >
              <div className="flex h-9 w-9 items-center justify-center rounded-md bg-muted">
                <Database className={cn("h-4 w-4", getFormatColor(dataset.format).split(" ")[0])} />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">{dataset.name}</p>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className={cn("rounded px-1.5 py-0.5 text-xs", getFormatColor(dataset.format))}>
                    {dataset.format}
                  </span>
                  <span className="text-xs text-muted-foreground">{formatSize(dataset.size)}</span>
                </div>
              </div>
              <div className="flex gap-1">
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); handlePreview(dataset); }}>
                  <Eye className="h-3.5 w-3.5" />
                </Button>
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); setSelectedDataset(dataset); setShowCleanDialog(true); }}>
                  <Sparkles className="h-3.5 w-3.5 text-orange-500" />
                </Button>
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); setSelectedDataset(dataset); setShowSplitDialog(true); }}>
                  <Split className="h-3.5 w-3.5 text-blue-500" />
                </Button>
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); setSelectedDataset(dataset); setShowExportDialog(true); }}>
                  <FileDown className="h-3.5 w-3.5 text-green-500" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Web Scraping Dialog */}
      <Dialog open={showScrapeDialog} onOpenChange={setShowScrapeDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Globe className="h-5 w-5 text-purple-500" />
              Web Scraping
            </DialogTitle>
            <DialogDescription>
              Extract data from any website using AI or configurable agents
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>URL to Scrape</Label>
              <Input
                placeholder="https://example.com/data"
                value={scrapeUrl}
                onChange={(e) => setScrapeUrl(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label>Output Name</Label>
              <Input
                placeholder="scraped_data"
                value={scrapeOutputName}
                onChange={(e) => setScrapeOutputName(e.target.value)}
              />
            </div>

            <div className="flex items-center gap-2">
              <Checkbox
                id="use-ai"
                checked={scrapeUseAI}
                onCheckedChange={(c) => setScrapeUseAI(!!c)}
              />
              <Label htmlFor="use-ai" className="text-sm cursor-pointer">
                Use AI Agent (auto-detect data structure)
              </Label>
            </div>

            {!scrapeUseAI && (
              <div className="space-y-4 p-4 rounded-lg bg-muted/50">
                <p className="text-sm font-medium">Agent Configuration</p>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Scraper Agent</Label>
                    <Select value={scrapeAgent} onValueChange={setScrapeAgent}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {scraperAgents.map(agent => (
                          <SelectItem key={agent.id} value={agent.id}>
                            <div className="flex items-center gap-2">
                              {agent.id === "basic" ? <Globe className="h-3 w-3" /> :
                               agent.id === "playwright" ? <Chrome className="h-3 w-3" /> :
                               <Bot className="h-3 w-3" />}
                              {agent.name}
                            </div>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <p className="text-xs text-muted-foreground">
                      {scraperAgents.find(a => a.id === scrapeAgent)?.description}
                    </p>
                  </div>

                  <div className="space-y-2">
                    <Label>Browser Identity</Label>
                    <Select value={scrapeUserAgent} onValueChange={setScrapeUserAgent}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {userAgents.map(ua => (
                          <SelectItem key={ua.id} value={ua.id}>
                            {ua.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="space-y-2">
                  <Label>Wait for Selector (optional)</Label>
                  <Input
                    placeholder=".data-table, #content"
                    value={scrapeWaitSelector}
                    onChange={(e) => setScrapeWaitSelector(e.target.value)}
                  />
                </div>

                <div className="flex items-center gap-2">
                  <Checkbox
                    id="scroll-page"
                    checked={scrapeScrollPage}
                    onCheckedChange={(c) => setScrapeScrollPage(!!c)}
                  />
                  <Label htmlFor="scroll-page" className="text-sm cursor-pointer">
                    Scroll page to load lazy content
                  </Label>
                </div>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowScrapeDialog(false)}>Cancel</Button>
            <Button onClick={handleScrape} disabled={isLoading || !scrapeUrl || !scrapeOutputName}>
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Play className="h-4 w-4 mr-2" />}
              Start Scraping
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Clean Dialog */}
      <Dialog open={showCleanDialog} onOpenChange={setShowCleanDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-orange-500" />
              Clean Dataset
            </DialogTitle>
            <DialogDescription>
              Select operations to apply to clean your data
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {datasets.length > 0 && (
              <div className="space-y-2">
                <Label>Dataset</Label>
                <Select
                  value={selectedDataset?.path || ""}
                  onValueChange={(path) => setSelectedDataset(datasets.find(d => d.path === path) || null)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select dataset" />
                  </SelectTrigger>
                  <SelectContent>
                    {datasets.map(d => (
                      <SelectItem key={d.path} value={d.path}>{d.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            {datasets.length === 0 && (
              <div className="text-center py-4 text-muted-foreground">
                No datasets available. Upload or scrape data first.
              </div>
            )}
            <div className="space-y-2">
              <Label>Operations</Label>
              <div className="space-y-2 border rounded-lg p-3">
                {availableOperations.map(op => (
                  <div key={op.id} className="flex items-center gap-2">
                    <Checkbox
                      id={op.id}
                      checked={cleanOperations.includes(op.id)}
                      onCheckedChange={() => toggleCleanOperation(op.id)}
                    />
                    <Label htmlFor={op.id} className="text-sm cursor-pointer">{op.name}</Label>
                  </div>
                ))}
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCleanDialog(false)}>Cancel</Button>
            <Button onClick={handleClean} disabled={isLoading || cleanOperations.length === 0 || !selectedDataset}>
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Apply ({cleanOperations.length})
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Split Dialog */}
      <Dialog open={showSplitDialog} onOpenChange={setShowSplitDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Split className="h-5 w-5 text-blue-500" />
              Train/Test Split
            </DialogTitle>
            <DialogDescription>
              Split dataset into training and testing sets
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {datasets.length > 0 && (
              <div className="space-y-2">
                <Label>Dataset</Label>
                <Select
                  value={selectedDataset?.path || ""}
                  onValueChange={(path) => setSelectedDataset(datasets.find(d => d.path === path) || null)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select dataset" />
                  </SelectTrigger>
                  <SelectContent>
                    {datasets.map(d => (
                      <SelectItem key={d.path} value={d.path}>{d.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            {datasets.length === 0 && (
              <div className="text-center py-4 text-muted-foreground">
                No datasets available. Upload or scrape data first.
              </div>
            )}
            <div className="space-y-2">
              <Label>Train Ratio</Label>
              <Select value={splitRatio} onValueChange={setSplitRatio}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="0.6">60% Train / 40% Test</SelectItem>
                  <SelectItem value="0.7">70% Train / 30% Test</SelectItem>
                  <SelectItem value="0.8">80% Train / 20% Test</SelectItem>
                  <SelectItem value="0.9">90% Train / 10% Test</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                id="shuffle"
                checked={splitShuffle}
                onCheckedChange={(c) => setSplitShuffle(!!c)}
              />
              <Label htmlFor="shuffle" className="text-sm cursor-pointer">Shuffle data before splitting</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowSplitDialog(false)}>Cancel</Button>
            <Button onClick={handleSplit} disabled={isLoading || !selectedDataset}>
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Split Dataset
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Export Dialog */}
      <Dialog open={showExportDialog} onOpenChange={setShowExportDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <FileDown className="h-5 w-5 text-green-500" />
              Export Dataset
            </DialogTitle>
            <DialogDescription>
              {selectedDataset?.name}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {datasets.length > 0 && (
              <div className="space-y-2">
                <Label>Dataset</Label>
                <Select
                  value={selectedDataset?.path || ""}
                  onValueChange={(path) => setSelectedDataset(datasets.find(d => d.path === path) || null)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select dataset" />
                  </SelectTrigger>
                  <SelectContent>
                    {datasets.map(d => (
                      <SelectItem key={d.path} value={d.path}>{d.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            <div className="space-y-2">
              <Label>Export Format</Label>
              <Select value={exportFormat} onValueChange={setExportFormat}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="csv">CSV</SelectItem>
                  <SelectItem value="xlsx">Excel (XLSX)</SelectItem>
                  <SelectItem value="json">JSON</SelectItem>
                  <SelectItem value="parquet">Parquet</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowExportDialog(false)}>Cancel</Button>
            <Button onClick={handleExport} disabled={isLoading || !selectedDataset}>
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Export
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Merge Dialog */}
      <Dialog open={showMergeDialog} onOpenChange={setShowMergeDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Combine className="h-5 w-5 text-cyan-500" />
              Merge Datasets
            </DialogTitle>
            <DialogDescription>
              Select datasets to merge into one file
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {datasets.length < 2 ? (
              <div className="text-center py-4 text-muted-foreground">
                Need at least 2 datasets to merge.
              </div>
            ) : (
              <>
                <div className="space-y-2">
                  <Label>Select Datasets ({mergeDatasets.length} selected)</Label>
                  <div className="max-h-48 overflow-auto space-y-2 border rounded-lg p-2">
                    {datasets.map(d => (
                      <div
                        key={d.path}
                        className={cn(
                          "flex items-center gap-2 p-2 rounded cursor-pointer transition-colors",
                          mergeDatasets.includes(d.path) ? "bg-primary/10 border border-primary/30" : "hover:bg-muted"
                        )}
                        onClick={() => toggleMergeDataset(d.path)}
                      >
                        <Checkbox checked={mergeDatasets.includes(d.path)} />
                        <Database className="h-4 w-4 text-muted-foreground" />
                        <span className="text-sm">{d.name}</span>
                      </div>
                    ))}
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Output Name</Label>
                  <Input
                    placeholder="merged_data"
                    value={mergeOutputName}
                    onChange={(e) => setMergeOutputName(e.target.value)}
                  />
                </div>
              </>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowMergeDialog(false)}>Cancel</Button>
            <Button onClick={handleMerge} disabled={isLoading || mergeDatasets.length < 2 || !mergeOutputName}>
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Merge Datasets
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Preview Dialog */}
      <Dialog open={showPreviewDialog} onOpenChange={setShowPreviewDialog}>
        <DialogContent className="max-w-4xl max-h-[80vh]">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Table className="h-5 w-5" />
              Preview: {selectedDataset?.name}
            </DialogTitle>
          </DialogHeader>
          <ScrollArea className="h-[60vh]">
            {previewData && (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted sticky top-0">
                    <tr>
                      {previewData.columns.map(col => (
                        <th key={col} className="px-3 py-2 text-left font-medium">{col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {previewData.rows.map((row, i) => (
                      <tr key={i} className="border-b border-border hover:bg-muted/50">
                        {previewData.columns.map(col => (
                          <td key={col} className="px-3 py-2 truncate max-w-[200px]">
                            {String(row[col] ?? "")}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </ScrollArea>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowPreviewDialog(false)}>Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

// =============================================================================
// ACTION CARD
// =============================================================================

interface ActionCardProps {
  icon: React.ReactNode;
  label: string;
  description: string;
  color: string;
  onClick: () => void;
}

const ActionCard = ({ icon, label, description, color, onClick }: ActionCardProps) => (
  <button
    onClick={onClick}
    className="w-44 rounded-lg border border-border bg-card p-4 text-left transition-colors hover:border-primary/50"
  >
    <div className={cn("flex h-10 w-10 items-center justify-center rounded-lg bg-muted", color)}>
      {icon}
    </div>
    <p className="mt-3 text-sm font-semibold">{label}</p>
    <p className="text-xs text-muted-foreground">{description}</p>
  </button>
);

// =============================================================================
// FILES SIDE PANEL
// =============================================================================

interface FilesSidePanelProps {
  storageInfo: StorageInfo;
}

const FilesSidePanel = ({ storageInfo }: FilesSidePanelProps) => (
  <div className="flex flex-col h-full">
    <div className="flex items-center gap-2 border-b border-border p-3">
      <span className="font-semibold text-sm">Storage</span>
    </div>

    <div className="flex-1 overflow-auto p-3 space-y-4">
      {/* Storage Card */}
      <div className="rounded-lg border border-border p-3">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-500/20 text-blue-400">
            <HardDrive className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-medium">Workspace</p>
            <p className="text-xs text-muted-foreground">Local storage</p>
          </div>
        </div>
        <div className="mt-3">
          <div className="flex items-center justify-between text-xs">
            <span className="text-muted-foreground">Used</span>
            <span>{storageInfo.usedGB.toFixed(1)} GB / {storageInfo.totalGB} GB</span>
          </div>
          <div className="mt-1 h-2 rounded-full bg-muted overflow-hidden">
            <div
              className="h-full bg-blue-500"
              style={{ width: `${storageInfo.percent}%` }}
            />
          </div>
        </div>
      </div>

      {/* Quick Upload */}
      <div>
        <p className="text-sm font-medium mb-2">Quick Upload</p>
        <div className="rounded-lg border-2 border-dashed border-border p-4 text-center">
          <Upload className="h-6 w-6 text-muted-foreground mx-auto" />
          <p className="mt-2 text-sm text-muted-foreground">Drop files here or click to upload</p>
        </div>
      </div>
    </div>

    {/* File Types */}
    <div className="border-t border-border p-3">
      <div className="rounded-lg border border-primary/30 bg-primary/5 p-3">
        <p className="text-sm font-medium mb-2">File Types</p>
        <div className="space-y-1 text-xs">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <FileCode className="h-3 w-3 text-blue-400" />
              Python
            </span>
            <span>2 files</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <FileImage className="h-3 w-3 text-purple-400" />
              Images
            </span>
            <span>1 file</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <FileText className="h-3 w-3 text-green-400" />
              Data
            </span>
            <span>1 file</span>
          </div>
        </div>
      </div>
    </div>
  </div>
);

// =============================================================================
// DATASETS SIDE PANEL
// =============================================================================

interface DatasetsSidePanelProps {
  datasets: DatasetInfo[];
  onSplit?: () => void;
  onMerge?: () => void;
  onExport?: () => void;
  onClean?: () => void;
}

const DatasetsSidePanel = ({ datasets, onSplit, onMerge, onExport, onClean }: DatasetsSidePanelProps) => {
  const formatTotalSize = () => {
    const total = datasets.reduce((sum, d) => sum + d.size, 0);
    if (total < 1024) return `${total} B`;
    if (total < 1048576) return `${(total / 1024).toFixed(1)} KB`;
    if (total < 1073741824) return `${(total / 1048576).toFixed(1)} MB`;
    return `${(total / 1073741824).toFixed(2)} GB`;
  };

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 border-b border-border p-3">
        <span className="font-semibold text-sm">Dataset Tools</span>
      </div>

      <div className="flex-1 overflow-auto p-3 space-y-2">
        <ToolCard icon={<Sparkles className="h-4 w-4" />} title="Clean Data" subtitle="Remove duplicates, nulls" onClick={onClean} />
        <ToolCard icon={<Split className="h-4 w-4" />} title="Train/Test Split" subtitle="Split for ML" onClick={onSplit} />
        <ToolCard icon={<Combine className="h-4 w-4" />} title="Merge Datasets" subtitle="Join multiple files" onClick={onMerge} />
        <ToolCard icon={<FileDown className="h-4 w-4" />} title="Export" subtitle="Download processed data" onClick={onExport} />
      </div>

      <div className="border-t border-border p-3">
        <p className="text-xs font-medium mb-2">Data Quality</p>
        <div className="space-y-1 text-xs">
          <div className="flex items-center justify-between">
            <span className="text-muted-foreground">Total Datasets</span>
            <span className="font-semibold text-primary">{datasets.length}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-muted-foreground">Total Size</span>
            <span className="font-semibold text-green-500">{formatTotalSize()}</span>
          </div>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// TOOL CARD
// =============================================================================

interface ToolCardProps {
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  onClick?: () => void;
}

const ToolCard = ({ icon, title, subtitle, onClick }: ToolCardProps) => (
  <button
    className="flex w-full items-center gap-3 rounded-lg border border-border p-3 transition-colors hover:bg-muted hover:border-primary/30"
    onClick={onClick}
  >
    <span className="text-primary">{icon}</span>
    <div className="flex-1 text-left">
      <p className="text-sm font-medium">{title}</p>
      <p className="text-xs text-muted-foreground">{subtitle}</p>
    </div>
    <ChevronRight className="h-4 w-4 text-muted-foreground" />
  </button>
);
