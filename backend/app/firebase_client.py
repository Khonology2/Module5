"""
Firebase Admin SDK initialization and configuration
"""
import logging
from typing import Optional, List
import firebase_admin
from firebase_admin import credentials, auth, firestore
from firebase_admin.exceptions import FirebaseError
from google.oauth2.service_account import Credentials

from app.config import get_firebase_service_account_dict, get_settings

logger = logging.getLogger(__name__)

# Global Firebase app instance
_firebase_app: Optional[firebase_admin.App] = None


def initialize_firebase() -> firebase_admin.App:
    """
    Initialize Firebase Admin SDK using service account from environment variables
    
    Returns:
        Initialized Firebase app instance
        
    Raises:
        ValueError: If Firebase initialization fails
        FirebaseError: If there's an error with Firebase Admin SDK
    """
    global _firebase_app
    
    if _firebase_app is not None:
        logger.info("Firebase Admin SDK already initialized")
        return _firebase_app
    
    try:
        # Load from FIREBASE_SERVICE_ACCOUNT_PATH (preferred) or FIREBASE_SERVICE_ACCOUNT_JSON
        service_account_dict = get_firebase_service_account_dict()
        project_id = service_account_dict.get("project_id") or "unknown"
        logger.info("Firebase service account loaded for project_id=%s (client must use same project)", project_id)

        # Create credentials from service account
        cred = credentials.Certificate(service_account_dict)

        # Initialize Firebase Admin SDK
        # Check if default app already exists (e.g., in tests)
        try:
            _firebase_app = firebase_admin.get_app()
            logger.info("Using existing Firebase app instance")
        except ValueError:
            # No existing app, create new one
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully")
        
        return _firebase_app
        
    except ValueError as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        raise
    except FirebaseError as e:
        logger.error(f"Firebase Admin SDK error: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error initializing Firebase: {e}")
        raise ValueError(f"Failed to initialize Firebase: {e}")


def get_firebase_app() -> firebase_admin.App:
    """
    Get the initialized Firebase app instance
    
    Returns:
        Firebase app instance
        
    Raises:
        ValueError: If Firebase is not initialized
    """
    if _firebase_app is None:
        return initialize_firebase()
    return _firebase_app


def get_auth() -> auth.Client:
    """
    Get Firebase Auth client for generating custom tokens
    
    Returns:
        Firebase Auth client
    """
    app = get_firebase_app()
    return auth.Client(app)


def get_firestore() -> firestore.Client:
    """
    Get Firestore client for querying collections
    
    Returns:
        Firestore client
    """
    app = get_firebase_app()
    return firestore.client(app)


def get_google_credentials(scopes: Optional[List[str]] = None) -> Credentials:
    info = get_firebase_service_account_dict()
    if not scopes:
        scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    return Credentials.from_service_account_info(info, scopes=scopes)

