import { useState, useCallback, useRef, useEffect } from "react";

interface UndoRedoOptions<T> {
  maxHistorySize?: number;
  debounceMs?: number;
}

interface UndoRedoState<T> {
  past: T[];
  present: T;
  future: T[];
}

export function useUndoRedo<T>(
  initialState: T,
  options: UndoRedoOptions<T> = {}
) {
  const { maxHistorySize = 50, debounceMs = 500 } = options;

  const [state, setState] = useState<UndoRedoState<T>>({
    past: [],
    present: initialState,
    future: [],
  });

  const debounceTimer = useRef<NodeJS.Timeout | null>(null);
  const lastSavedState = useRef<T>(initialState);

  // Check if we can undo/redo
  const canUndo = state.past.length > 0;
  const canRedo = state.future.length > 0;

  // Set new state with history tracking
  const set = useCallback(
    (newState: T | ((prev: T) => T), immediate = false) => {
      const resolvedState =
        typeof newState === "function"
          ? (newState as (prev: T) => T)(state.present)
          : newState;

      // Clear any pending debounce
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current);
      }

      if (immediate) {
        // Immediate save to history
        setState((prev) => {
          const newPast = [...prev.past, prev.present].slice(-maxHistorySize);
          return {
            past: newPast,
            present: resolvedState,
            future: [],
          };
        });
        lastSavedState.current = resolvedState;
      } else {
        // Update present immediately but debounce history save
        setState((prev) => ({
          ...prev,
          present: resolvedState,
        }));

        debounceTimer.current = setTimeout(() => {
          setState((prev) => {
            // Only save if state actually changed
            if (JSON.stringify(lastSavedState.current) === JSON.stringify(prev.present)) {
              return prev;
            }

            const newPast = [...prev.past, lastSavedState.current].slice(-maxHistorySize);
            lastSavedState.current = prev.present;

            return {
              past: newPast,
              present: prev.present,
              future: [],
            };
          });
        }, debounceMs);
      }
    },
    [state.present, maxHistorySize, debounceMs]
  );

  // Undo action
  const undo = useCallback(() => {
    setState((prev) => {
      if (prev.past.length === 0) return prev;

      const newPast = prev.past.slice(0, -1);
      const newPresent = prev.past[prev.past.length - 1];
      const newFuture = [prev.present, ...prev.future];

      lastSavedState.current = newPresent;

      return {
        past: newPast,
        present: newPresent,
        future: newFuture,
      };
    });
  }, []);

  // Redo action
  const redo = useCallback(() => {
    setState((prev) => {
      if (prev.future.length === 0) return prev;

      const newFuture = prev.future.slice(1);
      const newPresent = prev.future[0];
      const newPast = [...prev.past, prev.present];

      lastSavedState.current = newPresent;

      return {
        past: newPast,
        present: newPresent,
        future: newFuture,
      };
    });
  }, []);

  // Reset history
  const reset = useCallback((newState: T) => {
    if (debounceTimer.current) {
      clearTimeout(debounceTimer.current);
    }
    lastSavedState.current = newState;
    setState({
      past: [],
      present: newState,
      future: [],
    });
  }, []);

  // Clear history but keep current state
  const clearHistory = useCallback(() => {
    setState((prev) => ({
      past: [],
      present: prev.present,
      future: [],
    }));
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current);
      }
    };
  }, []);

  return {
    state: state.present,
    set,
    undo,
    redo,
    reset,
    clearHistory,
    canUndo,
    canRedo,
    historyLength: state.past.length,
    futureLength: state.future.length,
  };
}

export default useUndoRedo;
