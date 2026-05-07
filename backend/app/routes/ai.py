"""
AI routes: Gemini API for backend text generation (REST, no SDK).
Used by the frontend when Firebase in-app AI is unavailable.
"""
import logging
import requests
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.config import get_settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


class AIGenerateRequest(BaseModel):
    """Request body for POST /ai/generate (Gemini API)."""
    prompt: str = Field(..., min_length=1, description="User prompt/message")
    system_instruction: str | None = Field(None, description="Optional system instruction for context")


class AIGenerateResponse(BaseModel):
    """Response with generated text."""
    text: str


def _call_gemini_rest(api_key: str, prompt: str, system_instruction: str | None) -> str:
    url = GEMINI_URL.format(model=GEMINI_MODEL)
    params = {"key": api_key}
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
    }
    if system_instruction:
        body["systemInstruction"] = {"parts": [{"text": system_instruction}]}
    resp = requests.post(url, params=params, json=body, timeout=60)
    resp.raise_for_status()
    data = resp.json()
    candidates = (data.get("candidates") or [])
    if not candidates:
        raise ValueError("No candidates in response")
    parts = (candidates[0].get("content") or {}).get("parts") or []
    if not parts:
        raise ValueError("No parts in candidate")
    return (parts[0].get("text") or "").strip()


@router.post(
    "/generate",
    response_model=AIGenerateResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate text via Gemini API (fallback when Firebase AI fails)",
)
def ai_generate(request: AIGenerateRequest):
    """
    Call Gemini API via REST. Requires GEMINI_API_KEY in .env.
    """
    settings = get_settings()
    api_key = (settings.gemini_api_key or "").strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GEMINI_API_KEY is not set. Add it to backend/app/.env (create a key at https://aistudio.google.com/apikey).",
        )
    try:
        text = _call_gemini_rest(
            api_key, request.prompt, request.system_instruction
        )
        if not text:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Gemini returned empty content.",
            )
        return AIGenerateResponse(text=text)
    except HTTPException:
        raise
    except requests.RequestException as e:
        logger.warning("Gemini API failed: %s", e)
        detail = getattr(e, "response", None)
        if detail is not None and hasattr(detail, "text"):
            msg = (detail.text or str(e))[:500]
        else:
            msg = str(e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Gemini API error: {msg}. Check GEMINI_API_KEY and quota at https://aistudio.google.com/.",
        )
    except (ValueError, KeyError) as e:
        logger.warning("Gemini API failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unexpected Gemini response: {e!s}",
        )
