import { useState, useCallback, useEffect, useRef } from "react";
import {
  Search,
  Replace,
  ChevronUp,
  ChevronDown,
  X,
  CaseSensitive,
  Regex,
  WholeWord,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { Cell } from "@/types/notebook";

interface SearchMatch {
  cellId: string;
  cellIndex: number;
  startIndex: number;
  endIndex: number;
  lineNumber: number;
  lineContent: string;
}

interface FindReplacePanelProps {
  cells: Cell[];
  onClose: () => void;
  onNavigateToCell: (cellId: string) => void;
  onReplaceInCell: (cellId: string, newSource: string) => void;
}

export const FindReplacePanel = ({
  cells,
  onClose,
  onNavigateToCell,
  onReplaceInCell,
}: FindReplacePanelProps) => {
  const [findText, setFindText] = useState("");
  const [replaceText, setReplaceText] = useState("");
  const [matches, setMatches] = useState<SearchMatch[]>([]);
  const [currentMatchIndex, setCurrentMatchIndex] = useState(-1);
  const [showReplace, setShowReplace] = useState(false);
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [useRegex, setUseRegex] = useState(false);
  const [wholeWord, setWholeWord] = useState(false);

  const findInputRef = useRef<HTMLInputElement>(null);

  // Focus input on mount
  useEffect(() => {
    findInputRef.current?.focus();
  }, []);

  // Perform search
  const performSearch = useCallback(() => {
    if (!findText.trim()) {
      setMatches([]);
      setCurrentMatchIndex(-1);
      return;
    }

    const newMatches: SearchMatch[] = [];

    cells.forEach((cell, cellIndex) => {
      const source = cell.source;
      const lines = source.split("\n");

      let searchPattern: RegExp;
      try {
        if (useRegex) {
          searchPattern = new RegExp(findText, caseSensitive ? "g" : "gi");
        } else {
          const escaped = findText.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
          const pattern = wholeWord ? `\\b${escaped}\\b` : escaped;
          searchPattern = new RegExp(pattern, caseSensitive ? "g" : "gi");
        }
      } catch (e) {
        // Invalid regex
        return;
      }

      let charIndex = 0;
      lines.forEach((line, lineIndex) => {
        let match;
        const linePattern = new RegExp(searchPattern.source, searchPattern.flags);

        while ((match = linePattern.exec(line)) !== null) {
          newMatches.push({
            cellId: cell.id,
            cellIndex,
            startIndex: charIndex + match.index,
            endIndex: charIndex + match.index + match[0].length,
            lineNumber: lineIndex + 1,
            lineContent: line,
          });
        }
        charIndex += line.length + 1; // +1 for newline
      });
    });

    setMatches(newMatches);
    setCurrentMatchIndex(newMatches.length > 0 ? 0 : -1);

    // Navigate to first match
    if (newMatches.length > 0) {
      onNavigateToCell(newMatches[0].cellId);
    }
  }, [findText, cells, caseSensitive, useRegex, wholeWord, onNavigateToCell]);

  // Search when text or options change
  useEffect(() => {
    const debounce = setTimeout(performSearch, 150);
    return () => clearTimeout(debounce);
  }, [performSearch]);

  // Navigate to next match
  const goToNextMatch = () => {
    if (matches.length === 0) return;
    const newIndex = (currentMatchIndex + 1) % matches.length;
    setCurrentMatchIndex(newIndex);
    onNavigateToCell(matches[newIndex].cellId);
  };

  // Navigate to previous match
  const goToPrevMatch = () => {
    if (matches.length === 0) return;
    const newIndex = (currentMatchIndex - 1 + matches.length) % matches.length;
    setCurrentMatchIndex(newIndex);
    onNavigateToCell(matches[newIndex].cellId);
  };

  // Replace current match
  const replaceCurrent = () => {
    if (currentMatchIndex < 0 || matches.length === 0) return;

    const match = matches[currentMatchIndex];
    const cell = cells.find((c) => c.id === match.cellId);
    if (!cell) return;

    const before = cell.source.substring(0, match.startIndex);
    const after = cell.source.substring(match.endIndex);
    const newSource = before + replaceText + after;

    onReplaceInCell(match.cellId, newSource);

    // Re-search after replace
    setTimeout(performSearch, 50);
  };

  // Replace all matches
  const replaceAll = () => {
    if (matches.length === 0 || !findText.trim()) return;

    // Group matches by cell (in reverse order to maintain indices)
    const matchesByCell = new Map<string, SearchMatch[]>();
    matches.forEach((match) => {
      const cellMatches = matchesByCell.get(match.cellId) || [];
      cellMatches.push(match);
      matchesByCell.set(match.cellId, cellMatches);
    });

    // Replace in each cell (process matches in reverse order)
    matchesByCell.forEach((cellMatches, cellId) => {
      const cell = cells.find((c) => c.id === cellId);
      if (!cell) return;

      // Sort by startIndex descending
      cellMatches.sort((a, b) => b.startIndex - a.startIndex);

      let newSource = cell.source;
      cellMatches.forEach((match) => {
        const before = newSource.substring(0, match.startIndex);
        const after = newSource.substring(match.endIndex);
        newSource = before + replaceText + after;
      });

      onReplaceInCell(cellId, newSource);
    });

    // Clear matches after replace all
    setTimeout(performSearch, 50);
  };

  // Handle keyboard shortcuts
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") {
      onClose();
    } else if (e.key === "Enter") {
      if (e.shiftKey) {
        goToPrevMatch();
      } else {
        goToNextMatch();
      }
    } else if (e.key === "F3") {
      e.preventDefault();
      if (e.shiftKey) {
        goToPrevMatch();
      } else {
        goToNextMatch();
      }
    }
  };

  return (
    <div
      className="flex flex-col gap-2 border-b border-border bg-card px-3 py-2"
      onKeyDown={handleKeyDown}
    >
      {/* Find row */}
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <Input
            ref={findInputRef}
            value={findText}
            onChange={(e) => setFindText(e.target.value)}
            placeholder="Find in notebook..."
            className="h-7 pl-8 pr-20 text-xs"
          />
          {/* Match count */}
          <div className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-muted-foreground">
            {matches.length > 0
              ? `${currentMatchIndex + 1} of ${matches.length}`
              : findText
              ? "No results"
              : ""}
          </div>
        </div>

        {/* Search options */}
        <Button
          size="sm"
          variant={caseSensitive ? "default" : "ghost"}
          className="h-7 w-7 p-0"
          onClick={() => setCaseSensitive(!caseSensitive)}
          title="Case Sensitive (Alt+C)"
        >
          <CaseSensitive className="h-3.5 w-3.5" />
        </Button>
        <Button
          size="sm"
          variant={wholeWord ? "default" : "ghost"}
          className="h-7 w-7 p-0"
          onClick={() => setWholeWord(!wholeWord)}
          title="Whole Word (Alt+W)"
        >
          <WholeWord className="h-3.5 w-3.5" />
        </Button>
        <Button
          size="sm"
          variant={useRegex ? "default" : "ghost"}
          className="h-7 w-7 p-0"
          onClick={() => setUseRegex(!useRegex)}
          title="Use Regex (Alt+R)"
        >
          <Regex className="h-3.5 w-3.5" />
        </Button>

        {/* Navigation */}
        <div className="flex items-center">
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0"
            onClick={goToPrevMatch}
            disabled={matches.length === 0}
            title="Previous Match (Shift+Enter)"
          >
            <ChevronUp className="h-4 w-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0"
            onClick={goToNextMatch}
            disabled={matches.length === 0}
            title="Next Match (Enter)"
          >
            <ChevronDown className="h-4 w-4" />
          </Button>
        </div>

        {/* Toggle replace */}
        <Button
          size="sm"
          variant={showReplace ? "default" : "ghost"}
          className="h-7 w-7 p-0"
          onClick={() => setShowReplace(!showReplace)}
          title="Toggle Replace"
        >
          <Replace className="h-3.5 w-3.5" />
        </Button>

        {/* Close */}
        <Button
          size="sm"
          variant="ghost"
          className="h-7 w-7 p-0"
          onClick={onClose}
          title="Close (Escape)"
        >
          <X className="h-4 w-4" />
        </Button>
      </div>

      {/* Replace row */}
      {showReplace && (
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <Replace className="absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={replaceText}
              onChange={(e) => setReplaceText(e.target.value)}
              placeholder="Replace with..."
              className="h-7 pl-8 text-xs"
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  replaceCurrent();
                }
              }}
            />
          </div>

          <Button
            size="sm"
            variant="outline"
            className="h-7 px-2 text-xs"
            onClick={replaceCurrent}
            disabled={matches.length === 0}
          >
            Replace
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="h-7 px-2 text-xs"
            onClick={replaceAll}
            disabled={matches.length === 0}
          >
            Replace All
          </Button>
        </div>
      )}

      {/* Match preview */}
      {matches.length > 0 && currentMatchIndex >= 0 && (
        <div className="flex items-center gap-2 text-[10px] text-muted-foreground">
          <span className="px-1.5 py-0.5 bg-muted rounded">
            Cell {matches[currentMatchIndex].cellIndex + 1}
          </span>
          <span>Line {matches[currentMatchIndex].lineNumber}:</span>
          <span className="font-mono truncate flex-1">
            {matches[currentMatchIndex].lineContent.trim()}
          </span>
        </div>
      )}
    </div>
  );
};

export default FindReplacePanel;
