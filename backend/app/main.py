"""
FastAPI application entry point
Main application setup with CORS, routes, and error handling
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import os
import sys
import importlib
try:
    from app.config import get_settings, validate_settings, get_firebase_service_account_dict
    from app.firebase_client import initialize_firebase
    from app.routes import auth, ai
    from app.models import ErrorResponse
except ModuleNotFoundError:
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    if 'app' in sys.modules:
        del sys.modules['app']
    importlib.invalidate_caches()
    from app.config import get_settings, validate_settings, get_firebase_service_account_dict
    from app.firebase_client import initialize_firebase
    from app.routes import auth, ai
    from app.models import ErrorResponse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events
    
    Handles:
    - Configuration validation
    - Firebase initialization
    """
    # Startup
    logger.info("Starting PDH Backend...")
    
    try:
        # Validate configuration
        settings = get_settings()
        validate_settings(settings)
        logger.info("Configuration validated successfully")
        
        # Initialize Firebase
        initialize_firebase()
        logger.info("Firebase Admin SDK initialized")
        
        logger.info("PDH Backend started successfully")
        
    except Exception as e:
        logger.error(f"Failed to start PDH Backend: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Shutting down PDH Backend...")


# Create FastAPI application
app = FastAPI(
    title="PDH Backend API",
    description="Backend API for PDH token validation and Firebase custom token generation",
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS
# - Keep explicit production origin(s)
# - Allow localhost/127.0.0.1 with any port for Flutter web debug (Edge/Chrome)
#   so browser preflight (OPTIONS) succeeds instead of returning 400.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://personal-development-hub.onrender.com",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)


# Register routes
app.include_router(auth.router)
app.include_router(ai.router)


# Global exception handlers
@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """Handle ValueError exceptions"""
    logger.error(f"ValueError: {exc}")
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "error": "ValueError",
            "detail": str(exc),
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "InternalServerError",
            "detail": "An unexpected error occurred",
        }
    )


# Root endpoint
@app.get("/", tags=["root"])
async def root():
    """
    Root endpoint
    
    Returns:
        API information
    """
    return {
        "service": "PDH Backend API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
    }


# Health check endpoint (also available at /validate-token/health)
@app.get("/health", tags=["health"])
async def health():
    """
    Health check endpoint

    Returns:
        Health status
    """
    return {"status": "healthy", "service": "pdh-backend"}


# Firebase client config from service account JSON + optional web keys (no hardcoded keys in frontend)
@app.get("/firebase-config", tags=["config"])
async def firebase_config():
    """
    Return Firebase client config for web: projectId (from FIREBASE_SERVICE_ACCOUNT_JSON),
    authDomain and storageBucket derived from project_id, and optional apiKey/appId from env.
    Frontend uses this instead of hardcoded keys when FIREBASE_WEB_API_KEY and FIREBASE_WEB_APP_ID are set.
    """
    try:
        sa = get_firebase_service_account_dict()
        project_id = sa.get("project_id") or ""
        settings = get_settings()
        api_key = (settings.firebase_web_api_key or "").strip()
        app_id = (settings.firebase_web_app_id or "").strip()
        messaging_sender_id = (settings.firebase_web_messaging_sender_id or "").strip()
        auth_domain = f"{project_id}.firebaseapp.com" if project_id else ""
        storage_bucket = f"{project_id}.firebasestorage.app" if project_id else ""
        return {
            "projectId": project_id,
            "authDomain": auth_domain,
            "storageBucket": storage_bucket,
            "apiKey": api_key if api_key else None,
            "appId": app_id if app_id else None,
            "messagingSenderId": messaging_sender_id if messaging_sender_id else None,
        }
    except Exception as e:
        logger.warning(f"firebase-config error: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Firebase config unavailable", "detail": str(e)},
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )

