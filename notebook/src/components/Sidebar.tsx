import { useState } from "react";
import { Home, Sparkles, Settings as SettingsIcon, FileText, LayoutDashboard, ChevronRight, ExternalLink, Key, FileCode, MessageSquare, Brain, Cpu, FolderOpen, Database, Server, HelpCircle } from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";

interface NavItemProps {
  icon: React.ReactNode;
  label: string;
  to?: string;
  active?: boolean;
  badge?: string;
  hasChevron?: boolean;
  external?: boolean;
  collapsed?: boolean;
}

const NavItem = ({ icon, label, to, active, badge, hasChevron, external, collapsed }: NavItemProps) => {
  const content = (
    <>
      {icon}
      {!collapsed && (
        <>
          <span className="flex-1 text-left">{label}</span>
          {badge && (
            <span className="rounded bg-secondary px-2 py-0.5 text-xs text-muted-foreground">
              {badge}
            </span>
          )}
          {hasChevron && <ChevronRight className="h-4 w-4 text-muted-foreground" />}
          {external && <ExternalLink className="h-3.5 w-3.5 text-muted-foreground" />}
        </>
      )}
    </>
  );

  const className = cn(
    "flex w-full items-center rounded-lg px-3 py-2 text-sm transition-colors",
    collapsed ? "justify-center" : "gap-3",
    active
      ? "bg-sidebar-accent text-sidebar-accent-foreground"
      : "text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
  );

  if (to) {
    return (
      <Link to={to} className={className} title={collapsed ? label : undefined}>
        {content}
      </Link>
    );
  }

  return (
    <button className={className} title={collapsed ? label : undefined}>
      {content}
    </button>
  );
};

interface SidebarProps {
  activePage?: string;
}

export const Sidebar = ({ activePage }: SidebarProps) => {
  const [collapsed, setCollapsed] = useState(false);
  const location = useLocation();
  const currentPage = activePage || (location.pathname === "/" ? "home" : location.pathname.slice(1));

  return (
    <aside className={cn(
      "flex h-screen flex-col border-r border-border bg-sidebar transition-all duration-300",
      collapsed ? "w-16" : "w-40"
    )}>
      {/* Logo - GPU icon clickable to toggle */}
      <div className={cn(
        "flex items-center py-4",
        collapsed ? "justify-center px-2" : "gap-2 px-4"
      )}>
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 hover:bg-primary/20 transition-colors"
          title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          <Cpu className="h-5 w-5 text-primary" />
        </button>
        {!collapsed && (
          <span className="text-sm font-semibold text-foreground">GPU Notebook</span>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 px-2">
        <NavItem icon={<Home className="h-4 w-4" />} label="Home" to="/" active={currentPage === "home"} collapsed={collapsed} />
        <NavItem icon={<FileCode className="h-4 w-4" />} label="Notebooks" to="/notebooks" active={currentPage === "notebooks"} collapsed={collapsed} />
        <NavItem icon={<Sparkles className="h-4 w-4" />} label="Playground" to="/playground" active={currentPage === "playground"} collapsed={collapsed} />
        <NavItem icon={<MessageSquare className="h-4 w-4" />} label="AI Assistant" to="/ai-assistant" active={currentPage === "ai-assistant"} collapsed={collapsed} />
        <NavItem icon={<Brain className="h-4 w-4" />} label="AutoML" to="/automl" active={currentPage === "automl"} collapsed={collapsed} />
        <NavItem icon={<Cpu className="h-4 w-4" />} label="GPU Monitor" to="/gpu" active={currentPage === "gpu"} collapsed={collapsed} />
        <NavItem icon={<FolderOpen className="h-4 w-4" />} label="Files" to="/files" active={currentPage === "files"} collapsed={collapsed} />
        <NavItem icon={<Database className="h-4 w-4" />} label="Kaggle" to="/kaggle" active={currentPage === "kaggle"} collapsed={collapsed} />
        <NavItem icon={<Server className="h-4 w-4" />} label="Cluster" to="/cluster" active={currentPage === "cluster"} collapsed={collapsed} />
      </nav>

      {/* Footer */}
      <div className="border-t border-border p-2 space-y-1">
        <NavItem icon={<SettingsIcon className="h-4 w-4" />} label="Settings" to="/settings" active={currentPage === "settings"} collapsed={collapsed} />
        <NavItem icon={<HelpCircle className="h-4 w-4" />} label="Help" to="/help" active={currentPage === "help"} collapsed={collapsed} />
      </div>
    </aside>
  );
};
