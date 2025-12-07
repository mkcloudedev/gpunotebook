import { useMemo } from "react";
import katex from "katex";
import "katex/dist/katex.min.css";

interface MarkdownRendererProps {
  content: string;
  className?: string;
}

// Render LaTeX expression
function renderLatex(latex: string, displayMode: boolean): string {
  try {
    return katex.renderToString(latex, {
      displayMode,
      throwOnError: false,
      errorColor: "#ef4444",
      trust: true,
    });
  } catch (error) {
    console.error("LaTeX render error:", error);
    return `<span class="text-destructive font-mono text-sm">${latex}</span>`;
  }
}

// Simple markdown parser
function parseMarkdown(text: string): string {
  let html = text;

  // Process LaTeX BEFORE escaping HTML
  // Block LaTeX ($$...$$)
  html = html.replace(/\$\$([\s\S]*?)\$\$/g, (_, latex) => {
    return `<div class="my-4 overflow-x-auto">${renderLatex(latex.trim(), true)}</div>`;
  });

  // Inline LaTeX ($...$) - but not $$
  html = html.replace(/\$([^\$\n]+?)\$/g, (_, latex) => {
    return renderLatex(latex.trim(), false);
  });

  // Escape HTML (but preserve KaTeX output)
  const katexParts: string[] = [];
  html = html.replace(/<span class="katex[\s\S]*?<\/span>|<div class="my-4[\s\S]*?<\/div>/g, (match) => {
    katexParts.push(match);
    return `__KATEX_${katexParts.length - 1}__`;
  });

  html = html
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  // Restore KaTeX
  html = html.replace(/__KATEX_(\d+)__/g, (_, index) => katexParts[parseInt(index)]);

  // Headers
  html = html.replace(/^###### (.*$)/gim, '<h6 class="text-sm font-semibold mt-4 mb-2">$1</h6>');
  html = html.replace(/^##### (.*$)/gim, '<h5 class="text-base font-semibold mt-4 mb-2">$1</h5>');
  html = html.replace(/^#### (.*$)/gim, '<h4 class="text-lg font-semibold mt-4 mb-2">$1</h4>');
  html = html.replace(/^### (.*$)/gim, '<h3 class="text-xl font-semibold mt-4 mb-2">$1</h3>');
  html = html.replace(/^## (.*$)/gim, '<h2 class="text-2xl font-bold mt-6 mb-3">$1</h2>');
  html = html.replace(/^# (.*$)/gim, '<h1 class="text-3xl font-bold mt-6 mb-4">$1</h1>');

  // Bold
  html = html.replace(/\*\*(.*?)\*\*/gim, '<strong class="font-bold">$1</strong>');
  html = html.replace(/__(.*?)__/gim, '<strong class="font-bold">$1</strong>');

  // Italic
  html = html.replace(/\*(.*?)\*/gim, '<em class="italic">$1</em>');
  html = html.replace(/_(.*?)_/gim, '<em class="italic">$1</em>');

  // Strikethrough
  html = html.replace(/~~(.*?)~~/gim, '<del class="line-through">$1</del>');

  // Code blocks
  html = html.replace(
    /```(\w*)\n([\s\S]*?)```/gim,
    '<pre class="bg-muted p-3 rounded-md overflow-x-auto my-2"><code class="text-sm font-mono">$2</code></pre>'
  );

  // Inline code
  html = html.replace(
    /`([^`]+)`/gim,
    '<code class="bg-muted px-1.5 py-0.5 rounded text-sm font-mono">$1</code>'
  );

  // Links
  html = html.replace(
    /\[([^\]]+)\]\(([^)]+)\)/gim,
    '<a href="$2" class="text-primary underline hover:no-underline" target="_blank" rel="noopener">$1</a>'
  );

  // Images
  html = html.replace(
    /!\[([^\]]*)\]\(([^)]+)\)/gim,
    '<img src="$2" alt="$1" class="max-w-full rounded-md my-2" />'
  );

  // Unordered lists
  html = html.replace(/^\s*[-*+] (.+)$/gim, '<li class="ml-4">$1</li>');
  html = html.replace(/(<li class="ml-4">.*<\/li>\n?)+/gim, (match) => {
    return `<ul class="list-disc list-inside my-2 space-y-1">${match}</ul>`;
  });

  // Ordered lists
  html = html.replace(/^\s*\d+\. (.+)$/gim, '<li class="ml-4">$1</li>');

  // Blockquotes
  html = html.replace(
    /^&gt; (.+)$/gim,
    '<blockquote class="border-l-4 border-primary/50 pl-4 py-1 my-2 italic text-muted-foreground">$1</blockquote>'
  );

  // Horizontal rules
  html = html.replace(/^---$/gim, '<hr class="my-4 border-border" />');
  html = html.replace(/^\*\*\*$/gim, '<hr class="my-4 border-border" />');

  // Line breaks (paragraphs)
  html = html.replace(/\n\n/gim, '</p><p class="my-2">');
  html = html.replace(/\n/gim, '<br />');

  // Wrap in paragraph if not already wrapped
  if (!html.startsWith('<')) {
    html = `<p class="my-2">${html}</p>`;
  }

  // Task lists
  html = html.replace(
    /\[ \]/gim,
    '<input type="checkbox" disabled class="mr-2 rounded border-border" />'
  );
  html = html.replace(
    /\[x\]/gim,
    '<input type="checkbox" checked disabled class="mr-2 rounded border-border" />'
  );

  return html;
}

export const MarkdownRenderer = ({ content, className = "" }: MarkdownRendererProps) => {
  const renderedHtml = useMemo(() => parseMarkdown(content), [content]);

  return (
    <div
      className={`prose prose-sm dark:prose-invert max-w-none ${className}`}
      dangerouslySetInnerHTML={{ __html: renderedHtml }}
    />
  );
};

export default MarkdownRenderer;
