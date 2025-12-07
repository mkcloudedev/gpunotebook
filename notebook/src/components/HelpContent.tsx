import {
  HelpCircle,
  Rocket,
  FileCode,
  Bot,
  Cpu,
  FolderOpen,
  Keyboard,
  FilePlus,
  Play,
  Terminal,
  Plus,
  MousePointer,
  Upload,
  LayoutTemplate,
  MessageSquare,
  Sparkles,
  Eye,
  Activity,
  List,
  Monitor,
  UploadCloud,
  FolderPlus,
  HardDrive,
  Info,
  ChevronRight,
  Bookmark,
  MessageCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { HelpBreadcrumb } from "./HelpBreadcrumb";

interface HelpItem {
  title: string;
  description: string;
  icon: React.ReactNode;
}

interface ShortcutItem {
  shortcut: string;
  description: string;
}

export const HelpContent = () => {
  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <HelpBreadcrumb />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex-1 overflow-auto p-6">
          <div className="max-w-3xl mx-auto">
            {/* Header */}
            <div className="rounded-xl border border-primary/20 bg-gradient-to-r from-primary/10 to-primary/5 p-6">
              <div className="flex items-center gap-5">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/20">
                  <HelpCircle className="h-8 w-8 text-primary" />
                </div>
                <div>
                  <h1 className="text-2xl font-bold">GPU Notebook Help</h1>
                  <p className="text-muted-foreground mt-2">
                    Learn how to use the GPU Notebook application to run Python code with GPU
                    acceleration, manage notebooks, and use AI assistance.
                  </p>
                </div>
              </div>
            </div>

            <div className="mt-8 space-y-6">
              {/* Getting Started */}
              <HelpSection
                title="Getting Started"
                icon={<Rocket className="h-5 w-5" />}
                color="#3B82F6"
                items={[
                  {
                    title: "Create a Notebook",
                    description:
                      'Go to Notebooks page and click "New" button or use a template from "From Template".',
                    icon: <FilePlus className="h-4 w-4" />,
                  },
                  {
                    title: "Run Code",
                    description:
                      "Click the play button on a cell or press Shift+Enter to execute code.",
                    icon: <Play className="h-4 w-4" />,
                  },
                  {
                    title: "Use the CLI",
                    description:
                      "Type Python code in the footer CLI and press Enter for quick execution.",
                    icon: <Terminal className="h-4 w-4" />,
                  },
                ]}
              />

              {/* Notebooks */}
              <HelpSection
                title="Notebooks"
                icon={<FileCode className="h-5 w-5" />}
                color="#8B5CF6"
                items={[
                  {
                    title: "Add Cells",
                    description:
                      'Click "+ Code" or "+ Markdown" buttons to add new cells to your notebook.',
                    icon: <Plus className="h-4 w-4" />,
                  },
                  {
                    title: "Cell Actions",
                    description:
                      "Hover over a cell to see actions: Run, Move Up/Down, Copy, Delete.",
                    icon: <MousePointer className="h-4 w-4" />,
                  },
                  {
                    title: "Import Notebooks",
                    description:
                      'Import existing .ipynb files using the "Import" button on the Notebooks page.',
                    icon: <Upload className="h-4 w-4" />,
                  },
                  {
                    title: "Templates",
                    description:
                      "Use pre-built templates for Machine Learning, Data Analysis, or Computer Vision projects.",
                    icon: <LayoutTemplate className="h-4 w-4" />,
                  },
                ]}
              />

              {/* AI Assistant */}
              <HelpSection
                title="AI Assistant"
                icon={<Bot className="h-5 w-5" />}
                color="#10B981"
                items={[
                  {
                    title: "Chat with AI",
                    description:
                      "Use the AI panel on the right side of the notebook editor to get coding help.",
                    icon: <MessageSquare className="h-4 w-4" />,
                  },
                  {
                    title: "Code Generation",
                    description:
                      "Ask AI to generate code, fix errors, or explain concepts.",
                    icon: <Sparkles className="h-4 w-4" />,
                  },
                  {
                    title: "Context Aware",
                    description:
                      "AI can see your notebook cells and provide relevant suggestions.",
                    icon: <Eye className="h-4 w-4" />,
                  },
                ]}
              />

              {/* GPU Monitoring */}
              <HelpSection
                title="GPU Monitoring"
                icon={<Cpu className="h-5 w-5" />}
                color="#F59E0B"
                items={[
                  {
                    title: "Real-time Stats",
                    description:
                      "Monitor GPU utilization, memory usage, temperature, and power draw.",
                    icon: <Activity className="h-4 w-4" />,
                  },
                  {
                    title: "Process List",
                    description:
                      "View all processes running on your GPU and their memory usage.",
                    icon: <List className="h-4 w-4" />,
                  },
                  {
                    title: "Header Status",
                    description:
                      "GPU status is always visible in the header bar for quick reference.",
                    icon: <Monitor className="h-4 w-4" />,
                  },
                ]}
              />

              {/* File Management */}
              <HelpSection
                title="File Management"
                icon={<FolderOpen className="h-5 w-5" />}
                color="#EC4899"
                items={[
                  {
                    title: "Upload Files",
                    description:
                      'Click "Upload" to add files to your workspace for use in notebooks.',
                    icon: <UploadCloud className="h-4 w-4" />,
                  },
                  {
                    title: "Create Folders",
                    description:
                      'Organize your files by creating folders with "New Folder" button.',
                    icon: <FolderPlus className="h-4 w-4" />,
                  },
                  {
                    title: "Storage Info",
                    description:
                      "View storage usage in the side panel of the Files page.",
                    icon: <HardDrive className="h-4 w-4" />,
                  },
                ]}
              />

              {/* Keyboard Shortcuts */}
              <ShortcutsSection
                shortcuts={[
                  { shortcut: "Shift + Enter", description: "Run current cell" },
                  { shortcut: "Ctrl + Enter", description: "Run cell and stay" },
                  { shortcut: "Ctrl + S", description: "Save notebook" },
                  { shortcut: "Arrow Up/Down", description: "Navigate command history in CLI" },
                  { shortcut: "Escape", description: "Deselect current cell" },
                ]}
              />

              {/* Footer */}
              <div className="rounded-lg border border-border bg-card p-4">
                <div className="flex items-center gap-3">
                  <Info className="h-5 w-5 text-muted-foreground" />
                  <div>
                    <p className="font-medium">GPU Notebook v1.0</p>
                    <p className="text-sm text-muted-foreground">
                      Built with React & Python FastAPI
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Links Sidebar */}
        <div className="w-72 border-l border-border bg-card flex flex-col">
          <div className="flex items-center gap-2 border-b border-border p-4">
            <Bookmark className="h-4 w-4 text-primary" />
            <span className="font-semibold text-sm">Quick Links</span>
          </div>

          <div className="flex-1 overflow-auto p-3 space-y-2">
            <QuickLink icon={<Rocket className="h-4 w-4" />} title="Getting Started" color="#3B82F6" />
            <QuickLink icon={<FileCode className="h-4 w-4" />} title="Notebooks" color="#8B5CF6" />
            <QuickLink icon={<Bot className="h-4 w-4" />} title="AI Assistant" color="#10B981" />
            <QuickLink icon={<Cpu className="h-4 w-4" />} title="GPU Monitoring" color="#F59E0B" />
            <QuickLink icon={<FolderOpen className="h-4 w-4" />} title="File Management" color="#EC4899" />
            <QuickLink icon={<Keyboard className="h-4 w-4" />} title="Keyboard Shortcuts" color="#6366F1" />
          </div>

          <div className="border-t border-border p-3">
            <div className="rounded-lg border border-primary/20 bg-primary/5 p-3 text-center">
              <MessageCircle className="h-6 w-6 text-primary mx-auto" />
              <p className="font-medium mt-2">Need more help?</p>
              <p className="text-xs text-muted-foreground mt-1">Ask the AI Assistant</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// HELP SECTION
// =============================================================================

interface HelpSectionProps {
  title: string;
  icon: React.ReactNode;
  color: string;
  items: HelpItem[];
}

const HelpSection = ({ title, icon, color, items }: HelpSectionProps) => (
  <div className="rounded-lg border border-border bg-card overflow-hidden">
    <div className="px-4 py-3" style={{ backgroundColor: `${color}15` }}>
      <div className="flex items-center gap-3">
        <span style={{ color }}>{icon}</span>
        <span className="font-semibold" style={{ color }}>
          {title}
        </span>
      </div>
    </div>
    <div className="p-4 space-y-3">
      {items.map((item, idx) => (
        <div key={idx} className="flex gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-muted flex-shrink-0">
            {item.icon}
          </div>
          <div>
            <p className="font-medium text-sm">{item.title}</p>
            <p className="text-sm text-muted-foreground mt-0.5">{item.description}</p>
          </div>
        </div>
      ))}
    </div>
  </div>
);

// =============================================================================
// SHORTCUTS SECTION
// =============================================================================

interface ShortcutsSectionProps {
  shortcuts: ShortcutItem[];
}

const ShortcutsSection = ({ shortcuts }: ShortcutsSectionProps) => (
  <div className="rounded-lg border border-border bg-card overflow-hidden">
    <div className="px-4 py-3" style={{ backgroundColor: "#6366F115" }}>
      <div className="flex items-center gap-3">
        <Keyboard className="h-5 w-5" style={{ color: "#6366F1" }} />
        <span className="font-semibold" style={{ color: "#6366F1" }}>
          Keyboard Shortcuts
        </span>
      </div>
    </div>
    <div className="p-4 space-y-2">
      {shortcuts.map((item, idx) => (
        <div key={idx} className="flex items-center gap-3">
          <kbd className="rounded border border-border bg-muted px-2 py-1 font-mono text-xs">
            {item.shortcut}
          </kbd>
          <span className="text-sm text-muted-foreground">{item.description}</span>
        </div>
      ))}
    </div>
  </div>
);

// =============================================================================
// QUICK LINK
// =============================================================================

interface QuickLinkProps {
  icon: React.ReactNode;
  title: string;
  color: string;
}

const QuickLink = ({ icon, title, color }: QuickLinkProps) => (
  <button
    className="flex w-full items-center gap-3 rounded-lg border border-border p-3 text-left transition-colors hover:border-primary/30"
    style={{ ["--hover-color" as string]: color }}
  >
    <span style={{ color }}>{icon}</span>
    <span className="flex-1 text-sm">{title}</span>
    <ChevronRight className="h-4 w-4 text-muted-foreground" />
  </button>
);
