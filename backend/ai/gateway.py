"""
AI gateway - routes requests to appropriate providers.
"""
from typing import AsyncIterator

from models.ai import (
    AIProvider,
    AIRequest,
    AIResponse,
    CodeCompletionRequest,
    CodeCompletionResponse,
    CodeExplanationRequest,
    CodeExplanationResponse,
)
from ai.claude_provider import claude_provider
from ai.openai_provider import openai_provider
from ai.gemini_provider import gemini_provider
from core.exceptions import AIProviderError


class AIGateway:
    """Routes AI requests to appropriate providers."""

    def __init__(self):
        self._providers = {
            AIProvider.CLAUDE: claude_provider,
            AIProvider.OPENAI: openai_provider,
            AIProvider.GEMINI: gemini_provider,
        }

    def _get_provider(self, provider: AIProvider):
        """Get provider instance."""
        if provider not in self._providers:
            raise AIProviderError(f"Unknown provider: {provider}")
        return self._providers[provider]

    async def chat(self, request: AIRequest) -> AIResponse:
        """Send chat request to provider."""
        provider = self._get_provider(request.provider)
        return await provider.chat(request)

    async def chat_stream(self, request: AIRequest) -> AsyncIterator[str]:
        """Stream chat response from provider."""
        provider = self._get_provider(request.provider)
        async for chunk in provider.chat_stream(request):
            yield f"data: {chunk}\n\n"

    async def complete_code(self, request: CodeCompletionRequest) -> CodeCompletionResponse:
        """Get code completions."""
        provider = self._get_provider(request.provider)
        return await provider.complete_code(request)

    async def explain_code(self, request: CodeExplanationRequest) -> CodeExplanationResponse:
        """Explain code or error."""
        provider = self._get_provider(request.provider)
        return await provider.explain_code(request)


ai_gateway = AIGateway()
