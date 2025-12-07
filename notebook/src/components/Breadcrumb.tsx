import { ChevronRight } from "lucide-react";
import { Link } from "react-router-dom";
import { cn } from "@/lib/utils";

export interface BreadcrumbItem {
  label: string;
  href?: string;
  icon?: React.ReactNode;
}

interface BreadcrumbProps {
  items: BreadcrumbItem[];
  actions?: React.ReactNode;
  className?: string;
}

export const Breadcrumb = ({ items, actions, className }: BreadcrumbProps) => {
  return (
    <div className={cn("flex items-center justify-between border-b border-border bg-card px-2 py-1.5", className)}>
      {/* Breadcrumb items */}
      <div className="flex items-center gap-1">
        {items.map((item, index) => (
          <div key={index} className="flex items-center gap-1">
            {index > 0 && (
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
            )}
            {item.href ? (
              <Link
                to={item.href}
                className="flex items-center gap-2 rounded-md px-2 py-1 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
              >
                {item.icon}
                <span>{item.label}</span>
              </Link>
            ) : (
              <span className="flex items-center gap-2 px-2 py-1 text-sm font-medium text-foreground">
                {item.icon}
                <span>{item.label}</span>
              </span>
            )}
          </div>
        ))}
      </div>

      {/* Actions */}
      {actions && (
        <div className="flex items-center gap-2">
          {actions}
        </div>
      )}
    </div>
  );
};
