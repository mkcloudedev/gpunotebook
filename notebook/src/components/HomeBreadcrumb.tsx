import { Home, FileCode, Cpu, RefreshCw, Plus } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface HomeBreadcrumbProps {
  notebookCount?: number;
  kernelCount?: number;
  onRefresh?: () => void;
}

export const HomeBreadcrumb = ({
  notebookCount = 0,
  kernelCount = 0,
  onRefresh,
}: HomeBreadcrumbProps) => {
  const navigate = useNavigate();

  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* Stats */}
      <div className="flex items-center gap-3 mr-2">
        <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <FileCode className="h-3.5 w-3.5" />
          <span className="font-medium text-foreground">{notebookCount}</span> Notebooks
        </span>
        <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <Cpu className="h-3.5 w-3.5" />
          <span className="font-medium text-foreground">{kernelCount}</span> Kernels
        </span>
      </div>

      {/* Refresh Button */}
      <Button size="sm" variant="ghost" onClick={onRefresh} className="h-8 w-8 p-0">
        <RefreshCw className="h-4 w-4" />
      </Button>

      {/* New Notebook Button */}
      <Button size="sm" onClick={() => navigate("/notebooks")} className="gap-1.5">
        <Plus className="h-4 w-4" />
        New Notebook
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
