import { useState, useMemo } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { NOTEBOOK_SHORTCUTS, formatShortcut } from "@/hooks/useKeyboardShortcuts";
import { Keyboard, Search, X } from "lucide-react";
import { cn } from "@/lib/utils";

interface KeyboardShortcutsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export const KeyboardShortcutsDialog = ({
  open,
  onOpenChange,
}: KeyboardShortcutsDialogProps) => {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  // Get all categories
  const categories = useMemo(() => {
    const cats = new Set(NOTEBOOK_SHORTCUTS.map((s) => s.category));
    return Array.from(cats);
  }, []);

  // Group and filter shortcuts
  const groupedShortcuts = useMemo(() => {
    const filtered = NOTEBOOK_SHORTCUTS.filter((shortcut) => {
      const matchesSearch =
        searchQuery === "" ||
        shortcut.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        shortcut.key.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCategory =
        selectedCategory === null || shortcut.category === selectedCategory;
      return matchesSearch && matchesCategory;
    });

    return filtered.reduce(
      (acc, shortcut) => {
        if (!acc[shortcut.category]) {
          acc[shortcut.category] = [];
        }
        acc[shortcut.category].push(shortcut);
        return acc;
      },
      {} as Record<string, typeof NOTEBOOK_SHORTCUTS>
    );
  }, [searchQuery, selectedCategory]);

  const totalShortcuts = Object.values(groupedShortcuts).flat().length;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
              <Keyboard className="h-4 w-4 text-primary" />
            </div>
            <span>Keyboard Shortcuts</span>
            <span className="ml-2 rounded-full bg-muted px-2 py-0.5 text-xs text-muted-foreground">
              {totalShortcuts} shortcuts
            </span>
          </DialogTitle>
        </DialogHeader>

        {/* Search and Filter */}
        <div className="flex gap-2">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search shortcuts..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>
        </div>

        {/* Category Pills */}
        <div className="flex flex-wrap gap-1.5">
          <Button
            size="sm"
            variant={selectedCategory === null ? "default" : "outline"}
            className="h-7 text-xs"
            onClick={() => setSelectedCategory(null)}
          >
            All
          </Button>
          {categories.map((category) => (
            <Button
              key={category}
              size="sm"
              variant={selectedCategory === category ? "default" : "outline"}
              className="h-7 text-xs"
              onClick={() => setSelectedCategory(category)}
            >
              {category}
            </Button>
          ))}
        </div>

        <ScrollArea className="max-h-[50vh]">
          <div className="space-y-6 pr-4">
            {Object.keys(groupedShortcuts).length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-muted-foreground">
                <Keyboard className="mb-2 h-8 w-8" />
                <p className="text-sm">No shortcuts found</p>
                <p className="text-xs">Try a different search term</p>
              </div>
            ) : (
              Object.entries(groupedShortcuts).map(([category, shortcuts]) => (
                <div key={category}>
                  <h3 className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-primary">
                    {category}
                    <span className="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-normal normal-case text-primary">
                      {shortcuts.length}
                    </span>
                  </h3>
                  <div className="space-y-1">
                    {shortcuts.map((shortcut, index) => (
                      <div
                        key={index}
                        className="group flex items-center justify-between rounded-md px-3 py-2 transition-colors hover:bg-muted"
                      >
                        <span className="text-sm text-foreground">
                          {shortcut.description}
                        </span>
                        <ShortcutBadge shortcut={shortcut} />
                      </div>
                    ))}
                  </div>
                </div>
              ))
            )}
          </div>
        </ScrollArea>

        <div className="flex items-center justify-between border-t pt-4">
          <div className="text-xs text-muted-foreground">
            Press <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono">Ctrl + /</kbd> to toggle this dialog
          </div>
          <Button size="sm" variant="ghost" onClick={() => onOpenChange(false)}>
            Close
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

// Shortcut badge component with visual keys
const ShortcutBadge = ({ shortcut }: { shortcut: (typeof NOTEBOOK_SHORTCUTS)[0] }) => {
  const parts = formatShortcut(shortcut).split(" + ");

  return (
    <div className="flex items-center gap-1">
      {parts.map((part, index) => (
        <span key={index} className="flex items-center gap-1">
          <kbd className="inline-flex h-6 min-w-[24px] items-center justify-center rounded border border-border bg-muted px-1.5 font-mono text-[11px] font-medium text-foreground shadow-sm">
            {part}
          </kbd>
          {index < parts.length - 1 && (
            <span className="text-xs text-muted-foreground">+</span>
          )}
        </span>
      ))}
    </div>
  );
};

export default KeyboardShortcutsDialog;
