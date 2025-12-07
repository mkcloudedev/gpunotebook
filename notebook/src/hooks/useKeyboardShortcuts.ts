import { useEffect, useCallback } from "react";

interface KeyboardShortcut {
  key: string;
  ctrl?: boolean;
  shift?: boolean;
  alt?: boolean;
  meta?: boolean;
  action: () => void;
  description: string;
  category: string;
}

interface UseKeyboardShortcutsOptions {
  enabled?: boolean;
  shortcuts: KeyboardShortcut[];
}

export const NOTEBOOK_SHORTCUTS: Omit<KeyboardShortcut, "action">[] = [
  // Execution
  { key: "Enter", shift: true, description: "Run cell and stay", category: "Execution" },
  { key: "Enter", ctrl: true, description: "Run cell and move to next", category: "Execution" },
  { key: "Enter", alt: true, description: "Run cell and insert below", category: "Execution" },
  { key: "i", ctrl: false, shift: false, description: "Interrupt kernel", category: "Execution" },
  { key: "0", ctrl: false, shift: false, description: "Restart kernel (press twice)", category: "Execution" },

  // Navigation
  { key: "ArrowUp", description: "Select previous cell", category: "Navigation" },
  { key: "ArrowDown", description: "Select next cell", category: "Navigation" },
  { key: "Home", ctrl: true, description: "Go to first cell", category: "Navigation" },
  { key: "End", ctrl: true, description: "Go to last cell", category: "Navigation" },

  // Cell Operations
  { key: "a", description: "Insert cell above", category: "Cell Operations" },
  { key: "b", description: "Insert cell below", category: "Cell Operations" },
  { key: "d", description: "Delete cell (press twice)", category: "Cell Operations" },
  { key: "c", description: "Copy cell", category: "Cell Operations" },
  { key: "v", description: "Paste cell below", category: "Cell Operations" },
  { key: "x", description: "Cut cell", category: "Cell Operations" },
  { key: "z", ctrl: true, description: "Undo", category: "Cell Operations" },
  { key: "z", ctrl: true, shift: true, description: "Redo", category: "Cell Operations" },

  // Cell Type
  { key: "m", description: "Change to markdown", category: "Cell Type" },
  { key: "y", description: "Change to code", category: "Cell Type" },

  // View
  { key: "l", description: "Toggle line numbers", category: "View" },
  { key: "o", description: "Toggle output", category: "View" },
  { key: "h", shift: true, description: "Show shortcuts", category: "View" },

  // File
  { key: "s", ctrl: true, description: "Save notebook", category: "File" },
];

export function useKeyboardShortcuts({
  enabled = true,
  shortcuts,
}: UseKeyboardShortcutsOptions) {
  const handleKeyDown = useCallback(
    (event: KeyboardEvent) => {
      if (!enabled) return;

      // Ignore if typing in an input or contenteditable
      const target = event.target as HTMLElement;
      if (
        target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.isContentEditable ||
        target.classList.contains("monaco-editor")
      ) {
        // Allow some shortcuts even in editor
        const allowedInEditor = ["Enter", "s"];
        if (!allowedInEditor.includes(event.key) || (!event.ctrlKey && !event.metaKey && !event.shiftKey)) {
          return;
        }
      }

      for (const shortcut of shortcuts) {
        const keyMatches = event.key.toLowerCase() === shortcut.key.toLowerCase();
        const ctrlMatches = !!shortcut.ctrl === (event.ctrlKey || event.metaKey);
        const shiftMatches = !!shortcut.shift === event.shiftKey;
        const altMatches = !!shortcut.alt === event.altKey;

        if (keyMatches && ctrlMatches && shiftMatches && altMatches) {
          event.preventDefault();
          event.stopPropagation();
          shortcut.action();
          return;
        }
      }
    },
    [enabled, shortcuts]
  );

  useEffect(() => {
    if (enabled) {
      document.addEventListener("keydown", handleKeyDown);
      return () => {
        document.removeEventListener("keydown", handleKeyDown);
      };
    }
  }, [enabled, handleKeyDown]);
}

export function formatShortcut(shortcut: Omit<KeyboardShortcut, "action">): string {
  const parts: string[] = [];

  if (shortcut.ctrl) parts.push("Ctrl");
  if (shortcut.meta) parts.push("Cmd");
  if (shortcut.alt) parts.push("Alt");
  if (shortcut.shift) parts.push("Shift");

  let key = shortcut.key;
  if (key === "ArrowUp") key = "↑";
  else if (key === "ArrowDown") key = "↓";
  else if (key === "ArrowLeft") key = "←";
  else if (key === "ArrowRight") key = "→";
  else if (key === "Enter") key = "↵";
  else if (key === "Escape") key = "Esc";
  else if (key === " ") key = "Space";
  else key = key.toUpperCase();

  parts.push(key);

  return parts.join(" + ");
}

export default useKeyboardShortcuts;
