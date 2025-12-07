import { Home, Database, RefreshCw } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface KaggleBreadcrumbProps {
  datasetCount?: number;
  competitionCount?: number;
  onRefresh?: () => void;
}

export const KaggleBreadcrumb = ({
  datasetCount = 0,
  competitionCount = 0,
  onRefresh,
}: KaggleBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Kaggle", icon: <Database className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* Stats */}
      <div className="flex items-center gap-3 mr-2">
        <span className="text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{datasetCount}</span> Datasets
        </span>
        <span className="text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{competitionCount}</span> Competitions
        </span>
      </div>

      {/* Refresh Button */}
      <Button size="sm" variant="outline" onClick={onRefresh} className="gap-1.5">
        <RefreshCw className="h-4 w-4" />
        Refresh
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
