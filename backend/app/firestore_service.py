"""
Firestore service for querying onboarding and users collections
"""
import logging
from typing import Dict, Any, Optional, List
from google.cloud.firestore import Client, DocumentSnapshot
from google.cloud.exceptions import NotFound

from app.firebase_client import get_firestore

logger = logging.getLogger(__name__)


class FirestoreServiceError(Exception):
    """Custom exception for Firestore service errors"""
    pass


def get_onboarding_by_user_id(user_id: str) -> Optional[Dict[str, Any]]:
    """
    Query onboarding collection by user_id
    
    The onboarding collection may have documents with user_id field,
    or the document ID itself may be the user_id.
    
    Args:
        user_id: User ID to search for
        
    Returns:
        Document data if found, None otherwise
    """
    try:
        db = get_firestore()
        
        # First, try to get document by ID (common case)
        doc_ref = db.collection('onboarding').document(user_id)
        doc = doc_ref.get()
        
        if doc.exists:
            data = doc.to_dict()
            if data:
                logger.info(f"Found onboarding document by ID for user_id: {user_id}")
                return data
        
        # If not found by ID, try querying by user_id field
        query = db.collection('onboarding').where('user_id', '==', user_id).limit(1)
        docs = query.stream()
        
        for doc in docs:
            data = doc.to_dict()
            if data:
                logger.info(f"Found onboarding document by user_id field: {user_id}")
                return data
        
        logger.warning(f"No onboarding document found for user_id: {user_id}")
        return None
        
    except Exception as e:
        logger.error(f"Error querying onboarding collection by user_id: {e}")
        raise FirestoreServiceError(f"Failed to query onboarding collection: {e}")


def get_onboarding_by_email(email: str) -> Optional[Dict[str, Any]]:
    """
    Query onboarding collection by email
    
    Args:
        email: Email address to search for
        
    Returns:
        Document data if found, None otherwise
    """
    try:
        db = get_firestore()
        
        query = db.collection('onboarding').where('email', '==', email).limit(1)
        docs = query.stream()
        
        for doc in docs:
            data = doc.to_dict()
            if data:
                logger.info(f"Found onboarding document by email: {email}")
                return data
        
        logger.warning(f"No onboarding document found for email: {email}")
        return None
        
    except Exception as e:
        logger.error(f"Error querying onboarding collection by email: {e}")
        raise FirestoreServiceError(f"Failed to query onboarding collection: {e}")


def get_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    """
    Query users collection by user_id (document ID)
    
    Args:
        user_id: User ID (document ID in users collection)
        
    Returns:
        Document data if found, None otherwise
    """
    try:
        db = get_firestore()
        
        doc_ref = db.collection('users').document(user_id)
        doc = doc_ref.get()
        
        if doc.exists:
            data = doc.to_dict()
            if data:
                logger.info(f"Found user document for user_id: {user_id}")
                return data
        
        logger.warning(f"No user document found for user_id: {user_id}")
        return None
        
    except Exception as e:
        logger.error(f"Error querying users collection: {e}")
        raise FirestoreServiceError(f"Failed to query users collection: {e}")


def extract_module_access_role(onboarding_data: Dict[str, Any]) -> Optional[str]:
    """
    Extract moduleAccessRole from onboarding document
    
    Handles multiple field name variations:
    - moduleAccessRole (primary)
    - moduleRole (fallback)
    - role (fallback)
    
    Args:
        onboarding_data: Onboarding document data
        
    Returns:
        Module access role string, or None if not found
    """
    # Try moduleAccessRole first (most common)
    module_access_role = onboarding_data.get('moduleAccessRole')
    if module_access_role:
        return str(module_access_role)
    
    # Try moduleRole as fallback
    module_access_role = onboarding_data.get('moduleRole')
    if module_access_role:
        return str(module_access_role)
    
    # Try role as last fallback
    module_access_role = onboarding_data.get('role')
    if module_access_role:
        return str(module_access_role)
    
    return None


