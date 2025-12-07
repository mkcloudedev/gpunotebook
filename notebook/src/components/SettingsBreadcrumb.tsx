import { Home, Settings } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";

export const SettingsBreadcrumb = () => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Settings", icon: <Settings className="h-4 w-4" /> },
  ];

  return <Breadcrumb items={breadcrumbItems} />;
};
