"""
Configuration module for loading and validating environment variables
"""
import os
import json
from typing import Optional, Dict, Any
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

# Load environment variables from .env file (for local development)
load_dotenv()


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        # Explicitly map environment variables to field names
        env_ignore_empty=True,
    )
    
    # Firebase service account JSON (can be a JSON string or path to JSON file)
    # Environment variable: FIREBASE_SERVICE_ACCOUNT_JSON
    firebase_service_account_json: str
    
    # JWT secret for validating tokens from Khonobuzz
    # Environment variable: JWT_SECRET
    jwt_secret: str
    
    # Optional backend URL
    # Environment variable: BACKEND_URL
    backend_url: Optional[str] = None
    
    @model_validator(mode='before')
    @classmethod
    def read_env_vars(cls, data: Any) -> Dict[str, Any]:
        """Read environment variables explicitly and map them to field names"""
        if not isinstance(data, dict):
            data = {}
        
        # Read from environment variables and map to field names
        # Always read directly from os.getenv() to ensure we get the values
        env_mapping = {
            'FIREBASE_SERVICE_ACCOUNT_JSON': 'firebase_service_account_json',
            'JWT_SECRET': 'jwt_secret',
            'BACKEND_URL': 'backend_url',
        }
        
        result = dict(data)
        for env_var, field_name in env_mapping.items():
            # Always read from environment variable directly (most reliable)
            env_value = os.getenv(env_var)
            if env_value is not None:  # Check for None, not falsy (empty string is valid)
                result[field_name] = env_value
            # Fallback: check if BaseSettings already read it with uppercase name
            elif env_var in result and result[env_var] is not None:
                result[field_name] = result[env_var]
            # Fallback: check if it's already in the result with the field name
            elif field_name not in result:
                # If not found anywhere, check if it's in data with uppercase
                # This handles case where BaseSettings might have already processed it
                pass
        
        return result


# Global settings instance
_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get application settings, loading from environment if not already loaded"""
    global _settings
    if _settings is None:
        _settings = Settings()
        validate_settings(_settings)
    return _settings


def validate_settings(settings: Settings) -> None:
    """
    Validate that all required settings are present and properly formatted
    
    Args:
        settings: Settings instance to validate
        
    Raises:
        ValueError: If required settings are missing or invalid
    """
    if not settings.firebase_service_account_json:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON environment variable is required")
    
    if not settings.jwt_secret:
        raise ValueError("JWT_SECRET environment variable is required")
    
    # Try to parse Firebase service account JSON to validate it
    try:
        parse_firebase_service_account(settings.firebase_service_account_json)
    except (json.JSONDecodeError, ValueError) as e:
        raise ValueError(f"Invalid FIREBASE_SERVICE_ACCOUNT_JSON format: {e}")


def parse_firebase_service_account(service_account_str: str) -> Dict[str, Any]:
    """
    Parse Firebase service account JSON from environment variable
    
    The service account can be provided as:
    1. A JSON string (most common in production)
    2. A path to a JSON file (for local development)
    
    Args:
        service_account_str: JSON string or file path
        
    Returns:
        Parsed service account dictionary
        
    Raises:
        ValueError: If JSON is invalid or file doesn't exist
    """
    # Try to parse as JSON string first
    try:
        return json.loads(service_account_str)
    except json.JSONDecodeError:
        pass
    
    # If not valid JSON, try as file path
    if os.path.exists(service_account_str):
        try:
            with open(service_account_str, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            raise ValueError(f"Failed to read Firebase service account file: {e}")
    
    # If neither worked, raise error
    raise ValueError(
        "FIREBASE_SERVICE_ACCOUNT_JSON must be either a valid JSON string "
        "or a path to a JSON file"
    )

