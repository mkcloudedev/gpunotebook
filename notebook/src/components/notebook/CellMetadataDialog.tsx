import { useState } from "react";
import { Info, EyeOff, Lock, Trash2, X } from "lucide-react";
import { Cell, CellMetadata, DEFAULT_CELL_METADATA } from "@/types/notebook";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

interface CellMetadataDialogProps {
  cell: Cell;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (cellId: string, metadata: CellMetadata) => void;
}

export const CellMetadataDialog = ({
  cell,
  open,
  onOpenChange,
  onSave,
}: CellMetadataDialogProps) => {
  const metadata = cell.metadata || DEFAULT_CELL_METADATA;

  const [name, setName] = useState(metadata.name || "");
  const [hidden, setHidden] = useState(metadata.hidden);
  const [editable, setEditable] = useState(metadata.editable);
  const [deletable, setDeletable] = useState(metadata.deletable);

  const handleSave = () => {
    const newMetadata: CellMetadata = {
      hidden,
      editable,
      deletable,
      name: name.trim() || undefined,
      createdAt: metadata.createdAt,
      lastModified: new Date().toISOString(),
      custom: metadata.custom,
    };
    onSave(cell.id, newMetadata);
    onOpenChange(false);
  };

  const lineCount = cell.source.split("\n").length;
  const charCount = cell.source.length;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[400px]">
        <DialogHeader>
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
              <Info className="h-4 w-4 text-primary" />
            </div>
            <div>
              <DialogTitle className="text-base">Cell Metadata</DialogTitle>
              <p className="text-xs text-muted-foreground font-mono mt-0.5">
                Cell ID: {cell.id}
              </p>
            </div>
          </div>
        </DialogHeader>

        <div className="space-y-4 mt-4">
          {/* Cell name */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-foreground">
              Cell Name (Optional)
            </label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Give this cell a name..."
              className="h-9"
            />
          </div>

          {/* Properties */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-foreground">
              Properties
            </label>
            <div className="rounded-lg border border-border bg-background">
              <PropertySwitch
                icon={<EyeOff className="h-4 w-4" />}
                label="Hidden"
                description="Hide cell in read-only view"
                value={hidden}
                onChange={setHidden}
              />
              <div className="border-t border-border" />
              <PropertySwitch
                icon={<Lock className="h-4 w-4" />}
                label="Editable"
                description="Allow editing cell content"
                value={editable}
                onChange={setEditable}
              />
              <div className="border-t border-border" />
              <PropertySwitch
                icon={<Trash2 className="h-4 w-4" />}
                label="Deletable"
                description="Allow deleting this cell"
                value={deletable}
                onChange={setDeletable}
              />
            </div>
          </div>

          {/* Info section */}
          <div className="rounded-lg bg-muted/50 p-3 space-y-2">
            <div className="flex items-center gap-2">
              <Info className="h-3.5 w-3.5 text-muted-foreground" />
              <span className="text-xs font-medium text-muted-foreground">
                Cell Information
              </span>
            </div>
            <div className="space-y-1">
              <InfoRow label="Type" value={cell.cellType.toUpperCase()} />
              <InfoRow label="Status" value={cell.isExecuting ? "running" : "idle"} />
              {cell.executionCount && (
                <InfoRow label="Execution #" value={String(cell.executionCount)} />
              )}
              <InfoRow label="Lines" value={String(lineCount)} />
              <InfoRow label="Characters" value={String(charCount)} />
            </div>
          </div>

          {/* Buttons */}
          <div className="flex justify-end gap-2 pt-2">
            <Button
              variant="ghost"
              onClick={() => onOpenChange(false)}
              className="h-9"
            >
              Cancel
            </Button>
            <Button onClick={handleSave} className="h-9">
              Save
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

interface PropertySwitchProps {
  icon: React.ReactNode;
  label: string;
  description: string;
  value: boolean;
  onChange: (value: boolean) => void;
}

const PropertySwitch = ({
  icon,
  label,
  description,
  value,
  onChange,
}: PropertySwitchProps) => {
  return (
    <div className="flex items-center gap-3 px-3 py-2.5">
      <span className="text-muted-foreground">{icon}</span>
      <div className="flex-1">
        <p className="text-sm font-medium text-foreground">{label}</p>
        <p className="text-xs text-muted-foreground">{description}</p>
      </div>
      <Switch checked={value} onCheckedChange={onChange} />
    </div>
  );
};

interface InfoRowProps {
  label: string;
  value: string;
}

const InfoRow = ({ label, value }: InfoRowProps) => {
  return (
    <div className="flex items-center">
      <span className="w-24 text-[11px] text-muted-foreground">{label}</span>
      <span className="text-[11px] font-mono text-foreground">{value}</span>
    </div>
  );
};

export default CellMetadataDialog;
