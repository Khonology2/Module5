"""
Authentication routes for token validation and Firebase custom token generation
"""
import logging
import time
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import JSONResponse

from app.models import (
    TokenValidationRequest,
    TokenValidationResponse,
    AuthCallbackRequest,
    AuthCallbackResponse,
    ErrorResponse,
)
from app.jwt_validator import validate_jwt_token, extract_user_info, JWTValidationError
from app.firestore_service import (
    validate_user_and_get_roles,
    FirestoreServiceError,
)
from app.firebase_client import get_auth

logger = logging.getLogger(__name__)

router = APIRouter(tags=["authentication"])


@router.post(
    "/validate-token",
    response_model=TokenValidationResponse,
    status_code=status.HTTP_200_OK,
    responses={
        400: {"model": ErrorResponse, "description": "Bad Request - Invalid input"},
        401: {"model": ErrorResponse, "description": "Unauthorized - Invalid or expired token"},
        403: {"model": ErrorResponse, "description": "Forbidden - User status not Active"},
        404: {"model": ErrorResponse, "description": "Not Found - User not found in Firestore"},
        500: {"model": ErrorResponse, "description": "Internal Server Error"},
    },
    summary="Validate JWT token and generate Firebase custom token",
    description="""
    Validates a JWT token from Khonobuzz/ConoBuzz and generates a Firebase custom token for auto-login.
    
    **Process:**
    1. Validates JWT token signature and expiration using JWT_SECRET
    2. Extracts user_id (required) and email (optional) from token
       - Supports multiple field names: user_id/uid/sub for user ID, email/user_email for email
    3. Queries Firestore onboarding collection by user_id (or email if user_id not found)
    4. Validates user status is 'Active'
    5. Extracts moduleAccessRole from onboarding document
    6. Resolves email from Firestore if missing from JWT token
    7. Generates Firebase custom token using user_id
    8. Returns Firebase token, user_id, email, and roles
    
    **Note:** Email is optional in the JWT token. If missing, it will be resolved from 
    the onboarding or users collection in Firestore.
    
    **Error Codes:**
    - 400: Missing or invalid token in request
    - 401: Token signature invalid or expired
    - 403: User status is not Active
    - 404: User not found in Firestore onboarding collection
    - 500: Firebase or server error
    """,
)
async def validate_token(request: TokenValidationRequest) -> TokenValidationResponse:
    """
    Main endpoint for token validation and Firebase custom token generation
    
    This endpoint replaces the insecure frontend token validation logic.
    All token validation and Firebase custom token generation happens server-side.
    
    Args:
        request: TokenValidationRequest containing JWT token
        
    Returns:
        TokenValidationResponse with Firebase custom token and user information
        
    Raises:
        HTTPException: With appropriate status code and error message
    """
    try:
        start_total = time.perf_counter()
        logger.info("Validating JWT token")
        t = time.perf_counter()
        decoded_token = validate_jwt_token(request.token)
        logger.info(f"JWT validation completed in {int((time.perf_counter() - t) * 1000)} ms")
        
        user_info = extract_user_info(decoded_token)
        user_id = user_info['user_id']
        email = user_info['email']
        theme = user_info.get('theme') or ""
        
        logger.info(f"Token validated for user_id: {user_id}, email: {email or 'not provided (will resolve from Firestore)'}")
        
        logger.info(f"Querying Firestore for user_id: {user_id}")
        t = time.perf_counter()
        # Login flow should always use fresh role data so role changes apply immediately.
        user_data = validate_user_and_get_roles(user_id, email, use_cache=False)
        logger.info(f"Firestore query completed in {int((time.perf_counter() - t) * 1000)} ms")
        
        logger.info(f"Generating Firebase custom token for user_id: {user_id}")
        # Log project_id so we can confirm token audience matches client (must be pdh-v2)
        from app.config import get_firebase_service_account_dict
        _sa = get_firebase_service_account_dict()
        _project_id = _sa.get("project_id", "unknown")
        logger.info("Backend issuing custom token for Firebase project_id=%s (client must use same project)", _project_id)
        t = time.perf_counter()
        auth_client = get_auth()
        
        # Firebase custom tokens use the user_id (UID) as the identifier
        # The UID should match the user_id from the JWT token
        # create_custom_token returns a string (JWT token)
        custom_token = auth_client.create_custom_token(user_id)
        logger.info(f"Firebase custom token generation completed in {int((time.perf_counter() - t) * 1000)} ms")
        
        logger.info(f"Firebase custom token generated successfully for user_id: {user_id}")
        
        # Step 5: Return response
        # Ensure custom_token is a string (it should be, but handle edge cases)
        # If it's bytes, decode it; otherwise convert to string
        if isinstance(custom_token, bytes):
            firebase_token = custom_token.decode('utf-8')
        elif isinstance(custom_token, str):
            firebase_token = custom_token
        else:
            firebase_token = str(custom_token)
        
        # Validate token format (should be a JWT with 3 parts)
        token_parts = firebase_token.split('.')
        if len(token_parts) != 3:
            logger.error(f"Invalid Firebase token format - expected 3 parts, got {len(token_parts)}")
            raise ValueError("Invalid Firebase custom token format")
        
        logger.info(f"Firebase token validated - length: {len(firebase_token)}, parts: {len(token_parts)}")
        logger.info(f"Token validation completed in {int((time.perf_counter() - start_total) * 1000)} ms")
        
        return TokenValidationResponse(
            firebase_token=firebase_token,
            user_id=user_data['user_id'],
            email=user_data['email'],
            roles=user_data['roles'],
            theme=theme,
        )
        
    except JWTValidationError as e:
        logger.warning(f"JWT validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except FirestoreServiceError as e:
        error_msg = str(e)
        logger.warning(f"Firestore service error: {error_msg}")
        
        # Determine appropriate status code based on error message
        if "not found" in error_msg.lower():
            status_code = status.HTTP_404_NOT_FOUND
        elif "not Active" in error_msg or "status" in error_msg.lower():
            status_code = status.HTTP_403_FORBIDDEN
        else:
            status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
        
        raise HTTPException(
            status_code=status_code,
            detail=error_msg,
        )
    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Configuration error: {e}",
        )
    except Exception as e:
        logger.error(f"Unexpected error in validate_token: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}",
        )


