"""
Claude (Anthropic) AI provider.
"""
import json
import os
from pathlib import Path
from typing import AsyncIterator, Optional

from anthropic import AsyncAnthropic

from ai.base_provider import BaseAIProvider
from models.ai import (
    AIProvider,
    AIRequest,
    AIResponse,
    AIRole,
    CodeCompletionRequest,
    CodeCompletionResponse,
    CodeExplanationRequest,
    CodeExplanationResponse,
)
from core.config import settings
from core.exceptions import AIProviderError

SETTINGS_FILE = Path.home() / ".notebook_settings.json"


def _get_api_key_from_settings() -> Optional[str]:
    """Get API key from settings file."""
    if SETTINGS_FILE.exists():
        try:
            data = json.loads(SETTINGS_FILE.read_text())
            return data.get("claude_key")
        except (json.JSONDecodeError, IOError):
            pass
    return None


class ClaudeProvider(BaseAIProvider):
    """Anthropic Claude provider."""

    def __init__(self):
        self._client = None
        self._last_api_key = None

    def _get_client(self) -> AsyncAnthropic:
        """Get or create client."""
        # Try settings file first, then env var, then config
        api_key = _get_api_key_from_settings() or os.environ.get("ANTHROPIC_API_KEY") or settings.get_anthropic_key()

        if not api_key:
            raise AIProviderError("ANTHROPIC_API_KEY not configured. Please add your Claude API key in Settings.")

        # Recreate client if key changed
        if self._client is None or self._last_api_key != api_key:
            self._client = AsyncAnthropic(api_key=api_key)
            self._last_api_key = api_key

        return self._client

    async def chat(self, request: AIRequest) -> AIResponse:
        """Send chat request to Claude."""
        client = self._get_client()

        messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ]

        try:
            response = await client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=request.max_tokens,
                system=request.system_prompt or "You are a helpful coding assistant.",
                messages=messages,
            )

            return AIResponse(
                provider=AIProvider.CLAUDE,
                content=response.content[0].text,
                model=response.model,
                usage={
                    "input_tokens": response.usage.input_tokens,
                    "output_tokens": response.usage.output_tokens,
                },
                finish_reason=response.stop_reason,
            )

        except Exception as e:
            raise AIProviderError(f"Claude API error: {e}")

    async def chat_stream(self, request: AIRequest) -> AsyncIterator[str]:
        """Stream chat response from Claude."""
        client = self._get_client()

        messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ]

        try:
            async with client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=request.max_tokens,
                system=request.system_prompt or "You are a helpful coding assistant.",
                messages=messages,
            ) as stream:
                async for text in stream.text_stream:
                    yield json.dumps({"content": text})

        except Exception as e:
            yield json.dumps({"error": str(e)})

    async def complete_code(self, request: CodeCompletionRequest) -> CodeCompletionResponse:
        """Get code completions from Claude."""
        client = self._get_client()

        prompt = f"""Complete the following {request.language} code.
Only provide the completion, no explanations.
Code before cursor:
```{request.language}
{request.code[:request.cursor_position]}
```
Code after cursor:
```{request.language}
{request.code[request.cursor_position:]}
```
Provide up to 3 possible completions."""

        try:
            response = await client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}],
            )

            completions = response.content[0].text.strip().split("\n---\n")

            return CodeCompletionResponse(
                completions=completions[:3],
                provider=AIProvider.CLAUDE,
            )

        except Exception as e:
            raise AIProviderError(f"Claude API error: {e}")

    async def explain_code(self, request: CodeExplanationRequest) -> CodeExplanationResponse:
        """Explain code or error using Claude."""
        client = self._get_client()

        if request.error:
            prompt = f"""Explain this Python error and suggest fixes:
Error: {request.error}
"""
            if request.code:
                prompt += f"\nCode context:\n```python\n{request.code}\n```"
        else:
            prompt = f"""Explain this code concisely:
```python
{request.code}
```"""

        try:
            response = await client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}],
            )

            return CodeExplanationResponse(
                explanation=response.content[0].text,
                suggestions=[],
                provider=AIProvider.CLAUDE,
            )

        except Exception as e:
            raise AIProviderError(f"Claude API error: {e}")


claude_provider = ClaudeProvider()
