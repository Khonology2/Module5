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

