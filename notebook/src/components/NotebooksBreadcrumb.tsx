import { Search, Upload, Plus, Home, FileCode } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";
import { Input } from "./ui/input";

interface NotebooksBreadcrumbProps {
  onSearch?: (query: string) => void;
  onImport?: () => void;
  onNew?: () => void;
}

export const NotebooksBreadcrumb = ({
  onSearch,
  onImport,
  onNew,
}: NotebooksBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Notebooks", icon: <FileCode className="h-4 w-4" /> },
  ];

  const actions = (
    <div className="flex items-center gap-3">
      {/* Search */}
      <div className="relative">
        <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          placeholder="Search..."
          className="h-8 w-48 pl-8 text-sm"
          onChange={(e) => onSearch?.(e.target.value)}
        />
      </div>

      {/* Import */}
      <Button variant="outline" size="sm" className="gap-1.5" onClick={onImport}>
        <Upload className="h-4 w-4" />
        Import
      </Button>

      {/* New */}
      <Button size="sm" className="gap-1.5" onClick={onNew}>
        <Plus className="h-4 w-4" />
        New
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
