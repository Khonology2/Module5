"""
JWT token validation and decoding
"""
import logging
from typing import Dict, Any, Optional
import jwt
from jwt.exceptions import (
    InvalidTokenError,
    ExpiredSignatureError,
    DecodeError,
    InvalidSignatureError,
)
from cryptography.fernet import Fernet, InvalidToken as FernetInvalidToken

from app.config import get_settings

logger = logging.getLogger(__name__)


class JWTValidationError(Exception):
    """Custom exception for JWT validation errors"""
    pass


def validate_jwt_token(token: str) -> Dict[str, Any]:
    """
    Validate and decode JWT token from Khonobuzz
    
    This function:
    1. Validates the token structure (3 parts separated by dots)
    2. Verifies the token signature using JWT_SECRET
    3. Checks token expiration
    4. Extracts and validates required fields (user_id, email)
    
    Args:
        token: JWT token string to validate
        
    Returns:
        Decoded token payload as dictionary
        
    Raises:
        JWTValidationError: If token is invalid, expired, or missing required fields
    """
    if not token or not isinstance(token, str):
        raise JWTValidationError("Token is required and must be a string")
    
    # Some deployments provide an encrypted token (Fernet) rather than a raw JWT.
    # Attempt to decrypt using ENCRYPTION_KEY before JWT validation.
    try:
        settings = get_settings()
        enc_key = (settings.encryption_key or "").strip()
        looks_encrypted = token.startswith("gAAAA")
        if not enc_key and looks_encrypted:
            raise JWTValidationError(
                "Encrypted token detected but ENCRYPTION_KEY is not configured"
            )
        if enc_key:
            try:
                f = Fernet(enc_key.encode("utf-8"))
                decrypted_bytes = f.decrypt(token.encode("utf-8"))
                decrypted_token = decrypted_bytes.decode("utf-8").strip()
                if decrypted_token:
                    logger.info("Encrypted token detected and decrypted successfully")
                    token = decrypted_token
            except (FernetInvalidToken, ValueError, TypeError) as e:
                logger.warning(f"Fernet decryption failed: {e}. Proceeding as raw JWT")
                # Proceed assuming raw JWT
                pass
    except JWTValidationError:
        raise
    except Exception as e:
        logger.warning(f"Failed to load settings for decryption: {e}. Proceeding as raw JWT")
    
    # Validate token structure (JWT has 3 parts: header.payload.signature)
    parts = token.split('.')
    if len(parts) != 3:
        raise JWTValidationError(
            f"Invalid token format: expected 3 parts, got {len(parts)}"
        )
    
    try:
        settings = get_settings()
        
        # Decode and verify JWT token
        # Using HS256 algorithm (HMAC with SHA-256)
        # This matches the algorithm typically used by Khonobuzz
        decoded = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=['HS256'],
            options={
                'verify_signature': True,
                'verify_exp': True,
            }
        )
        
        logger.info(f"JWT token validated successfully for user_id: {decoded.get('user_id')}")
        return decoded
        
    except ExpiredSignatureError:
        logger.warning("JWT token has expired")
        raise JWTValidationError("Token has expired")
    except InvalidSignatureError:
        logger.warning("JWT token signature is invalid")
        raise JWTValidationError("Invalid token signature")
    except DecodeError as e:
        logger.warning(f"Failed to decode JWT token: {e}")
        raise JWTValidationError(f"Invalid token format: {e}")
    except jwt.MissingRequiredClaimError as e:
        logger.warning(f"Missing required claim in JWT token: {e}")
        raise JWTValidationError(f"Token missing required field: {e}")
    except InvalidTokenError as e:
        logger.warning(f"Invalid JWT token: {e}")
        raise JWTValidationError(f"Invalid token: {e}")
    except Exception as e:
        logger.error(f"Unexpected error validating JWT token: {e}")
        raise JWTValidationError(f"Token validation failed: {e}")


def extract_user_info(decoded_token: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract user information from decoded JWT token
    
    Handles multiple field name variations:
    - user_id, uid, sub (for user ID)
    - email, user_email (for email)
    
    Email is optional and can be resolved from Firestore if missing.
    User ID is required for Firebase custom token generation.
    
    Args:
        decoded_token: Decoded JWT payload
        
    Returns:
        Dictionary with user_id (required) and email (optional)
        
    Raises:
        JWTValidationError: If user_id is missing
    """
    # Try multiple field names for user_id
    user_id = (
        decoded_token.get('user_id') or
        decoded_token.get('uid') or
        decoded_token.get('sub') or
        decoded_token.get('userId')
    )
    
    # Try multiple field names for email (optional)
    email = (
        decoded_token.get('email') or
        decoded_token.get('user_email') or
        decoded_token.get('email_address')
    )
    
    # User ID is required (needed for Firebase custom token)
    if not user_id:
        raise JWTValidationError(
            "Token missing required field: user_id (or uid/sub). "
            "Available fields: " + ", ".join(decoded_token.keys())
        )
    
    # Email is optional - can be resolved from Firestore
    # Convert to string and return empty string if None
    email_str = str(email) if email else ""
    
    return {
        'user_id': str(user_id),
        'email': email_str,
    }

