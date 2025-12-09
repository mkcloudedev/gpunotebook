"""
AI integration API endpoints.
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from models.ai import (
    AIRequest,
    AIResponse,
    CodeCompletionRequest,
    CodeCompletionResponse,
    CodeExplanationRequest,
    CodeExplanationResponse,
)
from ai.gateway import ai_gateway
from core.exceptions import AIProviderError
from services.settings_service import settings_service
from services.claude_code_service import claude_code_service

router = APIRouter()


class ChatMessage(BaseModel):
    id: Optional[str] = None
    role: str
    content: str
    created_at: Optional[str] = None


class ChatHistoryRequest(BaseModel):
    messages: List[ChatMessage]


@router.post("/chat", response_model=AIResponse)
async def chat(request: AIRequest):
    """Send a message to AI provider."""
    try:
        response = await ai_gateway.chat(request)
        return response
    except AIProviderError as e:
        raise HTTPException(status_code=503, detail=str(e))


@router.post("/chat/stream")
async def chat_stream(request: AIRequest):
    """Stream response from AI provider."""
    try:
        return StreamingResponse(
            ai_gateway.chat_stream(request),
            media_type="text/event-stream",
        )
    except AIProviderError as e:
        raise HTTPException(status_code=503, detail=str(e))


@router.post("/complete", response_model=CodeCompletionResponse)
async def complete_code(request: CodeCompletionRequest):
    """Get code completions."""
    try:
        response = await ai_gateway.complete_code(request)
        return response
    except AIProviderError as e:
        raise HTTPException(status_code=503, detail=str(e))


@router.post("/explain", response_model=CodeExplanationResponse)
async def explain_code(request: CodeExplanationRequest):
    """Explain code or error."""
    try:
        response = await ai_gateway.explain_code(request)
        return response
    except AIProviderError as e:
        raise HTTPException(status_code=503, detail=str(e))


# ============================================================================
# GLOBAL CHAT HISTORY (AI Assistant)
# ============================================================================

CHAT_HISTORY_KEY = "ai_assistant_chat_history"
CONVERSATIONS_KEY = "ai_assistant_conversations"
TOKEN_USAGE_KEY = "ai_token_usage"


class ConversationInfo(BaseModel):
    id: str
    title: str
    created_at: str
    updated_at: str
    message_count: int = 0


class ConversationsResponse(BaseModel):
    conversations: List[ConversationInfo]


class TokenUsage(BaseModel):
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_tokens: int = 0
    by_provider: dict = {}


@router.get("/history")
async def get_chat_history():
    """Get global AI assistant chat history."""
    import json
    history_json = await settings_service.get(CHAT_HISTORY_KEY)
    if history_json:
        try:
            messages = json.loads(history_json)
            return {"messages": messages}
        except json.JSONDecodeError:
            pass
    return {"messages": []}


@router.post("/history")
async def save_chat_history(request: ChatHistoryRequest):
    """Save global AI assistant chat history."""
    import json
    messages_json = json.dumps([m.model_dump() for m in request.messages])
    await settings_service.set(CHAT_HISTORY_KEY, messages_json)
    return {"status": "ok"}


@router.delete("/history", status_code=status.HTTP_204_NO_CONTENT)
async def clear_chat_history():
    """Clear global AI assistant chat history."""
    await settings_service.delete(CHAT_HISTORY_KEY)


# ============================================================================
# MULTIPLE CONVERSATIONS
# ============================================================================

@router.get("/conversations", response_model=ConversationsResponse)
async def list_conversations():
    """List all saved conversations."""
    import json
    convs_json = await settings_service.get(CONVERSATIONS_KEY)
    if convs_json:
        try:
            convs = json.loads(convs_json)
            return {"conversations": convs}
        except json.JSONDecodeError:
            pass
    return {"conversations": []}


@router.post("/conversations")
async def create_conversation(title: str = "New Chat"):
    """Create a new conversation."""
    import json
    from datetime import datetime
    import uuid

    # Load existing conversations
    convs_json = await settings_service.get(CONVERSATIONS_KEY)
    convs = []
    if convs_json:
        try:
            convs = json.loads(convs_json)
        except json.JSONDecodeError:
            pass

    # Create new conversation
    conv_id = str(uuid.uuid4())[:8]
    now = datetime.now().isoformat()
    new_conv = {
        "id": conv_id,
        "title": title,
        "created_at": now,
        "updated_at": now,
        "message_count": 0
    }
    convs.insert(0, new_conv)

    # Save
    await settings_service.set(CONVERSATIONS_KEY, json.dumps(convs))

    return new_conv


@router.get("/conversations/{conv_id}")
async def get_conversation(conv_id: str):
    """Get messages for a specific conversation."""
    import json
    key = f"ai_conversation_{conv_id}"
    messages_json = await settings_service.get(key)
    if messages_json:
        try:
            messages = json.loads(messages_json)
            return {"messages": messages, "id": conv_id}
        except json.JSONDecodeError:
            pass
    return {"messages": [], "id": conv_id}


@router.post("/conversations/{conv_id}")
async def save_conversation(conv_id: str, request: ChatHistoryRequest):
    """Save messages to a specific conversation."""
    import json
    from datetime import datetime

    key = f"ai_conversation_{conv_id}"
    messages = [m.model_dump() for m in request.messages]
    await settings_service.set(key, json.dumps(messages))

    # Update conversation metadata
    convs_json = await settings_service.get(CONVERSATIONS_KEY)
    if convs_json:
        try:
            convs = json.loads(convs_json)
            for conv in convs:
                if conv["id"] == conv_id:
                    conv["updated_at"] = datetime.now().isoformat()
                    conv["message_count"] = len(messages)
                    # Update title from first user message if empty
                    if conv["title"] == "New Chat" and messages:
                        for m in messages:
                            if m.get("role") == "user":
                                conv["title"] = m.get("content", "")[:50] + ("..." if len(m.get("content", "")) > 50 else "")
                                break
                    break
            await settings_service.set(CONVERSATIONS_KEY, json.dumps(convs))
        except json.JSONDecodeError:
            pass

    return {"status": "ok"}


@router.delete("/conversations/{conv_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(conv_id: str):
    """Delete a conversation."""
    import json

    # Delete messages
    key = f"ai_conversation_{conv_id}"
    await settings_service.delete(key)

    # Remove from list
    convs_json = await settings_service.get(CONVERSATIONS_KEY)
    if convs_json:
        try:
            convs = json.loads(convs_json)
            convs = [c for c in convs if c["id"] != conv_id]
            await settings_service.set(CONVERSATIONS_KEY, json.dumps(convs))
        except json.JSONDecodeError:
            pass


# ============================================================================
# TOKEN USAGE TRACKING
# ============================================================================

@router.get("/tokens", response_model=TokenUsage)
async def get_token_usage():
    """Get token usage statistics."""
    import json
    usage_json = await settings_service.get(TOKEN_USAGE_KEY)
    if usage_json:
        try:
            return json.loads(usage_json)
        except json.JSONDecodeError:
            pass
    return TokenUsage()


@router.post("/tokens/track")
async def track_token_usage(
    provider: str,
    input_tokens: int = 0,
    output_tokens: int = 0
):
    """Track token usage for a request."""
    import json

    usage_json = await settings_service.get(TOKEN_USAGE_KEY)
    usage = {
        "total_input_tokens": 0,
        "total_output_tokens": 0,
        "total_tokens": 0,
        "by_provider": {}
    }
    if usage_json:
        try:
            usage = json.loads(usage_json)
        except json.JSONDecodeError:
            pass

    # Update totals
    usage["total_input_tokens"] += input_tokens
    usage["total_output_tokens"] += output_tokens
    usage["total_tokens"] += input_tokens + output_tokens

    # Update by provider
    if provider not in usage["by_provider"]:
        usage["by_provider"][provider] = {"input": 0, "output": 0, "total": 0}
    usage["by_provider"][provider]["input"] += input_tokens
    usage["by_provider"][provider]["output"] += output_tokens
    usage["by_provider"][provider]["total"] += input_tokens + output_tokens

    await settings_service.set(TOKEN_USAGE_KEY, json.dumps(usage))

    return usage


@router.delete("/tokens", status_code=status.HTTP_204_NO_CONTENT)
async def reset_token_usage():
    """Reset token usage statistics."""
    await settings_service.delete(TOKEN_USAGE_KEY)


# ============================================================================
# CLAUDE CODE CLI INTEGRATION
# ============================================================================

class ClaudeCodeRequest(BaseModel):
    messages: List[ChatMessage]
    system_prompt: Optional[str] = None
    model: Optional[str] = None
    notebook_context: Optional[dict] = None


class ClaudeCodeStatusResponse(BaseModel):
    available: bool
    version: Optional[str] = None
    path: str


@router.get("/claude-code/status", response_model=ClaudeCodeStatusResponse)
async def get_claude_code_status():
    """Check if Claude Code CLI is available."""
    available = await claude_code_service.check_available()
    version = await claude_code_service.get_version() if available else None
    return ClaudeCodeStatusResponse(
        available=available,
        version=version,
        path=claude_code_service.claude_path
    )


@router.post("/claude-code/chat")
async def claude_code_chat(request: ClaudeCodeRequest):
    """Send a message to Claude Code CLI and get response."""
    # Check if available
    if not await claude_code_service.check_available():
        raise HTTPException(
            status_code=503,
            detail="Claude Code CLI is not available. Make sure it's installed and authenticated."
        )

    # Convert messages
    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    # Collect full response
    full_response = ""
    session_id = None
    total_cost = None
    duration_ms = None
    is_error = False

    async for response in claude_code_service.chat(
        messages=messages,
        system_prompt=request.system_prompt,
        model=request.model,
        notebook_context=request.notebook_context
    ):
        if response.type == "assistant" and response.content:
            full_response += response.content
        elif response.type == "result":
            session_id = response.session_id
            total_cost = response.total_cost_usd
            duration_ms = response.duration_ms
        elif response.type == "error":
            is_error = True
            full_response = response.content or "Unknown error"

    return {
        "content": full_response,
        "session_id": session_id,
        "total_cost_usd": total_cost,
        "duration_ms": duration_ms,
        "is_error": is_error
    }


@router.post("/claude-code/chat/stream")
async def claude_code_chat_stream(request: ClaudeCodeRequest):
    """Stream response from Claude Code CLI."""
    import json

    # Check if available
    if not await claude_code_service.check_available():
        raise HTTPException(
            status_code=503,
            detail="Claude Code CLI is not available. Make sure it's installed and authenticated."
        )

    # Convert messages
    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    async def generate():
        async for response in claude_code_service.chat(
            messages=messages,
            system_prompt=request.system_prompt,
            model=request.model,
            notebook_context=request.notebook_context
        ):
            if response.type == "assistant" and response.content:
                yield f"data: {json.dumps({'type': 'content', 'content': response.content})}\n\n"
            elif response.type == "result":
                # Include the final result content if available
                result_data = {
                    'type': 'result',
                    'session_id': response.session_id,
                    'total_cost_usd': response.total_cost_usd,
                    'duration_ms': response.duration_ms
                }
                if response.content:
                    result_data['content'] = response.content
                yield f"data: {json.dumps(result_data)}\n\n"
            elif response.type == "error":
                yield f"data: {json.dumps({'type': 'error', 'content': response.content})}\n\n"
            elif response.type == "init":
                yield f"data: {json.dumps({'type': 'init', 'session_id': response.session_id})}\n\n"

        yield "data: [DONE]\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream"
    )
