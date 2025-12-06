"""
AI provider data models.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class AIProvider(str, Enum):
    """Supported AI providers."""
    CLAUDE = "claude"
    OPENAI = "openai"
    GEMINI = "gemini"


class AIRole(str, Enum):
    """Message role in conversation."""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class AIMessage(BaseModel):
    """A message in AI conversation."""
    role: AIRole
    content: str


class AIRequest(BaseModel):
    """Request to AI provider."""
    provider: AIProvider = AIProvider.CLAUDE
    messages: List[AIMessage]
    system_prompt: Optional[str] = None
    max_tokens: int = 4096
    temperature: float = 0.7
    stream: bool = False


class AIResponse(BaseModel):
    """Response from AI provider."""
    provider: AIProvider
    content: str
    model: str
    usage: Optional[dict[str, int]] = None
    finish_reason: Optional[str] = None


class CodeCompletionRequest(BaseModel):
    """Request for code completion."""
    code: str
    cursor_position: int
    language: str = "python"
    provider: AIProvider = AIProvider.CLAUDE


class CodeCompletionResponse(BaseModel):
    """Response for code completion."""
    completions: List[str]
    provider: AIProvider


class CodeExplanationRequest(BaseModel):
    """Request to explain code or error."""
    code: Optional[str] = None
    error: Optional[str] = None
    provider: AIProvider = AIProvider.CLAUDE


class CodeExplanationResponse(BaseModel):
    """Response with code explanation."""
    explanation: str
    suggestions: List[str] = []
    provider: AIProvider
