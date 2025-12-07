"""
OpenAI AI provider.
"""
import json
from typing import AsyncIterator

from openai import AsyncOpenAI

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


class OpenAIProvider(BaseAIProvider):
    """OpenAI provider."""

    def __init__(self):
        self._client = None

    def _get_client(self) -> AsyncOpenAI:
        """Get or create client."""
        api_key = settings.get_openai_key()
        if not api_key:
            raise AIProviderError("OPENAI_API_KEY not configured")

        if not self._client:
            self._client = AsyncOpenAI(api_key=api_key)

        return self._client

    async def chat(self, request: AIRequest) -> AIResponse:
        """Send chat request to OpenAI."""
        client = self._get_client()

        messages = []
        if request.system_prompt:
            messages.append({"role": "system", "content": request.system_prompt})

        messages.extend([
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ])

        try:
            response = await client.chat.completions.create(
                model="gpt-4o",
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                messages=messages,
            )

            choice = response.choices[0]

            return AIResponse(
                provider=AIProvider.OPENAI,
                content=choice.message.content,
                model=response.model,
                usage={
                    "input_tokens": response.usage.prompt_tokens,
                    "output_tokens": response.usage.completion_tokens,
                },
                finish_reason=choice.finish_reason,
            )

        except Exception as e:
            raise AIProviderError(f"OpenAI API error: {e}")

    async def chat_stream(self, request: AIRequest) -> AsyncIterator[str]:
        """Stream chat response from OpenAI."""
        client = self._get_client()

        messages = []
        if request.system_prompt:
            messages.append({"role": "system", "content": request.system_prompt})

        messages.extend([
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ])

        try:
            stream = await client.chat.completions.create(
                model="gpt-4o",
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                messages=messages,
                stream=True,
                stream_options={"include_usage": True},
            )

            async for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield json.dumps({"content": chunk.choices[0].delta.content})

                # Final chunk with usage
                if chunk.usage:
                    yield json.dumps({
                        "done": True,
                        "usage": {
                            "input_tokens": chunk.usage.prompt_tokens,
                            "output_tokens": chunk.usage.completion_tokens,
                        },
                        "model": chunk.model,
                    })

        except Exception as e:
            yield json.dumps({"error": str(e)})

    async def complete_code(self, request: CodeCompletionRequest) -> CodeCompletionResponse:
        """Get code completions from OpenAI."""
        client = self._get_client()

        prompt = f"""Complete the following {request.language} code.
Only provide the completion, no explanations.
Code: {request.code[:request.cursor_position]}"""

        try:
            response = await client.chat.completions.create(
                model="gpt-4o",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}],
            )

            completions = [response.choices[0].message.content.strip()]

            return CodeCompletionResponse(
                completions=completions,
                provider=AIProvider.OPENAI,
            )

        except Exception as e:
            raise AIProviderError(f"OpenAI API error: {e}")

    async def explain_code(self, request: CodeExplanationRequest) -> CodeExplanationResponse:
        """Explain code or error using OpenAI."""
        client = self._get_client()

        if request.error:
            prompt = f"Explain this error and suggest fixes:\n{request.error}"
            if request.code:
                prompt += f"\n\nCode:\n```\n{request.code}\n```"
        else:
            prompt = f"Explain this code:\n```\n{request.code}\n```"

        try:
            response = await client.chat.completions.create(
                model="gpt-4o",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}],
            )

            return CodeExplanationResponse(
                explanation=response.choices[0].message.content,
                suggestions=[],
                provider=AIProvider.OPENAI,
            )

        except Exception as e:
            raise AIProviderError(f"OpenAI API error: {e}")


openai_provider = OpenAIProvider()
