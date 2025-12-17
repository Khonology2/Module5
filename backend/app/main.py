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
    from app.config import get_settings, validate_settings
    from app.firebase_client import initialize_firebase
    from app.routes import auth
    from app.models import ErrorResponse
except ModuleNotFoundError:
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    if 'app' in sys.modules:
        del sys.modules['app']
    importlib.invalidate_caches()
    from app.config import get_settings, validate_settings
    from app.firebase_client import initialize_firebase
    from app.routes import auth
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
# Allow Flutter web app to make requests from any origin
# In production, you may want to restrict this to specific origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (adjust for production)
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)


# Register routes
app.include_router(auth.router)


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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )

