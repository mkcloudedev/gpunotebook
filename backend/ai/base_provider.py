"""
Base class for AI providers.
"""
from abc import ABC, abstractmethod
from typing import AsyncIterator

from models.ai import (
    AIRequest,
    AIResponse,
    CodeCompletionRequest,
    CodeCompletionResponse,
    CodeExplanationRequest,
    CodeExplanationResponse,
)


class BaseAIProvider(ABC):
    """Base class for AI providers."""

    @abstractmethod
    async def chat(self, request: AIRequest) -> AIResponse:
        """Send chat request."""
        pass

    @abstractmethod
    async def chat_stream(self, request: AIRequest) -> AsyncIterator[str]:
        """Stream chat response."""
        pass

    @abstractmethod
    async def complete_code(self, request: CodeCompletionRequest) -> CodeCompletionResponse:
        """Get code completions."""
        pass

    @abstractmethod
    async def explain_code(self, request: CodeExplanationRequest) -> CodeExplanationResponse:
        """Explain code or error."""
        pass
