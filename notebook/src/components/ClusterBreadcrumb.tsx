import { Home, Server, Plus } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface ClusterBreadcrumbProps {
  nodeCount?: number;
  onlineCount?: number;
  onAddNode?: () => void;
}

export const ClusterBreadcrumb = ({
  nodeCount = 0,
  onlineCount = 0,
  onAddNode,
}: ClusterBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Cluster", icon: <Server className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* Stats */}
      <div className="flex items-center gap-3 mr-2">
        <span className="text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{nodeCount}</span> Nodes
        </span>
        <span className="text-xs text-green-500">
          <span className="font-medium">{onlineCount}</span> Online
        </span>
      </div>

      {/* Add Node Button */}
      <Button size="sm" onClick={onAddNode} className="gap-1.5">
        <Plus className="h-4 w-4" />
        Add Node
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
