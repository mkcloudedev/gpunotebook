import { cn } from "@/lib/utils";
import { LucideIcon } from "lucide-react";

interface FeatureCardProps {
  icon: LucideIcon;
  title: string;
  description?: string;
  className?: string;
  variant?: "default" | "compact";
}

export const FeatureCard = ({
  icon: Icon,
  title,
  description,
  className,
  variant = "default",
}: FeatureCardProps) => {
  return (
    <button
      className={cn(
        "group flex items-center gap-4 rounded-xl border border-border bg-card p-4 text-left transition-all hover:border-muted-foreground/30 hover:bg-accent",
        variant === "compact" && "p-4",
        className
      )}
    >
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
        <Icon className="h-5 w-5 text-muted-foreground" />
      </div>
      <div className="min-w-0 flex-1">
        <h3 className="font-medium text-card-foreground">{title}</h3>
        {description && (
          <p className="mt-0.5 text-sm text-muted-foreground">{description}</p>
        )}
      </div>
    </button>
  );
};
