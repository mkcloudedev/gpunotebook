"""
Claude Code CLI integration service.
Spawns Claude Code CLI process and streams responses.
"""
import asyncio
import json
import os
import subprocess
import tempfile
import uuid
from typing import AsyncGenerator, Optional, List, Dict, Any
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class ClaudeCodeMessage:
    """Message format for Claude Code."""
    role: str  # "user" or "assistant"
    content: str


@dataclass
class ClaudeCodeResponse:
    """Response from Claude Code CLI."""
    type: str  # "init", "assistant", "result", "error"
    content: Optional[str] = None
    session_id: Optional[str] = None
    total_cost_usd: Optional[float] = None
    duration_ms: Optional[int] = None
    is_error: bool = False
    raw: Dict[str, Any] = field(default_factory=dict)


class ClaudeCodeService:
    """Service to interact with Claude Code CLI."""

    def __init__(self):
        self.claude_path = os.environ.get("CLAUDE_CODE_PATH", "claude")
        self.default_model = os.environ.get("CLAUDE_CODE_MODEL", "claude-sonnet-4-20250514")
        self.max_output_tokens = os.environ.get("CLAUDE_CODE_MAX_OUTPUT_TOKENS", "32000")
        self.timeout = 600  # 10 minutes
        # Cache for availability check
        self._available: Optional[bool] = None
        self._version: Optional[str] = None
        self._cache_checked = False

    async def check_available(self) -> bool:
        """Check if Claude Code CLI is available (cached)."""
        if self._cache_checked:
            return self._available or False

        try:
            process = await asyncio.create_subprocess_exec(
                self.claude_path, "--version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await process.communicate()
            self._available = process.returncode == 0
            if self._available:
                self._version = stdout.decode().strip()
            self._cache_checked = True
            return self._available
        except Exception:
            self._available = False
            self._cache_checked = True
            return False

    async def get_version(self) -> Optional[str]:
        """Get Claude Code CLI version (cached)."""
        if not self._cache_checked:
            await self.check_available()
        return self._version

    def _build_system_prompt(self, notebook_context: Optional[Dict] = None) -> str:
        """Build the system prompt for Claude Code."""
        base_prompt = """You are an AI assistant integrated into GPU Notebook, a Python notebook environment with GPU acceleration.

You can help users with:
- Writing and explaining Python code
- Data analysis and visualization
- Machine learning and deep learning
- Debugging and optimization
- General programming questions

When providing code, format it properly with markdown code blocks.
Be concise and helpful. Focus on practical solutions."""

        if notebook_context:
            cells_info = []
            for i, cell in enumerate(notebook_context.get("cells", [])):
                cell_type = cell.get("type", "code")
                source = cell.get("source", "")[:200]  # Truncate long cells
                outputs = cell.get("outputs", [])
                output_preview = outputs[0][:100] if outputs else ""
                cells_info.append(f"Cell {i} ({cell_type}): {source}...")
                if output_preview:
                    cells_info.append(f"  Output: {output_preview}...")

            if cells_info:
                base_prompt += f"\n\nCurrent notebook context:\n" + "\n".join(cells_info[:10])

        return base_prompt

    async def chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        model: Optional[str] = None,
        notebook_context: Optional[Dict] = None
    ) -> AsyncGenerator[ClaudeCodeResponse, None]:
        """
        Send messages to Claude Code CLI and stream responses.

        Args:
            messages: List of {"role": "user"|"assistant", "content": "..."}
            system_prompt: Custom system prompt (optional)
            model: Model to use (optional)
            notebook_context: Notebook cells context (optional)

        Yields:
            ClaudeCodeResponse objects with streaming content
        """
        if system_prompt is None:
            system_prompt = self._build_system_prompt(notebook_context)

        model = model or self.default_model

        # Build command arguments
        args = [
            self.claude_path,
            "--system-prompt", system_prompt,
            "--verbose",
            "--output-format", "stream-json",
            "--max-turns", "1",
            "--model", model,
            "-p"
        ]

        # Environment variables
        env = os.environ.copy()
        env["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] = self.max_output_tokens
        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
        env["DISABLE_NON_ESSENTIAL_MODEL_CALLS"] = "1"

        # Remove API key to let Claude Code use its own auth
        env.pop("ANTHROPIC_API_KEY", None)

        # Convert messages to Anthropic format
        anthropic_messages = []
        for msg in messages:
            anthropic_messages.append({
                "role": msg["role"],
                "content": msg["content"]
            })

        messages_json = json.dumps(anthropic_messages)

        try:
            # Create subprocess
            process = await asyncio.create_subprocess_exec(
                *args,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=env
            )

            # Send messages via stdin
            process.stdin.write(messages_json.encode())
            await process.stdin.drain()
            process.stdin.close()

            # Read and parse streaming output
            partial_data = ""

            while True:
                line = await process.stdout.readline()
                if not line:
                    break

                line_str = line.decode().strip()
                if not line_str:
                    continue

                # Try to parse JSON
                try:
                    data = json.loads(partial_data + line_str)
                    partial_data = ""
                except json.JSONDecodeError:
                    partial_data += line_str
                    continue

                # Process different message types
                response = self._parse_response(data)
                if response:
                    yield response

            # Wait for process to finish
            await process.wait()

            if process.returncode != 0:
                stderr = await process.stderr.read()
                error_msg = stderr.decode().strip()
                yield ClaudeCodeResponse(
                    type="error",
                    content=f"Claude Code exited with code {process.returncode}: {error_msg}",
                    is_error=True
                )

        except asyncio.TimeoutError:
            yield ClaudeCodeResponse(
                type="error",
                content="Claude Code request timed out",
                is_error=True
            )
        except FileNotFoundError:
            yield ClaudeCodeResponse(
                type="error",
                content=f"Claude Code CLI not found at '{self.claude_path}'. Make sure it's installed and in PATH.",
                is_error=True
            )
        except Exception as e:
            yield ClaudeCodeResponse(
                type="error",
                content=f"Error running Claude Code: {str(e)}",
                is_error=True
            )

    def _parse_response(self, data: Dict[str, Any]) -> Optional[ClaudeCodeResponse]:
        """Parse a JSON response from Claude Code CLI."""
        msg_type = data.get("type")

        if msg_type == "system" and data.get("subtype") == "init":
            return ClaudeCodeResponse(
                type="init",
                session_id=data.get("session_id"),
                raw=data
            )

        elif msg_type == "assistant":
            message = data.get("message", {})
            content_blocks = message.get("content", [])

            # Extract text content
            text_parts = []
            for block in content_blocks:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif block.get("type") == "thinking":
                        # Include thinking in response
                        thinking = block.get("thinking", "")
                        if thinking:
                            text_parts.append(f"<thinking>{thinking}</thinking>")

            content = "\n".join(text_parts) if text_parts else None

            return ClaudeCodeResponse(
                type="assistant",
                content=content,
                session_id=data.get("session_id"),
                raw=data
            )

        elif msg_type == "result":
            # Get the final result content
            result_content = data.get("result")
            return ClaudeCodeResponse(
                type="result",
                content=result_content,
                session_id=data.get("session_id"),
                total_cost_usd=data.get("total_cost_usd"),
                duration_ms=data.get("duration_ms"),
                is_error=data.get("is_error", False),
                raw=data
            )

        elif msg_type == "error":
            return ClaudeCodeResponse(
                type="error",
                content=str(data),
                is_error=True,
                raw=data
            )

        # Handle tool use messages (show progress)
        elif msg_type == "user" and data.get("message", {}).get("content"):
            content_blocks = data.get("message", {}).get("content", [])
            for block in content_blocks:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    tool_content = block.get("content", "")
                    if tool_content:
                        return ClaudeCodeResponse(
                            type="assistant",
                            content=f"\n{tool_content}\n",
                            raw=data
                        )

        return None

    async def simple_chat(
        self,
        user_message: str,
        history: Optional[List[Dict[str, str]]] = None,
        notebook_context: Optional[Dict] = None
    ) -> str:
        """
        Simple chat that returns the full response as a string.

        Args:
            user_message: The user's message
            history: Previous conversation history
            notebook_context: Notebook context

        Returns:
            The assistant's response as a string
        """
        messages = history or []
        messages.append({"role": "user", "content": user_message})

        response_parts = []
        async for response in self.chat(messages, notebook_context=notebook_context):
            if response.type == "assistant" and response.content:
                response_parts.append(response.content)
            elif response.type == "error":
                return f"Error: {response.content}"

        return "\n".join(response_parts) if response_parts else "No response received"


# Global instance
claude_code_service = ClaudeCodeService()
