import { Home, MessageSquare, ChevronDown, Coins, Plus } from "lucide-react";
import { Breadcrumb } from "./Breadcrumb";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";

interface Conversation {
  id: string;
  title: string;
  messageCount: number;
}

interface AIAssistantBreadcrumbProps {
  conversationTitle?: string;
  conversations?: Conversation[];
  tokenCount?: number;
  onSelectConversation?: (id: string) => void;
  onNewChat?: () => void;
  onShowTokenUsage?: () => void;
}

export const AIAssistantBreadcrumb = ({
  conversationTitle = "New Chat",
  conversations = [],
  tokenCount = 0,
  onSelectConversation,
  onNewChat,
  onShowTokenUsage,
}: AIAssistantBreadcrumbProps) => {
  const breadcrumbItems = [
    { label: "Home", href: "/", icon: <Home className="h-4 w-4" /> },
    { label: "AI Assistant", icon: <MessageSquare className="h-4 w-4" /> },
  ];

  const formatTokenCount = (count: number): string => {
    if (count >= 1000000) {
      return `${(count / 1000000).toFixed(1)}M`;
    }
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}K`;
    }
    return count.toString();
  };

  const actions = (
    <div className="flex items-center gap-2">
      {/* Conversation Selector */}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button className="flex items-center gap-2 rounded-md border border-border bg-background px-2.5 py-1.5 text-sm hover:bg-muted">
            <MessageSquare className="h-3.5 w-3.5 text-foreground" />
            <span className="max-w-[150px] truncate text-foreground">{conversationTitle}</span>
            <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-64">
          <DropdownMenuItem onClick={onNewChat} className="gap-2">
            <Plus className="h-4 w-4 text-primary" />
            <span className="font-medium text-primary">New Conversation</span>
          </DropdownMenuItem>
          {conversations.length > 0 && (
            <>
              <DropdownMenuSeparator />
              {conversations.slice(0, 10).map((conv) => (
                <DropdownMenuItem
                  key={conv.id}
                  onClick={() => onSelectConversation?.(conv.id)}
                  className="flex-col items-start gap-0.5"
                >
                  <div className="flex w-full items-center gap-2">
                    <MessageSquare className="h-3.5 w-3.5 text-muted-foreground" />
                    <span className="flex-1 truncate text-foreground">{conv.title}</span>
                  </div>
                  <span className="ml-5 text-[10px] text-muted-foreground">
                    {conv.messageCount} messages
                  </span>
                </DropdownMenuItem>
              ))}
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Token Counter */}
      <button
        onClick={onShowTokenUsage}
        className="flex items-center gap-1.5 rounded-md border border-border bg-background px-2.5 py-1.5 text-sm hover:bg-muted"
      >
        <Coins className="h-3.5 w-3.5 text-amber-500" />
        <span className="font-medium text-amber-500">{formatTokenCount(tokenCount)}</span>
      </button>

      {/* New Chat Button */}
      <Button size="sm" onClick={onNewChat} className="gap-1.5">
        <Plus className="h-4 w-4" />
        New Chat
      </Button>
    </div>
  );

  return <Breadcrumb items={breadcrumbItems} actions={actions} />;
};
