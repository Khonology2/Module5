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
    
    Args:
        decoded_token: Decoded JWT payload
        
    Returns:
        Dictionary with user_id and email
        
    Raises:
        JWTValidationError: If required fields are missing
    """
    user_id = decoded_token.get('user_id')
    email = decoded_token.get('email')
    
    if not user_id:
        raise JWTValidationError("Token missing required field: user_id")
    
    if not email:
        raise JWTValidationError("Token missing required field: email")
    
    return {
        'user_id': str(user_id),
        'email': str(email),
    }

