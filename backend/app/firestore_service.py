"""
PostgreSQL-backed service for onboarding/user lookups.

The legacy function names are preserved so the auth flow can switch stores
without needing broad route-level changes.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List, Optional

from app.postgres_store import (
    fetch_onboarding_by_email,
    fetch_onboarding_by_user_id,
    fetch_user_by_id,
    update_onboarding,
)

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 180
_roles_cache: dict = {}


class FirestoreServiceError(Exception):
    """Legacy exception name kept for callers."""


def get_onboarding_by_user_id(user_id: str) -> Optional[Dict[str, Any]]:
    try:
        data = fetch_onboarding_by_user_id(user_id)
        if data:
            logger.info("Found onboarding record for user_id: %s", user_id)
        else:
            logger.warning("No onboarding record found for user_id: %s", user_id)
        return data
    except Exception as e:
        logger.error("Error querying onboarding records by user_id: %s", e)
        raise FirestoreServiceError(f"Failed to query onboarding collection: {e}")


def get_onboarding_by_email(email: str) -> Optional[Dict[str, Any]]:
    try:
        data = fetch_onboarding_by_email(email)
        if data:
            logger.info("Found onboarding record by email: %s", email)
        else:
            logger.warning("No onboarding record found for email: %s", email)
        return data
    except Exception as e:
        logger.error("Error querying onboarding records by email: %s", e)
        raise FirestoreServiceError(f"Failed to query onboarding collection: {e}")


def get_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    try:
        data = fetch_user_by_id(user_id)
        if data:
            logger.info("Found user record for user_id: %s", user_id)
        else:
            logger.warning("No user record found for user_id: %s", user_id)
        return data
    except Exception as e:
        logger.error("Error querying users records: %s", e)
        raise FirestoreServiceError(f"Failed to query users collection: {e}")


def extract_display_name(onboarding_data: Dict[str, Any]) -> str:
    for key in ("displayName", "fullName", "name", "display_name", "full_name"):
        value = onboarding_data.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()

    first = onboarding_data.get("firstName") or onboarding_data.get("first_name")
    last = onboarding_data.get("lastName") or onboarding_data.get("last_name")
    if first or last:
        return f"{first or ''} {last or ''}".strip()

    return ""


def extract_module_access_role(onboarding_data: Dict[str, Any]) -> Optional[str]:
    module_access_role = onboarding_data.get("moduleAccessRole")
    if module_access_role:
        return str(module_access_role)

    module_access_role = onboarding_data.get("module_access_role")
    if module_access_role:
        return str(module_access_role)

    module_access_role = onboarding_data.get("moduleRole")
    if module_access_role:
        return str(module_access_role)

    module_access_role = onboarding_data.get("module_role")
    if module_access_role:
        return str(module_access_role)

    module_access_role = onboarding_data.get("role")
    if module_access_role:
        return str(module_access_role)

    return None


def validate_user_status(onboarding_data: Dict[str, Any]) -> bool:
    status = onboarding_data.get("status")
    if status is None:
        logger.warning("No status field in onboarding record, assuming active")
        return True
    is_active = str(status).strip().lower() == "active"
    if not is_active:
        logger.warning("User status is not Active: %s", status)
    return is_active


def get_user_roles_from_onboarding(onboarding_data: Dict[str, Any]) -> List[str]:
    module_access_role = extract_module_access_role(onboarding_data)
    if not module_access_role:
        return []

    roles = [role.strip() for role in module_access_role.split(",") if role.strip()]
    pdh_roles = [role for role in roles if "PDH" in role.upper()]
    return pdh_roles or roles


def get_primary_pdh_role(roles: List[str]) -> Optional[str]:
    normalized = [str(r).strip() for r in roles if str(r).strip()]
    for role in normalized:
        lower = role.lower()
        if lower.startswith("pdh") and "employee" in lower:
            return "PDH - Employee"
    for role in normalized:
        lower = role.lower()
        if lower.startswith("pdh") and "admin" in lower:
            return "PDH - Admin"
    for role in normalized:
        lower = role.lower()
        if lower.startswith("pdh") and "manager" in lower:
            return "PDH - Manager"
    return None


def _normalize_pdh_role(role: Optional[str]) -> Optional[str]:
    if not role:
        return None
    lower = str(role).strip().lower()
    if "employee" in lower or "staff" in lower:
        return "PDH - Employee"
    if "admin" in lower:
        return "PDH - Admin"
    if "manager" in lower:
        return "PDH - Manager"
    return None


def _merge_module_access_role_with_pdh(
    module_access_role: str,
    new_pdh_role: str,
) -> str:
    parts = [p.strip() for p in str(module_access_role).split(",") if p.strip()]
    non_pdh = [p for p in parts if "PDH" not in p.upper()]
    return ", ".join([new_pdh_role] + non_pdh)


def update_onboarding_pdh_role(
    user_id: str,
    email: str,
    new_pdh_role: str,
) -> Dict[str, Any]:
    normalized_role = _normalize_pdh_role(new_pdh_role)
    if not normalized_role:
        raise FirestoreServiceError(f"Invalid PDH role for update: {new_pdh_role}")

    try:
        data = get_onboarding_by_user_id(user_id)
        if not data and email:
            data = get_onboarding_by_email(email)
        if not data:
            raise FirestoreServiceError(
                f"User not found in onboarding collection for update (user_id: {user_id}, email: {email})"
            )

        current_module_access = extract_module_access_role(data) or ""
        merged_module_access = _merge_module_access_role_with_pdh(
            current_module_access,
            normalized_role,
        )

        updated_data = update_onboarding(
            user_id=data.get("user_id") or user_id,
            values={
                "module_access_role": merged_module_access,
                "module_role": merged_module_access,
                "role": normalized_role,
            },
        ) or {}
        logger.info(
            "Updated onboarding PDH role for user_id=%s email=%s to %s",
            user_id,
            email,
            normalized_role,
        )
        return updated_data
    except FirestoreServiceError:
        raise
    except Exception as e:
        logger.error("Failed updating onboarding PDH role: %s", e)
        raise FirestoreServiceError(f"Failed to update onboarding role: {e}")


def validate_user_and_get_roles(
    user_id: str,
    email: str,
    use_cache: bool = True,
) -> Dict[str, Any]:
    cache_key = f"{user_id}|{email or ''}"
    now = time.time()
    if use_cache and cache_key in _roles_cache:
        entry = _roles_cache[cache_key]
        if now - entry["ts"] < _CACHE_TTL_SECONDS:
            logger.info("Serving validation from cache for user_id: %s", user_id)
            return entry["data"]
        _roles_cache.pop(cache_key, None)

    onboarding_data = get_onboarding_by_user_id(user_id)
    if not onboarding_data and email:
        onboarding_data = get_onboarding_by_email(email)

    if not onboarding_data:
        error_msg = f"User not found in onboarding collection (user_id: {user_id}"
        if email:
            error_msg += f", email: {email}"
        error_msg += ")"
        raise FirestoreServiceError(error_msg)

    if not validate_user_status(onboarding_data):
        raise FirestoreServiceError(f"User status is not Active (user_id: {user_id})")

    module_access_role = extract_module_access_role(onboarding_data)
    if not module_access_role:
        raise FirestoreServiceError(
            f"No moduleAccessRole found in onboarding document (user_id: {user_id})"
        )

    roles = get_user_roles_from_onboarding(onboarding_data)
    pdh_role = get_primary_pdh_role(roles)

    resolved_email = email or (onboarding_data.get("email") or "")
    if not resolved_email:
        user_data = get_user_by_id(user_id)
        if user_data and user_data.get("email"):
            resolved_email = str(user_data["email"])
            logger.info("Resolved email from users table: %s", resolved_email)

    if not resolved_email:
        logger.warning(
            "Email not found in token, onboarding, or users table for user_id: %s",
            user_id,
        )

    display_name = extract_display_name(onboarding_data)

    result = {
        "user_id": user_id,
        "email": resolved_email,
        "roles": roles,
        "pdh_role": pdh_role,
        "module_access_role": module_access_role,
        "status": onboarding_data.get("status", "Active"),
        "display_name": display_name,
    }
    if use_cache:
        _roles_cache[cache_key] = {"data": result, "ts": now}
        logger.info(
            "Cached validation result for user_id: %s with TTL %ss",
            user_id,
            _CACHE_TTL_SECONDS,
        )
    return result

