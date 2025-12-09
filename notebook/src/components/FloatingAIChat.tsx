/**
 * Floating AI Chat component for non-notebook pages.
 * Provides a collapsible chat interface with AI assistance.
 */
import { useState, useRef, useEffect, useCallback } from "react";
import {
  MessageSquare,
  X,
  Send,
  Loader2,
  Sparkles,
  Bot,
  User,
  ChevronDown,
  Minimize2,
  Maximize2,
  RefreshCw,
  Trash2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { Textarea } from "./ui/textarea";
import { ScrollArea } from "./ui/scroll-area";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { aiService, AIProvider } from "@/services/aiService";
import { settingsService } from "@/services/settingsService";

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
}

interface FloatingAIChatProps {
  isOpen: boolean;
  onToggle: () => void;
  context?: Record<string, unknown>;
  systemPrompt?: string;
  title?: string;
  welcomeMessage?: string;
}

export const FloatingAIChat = ({
  isOpen,
  onToggle,
  context,
  systemPrompt,
  title = "AI Assistant",
  welcomeMessage = "Hello! I'm your AI assistant. How can I help you today?",
}: FloatingAIChatProps) => {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "welcome",
      role: "assistant",
      content: welcomeMessage,
      timestamp: new Date(),
    },
  ]);
  const [inputValue, setInputValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [selectedProvider, setSelectedProvider] = useState<AIProvider>("claude-code");
  const [claudeCodeAvailable, setClaudeCodeAvailable] = useState<boolean | null>(null);

  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Check Claude Code availability
  useEffect(() => {
    aiService.getClaudeCodeStatus().then((status) => {
      setClaudeCodeAvailable(status.available);
      if (!status.available) {
        setSelectedProvider("claude");
      }
    });
  }, []);

  // Scroll to bottom on new messages
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  // Focus input when opened
  useEffect(() => {
    if (isOpen && !isMinimized && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen, isMinimized]);

  const handleSend = useCallback(async () => {
    if (!inputValue.trim() || isLoading) return;

    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: "user",
      content: inputValue.trim(),
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputValue("");
    setIsLoading(true);

    // Create placeholder for streaming response
    const assistantMessageId = `assistant-${Date.now()}`;
    setMessages((prev) => [...prev, {
      id: assistantMessageId,
      role: "assistant",
      content: "",
      timestamp: new Date(),
    }]);

    try {
      // Build context string
      let contextStr = "";
      if (context) {
        contextStr = `\n\nContext:\n${JSON.stringify(context, null, 2)}`;
      }

      // Build messages for API
      const apiMessages = messages
        .filter((m) => m.id !== "welcome")
        .map((m) => ({
          role: m.role as "user" | "assistant",
          content: m.content,
        }));

      apiMessages.push({
        role: "user",
        content: userMessage.content + contextStr,
      });

      if (selectedProvider === "claude-code" && claudeCodeAvailable) {
        // Use Claude Code CLI with streaming
        let fullContent = "";

        for await (const chunk of aiService.claudeCodeChatStream({
          messages: apiMessages,
          systemPrompt: systemPrompt || "You are a helpful AI assistant for data science and machine learning tasks.",
        })) {
          if (chunk.type === "content" && chunk.content) {
            fullContent += chunk.content;
            setMessages((prev) =>
              prev.map((m) =>
                m.id === assistantMessageId
                  ? { ...m, content: fullContent }
                  : m
              )
            );
          } else if (chunk.type === "result") {
            // Final result - use content if provided, otherwise keep accumulated content
            if (chunk.content) {
              fullContent = chunk.content;
              setMessages((prev) =>
                prev.map((m) =>
                  m.id === assistantMessageId
                    ? { ...m, content: fullContent }
                    : m
                )
              );
            }
          } else if (chunk.type === "error") {
            setMessages((prev) =>
              prev.map((m) =>
                m.id === assistantMessageId
                  ? { ...m, content: `Error: ${chunk.content || "Unknown error"}` }
                  : m
              )
            );
          }
        }
      } else {
        // Use regular Claude API with streaming - use settings for maxTokens
        const settings = settingsService.get();
        const maxTokens = settings.claudeCode?.maxOutputTokens || 16384;
        let fullContent = "";

        for await (const chunk of aiService.chatStream({
          provider: selectedProvider,
          messages: apiMessages,
          systemPrompt: systemPrompt || "You are a helpful AI assistant for data science and machine learning tasks.",
          maxTokens,
        })) {
          if (chunk) {
            fullContent += chunk;
            setMessages((prev) =>
              prev.map((m) =>
                m.id === assistantMessageId
                  ? { ...m, content: fullContent }
                  : m
              )
            );
          }
        }
      }
    } catch (error) {
      setMessages((prev) =>
        prev.map((m) =>
          m.id === assistantMessageId
            ? { ...m, content: `Error: ${error instanceof Error ? error.message : "Failed to get response"}` }
            : m
        )
      );
    } finally {
      setIsLoading(false);
    }
  }, [inputValue, isLoading, messages, context, systemPrompt, selectedProvider, claudeCodeAvailable]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleClearChat = () => {
    setMessages([
      {
        id: "welcome",
        role: "assistant",
        content: welcomeMessage,
        timestamp: new Date(),
      },
    ]);
  };

  if (!isOpen) {
    return (
      <button
        onClick={onToggle}
        className="fixed bottom-6 right-6 z-50 flex h-14 w-14 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-lg transition-all hover:scale-105 hover:shadow-xl"
      >
        <MessageSquare className="h-6 w-6" />
      </button>
    );
  }

  return (
    <div
      className={cn(
        "fixed bottom-6 right-6 z-50 flex flex-col rounded-lg border border-border bg-background shadow-2xl transition-all",
        isMinimized ? "h-12 w-96" : "h-[650px] w-[480px]"
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border bg-muted/50 px-4 py-2 rounded-t-lg">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-primary" />
          <span className="font-semibold text-sm">{title}</span>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => setIsMinimized(!isMinimized)}
            className="rounded p-1 hover:bg-muted"
          >
            {isMinimized ? (
              <Maximize2 className="h-4 w-4" />
            ) : (
              <Minimize2 className="h-4 w-4" />
            )}
          </button>
          <button onClick={onToggle} className="rounded p-1 hover:bg-muted">
            <X className="h-4 w-4" />
          </button>
        </div>
      </div>

      {!isMinimized && (
        <>
          {/* Provider Selector */}
          <div className="flex items-center justify-between border-b border-border px-3 py-2 bg-muted/30">
            <Select
              value={selectedProvider}
              onValueChange={(v) => setSelectedProvider(v as AIProvider)}
            >
              <SelectTrigger className="h-7 w-40 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {claudeCodeAvailable && (
                  <SelectItem value="claude-code">
                    <div className="flex items-center gap-1.5">
                      <Bot className="h-3 w-3" />
                      Claude Code
                    </div>
                  </SelectItem>
                )}
                <SelectItem value="claude">
                  <div className="flex items-center gap-1.5">
                    <Sparkles className="h-3 w-3" />
                    Claude API
                  </div>
                </SelectItem>
                <SelectItem value="openai">
                  <div className="flex items-center gap-1.5">
                    <Bot className="h-3 w-3" />
                    GPT-4
                  </div>
                </SelectItem>
              </SelectContent>
            </Select>

            <button
              onClick={handleClearChat}
              className="rounded p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
              title="Clear chat"
            >
              <Trash2 className="h-3.5 w-3.5" />
            </button>
          </div>

          {/* Messages */}
          <ScrollArea className="flex-1 p-4" ref={scrollRef}>
            <div className="space-y-4">
              {messages.map((message) => (
                <div
                  key={message.id}
                  className={cn(
                    "flex gap-3",
                    message.role === "user" ? "flex-row-reverse" : "flex-row"
                  )}
                >
                  <div
                    className={cn(
                      "flex h-7 w-7 shrink-0 items-center justify-center rounded-full",
                      message.role === "user"
                        ? "bg-primary text-primary-foreground"
                        : "bg-muted"
                    )}
                  >
                    {message.role === "user" ? (
                      <User className="h-4 w-4" />
                    ) : (
                      <Bot className="h-4 w-4" />
                    )}
                  </div>
                  <div
                    className={cn(
                      "max-w-[80%] rounded-lg px-3 py-2 text-sm",
                      message.role === "user"
                        ? "bg-primary text-primary-foreground"
                        : "bg-muted"
                    )}
                  >
                    <p className="whitespace-pre-wrap">{message.content}</p>
                    <p className="mt-1 text-[10px] opacity-60">
                      {message.timestamp.toLocaleTimeString()}
                    </p>
                  </div>
                </div>
              ))}

              {isLoading && (
                <div className="flex items-center gap-3">
                  <div className="flex h-7 w-7 items-center justify-center rounded-full bg-muted">
                    <Bot className="h-4 w-4" />
                  </div>
                  <div className="flex items-center gap-2 rounded-lg bg-muted px-3 py-2">
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <span className="text-sm text-muted-foreground">Thinking...</span>
                  </div>
                </div>
              )}
            </div>
          </ScrollArea>

          {/* Input */}
          <div className="border-t border-border p-3">
            <div className="flex gap-2">
              <Textarea
                ref={inputRef}
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Ask me anything..."
                className="min-h-[40px] max-h-[100px] resize-none text-sm"
                rows={1}
              />
              <Button
                size="icon"
                onClick={handleSend}
                disabled={!inputValue.trim() || isLoading}
                className="shrink-0"
              >
                {isLoading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Send className="h-4 w-4" />
                )}
              </Button>
            </div>
            <p className="mt-1.5 text-[10px] text-muted-foreground text-center">
              Press Enter to send, Shift+Enter for new line
            </p>
          </div>
        </>
      )}
    </div>
  );
};

export default FloatingAIChat;
