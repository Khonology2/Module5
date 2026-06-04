from __future__ import annotations

import logging
from uuid import uuid4
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.postgres_store import (
    _GENERIC_TABLES,
    fetch_onboarding_by_email,
    fetch_onboarding_by_user_id,
    fetch_onboarding_records,
    fetch_user_by_id,
    get_session_factory,
    update_onboarding,
    update_user,
    upsert_onboarding,
    upsert_user,
    delete_where,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["users"])


class ProfileUpdateRequest(BaseModel):
    displayName: str | None = None
    photoURL: str | None = None
    department: str | None = None
    jobTitle: str | None = None


def _camel_to_snake_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    mapping = {
        "displayName": "display_name",
        "photoURL": "photo_url",
        "jobTitle": "job_title",
        "privateGoals": "private_goals",
        "managerOnly": "manager_only",
        "teamShare": "team_share",
        "leaderboardParticipation": "leaderboard_participation",
        "profileVisible": "profile_visible",
        "pushNotifications": "push_notifications",
        "emailNotifications": "email_notifications",
        "soundAlerts": "sound_alerts",
        "goalReminders": "goal_reminders",
        "weeklyReports": "weekly_reports",
        "darkMode": "dark_mode",
        "speechRecognitionEnabled": "speech_recognition_enabled",
        "celebrationFeed": "celebration_feed",
        "autoSync": "auto_sync",
        "timeZone": "time_zone",
        "tutorialEnabled": "tutorial_enabled",
        "twoFactorAuth": "two_factor_auth",
        "sessionTimeout": "session_timeout",
        "sessionTimeoutMinutes": "session_timeout_minutes",
        "biometricAuth": "biometric_auth",
        "moduleAccessRole": "module_access_role",
        "moduleRole": "module_role",
        "fullName": "full_name",
        "firstName": "first_name",
        "lastName": "last_name",
    }
    out: Dict[str, Any] = {}
    for key, value in payload.items():
        out[mapping.get(key, key)] = value
    return out


def _split_user_payload(payload: Dict[str, Any]) -> tuple[Dict[str, Any], Dict[str, Any]]:
    column_keys = {
        "email",
        "display_name",
        "photo_url",
        "department",
        "job_title",
        "role",
        "private_goals",
        "manager_only",
        "team_share",
        "leaderboard_participation",
        "profile_visible",
        "push_notifications",
        "email_notifications",
        "sound_alerts",
        "goal_reminders",
        "weekly_reports",
        "dark_mode",
        "speech_recognition_enabled",
        "celebration_feed",
        "auto_sync",
        "language",
        "time_zone",
        "tutorial_enabled",
        "two_factor_auth",
        "session_timeout",
        "session_timeout_minutes",
        "biometric_auth",
        "total_points",
        "level",
        "badges",
        "goal_visibility",
        "notification_frequency",
        "celebration_consent",
        "data",
    }
    columns: Dict[str, Any] = {}
    extra: Dict[str, Any] = {}
    for key, value in payload.items():
        if key in column_keys:
            columns[key] = value
        else:
            extra[key] = value
    return columns, extra