@router.post(
    "/auth-callback",
    response_model=AuthCallbackResponse,
    status_code=status.HTTP_200_OK,
    responses={
        400: {"model": ErrorResponse, "description": "Bad Request - Invalid input"},
        500: {"model": ErrorResponse, "description": "Internal Server Error"},
    },
    summary="Authentication callback endpoint",
    description="""
    Callback endpoint called by the frontend after successful authentication.
    
    This endpoint allows the frontend to communicate with the backend after the user
    has been authenticated and the application understands the token and persona.
    
    **Process:**
    1. Receives user information and authentication status from frontend
    2. Logs the authentication event
    3. Returns confirmation that the backend has processed the callback
    
    **Use Case:**
    After the frontend validates the token, signs in with Firebase custom token,
    and determines the user's role, it calls this endpoint to notify the backend
    that authentication is complete and the user is being navigated to their dashboard.
    """,
)
async def auth_callback(request: AuthCallbackRequest) -> AuthCallbackResponse:
    """
    Authentication callback endpoint
    
    Called by the frontend after successful authentication to notify the backend
    that the user has been authenticated and is being navigated to their dashboard.
    
    Args:
        request: AuthCallbackRequest containing user information and authentication status
        
    Returns:
        AuthCallbackResponse with confirmation that the callback was processed
    """
    try:
        if not request.authenticated:
            logger.warning(f"Auth callback received with authenticated=false for user_id: {request.user_id}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Authentication status is false",
            )
        
        # Log the authentication callback
        logger.info(
            f"Authentication callback received - user_id: {request.user_id}, "
            f"email: {request.email}, role: {request.role}, authenticated: {request.authenticated}"
        )
        
        # Here you can add additional processing if needed:
        # - Update user last login timestamp
        # - Log authentication event to analytics
        # - Send notifications
        # - Update user session information
        
        # Return success response
        return AuthCallbackResponse(
            status="success",
            message="Authentication callback processed successfully",
            user_id=request.user_id,
            email=request.email,
            role=request.role,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing auth callback: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}",
        )



