import { useState, useEffect, useCallback } from "react";
import {
  Search,
  RefreshCw,
  Plus,
  Trash2,
  ArrowUp,
  Download,
  Package,
  Loader2,
  ExternalLink,
  Check,
  X,
  ArrowUpCircle,
  Info,
  List,
  CheckCircle,
  AlertCircle,
  User,
  Globe,
  Code,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";
import {
  pipService,
  InstalledPackage,
  PackageSearchResult,
  InstallProgress,
} from "@/services/pipService";

interface PackageManagerPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

interface OutdatedPackage {
  name: string;
  currentVersion: string;
  latestVersion: string;
}

interface PackageInfo extends PackageSearchResult {
  author?: string;
  license?: string;
  homePage?: string;
  requiresPython?: string;
  versions?: string[];
}

// Quick install popular packages
const QUICK_INSTALL_PACKAGES = [
  "numpy",
  "pandas",
  "matplotlib",
  "torch",
  "scikit-learn",
  "tensorflow",
  "transformers",
  "opencv-python",
];

export const PackageManagerPanel = ({ isOpen, onClose }: PackageManagerPanelProps) => {
  const [activeTab, setActiveTab] = useState<"installed" | "search" | "updates">("installed");
  const [installedPackages, setInstalledPackages] = useState<InstalledPackage[]>([]);
  const [searchResults, setSearchResults] = useState<PackageSearchResult[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterQuery, setFilterQuery] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSearching, setIsSearching] = useState(false);
  const [installingPackage, setInstallingPackage] = useState<string | null>(null);
  const [installProgress, setInstallProgress] = useState<InstallProgress | null>(null);
  const [outdatedPackages, setOutdatedPackages] = useState<OutdatedPackage[]>([]);
  const [isCheckingUpdates, setIsCheckingUpdates] = useState(false);
  const [showPackageInfo, setShowPackageInfo] = useState(false);
  const [selectedPackageInfo, setSelectedPackageInfo] = useState<PackageInfo | null>(null);
  const [notification, setNotification] = useState<{ type: "success" | "error"; message: string } | null>(null);

  // Show notification
  const showNotification = (type: "success" | "error", message: string) => {
    setNotification({ type, message });
    setTimeout(() => setNotification(null), 3000);
  };

  // Fetch installed packages
  const fetchInstalledPackages = useCallback(async () => {
    setIsLoading(true);
    try {
      const packages = await pipService.listPackages();
      setInstalledPackages(packages);
    } catch (error) {
      console.error("Failed to fetch packages:", error);
      // Mock data for demo
      setInstalledPackages([
        { name: "torch", version: "2.1.0", location: "/usr/local/lib/python3.11", requires: ["numpy"], requiredBy: [] },
        { name: "numpy", version: "1.24.3", location: "/usr/local/lib/python3.11", requires: [], requiredBy: ["torch", "pandas"] },
        { name: "pandas", version: "2.0.3", location: "/usr/local/lib/python3.11", requires: ["numpy"], requiredBy: [] },
        { name: "matplotlib", version: "3.7.2", location: "/usr/local/lib/python3.11", requires: ["numpy"], requiredBy: [] },
        { name: "scikit-learn", version: "1.3.0", location: "/usr/local/lib/python3.11", requires: ["numpy"], requiredBy: [] },
        { name: "transformers", version: "4.35.0", location: "/usr/local/lib/python3.11", requires: ["torch"], requiredBy: [] },
        { name: "pillow", version: "10.0.0", location: "/usr/local/lib/python3.11", requires: [], requiredBy: ["matplotlib"] },
        { name: "requests", version: "2.31.0", location: "/usr/local/lib/python3.11", requires: [], requiredBy: [] },
      ]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Check for outdated packages
  const checkOutdatedPackages = useCallback(async () => {
    setIsCheckingUpdates(true);
    try {
      const outdated = await pipService.checkOutdated();
      setOutdatedPackages(outdated);
    } catch (error) {
      console.error("Failed to check outdated packages:", error);
      // Mock data
      setOutdatedPackages([
        { name: "numpy", currentVersion: "1.24.3", latestVersion: "1.26.0" },
        { name: "pandas", currentVersion: "2.0.3", latestVersion: "2.1.1" },
      ]);
    } finally {
      setIsCheckingUpdates(false);
    }
  }, []);

  // Search packages
  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    setIsSearching(true);
    try {
      const results = await pipService.searchPackages(searchQuery);
      setSearchResults(results);
    } catch (error) {
      console.error("Failed to search packages:", error);
      // Mock data
      setSearchResults([
        { name: searchQuery, version: "1.0.0", summary: "A Python package" },
        { name: `${searchQuery}-utils`, version: "0.5.0", summary: "Utilities for " + searchQuery },
        { name: `py${searchQuery}`, version: "2.0.0", summary: "Python wrapper for " + searchQuery },
      ]);
    } finally {
      setIsSearching(false);
    }
  };

  // Get package info
  const handleGetPackageInfo = async (packageName: string) => {
    try {
      const info = await pipService.getPackageInfo(packageName);
      setSelectedPackageInfo(info || {
        name: packageName,
        version: "1.0.0",
        summary: "A Python package",
        author: "Unknown",
        license: "MIT",
        homePage: `https://pypi.org/project/${packageName}`,
        requiresPython: ">=3.8",
        versions: ["1.0.0", "0.9.0", "0.8.0", "0.7.0", "0.6.0"],
      });
      setShowPackageInfo(true);
    } catch (error) {
      console.error("Failed to get package info:", error);
    }
  };

  // Install package
  const handleInstall = async (packageName: string, version?: string) => {
    setInstallingPackage(packageName);
    try {
      // Use streaming for progress
      for await (const progress of pipService.installWithProgress(packageName, version)) {
        setInstallProgress(progress);
      }

      showNotification("success", `Successfully installed ${packageName}`);
      await fetchInstalledPackages();
    } catch (error) {
      console.error("Failed to install package:", error);
      showNotification("error", `Failed to install ${packageName}`);
    } finally {
      setInstallingPackage(null);
      setInstallProgress(null);
    }
  };

  // Uninstall package
  const handleUninstall = async (packageName: string) => {
    if (!confirm(`Are you sure you want to uninstall "${packageName}"?`)) return;

    setInstallingPackage(packageName);
    try {
      await pipService.uninstallPackage(packageName);
      showNotification("success", `Successfully uninstalled ${packageName}`);
      await fetchInstalledPackages();
    } catch (error) {
      console.error("Failed to uninstall package:", error);
      showNotification("error", `Failed to uninstall ${packageName}`);
    } finally {
      setInstallingPackage(null);
    }
  };

  // Upgrade package
  const handleUpgrade = async (packageName: string) => {
    setInstallingPackage(packageName);
    try {
      await pipService.upgradePackage(packageName);
      showNotification("success", `Successfully upgraded ${packageName}`);
      await fetchInstalledPackages();
      await checkOutdatedPackages();
    } catch (error) {
      console.error("Failed to upgrade package:", error);
      showNotification("error", `Failed to upgrade ${packageName}`);
    } finally {
      setInstallingPackage(null);
    }
  };

  // Upgrade all packages
  const handleUpgradeAll = async () => {
    for (const pkg of outdatedPackages) {
      await handleUpgrade(pkg.name);
    }
  };

  // Filter installed packages
  const filteredInstalled = installedPackages.filter((pkg) =>
    pkg.name.toLowerCase().includes(filterQuery.toLowerCase())
  );

  // Check if package is installed
  const isInstalled = (name: string) => {
    return installedPackages.some(
      (p) => p.name.toLowerCase() === name.toLowerCase()
    );
  };

  // Check if package has update
  const hasUpdate = (name: string) => {
    return outdatedPackages.some((p) => p.name === name);
  };

  const getLatestVersion = (name: string) => {
    const outdated = outdatedPackages.find((p) => p.name === name);
    return outdated?.latestVersion;
  };

  // Initial load
  useEffect(() => {
    if (isOpen) {
      fetchInstalledPackages();
    }
  }, [isOpen, fetchInstalledPackages]);

  // Load updates when tab changes
  useEffect(() => {
    if (activeTab === "updates" && outdatedPackages.length === 0) {
      checkOutdatedPackages();
    }
  }, [activeTab, outdatedPackages.length, checkOutdatedPackages]);

  if (!isOpen) return null;

  return (
    <div className="flex flex-col h-full w-80 border-l border-border bg-card">
      {/* Notification */}
      {notification && (
        <div
          className={cn(
            "absolute top-2 right-2 z-50 flex items-center gap-2 rounded-lg px-3 py-2 shadow-lg",
            notification.type === "success"
              ? "bg-green-500/20 border border-green-500/30 text-green-500"
              : "bg-destructive/20 border border-destructive/30 text-destructive"
          )}
        >
          {notification.type === "success" ? (
            <CheckCircle className="h-4 w-4" />
          ) : (
            <AlertCircle className="h-4 w-4" />
          )}
          <span className="text-xs font-medium">{notification.message}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex items-center justify-between border-b border-border bg-muted/50 px-3 py-2">
        <div className="flex items-center gap-2">
          <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary/10">
            <Package className="h-4 w-4 text-primary" />
          </div>
          <span className="text-sm font-medium">Packages</span>
          <Badge variant="secondary" className="px-1.5 text-[10px]">
            {installedPackages.length}
          </Badge>
        </div>
        <div className="flex items-center gap-1">
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0"
            onClick={fetchInstalledPackages}
            disabled={isLoading}
          >
            <RefreshCw className={cn("h-4 w-4", isLoading && "animate-spin")} />
          </Button>
          <Button size="sm" variant="ghost" className="h-7 w-7 p-0" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as typeof activeTab)} className="flex-1 flex flex-col min-h-0">
        <TabsList className="w-full rounded-none border-b border-border bg-transparent h-9 shrink-0">
          <TabsTrigger value="installed" className="flex-1 text-[11px] gap-1 px-2 data-[state=active]:bg-transparent">
            <List className="h-3 w-3" />
            Installed
          </TabsTrigger>
          <TabsTrigger value="search" className="flex-1 text-[11px] gap-1 px-2 data-[state=active]:bg-transparent">
            <Search className="h-3 w-3" />
            PyPI
          </TabsTrigger>
          <TabsTrigger value="updates" className="flex-1 text-[11px] gap-1 px-2 data-[state=active]:bg-transparent">
            <ArrowUpCircle className="h-3 w-3" />
            Updates
            {outdatedPackages.length > 0 && (
              <Badge className="h-4 min-w-[16px] px-1 text-[9px] bg-amber-500 ml-0.5">
                {outdatedPackages.length}
              </Badge>
            )}
          </TabsTrigger>
        </TabsList>

        {/* Installed Tab */}
        <TabsContent value="installed" className="flex-1 m-0 flex flex-col">
          {/* Filter input */}
          <div className="p-2">
            <div className="relative">
              <Search className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Filter packages..."
                value={filterQuery}
                onChange={(e) => setFilterQuery(e.target.value)}
                className="pl-8 h-8 text-xs"
              />
            </div>
          </div>

          <ScrollArea className="flex-1">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                <p className="mt-3 text-sm text-muted-foreground">Loading packages...</p>
              </div>
            ) : filteredInstalled.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12">
                <Package className="h-10 w-10 text-muted-foreground/50" />
                <p className="mt-3 text-sm text-muted-foreground">No packages found</p>
              </div>
            ) : (
              <div className="px-2 pb-2 space-y-1">
                {filteredInstalled.map((pkg) => (
                  <PackageListItem
                    key={pkg.name}
                    name={pkg.name}
                    version={pkg.version}
                    isInstalled
                    isProcessing={installingPackage === pkg.name}
                    hasUpdate={hasUpdate(pkg.name)}
                    latestVersion={getLatestVersion(pkg.name)}
                    onInfo={() => handleGetPackageInfo(pkg.name)}
                    onUpgrade={() => handleUpgrade(pkg.name)}
                    onUninstall={() => handleUninstall(pkg.name)}
                  />
                ))}
              </div>
            )}
          </ScrollArea>
        </TabsContent>

        {/* Search Tab */}
        <TabsContent value="search" className="flex-1 m-0 flex flex-col">
          {/* Search input */}
          <div className="p-2 flex gap-1">
            <div className="relative flex-1">
              <Search className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search PyPI packages..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                className="pl-8 h-8 text-xs"
              />
            </div>
            <Button size="sm" onClick={handleSearch} disabled={isSearching} className="h-8 w-8 p-0">
              {isSearching ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Search className="h-3.5 w-3.5" />}
            </Button>
          </div>

          {/* Quick install chips */}
          <div className="px-2 pb-2">
            <div className="flex flex-wrap gap-1.5">
              {QUICK_INSTALL_PACKAGES.filter(p => !isInstalled(p)).slice(0, 6).map((pkg) => (
                <button
                  key={pkg}
                  onClick={() => handleInstall(pkg)}
                  disabled={installingPackage === pkg}
                  className="flex items-center gap-1 rounded-full border border-border bg-muted px-2.5 py-1 text-xs hover:bg-muted/80 transition-colors"
                >
                  {installingPackage === pkg ? (
                    <Loader2 className="h-3 w-3 animate-spin" />
                  ) : (
                    <Plus className="h-3 w-3" />
                  )}
                  {pkg}
                </button>
              ))}
            </div>
          </div>

          <ScrollArea className="flex-1">
            {isSearching ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : searchResults.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12">
                <Search className="h-10 w-10 text-muted-foreground/50" />
                <p className="mt-3 text-sm text-muted-foreground">
                  {searchQuery ? "No packages found" : "Search for packages on PyPI"}
                </p>
              </div>
            ) : (
              <div className="px-2 pb-2 space-y-1">
                {searchResults.map((pkg) => (
                  <PackageListItem
                    key={pkg.name}
                    name={pkg.name}
                    version={pkg.version}
                    summary={pkg.summary}
                    isInstalled={isInstalled(pkg.name)}
                    isProcessing={installingPackage === pkg.name}
                    onInfo={() => handleGetPackageInfo(pkg.name)}
                    onInstall={() => handleInstall(pkg.name)}
                  />
                ))}
              </div>
            )}
          </ScrollArea>
        </TabsContent>

        {/* Updates Tab */}
        <TabsContent value="updates" className="flex-1 m-0 flex flex-col">
          {isCheckingUpdates ? (
            <div className="flex flex-col items-center justify-center flex-1">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              <p className="mt-2 text-xs text-muted-foreground">Checking...</p>
            </div>
          ) : outdatedPackages.length === 0 ? (
            <div className="flex flex-col items-center justify-center flex-1">
              <CheckCircle className="h-8 w-8 text-green-500" />
              <p className="mt-2 text-xs font-medium">All up to date!</p>
              <Button
                variant="ghost"
                size="sm"
                className="mt-1 h-7 text-xs"
                onClick={checkOutdatedPackages}
              >
                <RefreshCw className="h-3 w-3 mr-1" />
                Check
              </Button>
            </div>
          ) : (
            <>
              {/* Upgrade all button */}
              <div className="p-2">
                <Button
                  className="w-full h-8 text-xs"
                  onClick={handleUpgradeAll}
                  disabled={installingPackage !== null}
                >
                  <ArrowUpCircle className="h-3.5 w-3.5 mr-1.5" />
                  Upgrade All ({outdatedPackages.length})
                </Button>
              </div>

              <ScrollArea className="flex-1">
                <div className="px-2 pb-2 space-y-1">
                  {outdatedPackages.map((pkg) => (
                    <div
                      key={pkg.name}
                      className="flex items-center gap-2 rounded-md border border-border bg-background p-2"
                    >
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs font-medium truncate">{pkg.name}</span>
                          <Badge variant="secondary" className="text-[9px] px-1 py-0 h-4">
                            {pkg.currentVersion}
                          </Badge>
                          <ArrowUp className="h-2.5 w-2.5 text-muted-foreground" />
                          <Badge className="text-[9px] px-1 py-0 h-4 bg-green-500/20 text-green-500">
                            {pkg.latestVersion}
                          </Badge>
                        </div>
                      </div>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => handleUpgrade(pkg.name)}
                        disabled={installingPackage === pkg.name}
                      >
                        {installingPackage === pkg.name ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <ArrowUpCircle className="h-3.5 w-3.5 text-primary" />
                        )}
                      </Button>
                    </div>
                  ))}
                </div>
              </ScrollArea>
            </>
          )}
        </TabsContent>
      </Tabs>

      {/* Install progress */}
      {installProgress && (
        <div className="p-3 border-t border-border bg-muted/30">
          <div className="flex items-center gap-2 text-xs mb-2">
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
            <span className="truncate">
              {installProgress.status === "downloading"
                ? `Downloading ${installProgress.package}...`
                : installProgress.status === "installing"
                ? `Installing ${installProgress.package}...`
                : installProgress.message}
            </span>
          </div>
          <div className="h-1.5 overflow-hidden rounded-full bg-muted">
            <div
              className="h-full bg-primary transition-all"
              style={{ width: `${installProgress.progress}%` }}
            />
          </div>
        </div>
      )}

      {/* Package Info Dialog */}
      <Dialog open={showPackageInfo} onOpenChange={setShowPackageInfo}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                <Package className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p>{selectedPackageInfo?.name}</p>
                <div className="flex items-center gap-2 mt-1">
                  <Badge className="bg-primary/20 text-primary">
                    v{selectedPackageInfo?.version}
                  </Badge>
                  {selectedPackageInfo?.license && (
                    <Badge variant="secondary" className="text-[10px]">
                      {selectedPackageInfo.license}
                    </Badge>
                  )}
                </div>
              </div>
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-4 mt-4">
            {selectedPackageInfo?.summary && (
              <p className="text-sm text-muted-foreground">
                {selectedPackageInfo.summary}
              </p>
            )}

            {selectedPackageInfo?.author && (
              <div className="flex items-center gap-2 text-sm">
                <User className="h-4 w-4 text-muted-foreground" />
                <span className="text-muted-foreground">Author:</span>
                <span>{selectedPackageInfo.author}</span>
              </div>
            )}

            {selectedPackageInfo?.requiresPython && (
              <div className="flex items-center gap-2 text-sm">
                <Code className="h-4 w-4 text-muted-foreground" />
                <span className="text-muted-foreground">Python:</span>
                <span>{selectedPackageInfo.requiresPython}</span>
              </div>
            )}

            {selectedPackageInfo?.homePage && (
              <div className="flex items-center gap-2 text-sm">
                <Globe className="h-4 w-4 text-muted-foreground" />
                <span className="text-muted-foreground">Homepage:</span>
                <a
                  href={selectedPackageInfo.homePage}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary hover:underline truncate"
                >
                  {selectedPackageInfo.homePage}
                </a>
              </div>
            )}

            {selectedPackageInfo?.versions && selectedPackageInfo.versions.length > 0 && (
              <div>
                <p className="text-sm font-medium mb-2">Available Versions</p>
                <div className="flex flex-wrap gap-1.5">
                  {selectedPackageInfo.versions.slice(0, 10).map((version) => {
                    const isLatest = version === selectedPackageInfo.version;
                    return (
                      <button
                        key={version}
                        onClick={() => {
                          setShowPackageInfo(false);
                          handleInstall(selectedPackageInfo.name, version);
                        }}
                        className={cn(
                          "rounded px-2 py-1 text-xs font-mono border transition-colors",
                          isLatest
                            ? "bg-green-500/15 border-green-500/30 text-green-500"
                            : "bg-muted border-border hover:bg-muted/80"
                        )}
                      >
                        {version}
                        {isLatest && " (latest)"}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-2 mt-6">
            <Button variant="outline" onClick={() => setShowPackageInfo(false)}>
              Close
            </Button>
            <Button onClick={() => {
              setShowPackageInfo(false);
              handleInstall(selectedPackageInfo!.name);
            }}>
              <Download className="h-4 w-4 mr-2" />
              Install Latest
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

interface PackageListItemProps {
  name: string;
  version: string;
  summary?: string;
  isInstalled: boolean;
  isProcessing?: boolean;
  hasUpdate?: boolean;
  latestVersion?: string;
  onInfo: () => void;
  onInstall?: () => void;
  onUpgrade?: () => void;
  onUninstall?: () => void;
}

const PackageListItem = ({
  name,
  version,
  summary,
  isInstalled,
  isProcessing,
  hasUpdate,
  latestVersion,
  onInfo,
  onInstall,
  onUpgrade,
  onUninstall,
}: PackageListItemProps) => {
  return (
    <div className="flex items-center gap-2 rounded-md border border-border bg-background p-2 hover:bg-muted/30 transition-colors">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <span className="text-xs font-medium truncate">{name}</span>
          <Badge variant="secondary" className="text-[9px] px-1 py-0 font-mono h-4">
            {version}
          </Badge>
          {hasUpdate && latestVersion && (
            <Badge className="text-[9px] px-1 py-0 h-4 bg-green-500/20 text-green-500 border-green-500/30">
              {latestVersion}
            </Badge>
          )}
        </div>
        {summary && !hasUpdate && (
          <p className="text-[10px] text-muted-foreground truncate mt-0.5">
            {summary}
          </p>
        )}
      </div>

      <div className="flex items-center">
        {isProcessing ? (
          <Loader2 className="h-3.5 w-3.5 animate-spin" />
        ) : (
          <>
            {hasUpdate && onUpgrade && (
              <Button
                size="sm"
                variant="ghost"
                className="h-6 w-6 p-0"
                onClick={onUpgrade}
              >
                <ArrowUp className="h-3 w-3 text-green-500" />
              </Button>
            )}

            {!isInstalled && onInstall && (
              <Button
                size="sm"
                className="h-6 w-6 p-0"
                onClick={onInstall}
              >
                <Download className="h-3 w-3" />
              </Button>
            )}

            {isInstalled && onUninstall && (
              <Button
                size="sm"
                variant="ghost"
                className="h-6 w-6 p-0 text-destructive hover:text-destructive"
                onClick={onUninstall}
              >
                <Trash2 className="h-3 w-3" />
              </Button>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default PackageManagerPanel;
