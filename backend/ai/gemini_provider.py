"""
Google Gemini AI provider.
"""
import json
from typing import AsyncIterator

import google.generativeai as genai

from ai.base_provider import BaseAIProvider
from models.ai import (
    AIProvider,
    AIRequest,
    AIResponse,
    CodeCompletionRequest,
    CodeCompletionResponse,
    CodeExplanationRequest,
    CodeExplanationResponse,
)
from core.config import settings
from core.exceptions import AIProviderError


class GeminiProvider(BaseAIProvider):
    """Google Gemini provider."""

    def __init__(self):
        self._configured = False

    def _configure(self) -> None:
        """Configure the Gemini API."""
        api_key = settings.get_google_key()
        if not api_key:
            raise AIProviderError("GOOGLE_API_KEY not configured")

        if not self._configured:
            genai.configure(api_key=api_key)
            self._configured = True

    async def chat(self, request: AIRequest) -> AIResponse:
        """Send chat request to Gemini."""
        self._configure()

        model = genai.GenerativeModel(
            model_name="gemini-1.5-pro",
            system_instruction=request.system_prompt or "You are a helpful coding assistant.",
        )

        history = []
        for msg in request.messages[:-1]:
            role = "user" if msg.role == "user" else "model"
            history.append({"role": role, "parts": [msg.content]})

        try:
            chat = model.start_chat(history=history)
            response = chat.send_message(request.messages[-1].content)

            return AIResponse(
                provider=AIProvider.GEMINI,
                content=response.text,
                model="gemini-1.5-pro",
                usage=None,
                finish_reason="stop",
            )

        except Exception as e:
            raise AIProviderError(f"Gemini API error: {e}")

    async def chat_stream(self, request: AIRequest) -> AsyncIterator[str]:
        """Stream chat response from Gemini."""
        self._configure()

        model = genai.GenerativeModel(
            model_name="gemini-1.5-pro",
            system_instruction=request.system_prompt or "You are a helpful coding assistant.",
        )

        history = []
        for msg in request.messages[:-1]:
            role = "user" if msg.role == "user" else "model"
            history.append({"role": role, "parts": [msg.content]})

        try:
            chat = model.start_chat(history=history)
            response = chat.send_message(
                request.messages[-1].content,
                stream=True,
            )

            for chunk in response:
                if chunk.text:
                    yield json.dumps({"content": chunk.text})

        except Exception as e:
            yield json.dumps({"error": str(e)})

    async def complete_code(self, request: CodeCompletionRequest) -> CodeCompletionResponse:
        """Get code completions from Gemini."""
        self._configure()

        model = genai.GenerativeModel("gemini-1.5-pro")

        prompt = f"""Complete the following {request.language} code.
Only provide the completion, no explanations.
Code: {request.code[:request.cursor_position]}"""

        try:
            response = model.generate_content(prompt)

            return CodeCompletionResponse(
                completions=[response.text.strip()],
                provider=AIProvider.GEMINI,
            )

        except Exception as e:
            raise AIProviderError(f"Gemini API error: {e}")

    async def explain_code(self, request: CodeExplanationRequest) -> CodeExplanationResponse:
        """Explain code or error using Gemini."""
        self._configure()

        model = genai.GenerativeModel("gemini-1.5-pro")

        if request.error:
            prompt = f"Explain this error and suggest fixes:\n{request.error}"
            if request.code:
                prompt += f"\n\nCode:\n```\n{request.code}\n```"
        else:
            prompt = f"Explain this code:\n```\n{request.code}\n```"

        try:
            response = model.generate_content(prompt)

            return CodeExplanationResponse(
                explanation=response.text,
                suggestions=[],
                provider=AIProvider.GEMINI,
            )

        except Exception as e:
            raise AIProviderError(f"Gemini API error: {e}")


gemini_provider = GeminiProvider()
