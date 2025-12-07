import { Home, Brain, Plus, Sparkles, RefreshCw } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface AutoMLBreadcrumbProps {
  algorithmCount?: number;
  experimentCount?: number;
  onNewExperiment?: () => void;
  onGetRecommendations?: () => void;
  onRefresh?: () => void;
}

export const AutoMLBreadcrumb = ({
  algorithmCount = 0,
  experimentCount = 0,
  onNewExperiment,
  onGetRecommendations,
  onRefresh,
}: AutoMLBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "AutoML", icon: <Brain className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* Stats */}
      <div className="flex items-center gap-3 mr-2">
        <span className="text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{algorithmCount}</span> Algorithms
        </span>
        <span className="text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{experimentCount}</span> Experiments
        </span>
      </div>

      {/* Refresh Button */}
      <Button size="sm" variant="ghost" onClick={onRefresh} className="h-8 w-8 p-0">
        <RefreshCw className="h-4 w-4" />
      </Button>

      {/* Get Recommendations Button */}
      <Button size="sm" variant="outline" onClick={onGetRecommendations} className="gap-1.5">
        <Sparkles className="h-4 w-4" />
        Recommendations
      </Button>

      {/* New Experiment Button */}
      <Button size="sm" onClick={onNewExperiment} className="gap-1.5">
        <Plus className="h-4 w-4" />
        New Experiment
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
