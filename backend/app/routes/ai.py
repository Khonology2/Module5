"""
AI routes: Gemini API for backend text generation.
Uses google-generativeai SDK. Used by the frontend when Firebase in-app AI is unavailable.
"""
import logging
import google.generativeai as genai
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.config import get_settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

GEMINI_MODEL = "gemini-2.5-flash"


class AIGenerateRequest(BaseModel):
    """Request body for POST /ai/generate (Gemini API)."""
    prompt: str = Field(..., min_length=1, description="User prompt/message")
    system_instruction: str | None = Field(None, description="Optional system instruction for context")


class AIGenerateResponse(BaseModel):
    """Response with generated text."""
    text: str


@router.post(
    "/generate",
    response_model=AIGenerateResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate text via Gemini API (fallback when Firebase AI fails)",
)
def ai_generate(request: AIGenerateRequest):
    """
    Call Gemini API using google-generativeai. Requires GEMINI_API_KEY in .env.
    """
    settings = get_settings()
    api_key = (settings.gemini_api_key or "").strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GEMINI_API_KEY is not set. Add it to backend/app/.env (create a key at https://aistudio.google.com/apikey).",
        )
    try:
        genai.configure(api_key=api_key)
        model_kwargs = {}
        if request.system_instruction:
            model_kwargs["system_instruction"] = request.system_instruction
        model = genai.GenerativeModel(GEMINI_MODEL, **model_kwargs)
        response = model.generate_content(request.prompt)
        text = (response.text or "").strip()
        if not text:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Gemini returned empty content.",
            )
        return AIGenerateResponse(text=text)
    except HTTPException:
        raise
    except Exception as e:
        logger.warning("Gemini API failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Gemini API error: {e!s}. Check GEMINI_API_KEY and quota at https://aistudio.google.com/.",
        )
