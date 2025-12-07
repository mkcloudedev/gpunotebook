import { useState, useEffect, useRef } from "react";
import { ChevronDown, ChevronRight, Copy, Check, AlertCircle, Terminal, Maximize2, Minimize2 } from "lucide-react";
import { cn, copyToClipboard } from "@/lib/utils";
import { CellOutput } from "@/types/notebook";
import { Button } from "@/components/ui/button";
import katex from "katex";
import "katex/dist/katex.min.css";

interface CellOutputDisplayProps {
  outputs: CellOutput[];
  maxHeight?: number;
  compact?: boolean;
}

export const CellOutputDisplay = ({
  outputs,
  maxHeight = 400,
  compact = false,
}: CellOutputDisplayProps) => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);
  const outputRef = useRef<HTMLDivElement>(null);
  const [showScrollIndicator, setShowScrollIndicator] = useState(false);

  // Check if content exceeds max height
  useEffect(() => {
    if (outputRef.current) {
      setShowScrollIndicator(outputRef.current.scrollHeight > maxHeight);
    }
  }, [outputs, maxHeight]);

  if (outputs.length === 0) return null;

  // Compact mode for CLI - no header, just outputs
  if (compact) {
    return (
      <div className="space-y-1">
        {outputs.map((output, index) => (
          <OutputItem key={index} output={output} compact />
        ))}
      </div>
    );
  }

  const effectiveMaxHeight = isExpanded ? undefined : maxHeight;

  return (
    <div className="border-t border-border bg-muted/30">
      {/* Output header */}
      <div
        className="flex cursor-pointer items-center gap-2 px-3 py-1.5 hover:bg-muted/50"
        onClick={() => setIsCollapsed(!isCollapsed)}
      >
        {isCollapsed ? (
          <ChevronRight className="h-4 w-4 text-muted-foreground" />
        ) : (
          <ChevronDown className="h-4 w-4 text-muted-foreground" />
        )}
        <Terminal className="h-4 w-4 text-muted-foreground" />
        <span className="text-xs text-muted-foreground">
          Output ({outputs.length} {outputs.length === 1 ? "item" : "items"})
        </span>

        <div className="flex-1" />

        {/* Expand/Collapse button for long outputs */}
        {showScrollIndicator && !isCollapsed && (
          <Button
            size="sm"
            variant="ghost"
            className="h-5 px-1.5 gap-0.5"
            onClick={(e) => {
              e.stopPropagation();
              setIsExpanded(!isExpanded);
            }}
          >
            {isExpanded ? (
              <>
                <Minimize2 className="h-3 w-3" />
                <span className="text-[10px]">Collapse</span>
              </>
            ) : (
              <>
                <Maximize2 className="h-3 w-3" />
                <span className="text-[10px]">Expand</span>
              </>
            )}
          </Button>
        )}
      </div>

      {/* Output content */}
      {!isCollapsed && (
        <div
          ref={outputRef}
          className={cn(
            "overflow-auto p-3",
            !isExpanded && showScrollIndicator && "relative"
          )}
          style={{ maxHeight: effectiveMaxHeight }}
        >
          {outputs.map((output, index) => (
            <OutputItem key={index} output={output} />
          ))}

          {/* Scroll fade indicator */}
          {!isExpanded && showScrollIndicator && (
            <div className="sticky bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-muted/80 to-transparent pointer-events-none" />
          )}
        </div>
      )}
    </div>
  );
};

interface OutputItemProps {
  output: CellOutput;
  compact?: boolean;
}