def _snake_to_camel_user(row: Dict[str, Any]) -> Dict[str, Any]:
    if not row:
        return {}
    return {
        "userId": row.get("user_id"),
        "email": row.get("email"),
        "displayName": row.get("display_name"),
        "photoURL": row.get("photo_url"),
        "department": row.get("department"),
        "jobTitle": row.get("job_title"),
        "role": row.get("role"),
        "privateGoals": row.get("private_goals", False),
        "managerOnly": row.get("manager_only", False),
        "teamShare": row.get("team_share", True),
        "leaderboardParticipation": row.get("leaderboard_participation", False),
        "profileVisible": row.get("profile_visible", True),
        "pushNotifications": row.get("push_notifications", True),
        "emailNotifications": row.get("email_notifications", True),
        "soundAlerts": row.get("sound_alerts", True),
        "goalReminders": row.get("goal_reminders", True),
        "weeklyReports": row.get("weekly_reports", False),
        "darkMode": row.get("dark_mode", True),
        "speechRecognitionEnabled": row.get("speech_recognition_enabled", False),
        "celebrationFeed": row.get("celebration_feed", True),
        "autoSync": row.get("auto_sync", True),
        "language": row.get("language", "en"),
        "timeZone": row.get("time_zone", "UTC"),
        "tutorialEnabled": row.get("tutorial_enabled", False),
        "twoFactorAuth": row.get("two_factor_auth", False),
        "sessionTimeout": row.get("session_timeout", False),
        "sessionTimeoutMinutes": row.get("session_timeout_minutes", 30),
        "biometricAuth": row.get("biometric_auth", False),
        "totalPoints": row.get("total_points", 0),
        "level": row.get("level", 1),
        "badges": row.get("badges", []),
        "goalVisibility": row.get("goal_visibility", "private"),
        "notificationFrequency": row.get("notification_frequency", "daily"),
        "celebrationConsent": row.get("celebration_consent", "private"),
        "data": row.get("data") or {},
    }


def _snake_to_camel_onboarding(row: Dict[str, Any]) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("data") or {}
    if not isinstance(payload, dict):
        payload = {}
    return {
        **payload,
        "userId": row.get("user_id"),
        "email": row.get("email"),
        "displayName": row.get("display_name"),
        "fullName": row.get("full_name"),
        "firstName": row.get("first_name"),
        "lastName": row.get("last_name"),
        "moduleAccessRole": row.get("module_access_role"),
        "moduleRole": row.get("module_role"),
        "role": row.get("role"),
        "status": row.get("status"),
        "theme": row.get("theme"),
    }


def _snake_to_camel_repository(row: Dict[str, Any]) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("payload") or {}
    if not isinstance(payload, dict):
        payload = {}
    return {
        "id": row.get("id"),
        "userId": row.get("user_id"),
        "email": row.get("email"),
        "title": row.get("title"),
        "status": row.get("status"),
        "payload": payload,
    }


def _iso_value(value: Any) -> Any:
    if hasattr(value, "isoformat"):
        return value.isoformat()
    if isinstance(value, list):
        return [_iso_value(item) for item in value]
    if isinstance(value, dict):
        return {key: _iso_value(item) for key, item in value.items()}
    return value


def _snake_to_camel_generic(row: Dict[str, Any]) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("payload") or {}
    if not isinstance(payload, dict):
        payload = {}
    camel_payload = {key: _iso_value(value) for key, value in payload.items()}
    return {
        **camel_payload,
        "id": row.get("id"),
        "userId": row.get("user_id"),
        "email": row.get("email"),
        "title": row.get("title"),
        "status": row.get("status"),
        "createdAt": _iso_value(row.get("created_at")),
        "updatedAt": _iso_value(row.get("updated_at")),
        "payload": camel_payload,
    }


def _collection_rows(collection_name: str) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        rows = session.execute(_GENERIC_TABLES[collection_name].select()).fetchall()
    return [dict(row._mapping) for row in rows]


def _upsert_collection_row(
    collection_name: str,
    payload: Dict[str, Any],
    *,
    row_id: str | None = None,
    user_id: str | None = None,
) -> Dict[str, Any]:
    table = _GENERIC_TABLES[collection_name]
    item_id = str(row_id or payload.get("id") or payload.get("goalId") or uuid4().hex).strip()
    row_payload = {
        "id": item_id,
        "user_id": user_id or payload.get("userId") or payload.get("user_id"),
        "email": payload.get("email"),
        "title": payload.get("title") or payload.get("goalTitle") or payload.get("description"),
        "status": payload.get("status"),
        "payload": payload,
    }
    with get_session_factory()() as session:
        stmt = pg_insert(table).values(**row_payload)
        stmt = stmt.on_conflict_do_update(
            index_elements=[table.c.id],
            set_=row_payload,
        )
        session.execute(stmt)
        session.commit()
        row = session.execute(table.select().where(table.c.id == item_id)).first()
    return _snake_to_camel_generic(dict(row._mapping)) if row else {}


