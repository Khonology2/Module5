"""
Configuration module for loading and validating environment variables
"""
import os
import json
from typing import Optional, Dict, Any
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

# Load .env from this package directory so it works whether you run from backend/ or backend/app/
_env_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=_env_path)


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    model_config = SettingsConfigDict(
        env_file=_env_path,
        case_sensitive=False,
        extra='ignore',  # Ignore extra fields in .env
        env_ignore_empty=True,
    )

    # Firebase: entire service account JSON as a single-line string (no file paths)
    firebase_service_account_json: Optional[str] = Field(None, alias='FIREBASE_SERVICE_ACCOUNT_JSON')

    # JWT secret for validating tokens
    jwt_secret: str = Field(..., alias='JWT_SECRET_KEY')

    # Encryption key for data protection
    encryption_key: str = Field(..., alias='ENCRYPTION_KEY')

    # Optional backend URL
    backend_url: Optional[str] = Field(None, alias='BACKEND_URL')

    # Optional: Firebase Web client config (for GET /firebase-config; not in service account JSON)
    firebase_web_api_key: Optional[str] = Field(None, alias='FIREBASE_WEB_API_KEY')
    firebase_web_app_id: Optional[str] = Field(None, alias='FIREBASE_WEB_APP_ID')
    firebase_web_messaging_sender_id: Optional[str] = Field(None, alias='FIREBASE_WEB_MESSAGING_SENDER_ID')

    # Gemini API key for backend AI (fallback when Firebase AI fails). Create at https://aistudio.google.com/apikey
    gemini_api_key: Optional[str] = Field(None, alias='GEMINI_API_KEY')

    @model_validator(mode='before')
    @classmethod
    def read_env_vars(cls, data: Any) -> Dict[str, Any]:
        """Read environment variables explicitly and map them to field names"""
        if not isinstance(data, dict):
            data = {}

        env_mapping = {
            'FIREBASE_SERVICE_ACCOUNT_JSON': 'firebase_service_account_json',
            'JWT_SECRET_KEY': 'jwt_secret',
            'ENCRYPTION_KEY': 'encryption_key',
            'BACKEND_URL': 'backend_url',
            'FIREBASE_WEB_API_KEY': 'firebase_web_api_key',
            'FIREBASE_WEB_APP_ID': 'firebase_web_app_id',
            'FIREBASE_WEB_MESSAGING_SENDER_ID': 'firebase_web_messaging_sender_id',
            'GEMINI_API_KEY': 'gemini_api_key',
        }

        result = dict(data)

        # Special handling for jwt_secret - check both JWT_SECRET and JWT_SECRET_KEY
        jwt_secret = os.getenv('JWT_SECRET') or os.getenv('JWT_SECRET_KEY')
        if jwt_secret is not None:
            result['jwt_secret'] = jwt_secret

        for env_var, field_name in env_mapping.items():
            if field_name == 'jwt_secret':
                continue
            env_value = os.getenv(env_var)
            if env_value is not None:
                result[field_name] = env_value
                continue
            if field_name in result and result[field_name] is not None:
                continue
            if env_var in result and result[env_var] is not None:
                result[field_name] = result[env_var]
                continue
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


def get_firebase_service_account_dict() -> Dict[str, Any]:
    """
    Load and return Firebase service account dict from FIREBASE_SERVICE_ACCOUNT_JSON.
    The env var must contain the entire service account JSON as a single-line string.
    No file paths are used; credentials are loaded solely from the environment.
    """
    settings = get_settings()
    raw = (settings.firebase_service_account_json or "").strip()
    if not raw:
        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT_JSON environment variable is required. "
            "Set it to the full service account JSON as a single-line string (e.g. in Render dashboard or .env)."
        )
    return parse_firebase_service_account_json(raw)


def validate_settings(settings: Settings) -> None:
    """
    Validate that all required settings are present and properly formatted.

    Raises:
        ValueError: If required settings are missing or invalid.
    """
    raw = (settings.firebase_service_account_json or "").strip()
    if not raw:
        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT_JSON environment variable is required. "
            "Set it to the full service account JSON as a single-line string."
        )
    if not settings.jwt_secret:
        raise ValueError("JWT_SECRET_KEY environment variable is required")
    try:
        parse_firebase_service_account_json(raw)
    except (json.JSONDecodeError, ValueError) as e:
        raise ValueError(f"Invalid FIREBASE_SERVICE_ACCOUNT_JSON: {e}")


def parse_firebase_service_account_json(json_str: str) -> Dict[str, Any]:
    """
    Parse Firebase service account from the FIREBASE_SERVICE_ACCOUNT_JSON string.

    Expects the entire service account JSON as a single-line string (no file paths).
    Handles optional surrounding quotes from .env or shell.

    Returns:
        Parsed service account dictionary.

    Raises:
        ValueError: If the string is not valid JSON or missing required keys.
    """
    s = (json_str or "").strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1].strip()
    try:
        data = json.loads(s)
    except json.JSONDecodeError as e:
        raise ValueError(f"FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: {e}")
    if not isinstance(data, dict):
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object")
    if data.get("type") != "service_account" or "project_id" not in data:
        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must be a Firebase service account JSON "
            "(type: service_account, project_id required)"
        )
    return data

