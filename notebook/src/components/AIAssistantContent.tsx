import { useState, useRef, useEffect, useCallback } from "react";
import {
  Sparkles,
  Bot,
  Gem,
  ChevronDown,
  Send,
  Trash2,
  User,
  Loader2,
  Copy,
  Play,
  FilePlus,
  SendHorizontal,
  Brain,
  Bug,
  Zap,
  FileText,
  Code2,
  TestTube,
  FileCode,
  BarChart,
  GitBranch,
  Cpu,
  ChevronRight,
  MessageSquare,
  Check,
  X,
  RefreshCw,
  Square,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "./ui/dialog";
import { AIAssistantBreadcrumb } from "./AIAssistantBreadcrumb";
import { aiService, AIProvider, ChatRequest } from "@/services/aiService";
import { useKernelExecution } from "@/hooks/useKernelExecution";
import { CellOutput } from "@/types/notebook";
import { MonacoCodeEditor } from "./notebook/MonacoCodeEditor";

interface AIMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  timestamp: Date;
  tokenCount?: number; // Real token count from API
}

interface Conversation {
  id: string;
  title: string;
  messages: AIMessage[];
  createdAt: Date;
  updatedAt: Date;
}

type ActionType = "executeCode" | "createNotebook" | "sendToNotebook" | "trainModel";

const WELCOME_MESSAGE = `Hello! I'm your AI coding assistant. I can help you with:

• Writing and debugging code
• Explaining complex concepts
• Optimizing GPU-accelerated code
• Data analysis with pandas/numpy
• Machine learning with PyTorch

**Actions I can perform:**
• Execute code directly
• Create new notebooks
• Add code to existing notebooks
• Train ML models

Use the action buttons below or just ask me!`;

const PROMPT_TEMPLATES = [
  {
    icon: Bug,
    title: "Debug Code",
    description: "Find and fix errors",
    prompt: "I have a bug in my code. Can you help me identify the issue and suggest a fix?",
  },
  {
    icon: Zap,
    title: "Optimize for GPU",
    description: "CUDA optimization tips",
    prompt: "How can I optimize this code to run faster on NVIDIA GPU with CUDA?",
  },
  {
    icon: Brain,
    title: "ML Architecture",
    description: "Neural network design",
    prompt: "Help me design a neural network architecture for my problem",
  },
  {
    icon: BarChart,
    title: "Data Analysis",
    description: "Pandas & visualization",
    prompt: "Show me how to analyze this dataset using pandas and create visualizations",
  },
  {
    icon: GitBranch,
    title: "Code Review",
    description: "Best practices check",
    prompt: "Review this code and suggest improvements for readability and best practices",
  },
  {
    icon: Cpu,
    title: "PyTorch Model",
    description: "Training & inference",
    prompt: "Help me create a PyTorch model with training loop and inference code",
  },
];

const QUICK_ACTIONS = [
  { icon: Bug, label: "Debug", prompt: "Help me debug this code. What could be wrong and how can I fix it?" },
  { icon: Zap, label: "Optimize", prompt: "How can I optimize this code for better performance on GPU?" },
  { icon: FileText, label: "Explain", prompt: "Can you explain how this code works step by step?" },
  { icon: Code2, label: "Generate", prompt: "Write Python code that" },
  { icon: TestTube, label: "Test", prompt: "Write unit tests for this code using pytest" },
  { icon: FileCode, label: "Document", prompt: "Add docstrings and comments to document this code" },
];

// Local storage key for chat history
const STORAGE_KEY = "ai_assistant_history";
const CONVERSATIONS_KEY = "ai_assistant_conversations";

// Load conversations from localStorage
const loadConversations = (): Conversation[] => {
  try {
    const data = localStorage.getItem(CONVERSATIONS_KEY);
    if (data) {
      const parsed = JSON.parse(data);
      return parsed.map((conv: Conversation) => ({
        ...conv,
        createdAt: new Date(conv.createdAt),
        updatedAt: new Date(conv.updatedAt),
        messages: conv.messages.map((m: AIMessage) => ({
          ...m,
          timestamp: new Date(m.timestamp),
        })),
      }));
    }
  } catch (e) {
    console.error("Error loading conversations:", e);
  }
  return [];
};