def _merge_collection_row(
    collection_name: str,
    row_id: str,
    updates: Dict[str, Any],
) -> Dict[str, Any]:
    table = _GENERIC_TABLES[collection_name]
    with get_session_factory()() as session:
        existing = session.execute(
            table.select().where(table.c.id == row_id)
        ).first()
        if existing is None:
            return _upsert_collection_row(collection_name, updates, row_id=row_id)

        current = dict(existing._mapping)
        current_payload = current.get("payload") or {}
        if not isinstance(current_payload, dict):
            current_payload = {}

        merged_payload = {**current_payload, **updates}
        merged_row = {
            "id": row_id,
            "user_id": updates.get("userId")
            or updates.get("user_id")
            or current.get("user_id"),
            "email": updates.get("email") or current.get("email"),
            "title": updates.get("title")
            or updates.get("goalTitle")
            or updates.get("description")
            or current.get("title"),
            "status": updates.get("status") or current.get("status"),
            "payload": merged_payload,
        }

        stmt = pg_insert(table).values(**merged_row)
        stmt = stmt.on_conflict_do_update(
            index_elements=[table.c.id],
            set_=merged_row,
        )
        session.execute(stmt)
        session.commit()
        row = session.execute(table.select().where(table.c.id == row_id)).first()

    return _snake_to_camel_generic(dict(row._mapping)) if row else {}


def _select_collection_items(
    collection_name: str,
    *,
    limit: int | None = None,
    predicate=None,
) -> list[Dict[str, Any]]:
    rows = _collection_rows(collection_name)
    items = [_snake_to_camel_generic(row) for row in rows]
    if predicate is not None:
        items = [item for item in items if predicate(item)]
    items.sort(
        key=lambda item: item.get("updatedAt")
        or item.get("createdAt")
        or "",
        reverse=True,
    )
    if limit is not None and limit >= 0:
        items = items[:limit]
    return items


