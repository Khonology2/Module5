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
        extra='ignore',  # Ignore extra fields in .env
        env_ignore_empty=True,
    )
    
    # Firebase service account JSON (can be a JSON string or path to JSON file)
    firebase_service_account_json: str = Field(..., alias='FIREBASE_SERVICE_ACCOUNT_JSON')
    
    # JWT secret for validating tokens
    jwt_secret: str = Field(..., alias='JWT_SECRET_KEY')
    
    # Encryption key for data protection
    encryption_key: str = Field(..., alias='ENCRYPTION_KEY')
    
    # Optional backend URL
    backend_url: Optional[str] = Field(None, alias='BACKEND_URL')
    
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
            'JWT_SECRET_KEY': 'jwt_secret',
            'ENCRYPTION_KEY': 'encryption_key',
            'BACKEND_URL': 'backend_url',
        }
        
        result = dict(data)
        
        # Special handling for jwt_secret - check both JWT_SECRET and JWT_SECRET_KEY
        jwt_secret = os.getenv('JWT_SECRET') or os.getenv('JWT_SECRET_KEY')
        if jwt_secret is not None:
            result['jwt_secret'] = jwt_secret
        
        # Handle other environment variables
        for env_var, field_name in env_mapping.items():
            # Skip jwt_secret as we already handled it above
            if field_name == 'jwt_secret':
                continue
                
            # Priority 1: Read directly from environment variable (most reliable)
            env_value = os.getenv(env_var)
            if env_value is not None:
                result[field_name] = env_value
                continue
            
            # Priority 2: Check if BaseSettings already converted it (uppercase -> lowercase)
            # BaseSettings with case_sensitive=False converts FIREBASE_SERVICE_ACCOUNT_JSON -> firebase_service_account_json
            if field_name in result and result[field_name] is not None:
                # Already set by BaseSettings, keep it
                continue
            
            # Priority 3: Check if it's in data with uppercase name (before BaseSettings conversion)
            if env_var in result and result[env_var] is not None:
                result[field_name] = result[env_var]
                continue
            
            # Priority 4: Check all possible case variations
            # BaseSettings might have converted it to different case
            for key in list(result.keys()):
                if key.upper() == env_var.upper() and result[key] is not None:
                    result[field_name] = result[key]
                    break
        
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
    s = (service_account_str or "").strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1].strip()
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        pass
    path_candidate = os.path.expandvars(os.path.expanduser(s))
    if not os.path.isabs(path_candidate):
        cwd = os.getcwd()
        path_candidate = os.path.normpath(os.path.join(cwd, path_candidate))
    if os.path.exists(path_candidate):
        try:
            with open(path_candidate, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            raise ValueError(f"Failed to read Firebase service account file: {e}")
    raise ValueError(
        "FIREBASE_SERVICE_ACCOUNT_JSON must be either a valid JSON string "
        "or a path to a JSON file"
    )

