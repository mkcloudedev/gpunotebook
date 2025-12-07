import { useState, useMemo } from "react";
import { Clock, BarChart2, ChevronDown, ChevronRight, Zap } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export interface LineProfile {
  lineNumber: number;
  code: string;
  hits: number;
  timeMs: number;
  percentage: number;
}

export interface CellProfile {
  cellId: string;
  totalTimeMs: number;
  peakMemoryMb?: number;
  lines?: LineProfile[];
  timestamp: Date;
}

interface CellProfilerProps {
  profile?: CellProfile;
  executionDuration?: number;
  isVisible?: boolean;
  onToggle?: () => void;
}

// Format time in human-readable format
const formatTime = (ms: number): string => {
  if (ms < 1) {
    return `${(ms * 1000).toFixed(0)}µs`;
  } else if (ms < 1000) {
    return `${ms.toFixed(1)}ms`;
  } else if (ms < 60000) {
    return `${(ms / 1000).toFixed(2)}s`;
  } else {
    const mins = Math.floor(ms / 60000);
    const secs = ((ms % 60000) / 1000).toFixed(0);
    return `${mins}m ${secs}s`;
  }
};

// Format memory
const formatMemory = (mb: number): string => {
  if (mb < 1) {
    return `${(mb * 1024).toFixed(0)} KB`;
  } else if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  } else {
    return `${(mb / 1024).toFixed(2)} GB`;
  }
};

export const CellProfiler = ({
  profile,
  executionDuration,
  isVisible = false,
  onToggle,
}: CellProfilerProps) => {
  const [isExpanded, setIsExpanded] = useState(false);

  // Calculate stats
  const stats = useMemo(() => {
    if (!profile?.lines || profile.lines.length === 0) {
      return null;
    }

    const sortedByTime = [...profile.lines].sort((a, b) => b.timeMs - a.timeMs);
    const hotspots = sortedByTime.slice(0, 3);
    const avgTimePerLine = profile.totalTimeMs / profile.lines.length;

    return {
      hotspots,
      avgTimePerLine,
      slowestLine: sortedByTime[0],
    };
  }, [profile]);

  if (!profile && !executionDuration) {
    return null;
  }

  // Simple duration display (no line profiling)
  if (!profile?.lines && executionDuration) {
    return (
      <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
        <Clock className="h-3 w-3" />
        <span>{formatTime(executionDuration)}</span>
      </div>
    );
  }

  // Minimal view - just icon and time
  if (!isVisible) {
    return (
      <Button
        variant="ghost"
        size="sm"
        className="h-5 gap-1 px-1.5"
        onClick={onToggle}
      >
        <BarChart2 className="h-3 w-3 text-muted-foreground" />
        <span className="text-[10px] text-muted-foreground">
          {profile ? formatTime(profile.totalTimeMs) : formatTime(executionDuration || 0)}
        </span>
      </Button>
    );
  }

  return (
    <div className="border-t border-border bg-muted/20">
      {/* Header */}
      <div
        className="flex cursor-pointer items-center gap-2 px-3 py-1.5 hover:bg-muted/30"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        {isExpanded ? (
          <ChevronDown className="h-3 w-3 text-muted-foreground" />
        ) : (
          <ChevronRight className="h-3 w-3 text-muted-foreground" />
        )}
        <BarChart2 className="h-3.5 w-3.5 text-primary" />
        <span className="text-xs font-medium">Cell Profile</span>

        <div className="flex-1" />

        {/* Quick stats */}
        <div className="flex items-center gap-3 text-[10px] text-muted-foreground">
          <span className="flex items-center gap-1">
            <Clock className="h-2.5 w-2.5" />
            {formatTime(profile?.totalTimeMs || executionDuration || 0)}
          </span>
          {profile?.peakMemoryMb && (
            <span className="flex items-center gap-1">
              <Zap className="h-2.5 w-2.5" />
              {formatMemory(profile.peakMemoryMb)}
            </span>
          )}
        </div>
      </div>

      {/* Expanded view - line profiling */}
      {isExpanded && profile?.lines && (
        <div className="px-3 pb-3">
          {/* Hotspots */}
          {stats && stats.hotspots.length > 0 && (
            <div className="mb-3">
              <div className="text-[10px] font-medium text-muted-foreground mb-1">
                Hotspots (slowest lines)
              </div>
              <div className="space-y-1">
                {stats.hotspots.map((line) => (
                  <div
                    key={line.lineNumber}
                    className="flex items-center gap-2 rounded bg-muted/50 px-2 py-1"
                  >
                    <span className="text-[10px] font-mono text-muted-foreground w-6">
                      L{line.lineNumber}
                    </span>
                    <div className="flex-1 min-w-0">
                      <code className="text-[10px] font-mono truncate block">
                        {line.code.trim().slice(0, 50)}
                        {line.code.trim().length > 50 && "..."}
                      </code>
                    </div>
                    <div className="flex items-center gap-2">
                      <div
                        className="h-1.5 rounded-full bg-primary/20"
                        style={{ width: `${Math.max(20, line.percentage)}px` }}
                      >
                        <div
                          className="h-full rounded-full bg-primary"
                          style={{ width: `${line.percentage}%` }}
                        />
                      </div>
                      <span className="text-[10px] font-mono text-primary w-16 text-right">
                        {formatTime(line.timeMs)}
                      </span>
                      <span className="text-[10px] text-muted-foreground w-10 text-right">
                        {line.percentage.toFixed(1)}%
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* All lines table */}
          <div className="text-[10px] font-medium text-muted-foreground mb-1">
            All Lines
          </div>
          <div className="max-h-40 overflow-auto rounded border border-border">
            <table className="w-full text-[10px]">
              <thead className="bg-muted sticky top-0">
                <tr>
                  <th className="px-2 py-1 text-left font-medium">Line</th>
                  <th className="px-2 py-1 text-left font-medium">Code</th>
                  <th className="px-2 py-1 text-right font-medium">Hits</th>
                  <th className="px-2 py-1 text-right font-medium">Time</th>
                  <th className="px-2 py-1 text-right font-medium">%</th>
                </tr>
              </thead>
              <tbody>
                {profile.lines.map((line) => (
                  <tr
                    key={line.lineNumber}
                    className={cn(
                      "border-t border-border/50",
                      line.percentage > 20 && "bg-amber-500/10"
                    )}
                  >
                    <td className="px-2 py-0.5 font-mono text-muted-foreground">
                      {line.lineNumber}
                    </td>
                    <td className="px-2 py-0.5 font-mono truncate max-w-[200px]">
                      {line.code.trim()}
                    </td>
                    <td className="px-2 py-0.5 text-right">{line.hits}</td>
                    <td className="px-2 py-0.5 text-right font-mono">
                      {formatTime(line.timeMs)}
                    </td>
                    <td className="px-2 py-0.5 text-right">
                      {line.percentage.toFixed(1)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Summary */}
          <div className="mt-2 flex items-center gap-4 text-[10px] text-muted-foreground">
            <span>Total: {formatTime(profile.totalTimeMs)}</span>
            {stats && (
              <span>Avg/line: {formatTime(stats.avgTimePerLine)}</span>
            )}
            {profile.peakMemoryMb && (
              <span>Peak Memory: {formatMemory(profile.peakMemoryMb)}</span>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default CellProfiler;