@router.get("/users/{user_id}")
async def get_user(user_id: str):
    row = fetch_user_by_id(user_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _snake_to_camel_user(row)


@router.patch("/users/{user_id}")
async def patch_user(user_id: str, payload: Dict[str, Any]):
    updates = _camel_to_snake_payload(payload)
    column_updates, extra_updates = _split_user_payload(updates)
    row = update_user(user_id, column_updates)
    if not row:
        row = upsert_user(user_id, column_updates)
    if extra_updates:
        current = fetch_user_by_id(user_id) or row or {}
        data = current.get("data") or {}
        if not isinstance(data, dict):
            data = {}
        data.update(extra_updates)
        row = update_user(user_id, {"data": data}) or row
    return _snake_to_camel_user(row)


@router.get("/users/{user_id}/settings")
async def get_user_settings(user_id: str):
    row = fetch_user_by_id(user_id)
    if not row:
      defaults = _snake_to_camel_user(upsert_user(user_id, {"user_id": user_id}))
      return defaults
    return _snake_to_camel_user(row)


@router.put("/users/{user_id}/settings")
async def put_user_settings(user_id: str, payload: Dict[str, Any]):
    updates = _camel_to_snake_payload(payload)
    column_updates, extra_updates = _split_user_payload(updates)
    row = update_user(user_id, column_updates)
    if not row:
        row = upsert_user(user_id, column_updates)
    if extra_updates:
        current = fetch_user_by_id(user_id) or row or {}
        data = current.get("data") or {}
        if not isinstance(data, dict):
            data = {}
        data.update(extra_updates)
        row = update_user(user_id, {"data": data}) or row
    return _snake_to_camel_user(row)


@router.get("/onboarding")
async def list_onboarding(email: str | None = None, limit: int = 500):
    if email and email.strip():
        row = fetch_onboarding_by_email(email.strip())
        items = [_snake_to_camel_onboarding(row)] if row else []
        return {"items": items}
    rows = fetch_onboarding_records(limit=limit)
    return {"items": [_snake_to_camel_onboarding(row) for row in rows]}


@router.get("/onboarding/{user_id}")
async def get_onboarding(user_id: str):
    row = fetch_onboarding_by_user_id(user_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _snake_to_camel_onboarding(row)


@router.patch("/onboarding/{user_id}")
async def patch_onboarding(user_id: str, payload: Dict[str, Any]):
    updates = _camel_to_snake_payload(payload)
    row = update_onboarding(user_id, updates)
    if not row:
        row = upsert_onboarding(user_id, updates)
    return _snake_to_camel_onboarding(row)


@router.get("/repositories/{user_id}")
async def get_repositories(user_id: str):
    with get_session_factory()() as session:
        rows = session.execute(
            _GENERIC_TABLES["repositories"]
            .select()
            .where(_GENERIC_TABLES["repositories"].c.user_id == user_id)
        ).fetchall()
    return {"items": [_snake_to_camel_repository(dict(r._mapping)) for r in rows]}


@router.get("/repositories")
async def get_all_repositories():
    with get_session_factory()() as session:
      rows = session.execute(_GENERIC_TABLES["repositories"].select()).fetchall()
    return {"items": [_snake_to_camel_repository(dict(r._mapping)) for r in rows]}


@router.post("/repositories/{user_id}")
async def upsert_repository(user_id: str, payload: Dict[str, Any]):
    table = _GENERIC_TABLES["repositories"]
    repo_id = str(payload.get("id") or payload.get("goalId") or "").strip()
    if not repo_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing repository id")
    row_payload = {
        "id": repo_id,
        "user_id": user_id,
        "email": payload.get("email"),
        "title": payload.get("title") or payload.get("goalTitle"),
        "status": payload.get("status"),
        "payload": payload.get("payload") or payload,
    }
    with get_session_factory()() as session:
        stmt = pg_insert(table).values(**row_payload)
        stmt = stmt.on_conflict_do_update(
            index_elements=[table.c.id],
            set_=row_payload,
        )
        session.execute(stmt)
        session.commit()
        row = session.execute(table.select().where(table.c.id == repo_id)).first()
    return _snake_to_camel_repository(dict(row._mapping)) if row else {}


@router.delete("/repositories/{user_id}/{repo_id}")
async def remove_repository(user_id: str, repo_id: str):
    delete_where("repositories", "id", repo_id)
    return {"status": "ok"}


@router.get("/goals")
async def get_goals(user_id: str | None = None, goal_id: str | None = None, status: str | None = None, limit: int = 200):
    items = _select_collection_items(
        "goals",
        limit=limit,
        predicate=lambda item: (
            (user_id is None or item.get("userId") == user_id)
            and (goal_id is None or item.get("goalId") == goal_id or item.get("id") == goal_id)
            and (status is None or item.get("status") == status)
        ),
    )
    return {"items": items}


@router.patch("/goals/{goal_id}")
async def patch_goal(goal_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("goals", goal_id, payload)


@router.get("/activities/{user_id}")
async def get_activities(user_id: str, limit: int = 50):
    items = _select_collection_items(
        "activities",
        limit=limit,
        predicate=lambda item: item.get("userId") == user_id,
    )
    return {"items": items}


@router.post("/activities/{user_id}")
async def create_activity(user_id: str, payload: Dict[str, Any]):
    return _upsert_collection_row("activities", payload, user_id=user_id)


@router.get("/approved-goals-audit")
async def get_approved_goals_audit(
    user_id: str | None = None,
    employee_id: str | None = None,
    goal_id: str | None = None,
    limit: int = 500,
):
    items = _select_collection_items(
        "approved_goals_audit",
        limit=limit,
        predicate=lambda item: (
            (user_id is None or item.get("userId") == user_id)
            and (employee_id is None or item.get("employeeId") == employee_id)
            and (goal_id is None or item.get("goalId") == goal_id or item.get("id") == goal_id)
        ),
    )
    return {"items": items}


@router.get("/approved-goals-audit/{goal_id}")
async def get_approved_goal_audit(goal_id: str):
    items = _select_collection_items(
        "approved_goals_audit",
        predicate=lambda item: item.get("goalId") == goal_id or item.get("id") == goal_id,
    )
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Approved goal audit not found")
    return items[0]


@router.post("/approved-goals-audit")
async def create_approved_goal_audit(payload: Dict[str, Any]):
    employee_id = str(payload.get("employeeId") or payload.get("userId") or payload.get("user_id") or "").strip()
    return _upsert_collection_row("approved_goals_audit", payload, row_id=payload.get("goalId"), user_id=employee_id or None)


@router.get("/audit-entries")
async def get_audit_entries(
    user_id: str | None = None,
    department: str | None = None,
    status: str | None = None,
    goal_id: str | None = None,
    entry_id: str | None = None,
    action: str | None = None,
    include_actions: bool = False,
    limit: int = 200,
):
    items = _select_collection_items(
        "audit_entries",
        limit=limit,
        predicate=lambda item: (
            (include_actions or item.get("action") is None)
            and (action is None or item.get("action") == action)
            and (user_id is None or item.get("userId") == user_id)
            and (department is None or item.get("userDepartment") == department)
            and (status is None or item.get("status") == status)
            and (goal_id is None or item.get("goalId") == goal_id)
            and (entry_id is None or item.get("id") == entry_id)
        ),
    )
    return {"items": items}


@router.get("/audit-entries/{entry_id}")
async def get_audit_entry(entry_id: str):
    items = _select_collection_items(
        "audit_entries",
        predicate=lambda item: item.get("id") == entry_id,
    )
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audit entry not found")
    return items[0]


@router.post("/audit-entries")
async def create_audit_entry(payload: Dict[str, Any]):
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip()
    return _upsert_collection_row("audit_entries", payload, user_id=user_id or None)


@router.patch("/audit-entries/{entry_id}")
async def patch_audit_entry(entry_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("audit_entries", entry_id, payload)


@router.get("/audit-entries/{entry_id}/timeline")
async def get_audit_timeline(entry_id: str, limit: int = 100):
    items = _select_collection_items(
        "audit_timelines",
        limit=limit,
        predicate=lambda item: item.get("entryId") == entry_id or item.get("userId") == entry_id,
    )
    return {"items": items}


@router.post("/audit-entries/{entry_id}/timeline")
async def add_audit_timeline_event(entry_id: str, payload: Dict[str, Any]):
    event_payload = {
        **payload,
        "entryId": entry_id,
    }
    return _upsert_collection_row("audit_timelines", event_payload, user_id=entry_id)


@router.get("/badges/{user_id}")
async def get_badges(user_id: str, limit: int = 500):
    items = _select_collection_items(
        "badges",
        limit=limit,
        predicate=lambda item: item.get("userId") == user_id,
    )
    return {"items": items}


@router.post("/badges/{user_id}/{badge_id}")
async def upsert_badge(user_id: str, badge_id: str, payload: Dict[str, Any]):
    return _upsert_collection_row("badges", payload, row_id=badge_id, user_id=user_id)


@router.patch("/badges/{user_id}/{badge_id}")
async def patch_badge(user_id: str, badge_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("badges", badge_id, payload)


@router.get("/alerts/{user_id}")
async def get_alerts(user_id: str, limit: int = 100):
    items = _select_collection_items(
        "alerts",
        limit=limit,
        predicate=lambda item: item.get("userId") == user_id,
    )
    return {"items": items}


@router.post("/alerts/{user_id}")
async def create_alert(user_id: str, payload: Dict[str, Any]):
    return _upsert_collection_row("alerts", payload, user_id=user_id)

