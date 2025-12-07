import { useState, useRef, useEffect, useCallback } from "react";
import {
  Bot,
  Sparkles,
  ChevronDown,
  Send,
  Trash2,
  Play,
  Bug,
  Zap,
  FileText,
  User,
  Loader2,
  Gem,
  History,
  Plus,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { AIMessage, AIProvider, Cell } from "@/types/notebook";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";
import apiClient from "@/services/apiClient";
import aiService from "@/services/aiService";
import {
  parseAIResponse,
  processActions,
  buildNotebookContext,
  NOTEBOOK_SYSTEM_PROMPT,
  AIToolsCallbacks,
  ActionResult,
} from "@/services/aiToolsHandler";

const WELCOME_MESSAGE = `Hello! I can help you with your notebook. I can:

• Create and edit code cells
• Execute code and show results
• Explain errors and suggest fixes
• Help optimize your code

What would you like to do?`;

// Chat message interface for backend
interface BackendChatMessage {
  id?: string;
  role: string;
  content: string;
  created_at?: string;
}

// Convert backend messages to AIMessage
let messageIdCounter = 0;
const toAIMessage = (msg: BackendChatMessage, index?: number): AIMessage => ({
  id: msg.id || `msg-${Date.now()}-${index ?? messageIdCounter++}-${Math.random().toString(36).substr(2, 9)}`,
  role: msg.role as "user" | "assistant" | "system",
  content: msg.content,
  timestamp: msg.created_at ? new Date(msg.created_at) : new Date(),
});

// Convert AIMessage to backend format
const toBackendMessage = (msg: AIMessage): BackendChatMessage => ({
  id: msg.id,
  role: msg.role,
  content: msg.content,
  created_at: msg.timestamp instanceof Date ? msg.timestamp.toISOString() : msg.timestamp as unknown as string,
});

interface AIChatPanelProps {
  notebookId: string;
  getCells: () => Cell[];
  getSelectedCellId: () => string | null;
  onCreateCell: (code: string, position?: number | null) => void;
  onEditCell: (cellId: string, code: string) => void;
  onDeleteCell: (cellId: string) => void;
  onExecuteCell: (cellId: string) => void;
}

export const AIChatPanel = ({
  notebookId,
  getCells,
  getSelectedCellId,
  onCreateCell,
  onEditCell,
  onDeleteCell,
  onExecuteCell,
}: AIChatPanelProps) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
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
  const [isSaving, setIsSaving] = useState(false);
  const [selectedProvider, setSelectedProvider] = useState<AIProvider>("claude");

  // Load chat history from backend on mount
  useEffect(() => {
    const loadChatHistory = async () => {
      if (!notebookId) return;

      try {
        const response = await apiClient.get<{ messages: BackendChatMessage[] }>(
          `/api/notebooks/${notebookId}/chat`
        );

        if (response.messages && response.messages.length > 0) {
          setMessages(response.messages.map((msg, idx) => toAIMessage(msg, idx)));
        }
      } catch (error) {
        console.error("Failed to load chat history:", error);
        // Keep default welcome message on error
      }
    };

    loadChatHistory();
  }, [notebookId]);

  // Save chat history to backend
  const saveChatHistory = useCallback(async (msgs: AIMessage[]) => {
    if (!notebookId || msgs.length <= 1) return; // Don't save just welcome message

    setIsSaving(true);
    try {
      await apiClient.post(`/api/notebooks/${notebookId}/chat`, {
        messages: msgs.map(toBackendMessage),
      });
    } catch (error) {
      console.error("Failed to save chat history:", error);
    } finally {
      setIsSaving(false);
    }
  }, [notebookId]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  };

  // AI Tools callbacks
  const toolsCallbacks: AIToolsCallbacks = {
    onCreateCell,
    onEditCell,
    onDeleteCell,
    onExecuteCell,
    getCells,
    getSelectedCellId,
  };

  // State for showing action results
  const [actionResults, setActionResults] = useState<ActionResult[]>([]);

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
    setActionResults([]);

    try {
      // Build notebook context for AI
      const notebookContext = buildNotebookContext(
        notebookId,
        getCells(),
        getSelectedCellId()
      );

      // Prepare messages for API (exclude welcome message and empty messages)
      const apiMessages = newMessages
        .filter((m) => m.id !== "welcome" && m.content && m.content.trim() !== "")
        .map((m) => ({
          role: m.role,
          content: m.content.trim(),
        }));

      // Call AI API
      const response = await aiService.chat({
        provider: selectedProvider,
        messages: apiMessages,
        systemPrompt: NOTEBOOK_SYSTEM_PROMPT,
        notebookContext,
        maxTokens: 4096,
        temperature: 0.7,
      });

      // Parse response for actions
      const parsed = parseAIResponse(response.message);

      // Process any actions
      let results: ActionResult[] = [];
      if (parsed.actions && parsed.actions.length > 0) {
        results = processActions(parsed.actions, toolsCallbacks);
        setActionResults(results);
      }

      // Build response message with action results
      let responseContent = parsed.message;
      if (results.length > 0) {
        const actionSummary = results
          .map((r) => `• ${r.tool}: ${r.success ? "✓" : "✗"} ${r.message}`)
          .join("\n");
        responseContent += `\n\n**Actions executed:**\n${actionSummary}`;
      }

      const assistantMessage: AIMessage = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: responseContent,
        timestamp: new Date(),
      };

      const updatedMessages = [...newMessages, assistantMessage];
      setMessages(updatedMessages);

      // Save to backend after response
      await saveChatHistory(updatedMessages);
    } catch (error) {
      console.error("AI chat error:", error);

      // Fallback to mock response on error
      const fallbackResponse = generateMockResponse(content, getCells());
      const assistantMessage: AIMessage = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: fallbackResponse,
        timestamp: new Date(),
      };

      const updatedMessages = [...newMessages, assistantMessage];
      setMessages(updatedMessages);
      await saveChatHistory(updatedMessages);
    } finally {
      setIsLoading(false);
    }
  };

  const generateMockResponse = (prompt: string, cells: Cell[]): string => {
    const lowerPrompt = prompt.toLowerCase();

    // Execute cell
    if (lowerPrompt.includes("run") || lowerPrompt.includes("execute")) {
      const selectedId = getSelectedCellId();
      if (selectedId) {
        onExecuteCell(selectedId);
        return "✓ I've started executing the selected cell. You should see the output shortly.\n\n**Action executed:**\n• executeCode: ✓ Executing cell";
      }
      return "Please select a cell first, then I can execute it for you.";
    }

    // Create cell
    if (lowerPrompt.includes("create") || lowerPrompt.includes("add")) {
      // Extract code from prompt if specified
      const codeMatch = prompt.match(/```(?:python)?\s*([\s\S]*?)```/);
      const code = codeMatch
        ? codeMatch[1].trim()
        : `# New cell created by AI\nprint("Hello from AI!")`;

      onCreateCell(code, cells.length);
      return `✓ I've created a new code cell for you.\n\n**Action executed:**\n• createCell: ✓ Created new cell at position ${cells.length}`;
    }

    // Delete cell
    if (lowerPrompt.includes("delete") || lowerPrompt.includes("remove")) {
      const selectedId = getSelectedCellId();
      if (selectedId) {
        onDeleteCell(selectedId);
        return `✓ I've deleted the selected cell.\n\n**Action executed:**\n• deleteCell: ✓ Deleted cell ${selectedId}`;
      }
      return "Please select a cell first to delete it.";
    }

    // List cells
    if (lowerPrompt.includes("list") || lowerPrompt.includes("show cells")) {
      const selectedId = getSelectedCellId();
      const cellList = cells.map((c, i) => {
        const preview = c.source.split("\n")[0].slice(0, 40);
        const marker = c.id === selectedId ? " ← selected" : "";
        return `${i + 1}. [${c.cellType}] ${preview}${preview.length >= 40 ? "..." : ""}${marker}`;
      }).join("\n");

      return `Here are your notebook cells:\n\n${cellList || "(no cells)"}\n\n**Total:** ${cells.length} cells`;
    }

    // Debug help
    if (lowerPrompt.includes("debug") || lowerPrompt.includes("error")) {
      const selectedId = getSelectedCellId();
      const selectedCell = cells.find((c) => c.id === selectedId);

      if (selectedCell && selectedCell.outputs.some(o => o.ename)) {
        const errorOutput = selectedCell.outputs.find(o => o.ename);
        return `I found an error in the selected cell:\n\n**${errorOutput?.ename}:** ${errorOutput?.evalue}\n\nHere are some suggestions:\n1. Check variable definitions\n2. Verify imported modules are installed\n3. Review the traceback for line numbers\n\nWould you like me to create a fix?`;
      }

      return `I'd be happy to help debug your code. Here's what to check:\n\n1. Make sure all variables are defined before use\n2. Check that imported modules are installed\n3. Verify tensor shapes match for operations\n\nSelect a cell with an error and I can provide more specific help.`;
    }

    // Optimize
    if (lowerPrompt.includes("optimize") || lowerPrompt.includes("faster")) {
      return `Here are some optimization suggestions:\n\n1. **Use GPU acceleration**: Move tensors to CUDA with \`.cuda()\`\n2. **Batch processing**: Process data in batches for efficiency\n3. **Memory management**: Use \`torch.no_grad()\` during inference\n\nWould you like me to create an optimized version of your code?`;
    }

    // Explain
    if (lowerPrompt.includes("explain")) {
      const selectedId = getSelectedCellId();
      const selectedCell = cells.find((c) => c.id === selectedId);
      if (selectedCell) {
        const lines = selectedCell.source.split("\n").slice(0, 8);
        const explanation = lines.map((line) => `• ${line.trim() || "(empty line)"}`).join("\n");

        return `This ${selectedCell.cellType} cell contains:\n\n\`\`\`\n${selectedCell.source.slice(0, 200)}${selectedCell.source.length > 200 ? "..." : ""}\n\`\`\`\n\n**Summary:**\n${explanation}\n\nThe code ${selectedCell.cellType === "code" ? "will be executed in the Python kernel" : "is documentation in Markdown format"}.`;
      }
      return "Please select a cell for me to explain.";
    }

    // Default response
    return `I understand you want help with: "${prompt}"\n\nI can assist with:\n• **create/add** - Create new code cells\n• **run/execute** - Execute the selected cell\n• **delete/remove** - Delete the selected cell\n• **list** - Show all cells in notebook\n• **debug** - Help fix errors\n• **explain** - Explain selected code\n• **optimize** - Suggest performance improvements\n\nWhat would you like me to do?`;
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleQuickAction = (prompt: string) => {
    setInputValue(prompt);
    setTimeout(() => {
      handleSend();
    }, 100);
  };

  const clearChat = async () => {
    // Clear from backend
    if (notebookId) {
      try {
        await apiClient.delete(`/api/notebooks/${notebookId}/chat`);
      } catch (error) {
        console.error("Failed to clear chat history:", error);
      }
    }

    // Reset to welcome message
    setMessages([
      {
        id: Date.now().toString(),
        role: "assistant",
        content: WELCOME_MESSAGE,
        timestamp: new Date(),
      },
    ]);
  };

  const getProviderIcon = () => {
    switch (selectedProvider) {
      case "claude":
        return <Sparkles className="h-3.5 w-3.5" />;
      case "openai":
        return <Bot className="h-3.5 w-3.5" />;
      case "gemini":
        return <Gem className="h-3.5 w-3.5" />;
    }
  };

  return (
    <div className="flex w-[400px] flex-col border-l border-border bg-card">
      {/* Header - Compact */}
      <div className="flex items-center gap-1.5 border-b border-border px-2 py-2">
        <div className="flex h-6 w-6 items-center justify-center rounded-md bg-primary/20">
          <Bot className="h-3 w-3 text-primary" />
        </div>
        <p className="flex-1 text-xs font-semibold text-foreground truncate">AI</p>

        {/* Provider Selector - Compact */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="flex items-center gap-0.5 rounded border border-border bg-background px-1.5 py-0.5 text-[10px] hover:bg-muted">
              <span className="text-primary">{getProviderIcon()}</span>
              <ChevronDown className="h-2.5 w-2.5 text-muted-foreground" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => setSelectedProvider("claude")}>
              <Sparkles className="mr-2 h-3.5 w-3.5" />
              Claude
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => setSelectedProvider("openai")}>
              <Bot className="mr-2 h-3.5 w-3.5" />
              GPT-4
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => setSelectedProvider("gemini")}>
              <Gem className="mr-2 h-3.5 w-3.5" />
              Gemini
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        {/* Clear Chat */}
        <button
          onClick={clearChat}
          className="rounded p-0.5 text-muted-foreground hover:bg-muted hover:text-foreground"
          title="Clear chat"
        >
          <Trash2 className="h-3 w-3" />
        </button>
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-auto p-2">
        <div className="space-y-2">
          {messages.map((message) => (
            <ChatMessage key={message.id} message={message} />
          ))}
          {isLoading && (
            <div className="flex items-start gap-1.5">
              <div className="flex h-5 w-5 items-center justify-center rounded bg-primary/20">
                <Sparkles className="h-2.5 w-2.5 text-primary" />
              </div>
              <div className="flex-1 rounded border border-border bg-background p-2">
                <Loader2 className="h-3 w-3 animate-spin text-muted-foreground" />
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Quick Actions - Grid 3x2 */}
      <div className="grid grid-cols-3 gap-0.5 border-t border-border px-1.5 py-1">
        <QuickActionChip
          icon={<Play className="h-2.5 w-2.5" />}
          label="Run"
          onClick={() => handleQuickAction("Execute the selected cell")}
        />
        <QuickActionChip
          icon={<Plus className="h-2.5 w-2.5" />}
          label="New"
          onClick={() => handleQuickAction("Create a new code cell")}
        />
        <QuickActionChip
          icon={<Bug className="h-2.5 w-2.5" />}
          label="Debug"
          onClick={() => handleQuickAction("Help me debug the error in the selected cell")}
        />
        <QuickActionChip
          icon={<FileText className="h-2.5 w-2.5" />}
          label="Explain"
          onClick={() => handleQuickAction("Explain what the selected cell does")}
        />
        <QuickActionChip
          icon={<Zap className="h-2.5 w-2.5" />}
          label="Optimize"
          onClick={() => handleQuickAction("Optimize this code for better performance")}
        />
        <QuickActionChip
          icon={<History className="h-2.5 w-2.5" />}
          label="List"
          onClick={() => handleQuickAction("List all cells in the notebook")}
        />
      </div>

      {/* Input */}
      <div className="border-t border-border p-2">
        <div className="flex items-end gap-1.5">
          <textarea
            ref={inputRef}
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask..."
            className="flex-1 resize-none rounded border border-border bg-background px-2 py-1.5 text-xs text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none"
            rows={1}
            style={{ minHeight: "32px", maxHeight: "80px" }}
          />
          <Button
            size="sm"
            onClick={handleSend}
            disabled={isLoading || !inputValue.trim()}
            className="h-8 w-8 p-0"
          >
            {isLoading ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Send className="h-3.5 w-3.5" />
            )}
          </Button>
        </div>
      </div>
    </div>
  );
};

interface ChatMessageProps {
  message: AIMessage;
}

const ChatMessage = ({ message }: ChatMessageProps) => {
  const isUser = message.role === "user";

  return (
    <div
      className={cn(
        "rounded px-2.5 py-2 text-sm leading-relaxed",
        isUser
          ? "bg-primary text-primary-foreground ml-4"
          : "border border-border bg-background text-foreground mr-4"
      )}
    >
      <p className="whitespace-pre-wrap break-words">{message.content}</p>
    </div>
  );
};

interface QuickActionChipProps {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
}

const QuickActionChip = ({ icon, label, onClick }: QuickActionChipProps) => {
  return (
    <button
      onClick={onClick}
      className="flex items-center justify-center gap-1 rounded-md border border-border bg-background px-1.5 py-1 text-[10px] text-foreground transition-colors hover:border-primary/30 hover:bg-primary/10 hover:text-primary"
    >
      <span className="text-muted-foreground">{icon}</span>
      {label}
    </button>
  );
};
