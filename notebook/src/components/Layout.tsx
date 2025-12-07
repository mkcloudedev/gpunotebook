import { Outlet, useLocation } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { AppHeader } from "./AppHeader";

interface LayoutProps {
  title?: string;
}

export const Layout = ({ title }: LayoutProps) => {
  const location = useLocation();

  // Hide GPU status in header when on GPU Monitor page (it has its own display)
  const hideGpuStatus = location.pathname === "/gpu";

  return (
    <div className="flex h-screen bg-background">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <AppHeader title={title} hideGpuStatus={hideGpuStatus} />
        <Outlet />
      </div>
    </div>
  );
};
