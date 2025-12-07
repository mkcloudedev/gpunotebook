import { Home, FolderOpen, FolderPlus, Upload, RefreshCw } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";

interface FilesBreadcrumbProps {
  onNewFolder?: () => void;
  onUpload?: () => void;
  onRefresh?: () => void;
}

export const FilesBreadcrumb = ({
  onNewFolder,
  onUpload,
  onRefresh,
}: FilesBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Files", icon: <FolderOpen className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-2">
      {/* Refresh Button */}
      <Button size="sm" variant="ghost" onClick={onRefresh} className="h-8 w-8 p-0">
        <RefreshCw className="h-4 w-4" />
      </Button>

      {/* New Folder Button */}
      <Button size="sm" variant="outline" onClick={onNewFolder} className="gap-1.5">
        <FolderPlus className="h-4 w-4" />
        New Folder
      </Button>

      {/* Upload Button */}
      <Button size="sm" onClick={onUpload} className="gap-1.5">
        <Upload className="h-4 w-4" />
        Upload
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
