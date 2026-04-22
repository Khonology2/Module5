"""
Pydantic models for API request and response validation
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class TokenValidationRequest(BaseModel):
    """
    Request model for token validation endpoint
    
    The JWT token from Khonobuzz is sent in the request body.
    """
    token: str = Field(
        ...,
        description="JWT token from Khonobuzz",
        min_length=1,
        example="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    )


class TokenValidationResponse(BaseModel):
    """
    Response model for successful token validation
    
    Contains the Firebase custom token for auto-login and user information.
    """
    firebase_token: str = Field(
        ...,
        description="Firebase custom token for auto-login",
        example="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
    )
    user_id: str = Field(
        ...,
        description="User ID from JWT token",
        example="user123"
    )
    email: str = Field(
        ...,
        description="User email address",
        example="user@example.com"
    )
    roles: List[str] = Field(
        ...,
        description="List of user roles (e.g., ['PDH - Employee', 'PDH - Manager'])",
        example=["PDH - Employee"]
    )
    pdh_role: Optional[str] = Field(
        None,
        description="Primary PDH role resolved from onboarding moduleAccessRole",
        example="PDH - Employee"
    )
    theme: Optional[str] = Field(
        None,
        description='Theme preference from token ("Light" or "dark")',
        example="Light"
    )


class AuthCallbackRequest(BaseModel):
    """
    Request model for authentication callback endpoint
    
    Called by the frontend after successful authentication to notify the backend.
    """
    user_id: str = Field(
        ...,
        description="User ID from Firebase",
        example="user123"
    )
    email: Optional[str] = Field(
        None,
        description="User email address",
        example="user@example.com"
    )
    role: Optional[str] = Field(
        None,
        description="User role (PDH - Employee, PDH - Manager, or PDH - Admin)",
        example="PDH - Employee"
    )
    authenticated: bool = Field(
        True,
        description="Authentication status",
        example=True
    )


class AuthCallbackResponse(BaseModel):
    """
    Response model for authentication callback endpoint
    """
    status: str = Field(
        ...,
        description="Callback processing status",
        example="success"
    )
    message: str = Field(
        ...,
        description="Response message",
        example="Authentication callback processed successfully"
    )
    user_id: str = Field(
        ...,
        description="User ID",
        example="user123"
    )
    email: Optional[str] = Field(
        None,
        description="User email address",
        example="user@example.com"
    )
    role: Optional[str] = Field(
        None,
        description="User role",
        example="PDH - Employee"
    )


class ErrorResponse(BaseModel):
    """
    Error response model for API errors
    
    All error responses follow this format for consistency.
    """
    error: str = Field(
        ...,
        description="Error type or category",
        example="JWTValidationError"
    )
    detail: str = Field(
        ...,
        description="Detailed error message",
        example="Token has expired"
    )

