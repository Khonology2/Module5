"""
Authentication routes for token validation and Firebase custom token generation
"""
import logging
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import JSONResponse

from app.models import (
    TokenValidationRequest,
    TokenValidationResponse,
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
        # Step 1: Validate JWT token
        logger.info("Validating JWT token")
        decoded_token = validate_jwt_token(request.token)
        
        # Step 2: Extract user information from token
        user_info = extract_user_info(decoded_token)
        user_id = user_info['user_id']
        email = user_info['email']
        
        logger.info(f"Token validated for user_id: {user_id}, email: {email or 'not provided (will resolve from Firestore)'}")
        
        # Step 3: Validate user against Firestore and get roles
        # Note: email is optional - validate_user_and_get_roles will resolve it from Firestore if missing
        logger.info(f"Querying Firestore for user_id: {user_id}")
        user_data = validate_user_and_get_roles(user_id, email)
        
        # Step 4: Generate Firebase custom token
        logger.info(f"Generating Firebase custom token for user_id: {user_id}")
        auth_client = get_auth()
        
        # Firebase custom tokens use the user_id (UID) as the identifier
        # The UID should match the user_id from the JWT token
        # create_custom_token returns a string (JWT token)
        custom_token = auth_client.create_custom_token(user_id)
        
        logger.info(f"Firebase custom token generated successfully for user_id: {user_id}")
        
        # Step 5: Return response
        # Ensure custom_token is a string (it should be, but handle edge cases)
        firebase_token = custom_token if isinstance(custom_token, str) else str(custom_token)
        
        return TokenValidationResponse(
            firebase_token=firebase_token,
            user_id=user_data['user_id'],
            email=user_data['email'],
            roles=user_data['roles'],
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



