"""
AI routes: OpenRouter chat completions for the Flutter app.
Keys live only in backend/app/.env (OPENROUTER_API_KEY_PRIMARY / SECONDARY).
"""
from __future__ import annotations

import logging
from typing import Any, Literal

import requests
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.config import get_settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-2.0-flash-001"
OPENROUTER_TIMEOUT_SEC = 90


class ChatMessageIn(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str = Field(..., min_length=1)


class AIChatRequest(BaseModel):
    """Multi-turn chat — matches Flutter [AppAiService.generate]."""

    system_instruction: str | None = Field(
        None, description="Optional system prompt (prepended as system message)"
    )
    messages: list[ChatMessageIn] = Field(
        ...,
        min_length=1,
        description="User/assistant turns in order (roles: user, assistant)",
    )


class AIGenerateRequest(BaseModel):
    """Simple single-prompt helper (legacy / scripts)."""

    prompt: str = Field(..., min_length=1)
    system_instruction: str | None = None


class AIGenerateResponse(BaseModel):
    text: str


def _openrouter_keys_primary_first(settings: Any) -> list[str]:
    primary = (getattr(settings, "openrouter_api_key_primary", None) or "").strip()
    secondary = (getattr(settings, "openrouter_api_key_secondary", None) or "").strip()
    keys: list[str] = []
    if primary:
        keys.append(primary)
    if secondary and secondary not in keys:
        keys.append(secondary)
    return keys


def _openrouter_model(settings: Any) -> str:
    m = (getattr(settings, "openrouter_model", None) or "").strip()
    return m if m else DEFAULT_MODEL


def _message_body_text(content: Any) -> str:
    if isinstance(content, str) and content.strip():
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                t = block.get("text")
                if isinstance(t, str):
                    parts.append(t)
        return "".join(parts)
    return ""


def _build_openrouter_messages(
    system_instruction: str | None,
    messages: list[dict[str, str]],
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    sys = (system_instruction or "").strip()
    if sys:
        out.append({"role": "system", "content": sys})
    for msg in messages:
        role = (msg.get("role") or "user").strip().lower()
        content = (msg.get("content") or "").strip()
        if not content:
            continue
        if role not in ("user", "assistant", "system"):
            role = "user"
        # Avoid duplicate system rows when client also sends system in messages
        if role == "system" and out and out[0].get("role") == "system":
            continue
        out.append({"role": role, "content": content})
    if not out or all(m.get("role") == "system" for m in out):
        raise ValueError("No user/assistant content in messages")
    return out


def _call_openrouter_messages(api_key: str, model: str, messages: list[dict[str, str]]) -> str:
    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/pdh-flutter",
            "X-Title": "PDH Backend",
        },
        json={"model": model, "messages": messages},
        timeout=OPENROUTER_TIMEOUT_SEC,
    )
    if resp.status_code < 200 or resp.status_code >= 300:
        body = (resp.text or "")[:800]
        raise ValueError(f"HTTP {resp.status_code}: {body}")

    data = resp.json()
    if not isinstance(data, dict):
        raise ValueError("Unexpected JSON root")
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise ValueError(f"No choices in response: {str(data)[:500]}")
    first = choices[0]
    if not isinstance(first, dict):
        raise ValueError("Invalid choice entry")
    msg = first.get("message")
    if not isinstance(msg, dict):
        raise ValueError("No message in choice")
    text = _message_body_text(msg.get("content")).strip()
    if not text:
        raise ValueError("Empty model content")
    return text


def _generate_with_failover(
    settings: Any,
    system_instruction: str | None,
    messages: list[dict[str, str]],
) -> str:
    keys = _openrouter_keys_primary_first(settings)
    if not keys:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "OpenRouter is not configured on the server. Set OPENROUTER_API_KEY_PRIMARY "
                "(and optionally OPENROUTER_API_KEY_SECONDARY, OPENROUTER_MODEL) in "
                "backend/app/.env or Render environment variables."
            ),
        )

    model = _openrouter_model(settings)
    try:
        payload_messages = _build_openrouter_messages(system_instruction, messages)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e

    last_err: Exception | None = None
    for i, api_key in enumerate(keys):
        label = "primary" if i == 0 else "secondary"
        try:
            return _call_openrouter_messages(api_key, model, payload_messages)
        except HTTPException:
            raise
        except Exception as e:
            last_err = e
            logger.warning("OpenRouter %s key failed: %s", label, e)

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=f"OpenRouter: all API keys failed. Last error: {last_err}",
    )


@router.get("/status", summary="AI configuration status (no secrets)")
def ai_status():
    settings = get_settings()
    keys = _openrouter_keys_primary_first(settings)
    return {
        "configured": len(keys) > 0,
        "primary_key_set": bool(
            (getattr(settings, "openrouter_api_key_primary", None) or "").strip()
        ),
        "secondary_key_set": bool(
            (getattr(settings, "openrouter_api_key_secondary", None) or "").strip()
        ),
        "model": _openrouter_model(settings),
    }


@router.post(
    "/chat",
    response_model=AIGenerateResponse,
    status_code=status.HTTP_200_OK,
    summary="Multi-turn chat for Flutter AI features",
)
def ai_chat(request: AIChatRequest):
    """All in-app AI features should call this endpoint."""
    settings = get_settings()
    raw_messages = [
        {"role": m.role, "content": m.content.strip()}
        for m in request.messages
        if m.content.strip()
    ]
    text = _generate_with_failover(settings, request.system_instruction, raw_messages)
    return AIGenerateResponse(text=text)


@router.post(
    "/generate",
    response_model=AIGenerateResponse,
    status_code=status.HTTP_200_OK,
    summary="Single user prompt (legacy)",
)
def ai_generate(request: AIGenerateRequest):
    settings = get_settings()
    text = _generate_with_failover(
        settings,
        request.system_instruction,
        [{"role": "user", "content": request.prompt.strip()}],
    )
    return AIGenerateResponse(text=text)
