import { Home, HelpCircle } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";

export const HelpBreadcrumb = () => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "Help", icon: <HelpCircle className="h-4 w-4" /> },
  ];

  return <Breadcrumb items={breadcrumbItems} />;
};
