import { useState, useCallback } from "react";
import {
  AlertCircle,
  CheckSquare,
  SkipForward,
  Clock,
  TestTube2,
  Settings,
  Trash2,
  LineChart,
  Database,
  Brain,
  Tag,
  Plus,
  X,
  Check,
  Edit3,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  CellTag,
  CellTagType,
  PREDEFINED_TAGS,
  TAG_COLOR_OPTIONS,
} from "@/types/notebook";

interface CellTagsWidgetProps {
  tags: CellTag[];
  onAddTag: (tag: CellTag) => void;
  onRemoveTag: (tag: CellTag) => void;
  isEditable?: boolean;
}

// Get icon for tag type
const getTagIcon = (type: CellTagType) => {
  const iconClass = "h-2.5 w-2.5";
  switch (type) {
    case "important":
      return <AlertCircle className={iconClass} />;
    case "todo":
      return <CheckSquare className={iconClass} />;
    case "skip":
      return <SkipForward className={iconClass} />;
    case "slow":
      return <Clock className={iconClass} />;
    case "test":
      return <TestTube2 className={iconClass} />;
    case "setup":
      return <Settings className={iconClass} />;
    case "cleanup":
      return <Trash2 className={iconClass} />;
    case "visualization":
      return <LineChart className={iconClass} />;
    case "dataLoad":
      return <Database className={iconClass} />;
    case "model":
      return <Brain className={iconClass} />;
    case "custom":
    default:
      return <Tag className={iconClass} />;
  }
};

// Tag chip component
const TagChip = ({
  tag,
  onRemove,
}: {
  tag: CellTag;
  onRemove?: () => void;
}) => {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <div
      className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium transition-all"
      style={{
        backgroundColor: `${tag.color}20`,
        borderColor: `${tag.color}40`,
        color: tag.color,
        borderWidth: 1,
      }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {getTagIcon(tag.type)}
      <span>{tag.label}</span>
      {onRemove && isHovered && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            onRemove();
          }}
          className="ml-0.5 rounded-full hover:bg-black/10"
        >
          <X className="h-2.5 w-2.5" />
        </button>
      )}
    </div>
  );
};

// Add tag button with dropdown
const AddTagButton = ({
  existingTags,
  onAddTag,
}: {
  existingTags: CellTag[];
  onAddTag: (tag: CellTag) => void;
}) => {
  const [showCustomDialog, setShowCustomDialog] = useState(false);

  const predefinedTagTypes = Object.keys(PREDEFINED_TAGS) as Exclude<CellTagType, "custom">[];

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button
            className="inline-flex items-center gap-0.5 rounded border border-border bg-muted/50 px-1.5 py-0.5 text-[10px] text-muted-foreground transition-colors hover:bg-muted"
            onClick={(e) => e.stopPropagation()}
          >
            <Plus className="h-2.5 w-2.5" />
            <span>Tag</span>
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-48">
          <div className="px-2 py-1.5 text-[10px] font-bold uppercase tracking-wide text-muted-foreground">
            Predefined Tags
          </div>
          {predefinedTagTypes.map((type) => {
            const tag = PREDEFINED_TAGS[type];
            const isAlreadyAdded = existingTags.some((t) => t.type === type);

            return (
              <DropdownMenuItem
                key={type}
                disabled={isAlreadyAdded}
                onClick={() => !isAlreadyAdded && onAddTag(tag)}
                className="flex items-center gap-2"
              >
                <div
                  className="flex h-4 w-4 items-center justify-center rounded"
                  style={{ backgroundColor: `${tag.color}20` }}
                >
                  <span style={{ color: tag.color }}>{getTagIcon(tag.type)}</span>
                </div>
                <span className="flex-1 text-xs">{tag.label}</span>
                {isAlreadyAdded && (
                  <Check className="h-3 w-3 text-success" />
                )}
              </DropdownMenuItem>
            );
          })}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            onClick={() => setShowCustomDialog(true)}
            className="flex items-center gap-2 text-primary"
          >
            <Edit3 className="h-3.5 w-3.5" />
            <span className="text-xs font-medium">Create Custom Tag...</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <CustomTagDialog
        open={showCustomDialog}
        onOpenChange={setShowCustomDialog}
        onCreateTag={onAddTag}
      />
    </>
  );
};

// Custom tag creation dialog
const CustomTagDialog = ({
  open,
  onOpenChange,
  onCreateTag,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreateTag: (tag: CellTag) => void;
}) => {
  const [tagName, setTagName] = useState("");
  const [selectedColor, setSelectedColor] = useState(TAG_COLOR_OPTIONS[0]);

  const handleCreate = useCallback(() => {
    if (tagName.trim()) {
      onCreateTag({
        label: tagName.trim(),
        type: "custom",
        color: selectedColor,
      });
      setTagName("");
      setSelectedColor(TAG_COLOR_OPTIONS[0]);
      onOpenChange(false);
    }
  }, [tagName, selectedColor, onCreateTag, onOpenChange]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[320px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
              <Tag className="h-4 w-4 text-primary" />
            </div>
            Create Custom Tag
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Tag name input */}
          <div className="space-y-2">
            <label className="text-xs font-medium">Tag Name</label>
            <Input
              value={tagName}
              onChange={(e) => setTagName(e.target.value)}
              placeholder="Enter tag name..."
              className="h-8 text-sm"
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  handleCreate();
                }
              }}
            />
          </div>

          {/* Color picker */}
          <div className="space-y-2">
            <label className="text-xs font-medium">Tag Color</label>
            <div className="flex flex-wrap gap-2">
              {TAG_COLOR_OPTIONS.map((color) => (
                <button
                  key={color}
                  className={cn(
                    "h-7 w-7 rounded-md transition-all",
                    selectedColor === color
                      ? "ring-2 ring-foreground ring-offset-2 ring-offset-background"
                      : "hover:scale-110"
                  )}
                  style={{ backgroundColor: color }}
                  onClick={() => setSelectedColor(color)}
                >
                  {selectedColor === color && (
                    <Check className="mx-auto h-3.5 w-3.5 text-white" />
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Preview */}
          <div className="space-y-2">
            <label className="text-xs font-medium">Preview</label>
            <div className="flex items-center rounded-md border border-border bg-muted/30 p-3">
              <div
                className="inline-flex items-center gap-1 rounded px-2 py-1 text-xs font-medium"
                style={{
                  backgroundColor: `${selectedColor}20`,
                  borderColor: `${selectedColor}40`,
                  color: selectedColor,
                  borderWidth: 1,
                }}
              >
                <Tag className="h-3 w-3" />
                <span>{tagName || "Custom Tag"}</span>
              </div>
            </div>
          </div>

          {/* Buttons */}
          <div className="flex justify-end gap-2 pt-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button size="sm" onClick={handleCreate} disabled={!tagName.trim()}>
              Create
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

// Main component
export const CellTagsWidget = ({
  tags,
  onAddTag,
  onRemoveTag,
  isEditable = true,
}: CellTagsWidgetProps) => {
  if (tags.length === 0 && !isEditable) {
    return null;
  }

  return (
    <div className="flex flex-wrap items-center gap-1">
      {tags.map((tag, index) => (
        <TagChip
          key={`${tag.type}-${tag.label}-${index}`}
          tag={tag}
          onRemove={isEditable ? () => onRemoveTag(tag) : undefined}
        />
      ))}
      {isEditable && (
        <AddTagButton existingTags={tags} onAddTag={onAddTag} />
      )}
    </div>
  );
};

export default CellTagsWidget;
