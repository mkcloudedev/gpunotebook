import { useRef, useCallback, useEffect } from "react";
import Editor, { OnMount, OnChange } from "@monaco-editor/react";
import * as monaco from "monaco-editor";
import { executionService } from "@/services/executionService";

interface MonacoCodeEditorProps {
  value: string;
  onChange: (value: string) => void;
  language?: string;
  readOnly?: boolean;
  height?: string | number;
  onExecute?: () => void;
  onExecuteAndNext?: () => void;
  onFocus?: () => void;
  onBlur?: () => void;
  placeholder?: string;
  noBorder?: boolean;
  kernelId?: string; // For kernel-based completions
  onGoToDefinition?: (symbol: string, line: number) => void;
}

export const MonacoCodeEditor = ({
  value,
  onChange,
  language = "python",
  readOnly = false,
  height = "auto",
  onExecute,
  onExecuteAndNext,
  onFocus,
  onBlur,
  placeholder,
  noBorder = false,
  kernelId,
  onGoToDefinition,
}: MonacoCodeEditorProps) => {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const completionProviderRef = useRef<monaco.IDisposable | null>(null);
  const hoverProviderRef = useRef<monaco.IDisposable | null>(null);
  const signatureProviderRef = useRef<monaco.IDisposable | null>(null);
  const monacoRef = useRef<typeof monaco | null>(null);
  const kernelIdRef = useRef<string | undefined>(kernelId);

  // Keep kernelIdRef in sync
  useEffect(() => {
    kernelIdRef.current = kernelId;
  }, [kernelId]);

  const handleEditorDidMount: OnMount = useCallback(
    (editor, monacoInstance) => {
      editorRef.current = editor;
      monacoRef.current = monacoInstance as typeof monaco;

      // Auto-resize based on content
      const updateHeight = () => {
        const contentHeight = Math.max(
          50,
          Math.min(500, editor.getContentHeight())
        );
        if (containerRef.current) {
          containerRef.current.style.height = `${contentHeight}px`;
        }
        editor.layout();
      };

      editor.onDidContentSizeChange(updateHeight);
      updateHeight();

      // Add keyboard shortcuts
      editor.addCommand(
        monacoInstance.KeyMod.Shift | monacoInstance.KeyCode.Enter,
        () => {
          if (onExecute) {
            onExecute();
          }
        }
      );

      // Ctrl+Enter to execute
      editor.addCommand(
        monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyCode.Enter,
        () => {
          if (onExecute) {
            onExecute();
          }
        }
      );

      // Focus/blur events
      editor.onDidFocusEditorText(() => {
        if (onFocus) onFocus();
      });

      editor.onDidBlurEditorText(() => {
        if (onBlur) onBlur();
      });

      // Register kernel completion provider for Python
      if (language === "python") {
        // Dispose previous providers if exist
        if (completionProviderRef.current) {
          completionProviderRef.current.dispose();
        }
        if (hoverProviderRef.current) {
          hoverProviderRef.current.dispose();
        }
        if (signatureProviderRef.current) {
          signatureProviderRef.current.dispose();
        }

        // Completion provider with enhanced details
        completionProviderRef.current = monacoInstance.languages.registerCompletionItemProvider("python", {
          triggerCharacters: [".", "(", "[", ",", " "],
          provideCompletionItems: async (model, position) => {
            const currentKernelId = kernelIdRef.current;
            if (!currentKernelId) return { suggestions: [] };

            try {
              const code = model.getValue();
              const offset = model.getOffsetAt(position);

              const completions = await executionService.getCompletions(currentKernelId, code, offset);

              const suggestions: monaco.languages.CompletionItem[] = completions.map((match) => {
                // Determine the kind based on the completion text
                let kind = monacoInstance.languages.CompletionItemKind.Variable;
                let detail = "variable";

                if (match.startsWith("__") && match.endsWith("__")) {
                  kind = monacoInstance.languages.CompletionItemKind.Property;
                  detail = "magic method";
                } else if (match.startsWith("_")) {
                  kind = monacoInstance.languages.CompletionItemKind.Field;
                  detail = "private";
                } else if (match.endsWith("(")) {
                  kind = monacoInstance.languages.CompletionItemKind.Function;
                  detail = "function";
                } else if (match === match.toUpperCase() && match.length > 1) {
                  kind = monacoInstance.languages.CompletionItemKind.Constant;
                  detail = "constant";
                } else if (match[0] === match[0].toUpperCase()) {
                  kind = monacoInstance.languages.CompletionItemKind.Class;
                  detail = "class";
                }

                return {
                  label: match,
                  kind,
                  detail,
                  insertText: match.endsWith("(") ? match.slice(0, -1) : match,
                  insertTextRules: match.endsWith("(")
                    ? monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet
                    : undefined,
                  range: {
                    startLineNumber: position.lineNumber,
                    startColumn: position.column,
                    endLineNumber: position.lineNumber,
                    endColumn: position.column,
                  },
                  command: match.endsWith("(") ? {
                    id: "editor.action.triggerParameterHints",
                    title: "Trigger Parameter Hints",
                  } : undefined,
                };
              });

              return { suggestions };
            } catch (error) {
              console.error("Completion error:", error);
              return { suggestions: [] };
            }
          },
        });

        // Hover provider for tooltips
        hoverProviderRef.current = monacoInstance.languages.registerHoverProvider("python", {
          provideHover: async (model, position) => {
            const currentKernelId = kernelIdRef.current;
            if (!currentKernelId) return null;

            try {
              const word = model.getWordAtPosition(position);
              if (!word) return null;

              const code = model.getValue();
              const offset = model.getOffsetAt(position);

              // Get inspect info from kernel
              const inspectInfo = await executionService.inspect(currentKernelId, code, offset);

              if (inspectInfo && inspectInfo.found) {
                return {
                  range: new monacoInstance.Range(
                    position.lineNumber,
                    word.startColumn,
                    position.lineNumber,
                    word.endColumn
                  ),
                  contents: [
                    { value: `**${word.word}**` },
                    { value: "```python\n" + (inspectInfo.data?.["text/plain"] || "") + "\n```" },
                  ],
                };
              }
              return null;
            } catch (error) {
              return null;
            }
          },
        });

        // Signature help provider for function parameters
        signatureProviderRef.current = monacoInstance.languages.registerSignatureHelpProvider("python", {
          signatureHelpTriggerCharacters: ["(", ","],
          provideSignatureHelp: async (model, position) => {
            const currentKernelId = kernelIdRef.current;
            if (!currentKernelId) return null;

            try {
              const code = model.getValue();
              const offset = model.getOffsetAt(position);

              // Find the function name before the opening parenthesis
              const textBefore = model.getValueInRange({
                startLineNumber: position.lineNumber,
                startColumn: 1,
                endLineNumber: position.lineNumber,
                endColumn: position.column,
              });

              // Match function call pattern
              const funcMatch = textBefore.match(/(\w+)\s*\([^)]*$/);
              if (!funcMatch) return null;

              const inspectInfo = await executionService.inspect(currentKernelId, code, offset - 1);

              if (inspectInfo && inspectInfo.found) {
                const docString = inspectInfo.data?.["text/plain"] || "";
                // Extract signature from docstring
                const sigMatch = docString.match(/^([^\n]+)/);
                const signature = sigMatch ? sigMatch[1] : funcMatch[1] + "(...)";

                return {
                  value: {
                    signatures: [{
                      label: signature,
                      documentation: docString,
                      parameters: [],
                    }],
                    activeSignature: 0,
                    activeParameter: 0,
                  },
                  dispose: () => {},
                };
              }
              return null;
            } catch (error) {
              return null;
            }
          },
        });

        // Go to Definition (Ctrl+Click)
        editor.addAction({
          id: "go-to-definition",
          label: "Go to Definition",
          keybindings: [monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyCode.F12],
          contextMenuGroupId: "navigation",
          contextMenuOrder: 1,
          run: (ed) => {
            const position = ed.getPosition();
            if (!position) return;

            const word = model.getWordAtPosition(position);
            if (word && onGoToDefinition) {
              onGoToDefinition(word.word, position.lineNumber);
            }
          },
        });
      }
    },
    [onExecute, onExecuteAndNext, onFocus, onBlur, language, onGoToDefinition]
  );

  // Cleanup providers on unmount
  useEffect(() => {
    return () => {
      if (completionProviderRef.current) {
        completionProviderRef.current.dispose();
      }
      if (hoverProviderRef.current) {
        hoverProviderRef.current.dispose();
      }
      if (signatureProviderRef.current) {
        signatureProviderRef.current.dispose();
      }
    };
  }, []);

  const handleChange: OnChange = useCallback(
    (newValue) => {
      onChange(newValue || "");
    },
    [onChange]
  );

  // Calculate min height based on lines
  const lineCount = value.split("\n").length;
  const minHeight = Math.max(50, Math.min(500, lineCount * 19 + 20));

  return (
    <div
      ref={containerRef}
      className={`monaco-editor-container overflow-hidden ${noBorder ? '' : 'rounded-md border border-border'}`}
      style={{ height: height === "auto" ? minHeight : height }}
    >
      <Editor
        value={value}
        onChange={handleChange}
        onMount={handleEditorDidMount}
        language={language}
        theme="vs-dark"
        options={{
          readOnly,
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          lineNumbers: "on",
          lineNumbersMinChars: 3,
          glyphMargin: false,
          // Code Folding - enabled with enhanced options
          folding: true,
          foldingStrategy: "indentation",
          foldingHighlight: true,
          showFoldingControls: "always",
          lineDecorationsWidth: 10,
          renderLineHighlight: "line",
          scrollbar: {
            vertical: "auto",
            horizontal: "auto",
            verticalScrollbarSize: 8,
            horizontalScrollbarSize: 8,
          },
          overviewRulerBorder: false,
          overviewRulerLanes: 0,
          hideCursorInOverviewRuler: true,
          padding: { top: 8, bottom: 8 },
          fontSize: 13,
          fontFamily: "'JetBrains Mono', 'Fira Code', 'Consolas', monospace",
          fontLigatures: true,
          tabSize: 4,
          insertSpaces: true,
          wordWrap: "on",
          wrappingIndent: "indent",
          automaticLayout: true,
          suggestOnTriggerCharacters: true,
          quickSuggestions: true,
          parameterHints: { enabled: true },
          bracketPairColorization: { enabled: true },
          autoClosingBrackets: "always",
          autoClosingQuotes: "always",
          autoIndent: "full",
          formatOnType: true,
          formatOnPaste: true,
          renderWhitespace: "selection",
          cursorBlinking: "smooth",
          cursorSmoothCaretAnimation: "on",
          smoothScrolling: true,
          mouseWheelZoom: true,
          contextmenu: true,
          extraEditorClassName: "notebook-cell-editor",
        }}
        loading={
          <div className="flex h-full items-center justify-center bg-muted/50">
            <span className="text-sm text-muted-foreground">Loading editor...</span>
          </div>
        }
      />
      {!value && placeholder && (
        <div className="pointer-events-none absolute left-12 top-2 text-sm text-muted-foreground/50">
          {placeholder}
        </div>
      )}
    </div>
  );
};

export default MonacoCodeEditor;
