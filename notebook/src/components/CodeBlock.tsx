import { useState } from "react";
import { Check, Copy, ChevronDown } from "lucide-react";
import { cn, copyToClipboard } from "@/lib/utils";

const languages = ["Java", "Python", "JavaScript", "Go", "cURL"];

const codeSnippets: Record<string, string> = {
  Java: `package com.example;

import com.google.genai.Client;
import com.google.genai.types.GenerateContentResponse;

public class GenerateTextFromTextInput {
  public static void main(String[] args) {
    Client client = new Client();

    GenerateContentResponse response =
        client.models.generateContent(
            "gemini-3-pro-preview",
            "Explain how AI works in a few words",
            null);`,
  Python: `from google import genai

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3-pro-preview",
    contents="Explain how AI works in a few words"
)

print(response.text)`,
  JavaScript: `import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({ apiKey: "YOUR_API_KEY" });

async function main() {
  const response = await ai.models.generateContent({
    model: "gemini-3-pro-preview",
    contents: "Explain how AI works in a few words",
  });

  console.log(response.text);
}`,
  Go: `package main

import (
    "context"
    "fmt"
    genai "google.golang.org/genai"
)

func main() {
    ctx := context.Background()
    client, _ := genai.NewClient(ctx)

    resp, _ := client.GenerateContent(ctx,
        "gemini-3-pro-preview",
        "Explain how AI works in a few words")

    fmt.Println(resp.Text())
}`,
  cURL: `curl https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent \\
  -H "Content-Type: application/json" \\
  -H "x-goog-api-key: YOUR_API_KEY" \\
  -d '{
    "contents": [{
      "parts": [{"text": "Explain how AI works in a few words"}]
    }]
  }'`,
};

const highlightCode = (code: string, lang: string) => {
  const keywords = ["package", "import", "public", "class", "static", "void", "new", "from", "async", "function", "await", "const", "func"];
  const strings = /"[^"]*"/g;
  
  let highlighted = code
    .replace(strings, (match) => `<span class="text-code-string">${match}</span>`);
  
  keywords.forEach((kw) => {
    const regex = new RegExp(`\\b${kw}\\b`, "g");
    highlighted = highlighted.replace(regex, `<span class="text-code-keyword">${kw}</span>`);
  });
  
  return highlighted;
};

export const CodeBlock = () => {
  const [selectedLang, setSelectedLang] = useState("Java");
  const [copied, setCopied] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const handleCopy = async () => {
    const success = await copyToClipboard(codeSnippets[selectedLang]);
    if (success) {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="rounded-xl border border-border bg-card overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <div className="relative">
          <button
            onClick={() => setDropdownOpen(!dropdownOpen)}
            className="flex items-center gap-2 rounded-lg bg-secondary px-3 py-1.5 text-sm text-foreground hover:bg-accent"
          >
            {selectedLang}
            <ChevronDown className="h-4 w-4 text-muted-foreground" />
          </button>
          {dropdownOpen && (
            <div className="absolute left-0 top-full z-10 mt-1 w-32 rounded-lg border border-border bg-popover py-1 shadow-lg">
              {languages.map((lang) => (
                <button
                  key={lang}
                  onClick={() => {
                    setSelectedLang(lang);
                    setDropdownOpen(false);
                  }}
                  className={cn(
                    "w-full px-3 py-1.5 text-left text-sm hover:bg-accent",
                    selectedLang === lang && "bg-accent"
                  )}
                >
                  {lang}
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1.5 rounded-lg p-2 text-muted-foreground hover:bg-secondary hover:text-foreground"
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        </button>
      </div>

      {/* Code */}
      <div className="overflow-x-auto p-4">
        <pre className="font-mono text-sm leading-relaxed">
          <code
            dangerouslySetInnerHTML={{
              __html: highlightCode(codeSnippets[selectedLang], selectedLang),
            }}
          />
        </pre>
      </div>
    </div>
  );
};
