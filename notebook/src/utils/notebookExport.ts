// Notebook export utilities

import { Cell, Notebook, CellOutput } from "@/types/notebook";

// Convert notebook to Jupyter .ipynb format
export function toIpynbFormat(notebook: Notebook): object {
  return {
    cells: notebook.cells.map((cell) => ({
      cell_type: cell.cellType,
      source: cell.source.split("\n").map((line, i, arr) =>
        i === arr.length - 1 ? line : line + "\n"
      ),
      metadata: cell.metadata || {},
      ...(cell.cellType === "code" && {
        execution_count: cell.executionCount || null,
        outputs: cell.outputs.map(convertOutputToIpynb),
      }),
    })),
    metadata: {
      kernelspec: {
        display_name: "Python 3",
        language: "python",
        name: "python3",
      },
      language_info: {
        codemirror_mode: {
          name: "ipython",
          version: 3,
        },
        file_extension: ".py",
        mimetype: "text/x-python",
        name: "python",
        nbconvert_exporter: "python",
        pygments_lexer: "ipython3",
        version: "3.11.0",
      },
      ...notebook.metadata,
    },
    nbformat: 4,
    nbformat_minor: 5,
  };
}

// Convert CellOutput to Jupyter output format
function convertOutputToIpynb(output: CellOutput): object {
  switch (output.outputType) {
    case "stream":
      return {
        output_type: "stream",
        name: output.name || "stdout",
        text: output.text?.split("\n").map((line, i, arr) =>
          i === arr.length - 1 ? line : line + "\n"
        ) || [],
      };

    case "execute_result":
      return {
        output_type: "execute_result",
        execution_count: output.executionCount || null,
        data: output.data || { "text/plain": "" },
        metadata: {},
      };

    case "display_data":
      return {
        output_type: "display_data",
        data: output.data || {},
        metadata: {},
      };

    case "error":
      return {
        output_type: "error",
        ename: output.ename || "Error",
        evalue: output.evalue || "",
        traceback: output.traceback || [],
      };

    default:
      return {
        output_type: "stream",
        name: "stdout",
        text: [output.text || ""],
      };
  }
}

// Convert notebook to Python script
export function toPythonScript(notebook: Notebook): string {
  const lines: string[] = [];

  lines.push("#!/usr/bin/env python");
  lines.push("# -*- coding: utf-8 -*-");
  lines.push("");
  lines.push(`# ${notebook.name}`);
  lines.push(`# Generated from GPU Notebook`);
  lines.push("");

  for (const cell of notebook.cells) {
    if (cell.cellType === "code") {
      lines.push(cell.source);
      lines.push("");
    } else if (cell.cellType === "markdown") {
      // Convert markdown to Python comments
      const commentLines = cell.source
        .split("\n")
        .map((line) => `# ${line}`);
      lines.push(...commentLines);
      lines.push("");
    }
  }

  return lines.join("\n");
}

// Convert notebook to HTML
export function toHtmlDocument(notebook: Notebook): string {
  const cellsHtml = notebook.cells
    .map((cell, index) => {
      if (cell.cellType === "code") {
        return `
          <div class="cell code-cell">
            <div class="cell-header">
              <span class="cell-type">In [${cell.executionCount || " "}]:</span>
            </div>
            <div class="cell-content">
              <pre><code class="language-python">${escapeHtml(cell.source)}</code></pre>
            </div>
            ${
              cell.outputs.length > 0
                ? `<div class="cell-output">
                    <div class="output-header">Out [${cell.executionCount || " "}]:</div>
                    ${cell.outputs.map(outputToHtml).join("\n")}
                  </div>`
                : ""
            }
          </div>
        `;
      } else {
        return `
          <div class="cell markdown-cell">
            <div class="cell-content markdown">
              ${markdownToHtml(cell.source)}
            </div>
          </div>
        `;
      }
    })
    .join("\n");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(notebook.name)}</title>
  <style>
    :root {
      --bg-color: #1e1e1e;
      --text-color: #d4d4d4;
      --cell-bg: #2d2d2d;
      --border-color: #404040;
      --code-bg: #1e1e1e;
      --output-bg: #252526;
      --primary: #569cd6;
      --error: #f14c4c;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background-color: var(--bg-color);
      color: var(--text-color);
      line-height: 1.6;
      max-width: 1000px;
      margin: 0 auto;
      padding: 20px;
    }

    .cell {
      margin-bottom: 16px;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      overflow: hidden;
    }

    .cell-header {
      background: var(--cell-bg);
      padding: 8px 16px;
      border-bottom: 1px solid var(--border-color);
      font-size: 12px;
      color: #888;
    }

    .cell-type {
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      color: var(--primary);
    }

    .cell-content {
      padding: 16px;
      background: var(--code-bg);
    }

    .cell-content pre {
      margin: 0;
      overflow-x: auto;
    }

    .cell-content code {
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      font-size: 14px;
    }

    .cell-output {
      background: var(--output-bg);
      padding: 12px 16px;
      border-top: 1px solid var(--border-color);
    }

    .output-header {
      font-size: 12px;
      color: #888;
      margin-bottom: 8px;
    }

    .output-text {
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      font-size: 13px;
      white-space: pre-wrap;
    }

    .output-error {
      color: var(--error);
    }

    .output-image img {
      max-width: 100%;
      height: auto;
    }

    .markdown-cell .cell-content {
      background: transparent;
    }

    .markdown h1, .markdown h2, .markdown h3 {
      color: var(--text-color);
      margin-top: 1em;
      margin-bottom: 0.5em;
    }

    .markdown p {
      margin: 0.5em 0;
    }

    .markdown code {
      background: var(--cell-bg);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      font-size: 13px;
    }

    .markdown pre code {
      display: block;
      padding: 12px;
      overflow-x: auto;
    }
  </style>