def validate_user_status(onboarding_data: Dict[str, Any]) -> bool:
    """
    Validate that user status is 'Active'
    
    Args:
        onboarding_data: Onboarding document data
        
    Returns:
        True if status is 'Active', False otherwise
    """
    status = onboarding_data.get('status')
    
    # If status field doesn't exist, assume active (backward compatibility)
    if status is None:
        logger.warning("No status field in onboarding document, assuming active")
        return True
    
    # Check if status is 'Active'
    is_active = str(status).strip().lower() == 'active'
    
    if not is_active:
        logger.warning(f"User status is not Active: {status}")
    
    return is_active


def get_user_roles_from_onboarding(onboarding_data: Dict[str, Any]) -> List[str]:
    """
    Extract roles from onboarding data
    
    The moduleAccessRole field may contain a single role or comma-separated roles.
    This function extracts PDH-related roles and returns them as a list.
    
    Args:
        onboarding_data: Onboarding document data
        
    Returns:
        List of role strings (e.g., ["PDH - Employee", "PDH - Manager"])
    """
    module_access_role = extract_module_access_role(onboarding_data)
    
    if not module_access_role:
        return []
    
    # Split by comma if multiple roles are present
    roles = [role.strip() for role in module_access_role.split(',')]
    
    # Filter to only PDH-related roles
    pdh_roles = [role for role in roles if 'PDH' in role.upper()]
    
    # If no PDH roles found, return all roles
    if not pdh_roles:
        return roles
    
    return pdh_roles


def validate_user_and_get_roles(
    user_id: str,
    email: str
) -> Dict[str, Any]:
    """
    Validate user against Firestore and extract role information
    
    This function:
    1. Queries onboarding collection by user_id (primary) or email (fallback if provided)
    2. Validates user status is 'Active'
    3. Extracts moduleAccessRole
    4. Resolves email from users collection if not provided in JWT
    
    Args:
        user_id: User ID from JWT token (required)
        email: Email from JWT token (optional - will be resolved from Firestore if missing)
        
    Returns:
        Dictionary with user_id, email, roles, and status
        
    Raises:
        FirestoreServiceError: If user not found or validation fails
    """
    # Try to get onboarding data by user_id first (most reliable)
    onboarding_data = get_onboarding_by_user_id(user_id)
    
    # If not found by user_id and email is provided, try by email
    if not onboarding_data and email:
        onboarding_data = get_onboarding_by_email(email)
    
    if not onboarding_data:
        error_msg = f"User not found in onboarding collection (user_id: {user_id}"
        if email:
            error_msg += f", email: {email}"
        error_msg += ")"
        raise FirestoreServiceError(error_msg)
    
    # Validate user status
    if not validate_user_status(onboarding_data):
        raise FirestoreServiceError(
            f"User status is not Active (user_id: {user_id})"
        )
    
    # Extract module access role
    module_access_role = extract_module_access_role(onboarding_data)
    if not module_access_role:
        raise FirestoreServiceError(
            f"No moduleAccessRole found in onboarding document (user_id: {user_id})"
        )
    
    # Get roles list
    roles = get_user_roles_from_onboarding(onboarding_data)
    
    # Resolve email: priority order:
    # 1. Email from JWT token (if provided)
    # 2. Email from onboarding document
    # 3. Email from users collection
    resolved_email = email
    if not resolved_email:
        resolved_email = onboarding_data.get('email')
    
    if not resolved_email:
        user_data = get_user_by_id(user_id)
        if user_data and user_data.get('email'):
            resolved_email = user_data['email']
            logger.info(f"Resolved email from users collection: {resolved_email}")
    
    # If still no email, use empty string (email is optional for some use cases)
    if not resolved_email:
        logger.warning(f"Email not found in JWT, onboarding, or users collection for user_id: {user_id}")
        resolved_email = ""
    
    return {
        'user_id': user_id,
        'email': resolved_email,
        'roles': roles,
        'module_access_role': module_access_role,
        'status': onboarding_data.get('status', 'Active'),
    }