// Save conversations to localStorage
const saveConversations = (conversations: Conversation[]) => {
  try {
    localStorage.setItem(CONVERSATIONS_KEY, JSON.stringify(conversations));
  } catch (e) {
    console.error("Error saving conversations:", e);
  }
};

export const AIAssistantContent = () => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Conversations state
  const [conversations, setConversations] = useState<Conversation[]>(() => loadConversations());
  const [currentConversationId, setCurrentConversationId] = useState<string | null>(null);

  // Messages for current conversation
  const [messages, setMessages] = useState<AIMessage[]>([
    {
      id: "welcome",
      role: "assistant",
      content: WELCOME_MESSAGE,
      timestamp: new Date(),
    },
  ]);

  const [inputValue, setInputValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [streamingContent, setStreamingContent] = useState("");
  const [selectedProvider, setSelectedProvider] = useState<AIProvider>("claude");
  const [conversationTitle, setConversationTitle] = useState("New Chat");
  const [tokenCount, setTokenCount] = useState(0);
  const [copied, setCopied] = useState<string | null>(null);

  // Action modal state
  const [actionModal, setActionModal] = useState<{
    open: boolean;
    type: ActionType;
    code: string;
  }>({ open: false, type: "executeCode", code: "" });

  // Execution state for action modal
  const [actionOutput, setActionOutput] = useState<CellOutput[]>([]);
  const [isExecutingAction, setIsExecutingAction] = useState(false);

  // Kernel execution for running code
  const {
    kernel,
    kernelStatus,
    isConnected,
    isExecuting: isKernelExecuting,
    connect: connectKernel,
    execute: executeCode,
    interrupt: interruptExecution,
  } = useKernelExecution({
    onOutput: useCallback((cellId: string, output: CellOutput) => {
      if (cellId === "ai-action") {
        setActionOutput((prev) => [...prev, output]);
      }
    }, []),
  });

  // Connect to kernel on mount
  useEffect(() => {
    connectKernel().catch(console.error);
  }, []);

  // Save conversations when they change
  useEffect(() => {
    saveConversations(conversations);
  }, [conversations]);

  // Update token count - use real tokens when available, estimate for user messages
  useEffect(() => {
    const totalTokens = messages.reduce((acc, m) => {
      // Use real token count if available, otherwise estimate
      return acc + (m.tokenCount || aiService.estimateTokens(m.content));
    }, 0);
    setTokenCount(totalTokens);
  }, [messages]);

  useEffect(() => {
    scrollToBottom();
  }, [messages, streamingContent]);

  const scrollToBottom = () => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  };

  // Create new conversation
  const createNewConversation = useCallback(() => {
    const newConv: Conversation = {
      id: Date.now().toString(),
      title: "New Chat",
      messages: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    setConversations((prev) => [newConv, ...prev]);
    setCurrentConversationId(newConv.id);
    setMessages([
      {
        id: "welcome",
        role: "assistant",
        content: WELCOME_MESSAGE,
        timestamp: new Date(),
      },
    ]);
    setConversationTitle("New Chat");
  }, []);

  // Save current messages to conversation
  const saveCurrentConversation = useCallback(() => {
    if (!currentConversationId) return;

    setConversations((prev) =>
      prev.map((conv) =>
        conv.id === currentConversationId
          ? { ...conv, messages, title: conversationTitle, updatedAt: new Date() }
          : conv
      )
    );
  }, [currentConversationId, messages, conversationTitle]);

  // Load a conversation
  const loadConversation = useCallback((conv: Conversation) => {
    setCurrentConversationId(conv.id);
    setMessages(conv.messages.length > 0 ? conv.messages : [
      {
        id: "welcome",
        role: "assistant",
        content: WELCOME_MESSAGE,
        timestamp: new Date(),
      },
    ]);
    setConversationTitle(conv.title);
  }, []);

  // Send message with real API
  const handleSend = async () => {
    const content = inputValue.trim();
    if (!content || isLoading) return;

    const userMessage: AIMessage = {
      id: Date.now().toString(),
      role: "user",
      content,
      timestamp: new Date(),
    };

    const newMessages = [...messages, userMessage];
    setMessages(newMessages);
    setInputValue("");
    setIsLoading(true);
    setStreamingContent("");

    // Update conversation title from first user message
    if (messages.filter((m) => m.role === "user").length === 0) {
      const newTitle = content.length > 30 ? content.substring(0, 30) + "..." : content;
      setConversationTitle(newTitle);
    }

    // Create conversation if needed
    if (!currentConversationId) {
      const newConv: Conversation = {
        id: Date.now().toString(),
        title: content.length > 30 ? content.substring(0, 30) + "..." : content,
        messages: newMessages,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      setConversations((prev) => [newConv, ...prev]);
      setCurrentConversationId(newConv.id);
    }

    try {
      const request: ChatRequest = {
        provider: selectedProvider,
        messages: newMessages
          .filter((m) => m.role !== "system" && m.id !== "welcome")
          .map((m) => ({ role: m.role, content: m.content })),
        systemPrompt: "You are a helpful AI coding assistant. You help with Python, GPU programming, machine learning, and data analysis. When providing code, use markdown code blocks with the language specified.",
      };

      let responseContent = "";
      let realTokenCount: number | undefined;
      let model: string | undefined;

      // Use streaming API
      for await (const chunk of aiService.chatStream(request)) {
        try {
          const parsed = JSON.parse(chunk);
          if (parsed.content) {
            responseContent += parsed.content;
            setStreamingContent(responseContent);
            scrollToBottom();
          }
          if (parsed.done && parsed.usage) {
            realTokenCount = (parsed.usage.input_tokens || 0) + (parsed.usage.output_tokens || 0);
            model = parsed.model;
          }
          if (parsed.error) {
            throw new Error(parsed.error);
          }
        } catch (e) {
          // If not valid JSON, treat as plain text (fallback)
          if (!(e instanceof SyntaxError)) throw e;
          responseContent += chunk;
          setStreamingContent(responseContent);
          scrollToBottom();
        }
      }

      const assistantMessage: AIMessage = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: responseContent || "I apologize, but I couldn't generate a response. Please try again.",
        timestamp: new Date(),
        tokenCount: realTokenCount,
      };

      const updatedMessages = [...newMessages, assistantMessage];
      setMessages(updatedMessages);

      // Save to conversation
      if (currentConversationId) {
        setConversations((prev) =>
          prev.map((conv) =>
            conv.id === currentConversationId
              ? { ...conv, messages: updatedMessages, updatedAt: new Date() }
              : conv
          )
        );
      }
    } catch (error) {
      console.error("AI chat error:", error);
      const errorMessage: AIMessage = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: `Error: ${error instanceof Error ? error.message : "Failed to get response"}\n\nPlease check your API key in Settings and try again.`,
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
      setStreamingContent("");
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleQuickAction = (prompt: string) => {
    setInputValue(prompt);
    inputRef.current?.focus();
  };

  const handleClearChat = () => {
    setMessages([
      {
        id: Date.now().toString(),
        role: "assistant",
        content: "Chat cleared. How can I help you?",
        timestamp: new Date(),
      },
    ]);
    setConversationTitle("New Chat");
    setCurrentConversationId(null);
  };

  const handleNewChat = () => {
    createNewConversation();
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopied(id);
    setTimeout(() => setCopied(null), 2000);
  };

  const extractCodeBlocks = (content: string): string[] => {
    const regex = /```(?:python|py)?\n?([\s\S]*?)```/g;
    const matches = [...content.matchAll(regex)];
    return matches.map((m) => m[1]?.trim() || "").filter((c) => c.length > 0);
  };

  // Action handlers
  const openActionModal = (type: ActionType, code: string = "") => {
    setActionModal({ open: true, type, code });
    setActionOutput([]);
    setIsExecutingAction(false);
  };

  const closeActionModal = () => {
    setActionModal({ open: false, type: "executeCode", code: "" });
    setActionOutput([]);
    setIsExecutingAction(false);
  };

  const handleExecuteCode = async () => {
    if (!isConnected || !actionModal.code.trim()) return;

    setIsExecutingAction(true);
    setActionOutput([]);

    try {
      await executeCode("ai-action", actionModal.code);
    } catch (error) {
      setActionOutput([{
        outputType: "error",
        ename: "Error",
        evalue: error instanceof Error ? error.message : "Execution failed",
        traceback: [],
      }]);
    } finally {
      setIsExecutingAction(false);
    }
  };

  const handleCreateNotebook = () => {
    // Navigate to notebook creation with code
    const code = actionModal.code;
    // Store in sessionStorage for notebook to pick up
    sessionStorage.setItem("newNotebookCode", code);
    window.location.href = "/notebooks?action=create";
    closeActionModal();
  };

  const handleSendToNotebook = () => {
    // Store code for notebook to pick up
    const code = actionModal.code;
    sessionStorage.setItem("appendToNotebook", code);
    window.location.href = "/notebooks?action=append";
    closeActionModal();
  };

  const getProviderIcon = (provider: AIProvider) => {
    switch (provider) {
      case "claude":
        return Sparkles;
      case "openai":
        return Bot;
      case "gemini":
        return Gem;
    }
  };

  const ProviderIcon = getProviderIcon(selectedProvider);

  // Format output for display
  const formatOutput = (output: CellOutput): string => {
    if (output.text) return output.text;
    if (output.ename && output.evalue) {
      const traceback = output.traceback?.join("\n") || "";
      return `${output.ename}: ${output.evalue}\n${traceback}`;
    }
    if (output.data) {
      if (typeof output.data["text/plain"] === "string") {
        return output.data["text/plain"];
      }
      return JSON.stringify(output.data, null, 2);
    }
    return "";
  };

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Breadcrumb */}
      <AIAssistantBreadcrumb
        conversationTitle={conversationTitle}
        tokenCount={tokenCount}
        onNewChat={handleNewChat}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main Chat Area */}
        <div className="flex flex-1 flex-col">
          {/* Messages */}
          <div ref={scrollRef} className="flex-1 overflow-auto p-4">
            {messages.length === 0 ? (
              <EmptyState />
            ) : (
              <div className="space-y-4">
                {messages.map((message) => (
                  <ChatBubble
                    key={message.id}
                    message={message}
                    providerIcon={ProviderIcon}
                    copied={copied === message.id}
                    onCopy={() => copyToClipboard(message.content, message.id)}
                    onExecuteCode={(code) => openActionModal("executeCode", code)}
                    onSendToNotebook={(code) => openActionModal("sendToNotebook", code)}
                    onCreateNotebook={(code) => openActionModal("createNotebook", code)}
                  />
                ))}
                {isLoading && (
                  <TypingIndicator
                    providerIcon={ProviderIcon}
                    streamingContent={streamingContent}
                  />
                )}
              </div>
            )}
          </div>

          {/* Actions Bar */}
          <div className="flex items-center gap-2 border-t border-border bg-card px-4 py-2">
            <span className="text-xs text-muted-foreground">Actions:</span>
            <ActionButton
              icon={Play}
              label="Execute Code"
              color="text-success"
              bgColor="bg-success/10 border-success/30 hover:bg-success/20"
              onClick={() => openActionModal("executeCode")}
            />
            <ActionButton
              icon={FilePlus}
              label="New Notebook"
              color="text-primary"
              bgColor="bg-primary/10 border-primary/30 hover:bg-primary/20"
              onClick={() => openActionModal("createNotebook")}
            />
            <ActionButton
              icon={SendHorizontal}
              label="To Notebook"
              color="text-orange-500"
              bgColor="bg-orange-500/10 border-orange-500/30 hover:bg-orange-500/20"
              onClick={() => openActionModal("sendToNotebook")}
            />
            <ActionButton
              icon={Brain}
              label="Train Model"
              color="text-purple-500"
              bgColor="bg-purple-500/10 border-purple-500/30 hover:bg-purple-500/20"
              onClick={() => openActionModal("trainModel")}
            />
          </div>

          {/* Quick Actions */}
          <div className="flex items-center gap-2 overflow-x-auto border-t border-border px-4 py-2">
            <span className="shrink-0 text-xs text-muted-foreground">Quick:</span>
            {QUICK_ACTIONS.map((action) => (
              <QuickActionChip
                key={action.label}
                icon={action.icon}
                label={action.label}
                onClick={() => handleQuickAction(action.prompt)}
              />
            ))}
          </div>

          {/* Input */}
          <div className="flex items-end gap-3 border-t border-border bg-card p-4">
            {/* Provider Selector */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="flex items-center gap-1.5 rounded-lg border border-border bg-background px-3 py-2 text-sm hover:bg-muted">
                  <ProviderIcon className="h-4 w-4 text-primary" />
                  <span className="capitalize text-foreground">{selectedProvider}</span>
                  <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start">
                <DropdownMenuItem onClick={() => setSelectedProvider("claude")}>
                  <Sparkles className="mr-2 h-4 w-4" />
                  Claude
                  {selectedProvider === "claude" && <Check className="ml-auto h-4 w-4 text-primary" />}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => setSelectedProvider("openai")}>
                  <Bot className="mr-2 h-4 w-4" />
                  OpenAI
                  {selectedProvider === "openai" && <Check className="ml-auto h-4 w-4 text-primary" />}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => setSelectedProvider("gemini")}>
                  <Gem className="mr-2 h-4 w-4" />
                  Gemini
                  {selectedProvider === "gemini" && <Check className="ml-auto h-4 w-4 text-primary" />}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Input Field */}
            <textarea
              ref={inputRef}
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Ask anything about coding, GPU, or ML..."
              className="flex-1 resize-none rounded-lg border border-border bg-background px-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none"
              rows={1}
              style={{ minHeight: "42px", maxHeight: "120px" }}
            />

            {/* Send Button */}
            <Button onClick={handleSend} disabled={isLoading || !inputValue.trim()}>
              {isLoading ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Send className="h-4 w-4" />
              )}
            </Button>
          </div>
        </div>

        {/* Side Panel */}
        <div className="flex w-72 flex-col border-l border-border bg-card">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <span className="text-xs font-semibold text-muted-foreground">Prompts</span>
            <button
              onClick={handleClearChat}
              className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground"
            >
              <Trash2 className="h-3.5 w-3.5" />
            </button>
          </div>

          {/* Prompt Templates */}
          <div className="flex-1 overflow-auto p-3">
            <div className="space-y-2">
              {PROMPT_TEMPLATES.map((template) => (
                <PromptCard
                  key={template.title}
                  icon={template.icon}
                  title={template.title}
                  description={template.description}
                  onClick={() => handleQuickAction(template.prompt)}
                />
              ))}
            </div>
          </div>

          {/* Provider Status */}
          <div className="border-t border-border p-3">
            <div className="flex items-center gap-2.5 rounded-lg border border-success/30 bg-success/5 p-3">
              <div className="flex h-8 w-8 items-center justify-center rounded-md bg-success/10">
                <ProviderIcon className="h-4 w-4 text-success" />
              </div>
              <div className="flex-1">
                <p className="text-xs font-medium capitalize text-foreground">{selectedProvider}</p>
                <p className="text-[10px] text-success">Ready</p>
              </div>
              <span className="h-2 w-2 rounded-full bg-success" />
            </div>
          </div>
        </div>
      </div>

      {/* Action Modal */}
      <Dialog open={actionModal.open} onOpenChange={(open) => !open && closeActionModal()}>
        <DialogContent className="max-w-3xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {actionModal.type === "executeCode" && (
                <>
                  <Play className="h-5 w-5 text-success" />
                  Execute Code
                </>
              )}
              {actionModal.type === "createNotebook" && (
                <>
                  <FilePlus className="h-5 w-5 text-primary" />
                  Create New Notebook
                </>
              )}
              {actionModal.type === "sendToNotebook" && (
                <>
                  <SendHorizontal className="h-5 w-5 text-orange-500" />
                  Send to Notebook
                </>
              )}
              {actionModal.type === "trainModel" && (
                <>
                  <Brain className="h-5 w-5 text-purple-500" />
                  Train Model
                </>
              )}
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-4">
            {/* Code Editor */}
            <div className="h-64 overflow-hidden rounded-lg border border-border">
              <MonacoCodeEditor
                value={actionModal.code}
                onChange={(code) => setActionModal((prev) => ({ ...prev, code }))}
                language="python"
                height="100%"
                placeholder="# Enter Python code..."
              />
            </div>

            {/* Output (for execute) */}
            {actionModal.type === "executeCode" && (
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">Output</span>
                  {isExecutingAction && (
                    <span className="flex items-center gap-1 text-xs text-muted-foreground">
                      <Loader2 className="h-3 w-3 animate-spin" />
                      Running...
                    </span>
                  )}
                </div>
                <div className="max-h-48 overflow-auto rounded-lg border border-border bg-muted p-3">
                  {actionOutput.length === 0 ? (
                    <p className="text-sm text-muted-foreground">Output will appear here</p>
                  ) : (
                    <pre className="whitespace-pre-wrap font-mono text-sm">
                      {actionOutput.map(formatOutput).filter(Boolean).join("")}
                    </pre>
                  )}
                </div>
              </div>
            )}

            {/* Kernel Status */}
            {actionModal.type === "executeCode" && (
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <span
                  className={cn(
                    "h-2 w-2 rounded-full",
                    isConnected ? "bg-success" : "bg-destructive"
                  )}
                />
                <span>
                  {isConnected
                    ? `Kernel ${kernelStatus}`
                    : "Kernel disconnected"}
                </span>
              </div>
            )}
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={closeActionModal}>
              Cancel
            </Button>

            {actionModal.type === "executeCode" && (
              <>
                {isExecutingAction ? (
                  <Button variant="destructive" onClick={interruptExecution}>
                    <Square className="mr-2 h-4 w-4" />
                    Stop
                  </Button>
                ) : (
                  <Button onClick={handleExecuteCode} disabled={!isConnected || !actionModal.code.trim()}>
                    <Play className="mr-2 h-4 w-4" />
                    Run
                  </Button>
                )}
              </>
            )}

            {actionModal.type === "createNotebook" && (
              <Button onClick={handleCreateNotebook} disabled={!actionModal.code.trim()}>
                <FilePlus className="mr-2 h-4 w-4" />
                Create Notebook
              </Button>
            )}

            {actionModal.type === "sendToNotebook" && (
              <Button onClick={handleSendToNotebook} disabled={!actionModal.code.trim()}>
                <SendHorizontal className="mr-2 h-4 w-4" />
                Send to Notebook
              </Button>
            )}

            {actionModal.type === "trainModel" && (
              <Button onClick={() => closeActionModal()} disabled={!actionModal.code.trim()}>
                <Brain className="mr-2 h-4 w-4" />
                Start Training
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

// Empty State
const EmptyState = () => (
  <div className="flex h-full flex-col items-center justify-center">
    <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/10">
      <MessageSquare className="h-8 w-8 text-primary" />
    </div>
    <p className="mt-4 text-lg font-semibold text-foreground">Start a conversation</p>
    <p className="mt-2 text-sm text-muted-foreground">
      Ask me anything about coding, debugging, or GPU programming
    </p>
  </div>
);

// Typing Indicator
interface TypingIndicatorProps {
  providerIcon: React.ComponentType<{ className?: string }>;
  streamingContent: string;
}

const TypingIndicator = ({ providerIcon: Icon, streamingContent }: TypingIndicatorProps) => (
  <div className="flex items-start gap-3">
    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/20">
      <Icon className="h-4 w-4 text-primary" />
    </div>
    <div className="flex-1 rounded-xl border border-border bg-card p-4">
      {streamingContent ? (
        <p className="whitespace-pre-wrap text-sm text-foreground">{streamingContent}</p>
      ) : (
        <div className="flex items-center gap-1">
          <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground" style={{ animationDelay: "0ms" }} />
          <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground" style={{ animationDelay: "150ms" }} />
          <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground" style={{ animationDelay: "300ms" }} />
        </div>
      )}
    </div>
  </div>
);

// Chat Bubble
interface ChatBubbleProps {
  message: AIMessage;
  providerIcon: React.ComponentType<{ className?: string }>;
  copied: boolean;
  onCopy: () => void;
  onExecuteCode?: (code: string) => void;
  onSendToNotebook?: (code: string) => void;
  onCreateNotebook?: (code: string) => void;
}

const ChatBubble = ({
  message,
  providerIcon: Icon,
  copied,
  onCopy,
  onExecuteCode,
  onSendToNotebook,
  onCreateNotebook,
}: ChatBubbleProps) => {
  const [isHovered, setIsHovered] = useState(false);
  const isUser = message.role === "user";

  const extractCodeBlocks = (content: string): string[] => {
    const regex = /```(?:python|py)?\n?([\s\S]*?)```/g;
    const matches = [...content.matchAll(regex)];
    return matches.map((m) => m[1]?.trim() || "").filter((c) => c.length > 0);
  };

  const codeBlocks = !isUser ? extractCodeBlocks(message.content) : [];
  const hasCode = codeBlocks.length > 0;

  return (
    <div
      className={cn("flex items-start gap-3", isUser && "flex-row-reverse")}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div
        className={cn(
          "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
          isUser ? "bg-muted" : "bg-primary/20"
        )}
      >
        {isUser ? (
          <User className="h-4 w-4 text-foreground" />
        ) : (
          <Icon className="h-4 w-4 text-primary" />
        )}
      </div>
      <div className="flex flex-col gap-2">
        <div
          className={cn(
            "max-w-2xl rounded-xl px-4 py-3",
            isUser
              ? "bg-primary text-primary-foreground"
              : "border border-border bg-card text-foreground"
          )}
        >
          <p className="whitespace-pre-wrap text-sm leading-relaxed">{message.content}</p>
        </div>
        {isHovered && !isUser && (
          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={onCopy}
              className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground"
            >
              {copied ? (
                <Check className="h-3 w-3 text-success" />
              ) : (
                <Copy className="h-3 w-3" />
              )}
            </button>
            {hasCode && onExecuteCode && (
              <CodeActionButton
                icon={Play}
                label="Run"
                color="text-success"
                onClick={() => onExecuteCode(codeBlocks[0])}
              />
            )}
            {hasCode && onSendToNotebook && (
              <CodeActionButton
                icon={SendHorizontal}
                label="To Notebook"
                color="text-orange-500"
                onClick={() => onSendToNotebook(codeBlocks[0])}
              />
            )}
            {hasCode && onCreateNotebook && (
              <CodeActionButton
                icon={FilePlus}
                label="New Notebook"
                color="text-primary"
                onClick={() => onCreateNotebook(codeBlocks[0])}
              />
            )}
          </div>
        )}
      </div>
    </div>
  );
};

// Code Action Button
interface CodeActionButtonProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  color: string;
  onClick: () => void;
}

const CodeActionButton = ({ icon: Icon, label, color, onClick }: CodeActionButtonProps) => (
  <button
    onClick={onClick}
    className={cn(
      "flex items-center gap-1 rounded border px-2 py-1 text-xs transition-colors",
      color,
      "border-current/30 bg-current/10 hover:bg-current/20"
    )}
    style={{ borderColor: "currentColor", backgroundColor: "color-mix(in srgb, currentColor 10%, transparent)" }}
  >
    <Icon className="h-3 w-3" />
    {label}
  </button>
);

// Action Button
interface ActionButtonProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  color: string;
  bgColor: string;
  onClick: () => void;
}

