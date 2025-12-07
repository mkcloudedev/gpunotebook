import { useState, useEffect, useCallback } from "react";
import {
  Database,
  Trophy,
  FileCode,
  Search,
  RefreshCw,
  Download,
  ThumbsUp,
  HardDrive,
  Users,
  Calendar,
  Gift,
  Clock,
  User,
  ExternalLink,
  Settings,
  X,
  Loader2,
  CheckCircle,
  AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { KaggleBreadcrumb } from "./KaggleBreadcrumb";
import { kaggleService, KaggleDataset as ServiceDataset, KaggleCompetition as ServiceCompetition, KaggleKernel as ServiceKernel } from "@/services/kaggleService";

interface KaggleDataset {
  ref: string;
  title: string;
  owner: string;
  name: string;
  downloadCount: number;
  voteCount: number;
  size: string;
}

interface KaggleCompetition {
  ref: string;
  title: string;
  category: string;
  reward: string;
  teamCount: number;
  deadline: string;
  userHasEntered: boolean;
}

interface KaggleKernel {
  ref: string;
  title: string;
  author: string;
  language: string;
  totalVotes: number;
  lastRunTime: string;
}

// Mock data for fallback
const mockDatasets: KaggleDataset[] = [
  { ref: "zillow/zecon", title: "Zillow Economics Data", owner: "zillow", name: "zecon", downloadCount: 45000, voteCount: 890, size: "2.5 GB" },
  { ref: "hacker-news/hacker-news-posts", title: "Hacker News Posts", owner: "hacker-news", name: "hacker-news-posts", downloadCount: 32000, voteCount: 567, size: "1.2 GB" },
  { ref: "snap/amazon-fine-food-reviews", title: "Amazon Fine Food Reviews", owner: "snap", name: "amazon-fine-food-reviews", downloadCount: 28000, voteCount: 445, size: "450 MB" },
];

const mockCompetitions: KaggleCompetition[] = [
  { ref: "titanic", title: "Titanic - Machine Learning from Disaster", category: "Getting Started", reward: "Knowledge", teamCount: 15000, deadline: "Ongoing", userHasEntered: true },
  { ref: "house-prices", title: "House Prices - Advanced Regression", category: "Getting Started", reward: "Knowledge", teamCount: 12000, deadline: "Ongoing", userHasEntered: false },
  { ref: "digit-recognizer", title: "Digit Recognizer", category: "Getting Started", reward: "Knowledge", teamCount: 8000, deadline: "Ongoing", userHasEntered: false },
];

const mockKernels: KaggleKernel[] = [
  { ref: "user/notebook1", title: "Complete EDA with Python", author: "datamaster", language: "Python", totalVotes: 1200, lastRunTime: "2 days ago" },
  { ref: "user/notebook2", title: "XGBoost Tutorial", author: "mlexpert", language: "Python", totalVotes: 890, lastRunTime: "1 week ago" },
  { ref: "user/notebook3", title: "Deep Learning Starter", author: "neuralnetfan", language: "Python", totalVotes: 650, lastRunTime: "3 days ago" },
];

type TabType = "datasets" | "competitions" | "kernels";

export const KaggleContent = () => {
  const [isConfigured, setIsConfigured] = useState(false);
  const [username, setUsername] = useState("");
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>("datasets");
  const [searchQuery, setSearchQuery] = useState("");
  const [downloading, setDownloading] = useState<Set<string>>(new Set());

  const [datasets, setDatasets] = useState<KaggleDataset[]>([]);
  const [competitions, setCompetitions] = useState<KaggleCompetition[]>([]);
  const [kernels, setKernels] = useState<KaggleKernel[]>([]);

  // Convert service types to component types
  const convertDataset = (d: ServiceDataset): KaggleDataset => ({
    ref: d.ref,
    title: d.title,
    owner: d.owner,
    name: d.name,
    downloadCount: d.downloadCount,
    voteCount: d.voteCount,
    size: d.size,
  });

  const convertCompetition = (c: ServiceCompetition): KaggleCompetition => ({
    ref: c.ref,
    title: c.title,
    category: c.category,
    reward: c.reward,
    teamCount: c.teamCount,
    deadline: c.deadline instanceof Date ? c.deadline.toLocaleDateString() : "Ongoing",
    userHasEntered: c.userHasEntered,
  });

  const convertKernel = (k: ServiceKernel): KaggleKernel => ({
    ref: k.ref,
    title: k.title,
    author: k.author,
    language: k.language,
    totalVotes: k.totalVotes,
    lastRunTime: k.lastRunTime instanceof Date ? formatTimeAgo(k.lastRunTime) : "Unknown",
  });

  const formatTimeAgo = (date: Date): string => {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} hours ago`;
    return `${Math.floor(seconds / 86400)} days ago`;
  };

  // Load data from API
  const loadData = useCallback(async (isInitial = false) => {
    if (isInitial) {
      setIsInitialLoading(true);
    } else {
      setIsLoading(true);
    }
    setError(null);

    try {
      // Check if configured
      const configured = await kaggleService.isConfigured();
      setIsConfigured(configured);

      if (configured) {
        // Get user info
        const user = await kaggleService.getUser();
        if (user) setUsername(user.username);

        // Load data in parallel
        const [datasetsData, competitionsData, kernelsData] = await Promise.all([
          kaggleService.listDatasets(),
          kaggleService.listCompetitions(),
          kaggleService.listKernels(),
        ]);

        setDatasets(datasetsData.map(convertDataset));
        setCompetitions(competitionsData.map(convertCompetition));
        setKernels(kernelsData.map(convertKernel));
      }
    } catch (err) {
      console.error("Error loading Kaggle data:", err);
      setError(err instanceof Error ? err.message : "Failed to load data");
      // Use mock data as fallback
      setDatasets(mockDatasets);
      setCompetitions(mockCompetitions);
      setKernels(mockKernels);
      setIsConfigured(true);
    } finally {
      setIsInitialLoading(false);
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    loadData(true);
  }, [loadData]);

  // Search handler
  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    setIsLoading(true);
    try {
      if (activeTab === "datasets") {
        const results = await kaggleService.searchDatasets(searchQuery);
        setDatasets(results.map(convertDataset));
      } else if (activeTab === "competitions") {
        const results = await kaggleService.searchCompetitions(searchQuery);
        setCompetitions(results.map(convertCompetition));
      }
    } catch (err) {
      console.error("Search error:", err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDownload = async (ref: string) => {
    setDownloading((prev) => new Set(prev).add(ref));
    try {
      await kaggleService.downloadDataset(ref, "/downloads");
    } catch (err) {
      console.error("Download error:", err);
    } finally {
      setDownloading((prev) => {
        const next = new Set(prev);
        next.delete(ref);
        return next;
      });
    }
  };

  const handleRefresh = () => {
    loadData(false);
  };

  // Show full-screen loader until initial data is ready
  if (isInitialLoading) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-cyan-500/20">
            <Database className="h-8 w-8 text-cyan-500" />
          </div>
          <Loader2 className="h-8 w-8 animate-spin text-cyan-500" />
          <p className="text-sm text-muted-foreground">Loading Kaggle...</p>
        </div>
      </div>
    );
  }

  if (!isConfigured) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="w-96 rounded-lg border border-border bg-card p-8 text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-cyan-500/20">
            <Database className="h-8 w-8 text-cyan-500" />
          </div>
          <h2 className="mt-6 text-xl font-semibold">Connect to Kaggle</h2>
          <p className="mt-2 text-muted-foreground">
            Configure your Kaggle API credentials in Settings to access datasets, competitions, and notebooks.
          </p>
          <Button className="mt-6 w-full bg-cyan-500 hover:bg-cyan-600">
            <Settings className="mr-2 h-4 w-4" />
            Go to Settings
          </Button>
          <Button variant="outline" className="mt-3 w-full" onClick={() => setIsConfigured(true)}>
            <RefreshCw className="mr-2 h-4 w-4" />
            Check Connection
          </Button>
          <Button variant="ghost" className="mt-3" size="sm">
            <ExternalLink className="mr-2 h-3.5 w-3.5" />
            Get your API key from kaggle.com/settings
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <KaggleBreadcrumb
        datasetCount={datasets.length}
        competitionCount={competitions.length}
        onRefresh={handleRefresh}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex flex-1 flex-col overflow-hidden">
          {/* Tabs */}
          <div className="flex border-b border-border bg-card">
            <TabButton
              active={activeTab === "datasets"}
              onClick={() => setActiveTab("datasets")}
              icon={<Database className="h-4 w-4" />}
              label="Datasets"
              badge={datasets.length}
            />
            <TabButton
              active={activeTab === "competitions"}
              onClick={() => setActiveTab("competitions")}
              icon={<Trophy className="h-4 w-4" />}
              label="Competitions"
              badge={competitions.length}
            />
            <TabButton
              active={activeTab === "kernels"}
              onClick={() => setActiveTab("kernels")}
              icon={<FileCode className="h-4 w-4" />}
              label="Notebooks"
              badge={kernels.length}
            />
          </div>

          {/* Content */}
          <div className="flex-1 overflow-auto p-4">
            {isLoading ? (
              <div className="flex h-full items-center justify-center">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
              </div>
            ) : (
              <>
                {activeTab === "datasets" && (
                  <DatasetsList
                    datasets={datasets}
                    downloading={downloading}
                    onDownload={handleDownload}
                  />
                )}
                {activeTab === "competitions" && (
                  <CompetitionsList
                    competitions={competitions}
                    downloading={downloading}
                    onDownload={handleDownload}
                  />
                )}
                {activeTab === "kernels" && (
                  <KernelsList
                    kernels={kernels}
                    downloading={downloading}
                    onDownload={handleDownload}
                  />
                )}
              </>
            )}
          </div>
        </div>

        {/* Side panel */}
        <div className="w-72 border-l border-border bg-card flex flex-col">
          <SidePanel
            isConfigured={isConfigured}
            username={username}
            datasets={datasets}
            competitions={competitions}
            kernels={kernels}
            searchQuery={searchQuery}
            onSearchChange={setSearchQuery}
            onRefresh={handleRefresh}
          />
        </div>
      </div>
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
      <span className="rounded-full bg-muted px-2 py-0.5 text-xs">{badge}</span>
    )}
  </button>
);

// =============================================================================
// DATASETS LIST
// =============================================================================

interface DatasetsListProps {
  datasets: KaggleDataset[];
  downloading: Set<string>;
  onDownload: (ref: string) => void;
}

const DatasetsList = ({ datasets, downloading, onDownload }: DatasetsListProps) => {
  if (datasets.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <Database className="h-12 w-12 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">No datasets found</p>
        <p className="text-sm text-muted-foreground">Search for datasets or refresh to load more</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {datasets.map((dataset) => (
        <ItemCard
          key={dataset.ref}
          icon={<Database className="h-5 w-5" />}
          iconColor="text-cyan-500"
          bgColor="bg-cyan-500/10"
          title={dataset.title}
          subtitle={dataset.ref}
          stats={[
            { icon: <Download className="h-3 w-3" />, value: dataset.downloadCount.toLocaleString() },
            { icon: <ThumbsUp className="h-3 w-3" />, value: dataset.voteCount.toLocaleString() },
            { icon: <HardDrive className="h-3 w-3" />, value: dataset.size },
          ]}
          isDownloading={downloading.has(dataset.ref)}
          onDownload={() => onDownload(dataset.ref)}
          downloadLabel="Download"
        />
      ))}
    </div>
  );
};

// =============================================================================
// COMPETITIONS LIST
// =============================================================================

interface CompetitionsListProps {
  competitions: KaggleCompetition[];
  downloading: Set<string>;
  onDownload: (ref: string) => void;
}

const CompetitionsList = ({ competitions, downloading, onDownload }: CompetitionsListProps) => {
  if (competitions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <Trophy className="h-12 w-12 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">No competitions found</p>
        <p className="text-sm text-muted-foreground">Check back later for new competitions</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {competitions.map((competition) => (
        <ItemCard
          key={competition.ref}
          icon={<Trophy className="h-5 w-5" />}
          iconColor="text-amber-500"
          bgColor="bg-amber-500/10"
          title={competition.title}
          subtitle={competition.category}
          badge={competition.userHasEntered ? "Entered" : undefined}
          stats={[
            { icon: <Gift className="h-3 w-3" />, value: competition.reward },
            { icon: <Users className="h-3 w-3" />, value: competition.teamCount.toLocaleString() },
            { icon: <Calendar className="h-3 w-3" />, value: competition.deadline },
          ]}
          isDownloading={downloading.has(competition.ref)}
          onDownload={() => onDownload(competition.ref)}
          downloadLabel="Get Data"
        />
      ))}
    </div>
  );
};

// =============================================================================
// KERNELS LIST
// =============================================================================

interface KernelsListProps {
  kernels: KaggleKernel[];
  downloading: Set<string>;
  onDownload: (ref: string) => void;
}

const KernelsList = ({ kernels, downloading, onDownload }: KernelsListProps) => {
  if (kernels.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <FileCode className="h-12 w-12 text-muted-foreground/50" />
        <p className="mt-4 text-muted-foreground">No notebooks found</p>
        <p className="text-sm text-muted-foreground">Search for notebooks to import</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {kernels.map((kernel) => (
        <ItemCard
          key={kernel.ref}
          icon={<FileCode className="h-5 w-5" />}
          iconColor="text-purple-500"
          bgColor="bg-purple-500/10"
          title={kernel.title}
          subtitle={`by ${kernel.author}`}
          badge={kernel.language}
          stats={[
            { icon: <ThumbsUp className="h-3 w-3" />, value: kernel.totalVotes.toLocaleString() },
            { icon: <Clock className="h-3 w-3" />, value: kernel.lastRunTime },
          ]}
          isDownloading={downloading.has(kernel.ref)}
          onDownload={() => onDownload(kernel.ref)}
          downloadLabel="Import"
        />
      ))}
    </div>
  );
};

// =============================================================================
// ITEM CARD
// =============================================================================

interface Stat {
  icon: React.ReactNode;
  value: string;
}

interface ItemCardProps {
  icon: React.ReactNode;
  iconColor: string;
  bgColor: string;
  title: string;
  subtitle: string;
  badge?: string;
  stats: Stat[];
  isDownloading: boolean;
  onDownload: () => void;
  downloadLabel: string;
}

const ItemCard = ({
  icon,
  iconColor,
  bgColor,
  title,
  subtitle,
  badge,
  stats,
  isDownloading,
  onDownload,
  downloadLabel,
}: ItemCardProps) => (
  <div className="flex items-center gap-3 rounded-lg border border-border bg-card p-3 hover:border-primary/30 transition-colors">
    <div className={cn("flex h-10 w-10 items-center justify-center rounded-lg", bgColor)}>
      <span className={iconColor}>{icon}</span>
    </div>
    <div className="flex-1 min-w-0">
      <div className="flex items-center gap-2">
        <p className="text-sm font-medium truncate">{title}</p>
        {badge && (
          <span className="rounded bg-muted px-1.5 py-0.5 text-xs">{badge}</span>
        )}
      </div>
      <p className="text-xs text-muted-foreground truncate">{subtitle}</p>
      <div className="flex items-center gap-3 mt-1">
        {stats.map((stat, idx) => (
          <span key={idx} className="flex items-center gap-1 text-xs text-muted-foreground">
            {stat.icon}
            {stat.value}
          </span>
        ))}
      </div>
    </div>
    <Button
      size="sm"
      disabled={isDownloading}
      onClick={onDownload}
      className={cn("gap-1.5", isDownloading ? "" : "bg-cyan-500 hover:bg-cyan-600")}
    >
      {isDownloading ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <Download className="h-4 w-4" />
      )}
      {isDownloading ? "..." : downloadLabel}
    </Button>
  </div>
);

// =============================================================================
// SIDE PANEL
// =============================================================================

interface SidePanelProps {
  isConfigured: boolean;
  username: string;
  datasets: KaggleDataset[];
  competitions: KaggleCompetition[];
  kernels: KaggleKernel[];
  searchQuery: string;
  onSearchChange: (query: string) => void;
  onRefresh: () => void;
}

const SidePanel = ({
  isConfigured,
  username,
  datasets,
  competitions,
  kernels,
  searchQuery,
  onSearchChange,
  onRefresh,
}: SidePanelProps) => (
  <div className="flex flex-col h-full">
    {/* Search */}
    <div className="p-4">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input
          value={searchQuery}
          onChange={(e) => onSearchChange(e.target.value)}
          placeholder="Search..."
          className="pl-9 pr-8"
        />
        {searchQuery && (
          <button
            onClick={() => onSearchChange("")}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>
    </div>

    <div className="border-t border-border" />

    {/* Account */}
    <div className="p-4">
      <p className="text-xs font-semibold text-muted-foreground uppercase mb-3">Account</p>
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-cyan-500/10">
          <User className="h-5 w-5 text-cyan-500" />
        </div>
        <div>
          <p className="text-sm font-medium">{username || "Not connected"}</p>
          <div className="flex items-center gap-1.5">
            <span
              className={cn("h-1.5 w-1.5 rounded-full", isConfigured ? "bg-green-500" : "bg-muted-foreground")}
            />
            <span className={cn("text-xs", isConfigured ? "text-green-500" : "text-muted-foreground")}>
              {isConfigured ? "Connected" : "Not configured"}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div className="border-t border-border" />

    {/* Quick Stats */}
    <div className="p-4">
      <p className="text-xs font-semibold text-muted-foreground uppercase mb-3">Quick Stats</p>
      <div className="space-y-2">
        <StatRow icon={<Database className="h-3.5 w-3.5" />} label="Datasets" value={datasets.length} />
        <StatRow icon={<Trophy className="h-3.5 w-3.5" />} label="Competitions" value={competitions.length} />
        <StatRow icon={<FileCode className="h-3.5 w-3.5" />} label="Notebooks" value={kernels.length} />
      </div>
    </div>

    <div className="border-t border-border" />

    {/* Actions */}
    <div className="p-4">
      <p className="text-xs font-semibold text-muted-foreground uppercase mb-3">Actions</p>
      <Button variant="outline" className="w-full" onClick={onRefresh}>
        <RefreshCw className="mr-2 h-4 w-4" />
        Refresh
      </Button>
    </div>

    <div className="flex-1" />

    {/* Footer */}
    <div className="border-t border-border p-4">
      <div className="flex items-center gap-3">
        <div className="flex h-9 w-9 items-center justify-center rounded-md bg-cyan-500/10">
          <Database className="h-4 w-4 text-cyan-500" />
        </div>
        <div>
          <p className="text-sm font-semibold">Kaggle</p>
          <p className="text-xs text-muted-foreground">kaggle.com</p>
        </div>
      </div>
    </div>
  </div>
);

// =============================================================================
// STAT ROW
// =============================================================================

interface StatRowProps {
  icon: React.ReactNode;
  label: string;
  value: number;
}

const StatRow = ({ icon, label, value }: StatRowProps) => (
  <div className="flex items-center text-sm">
    <span className="text-muted-foreground">{icon}</span>
    <span className="ml-2 flex-1 text-muted-foreground">{label}</span>
    <span className="font-medium">{value}</span>
  </div>
);