</head>
<body>
  <h1 class="notebook-title">${escapeHtml(notebook.name)}</h1>
  ${cellsHtml}
</body>
</html>`;
}

// Convert output to HTML
function outputToHtml(output: CellOutput): string {
  switch (output.outputType) {
    case "stream":
      return `<div class="output-text">${escapeHtml(output.text || "")}</div>`;

    case "execute_result":
    case "display_data":
      if (output.data) {
        if (output.data["image/png"]) {
          return `<div class="output-image"><img src="data:image/png;base64,${output.data["image/png"]}" alt="Output"></div>`;
        }
        if (output.data["text/html"]) {
          return `<div class="output-html">${output.data["text/html"]}</div>`;
        }
        if (output.data["text/plain"]) {
          return `<div class="output-text">${escapeHtml(String(output.data["text/plain"]))}</div>`;
        }
      }
      return "";

    case "error":
      return `<div class="output-error">
        <strong>${escapeHtml(output.ename || "Error")}: ${escapeHtml(output.evalue || "")}</strong>
        <pre>${escapeHtml((output.traceback || []).join("\n"))}</pre>
      </div>`;

    default:
      return "";
  }
}

// Simple markdown to HTML converter
function markdownToHtml(markdown: string): string {
  let html = escapeHtml(markdown);

  // Headers
  html = html.replace(/^### (.*$)/gim, "<h3>$1</h3>");
  html = html.replace(/^## (.*$)/gim, "<h2>$1</h2>");
  html = html.replace(/^# (.*$)/gim, "<h1>$1</h1>");

  // Bold
  html = html.replace(/\*\*(.*?)\*\*/gim, "<strong>$1</strong>");

  // Italic
  html = html.replace(/\*(.*?)\*/gim, "<em>$1</em>");

  // Code blocks
  html = html.replace(/```(\w*)\n([\s\S]*?)```/gim, "<pre><code>$2</code></pre>");

  // Inline code
  html = html.replace(/`([^`]+)`/gim, "<code>$1</code>");

  // Line breaks
  html = html.replace(/\n\n/gim, "</p><p>");
  html = html.replace(/\n/gim, "<br>");

  return `<p>${html}</p>`;
}

// Escape HTML characters
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Download file
export function downloadFile(content: string | Blob, filename: string, mimeType: string = "text/plain") {
  const blob = content instanceof Blob ? content : new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  URL.revokeObjectURL(url);
}

// Export notebook to .ipynb file
export function exportToIpynb(notebook: Notebook) {
  const ipynb = toIpynbFormat(notebook);
  const json = JSON.stringify(ipynb, null, 2);
  const filename = `${notebook.name.replace(/[^a-z0-9]/gi, "_")}.ipynb`;
  downloadFile(json, filename, "application/json");
}

// Export notebook to Python script
export function exportToPython(notebook: Notebook) {
  const script = toPythonScript(notebook);
  const filename = `${notebook.name.replace(/[^a-z0-9]/gi, "_")}.py`;
  downloadFile(script, filename, "text/x-python");
}

// Export notebook to HTML
export function exportToHtml(notebook: Notebook) {
  const html = toHtmlDocument(notebook);
  const filename = `${notebook.name.replace(/[^a-z0-9]/gi, "_")}.html`;
  downloadFile(html, filename, "text/html");
}