const ActionButton = ({ icon: Icon, label, color, bgColor, onClick }: ActionButtonProps) => (
  <button
    onClick={onClick}
    className={cn(
      "flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs font-medium transition-colors",
      color,
      bgColor
    )}
  >
    <Icon className="h-3.5 w-3.5" />
    {label}
  </button>
);

// Quick Action Chip
interface QuickActionChipProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  onClick: () => void;
}

const QuickActionChip = ({ icon: Icon, label, onClick }: QuickActionChipProps) => (
  <button
    onClick={onClick}
    className="flex shrink-0 items-center gap-1.5 rounded-full border border-border bg-muted px-3 py-1.5 text-xs text-foreground transition-colors hover:border-primary/30 hover:bg-primary/10 hover:text-primary"
  >
    <Icon className="h-3 w-3 text-muted-foreground" />
    {label}
  </button>
);

// Prompt Card
interface PromptCardProps {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  onClick: () => void;
}

const PromptCard = ({ icon: Icon, title, description, onClick }: PromptCardProps) => (
  <button
    onClick={onClick}
    className="flex w-full items-center gap-2.5 rounded-lg border border-border p-3 text-left transition-colors hover:border-primary/30 hover:bg-primary/5"
  >
    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-primary/10">
      <Icon className="h-4 w-4 text-primary" />
    </div>
    <div className="flex-1">
      <p className="text-xs font-medium text-foreground">{title}</p>
      <p className="text-[10px] text-muted-foreground">{description}</p>
    </div>
    <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />
  </button>
);