const OutputItem = ({ output, compact = false }: OutputItemProps) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async (text: string) => {
    const success = await copyToClipboard(text);
    if (success) {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  // Error output
  if (output.outputType === "error") {
    return (
      <div className={cn("rounded-md bg-destructive/10", compact ? "p-2" : "p-3")}>
        <div className="flex items-center gap-2 mb-1">
          <AlertCircle className={cn("text-destructive", compact ? "h-3 w-3" : "h-4 w-4")} />
          <span className={cn("font-mono font-semibold text-destructive", compact ? "text-xs" : "text-sm")}>
            {output.ename}: {output.evalue}
          </span>
        </div>
        {output.traceback && !compact && (
          <pre className="overflow-x-auto font-mono text-xs text-destructive/80 whitespace-pre-wrap">
            {output.traceback.join("\n")}
          </pre>
        )}
      </div>
    );
  }

  // Stream output (stdout/stderr)
  if (output.outputType === "stream") {
    const isStderr = output.name === "stderr";
    return (
      <div className={cn("group relative", isStderr && "bg-yellow-500/10 rounded-md p-2")}>
        <pre className={cn(
          "overflow-x-auto whitespace-pre-wrap font-mono",
          compact ? "text-xs" : "text-sm",
          isStderr ? "text-yellow-600 dark:text-yellow-400" : "text-foreground"
        )}>
          {output.text}
        </pre>
        {output.text && !compact && (
          <Button
            size="sm"
            variant="ghost"
            className="absolute right-1 top-1 h-6 w-6 p-0 opacity-0 group-hover:opacity-100"
            onClick={() => handleCopy(output.text || "")}
          >
            {copied ? (
              <Check className="h-3 w-3 text-success" />
            ) : (
              <Copy className="h-3 w-3" />
            )}
          </Button>
        )}
      </div>
    );
  }

  // Execute result
  if (output.outputType === "execute_result" || output.outputType === "display_data") {
    return <RichOutput data={output.data} />;
  }

  // Plain text fallback
  if (output.text) {
    return (
      <pre className="overflow-x-auto whitespace-pre-wrap font-mono text-sm text-foreground">
        {output.text}
      </pre>
    );
  }

  return null;
};

interface RichOutputProps {
  data?: Record<string, unknown>;
}

const RichOutput = ({ data }: RichOutputProps) => {
  if (!data) return null;

  // Priority order for display
  // 1. Interactive widgets (application/vnd.jupyter.widget-view+json)
  // 2. Plotly (application/vnd.plotly.v1+json)
  // 3. HTML
  // 4. SVG
  // 5. PNG image
  // 6. JPEG image
  // 7. LaTeX
  // 8. Markdown
  // 9. Plain text

  // Plotly chart
  if (data["application/vnd.plotly.v1+json"]) {
    const plotlyData = data["application/vnd.plotly.v1+json"] as {
      data: unknown[];
      layout?: Record<string, unknown>;
    };
    return (
      <div className="plotly-output my-2">
        <div
          className="bg-card rounded-md p-2 border border-border"
          dangerouslySetInnerHTML={{
            __html: `<div id="plotly-${Date.now()}" style="width:100%;height:400px"></div>
              <script>
                if (window.Plotly) {
                  Plotly.newPlot('plotly-${Date.now()}', ${JSON.stringify(plotlyData.data)}, ${JSON.stringify(plotlyData.layout || {})});
                }
              </script>`
          }}
        />
      </div>
    );
  }

  // HTML output (includes pandas DataFrames)
  if (data["text/html"]) {
    const htmlContent = Array.isArray(data["text/html"])
      ? data["text/html"].join("")
      : (data["text/html"] as string);

    // Check if it's a DataFrame table
    const isDataFrame = htmlContent.includes('class="dataframe"') ||
                        htmlContent.includes('<table') ||
                        htmlContent.includes('pandas');

    return (
      <div
        className={cn(
          "html-output overflow-x-auto my-2",
          isDataFrame && "dataframe-table"
        )}
        style={{
          // Style for pandas DataFrames
          ...(isDataFrame && {
            fontSize: '13px',
          })
        }}
        dangerouslySetInnerHTML={{ __html: htmlContent }}
      />
    );
  }

  // SVG output
  if (data["image/svg+xml"]) {
    const svgContent = Array.isArray(data["image/svg+xml"])
      ? data["image/svg+xml"].join("")
      : (data["image/svg+xml"] as string);

    return (
      <div
        className="svg-output my-2"
        dangerouslySetInnerHTML={{ __html: svgContent }}
      />
    );
  }

  // PNG image
  if (data["image/png"]) {
    const imgData = data["image/png"] as string;
    return (
      <div className="image-output my-2">
        <img
          src={`data:image/png;base64,${imgData}`}
          alt="Output"
          className="max-w-full rounded-md"
        />
      </div>
    );
  }

  // JPEG image
  if (data["image/jpeg"]) {
    const imgData = data["image/jpeg"] as string;
    return (
      <div className="image-output my-2">
        <img
          src={`data:image/jpeg;base64,${imgData}`}
          alt="Output"
          className="max-w-full rounded-md"
        />
      </div>
    );
  }

  // GIF image
  if (data["image/gif"]) {
    const imgData = data["image/gif"] as string;
    return (
      <div className="image-output my-2">
        <img
          src={`data:image/gif;base64,${imgData}`}
          alt="Output"
          className="max-w-full rounded-md"
        />
      </div>
    );
  }

  // LaTeX output - render with KaTeX
  if (data["text/latex"]) {
    let latexContent = Array.isArray(data["text/latex"])
      ? data["text/latex"].join("")
      : (data["text/latex"] as string);

    // Remove wrapping $ or $$ if present
    latexContent = latexContent.replace(/^\$\$?|\$\$?$/g, "").trim();

    try {
      const renderedLatex = katex.renderToString(latexContent, {
        displayMode: true,
        throwOnError: false,
        errorColor: "#ef4444",
        trust: true,
      });

      return (
        <div
          className="latex-output my-2 overflow-x-auto"
          dangerouslySetInnerHTML={{ __html: renderedLatex }}
        />
      );
    } catch (error) {
      return (
        <div className="latex-output font-mono my-2 p-2 bg-muted/50 rounded-md text-sm">
          {latexContent}
        </div>
      );
    }
  }

  // Markdown output
  if (data["text/markdown"]) {
    const mdContent = Array.isArray(data["text/markdown"])
      ? data["text/markdown"].join("")
      : (data["text/markdown"] as string);

    return (
      <div className="markdown-output prose prose-sm dark:prose-invert max-w-none">
        {mdContent}
      </div>
    );
  }

  // JSON output
  if (data["application/json"]) {
    const jsonData = data["application/json"];
    return (
      <pre className="overflow-x-auto whitespace-pre-wrap font-mono text-sm text-foreground bg-muted/50 p-3 rounded-md">
        {JSON.stringify(jsonData, null, 2)}
      </pre>
    );
  }

  // Plain text fallback
  if (data["text/plain"]) {
    const textContent = Array.isArray(data["text/plain"])
      ? data["text/plain"].join("")
      : (data["text/plain"] as string);

    return (
      <pre className="overflow-x-auto whitespace-pre-wrap font-mono text-sm text-foreground">
        {textContent}
      </pre>
    );
  }

  return null;
};

export default CellOutputDisplay;
