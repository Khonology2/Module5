"""Generic and domain-specific REST routes for PostgreSQL JSON collections."""

from __future__ import annotations

from typing import Any, Dict
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.postgres_store import (
    COLLECTION_TABLE_NAMES,
    _GENERIC_TABLES,
    delete_where,
    fetch_deleted_account_ids,
    fetch_users,
    get_session_factory,
    update_user,
)
from app.routes.users import (
    _merge_collection_row,
    _select_collection_items,
    _snake_to_camel_generic,
    _snake_to_camel_user,
    _upsert_collection_row,
)

router = APIRouter(tags=["collections"])


def _ensure_collection(name: str) -> str:
    if name not in COLLECTION_TABLE_NAMES:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Unknown collection: {name}",
        )
    return name


def _match_item(
    item: Dict[str, Any],
    *,
    user_id: str | None = None,
    goal_id: str | None = None,
    status: str | None = None,
    action: str | None = None,
    manager_id: str | None = None,
    employee_id: str | None = None,
    department: str | None = None,
    include_actions: bool = False,
) -> bool:
    if not include_actions and item.get("action") is not None:
        return False
    if user_id is not None and item.get("userId") != user_id:
        return False
    if goal_id is not None and item.get("goalId") != goal_id and item.get("id") != goal_id:
        return False
    if status is not None and item.get("status") != status:
        return False
    if action is not None and item.get("action") != action:
        return False
    if manager_id is not None and item.get("managerId") != manager_id:
        return False
    if employee_id is not None and item.get("employeeId") != employee_id:
        return False
    if department is not None and item.get("department") != department and item.get("userDepartment") != department:
        return False
    return True


@router.get("/users")
async def list_users(
    role: str | None = None,
    department: str | None = None,
    limit: int = 500,
):
    rows = fetch_users(role=role, department=department, limit=limit)
    return {"items": [_snake_to_camel_user(row) for row in rows]}


@router.get("/deleted-accounts")
async def list_deleted_accounts(limit: int = 2000):
    return {"items": fetch_deleted_account_ids(limit=limit)}


@router.patch("/users/{user_id}/streak")
async def patch_user_streak(user_id: str, payload: Dict[str, Any]):
    row = update_user(user_id, {
        "data": payload,
        **{k: v for k, v in {
            "total_points": payload.get("totalPoints"),
            "level": payload.get("level"),
        }.items() if v is not None},
    })
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    streak_updates = {
        k: payload[k]
        for k in ("currentStreak", "longestStreak", "lastLoginAt")
        if k in payload
    }
    if streak_updates:
        current = row.get("data") or {}
        if not isinstance(current, dict):
            current = {}
        current.update(streak_updates)
        row = update_user(user_id, {"data": current}) or row
    return _snake_to_camel_user(row)


@router.post("/goals")
async def create_goal(payload: Dict[str, Any]):
    goal_id = str(payload.get("id") or payload.get("goalId") or uuid4().hex).strip()
    payload = {**payload, "id": goal_id, "goalId": goal_id}
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip() or None
    return _upsert_collection_row("goals", payload, row_id=goal_id, user_id=user_id)


@router.delete("/goals/{goal_id}")
async def delete_goal(goal_id: str):
    delete_where("goals", "id", goal_id)
    delete_where("milestones", "id", goal_id)
    return {"status": "ok"}


@router.get("/milestones")
async def get_milestones(goal_id: str | None = None, user_id: str | None = None, limit: int = 500):
    items = _select_collection_items(
        "milestones",
        limit=limit,
        predicate=lambda item: _match_item(item, user_id=user_id, goal_id=goal_id, include_actions=True),
    )
    if goal_id:
        items = [
            item for item in items
            if item.get("goalId") == goal_id or (item.get("payload") or {}).get("goalId") == goal_id
        ]
    return {"items": items}


@router.post("/milestones")
async def create_milestone(payload: Dict[str, Any]):
    milestone_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": milestone_id}
    goal_id = str(payload.get("goalId") or "").strip() or None
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip() or None
    return _upsert_collection_row("milestones", payload, row_id=milestone_id, user_id=user_id or goal_id)


@router.patch("/milestones/{milestone_id}")
async def patch_milestone(milestone_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("milestones", milestone_id, payload)


@router.delete("/milestones/{milestone_id}")
async def delete_milestone(milestone_id: str):
    delete_where("milestones", "id", milestone_id)
    return {"status": "ok"}


@router.get("/milestone-evidence")
async def get_milestone_evidence(
    goal_id: str | None = None,
    milestone_id: str | None = None,
    user_id: str | None = None,
    limit: int = 500,
):
    items = _select_collection_items(
        "milestone_evidence",
        limit=limit,
        predicate=lambda item: (
            (user_id is None or item.get("userId") == user_id)
            and (goal_id is None or item.get("goalId") == goal_id)
            and (milestone_id is None or item.get("milestoneId") == milestone_id)
        ),
    )
    return {"items": items}


@router.post("/milestone-evidence")
async def create_milestone_evidence(payload: Dict[str, Any]):
    item_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": item_id}
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip() or None
    return _upsert_collection_row("milestone_evidence", payload, row_id=item_id, user_id=user_id)


@router.patch("/milestone-evidence/{item_id}")
async def patch_milestone_evidence(item_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("milestone_evidence", item_id, payload)


@router.get("/evidence-files")
async def get_evidence_files(
    goal_id: str | None = None,
    audit_entry_id: str | None = None,
    user_id: str | None = None,
    limit: int = 500,
):
    items = _select_collection_items(
        "evidence_files",
        limit=limit,
        predicate=lambda item: (
            (user_id is None or item.get("userId") == user_id)
            and (goal_id is None or item.get("goalId") == goal_id)
            and (audit_entry_id is None or item.get("auditEntryId") == audit_entry_id)
        ),
    )
    return {"items": items}


@router.post("/evidence-files")
async def create_evidence_file(payload: Dict[str, Any]):
    item_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": item_id}
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip() or None
    return _upsert_collection_row("evidence_files", payload, row_id=item_id, user_id=user_id)


@router.patch("/evidence-files/{item_id}")
async def patch_evidence_file(item_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("evidence_files", item_id, payload)


@router.delete("/evidence-files/{item_id}")
async def delete_evidence_file(item_id: str):
    delete_where("evidence_files", "id", item_id)
    return {"status": "ok"}


@router.patch("/alerts/{user_id}/{alert_id}")
async def patch_alert(user_id: str, alert_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("alerts", alert_id, {**payload, "userId": user_id})


@router.patch("/alerts/{user_id}/batch")
async def patch_alerts_batch(user_id: str, payload: Dict[str, Any]):
    updates = payload.get("updates") or payload
    alert_ids = updates.get("alertIds") or updates.get("ids") or []
    patch_body = {k: v for k, v in updates.items() if k not in ("alertIds", "ids")}
    results = []
    for alert_id in alert_ids:
        results.append(_merge_collection_row("alerts", str(alert_id), {**patch_body, "userId": user_id}))
    if not alert_ids and updates.get("markAllRead"):
        items = _select_collection_items(
            "alerts",
            predicate=lambda item: item.get("userId") == user_id,
        )
        for item in items:
            aid = str(item.get("id") or "")
            if aid:
                results.append(_merge_collection_row("alerts", aid, {"isRead": True, "userId": user_id}))
    return {"items": results}


@router.get("/seasons")
async def get_seasons(
    user_id: str | None = None,
    status: str | None = None,
    season_id: str | None = None,
    limit: int = 200,
):
    items = _select_collection_items(
        "seasons",
        limit=limit,
        predicate=lambda item: (
            (season_id is None or item.get("id") == season_id)
            and (status is None or item.get("status") == status)
            and (user_id is None or user_id in (item.get("participantIds") or []) or item.get("managerId") == user_id)
        ),
    )
    return {"items": items}


@router.get("/seasons/{season_id}")
async def get_season(season_id: str):
    items = _select_collection_items(
        "seasons",
        predicate=lambda item: item.get("id") == season_id,
    )
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Season not found")
    return items[0]


@router.post("/seasons")
async def create_season(payload: Dict[str, Any]):
    season_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": season_id}
    user_id = str(payload.get("managerId") or payload.get("userId") or "").strip() or None
    return _upsert_collection_row("seasons", payload, row_id=season_id, user_id=user_id)


@router.patch("/seasons/{season_id}")
async def patch_season(season_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("seasons", season_id, payload)


@router.delete("/seasons/{season_id}")
async def delete_season(season_id: str):
    delete_where("seasons", "id", season_id)
    return {"status": "ok"}


@router.get("/one-on-one-meetings")
async def get_one_on_one_meetings(
    employee_id: str | None = None,
    manager_id: str | None = None,
    meeting_id: str | None = None,
    limit: int = 200,
):
    items = _select_collection_items(
        "one_on_one_meetings",
        limit=limit,
        predicate=lambda item: (
            (meeting_id is None or item.get("id") == meeting_id)
            and (employee_id is None or item.get("employeeId") == employee_id)
            and (manager_id is None or item.get("managerId") == manager_id)
        ),
    )
    return {"items": items}


@router.post("/one-on-one-meetings")
async def create_one_on_one_meeting(payload: Dict[str, Any]):
    meeting_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": meeting_id}
    user_id = str(payload.get("managerId") or payload.get("employeeId") or "").strip() or None
    return _upsert_collection_row("one_on_one_meetings", payload, row_id=meeting_id, user_id=user_id)


@router.patch("/one-on-one-meetings/{meeting_id}")
async def patch_one_on_one_meeting(meeting_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("one_on_one_meetings", meeting_id, payload)


@router.get("/manager-actions/{manager_id}")
async def get_manager_actions(manager_id: str, limit: int = 500):
    items = _select_collection_items(
        "manager_actions",
        limit=limit,
        predicate=lambda item: item.get("managerId") == manager_id,
    )
    return {"items": items}


@router.post("/manager-actions/{manager_id}")
async def create_manager_action(manager_id: str, payload: Dict[str, Any]):
    action_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": action_id, "managerId": manager_id}
    return _upsert_collection_row("manager_actions", payload, row_id=action_id, user_id=manager_id)


@router.get("/daily-activities/{user_id}")
async def get_daily_activities(user_id: str, limit: int = 400):
    items = _select_collection_items(
        "daily_activities",
        limit=limit,
        predicate=lambda item: item.get("userId") == user_id,
    )
    return {"items": items}


@router.post("/daily-activities/{user_id}")
async def create_daily_activity(user_id: str, payload: Dict[str, Any]):
    item_id = str(payload.get("id") or payload.get("dateKey") or uuid4().hex).strip()
    payload = {**payload, "id": item_id, "userId": user_id}
    return _upsert_collection_row("daily_activities", payload, row_id=item_id, user_id=user_id)


@router.patch("/daily-activities/{user_id}/{activity_id}")
async def patch_daily_activity(user_id: str, activity_id: str, payload: Dict[str, Any]):
    return _merge_collection_row("daily_activities", activity_id, {**payload, "userId": user_id})


@router.get("/goal-daily-progress")
async def get_goal_daily_progress(goal_id: str | None = None, user_id: str | None = None, limit: int = 500):
    items = _select_collection_items(
        "goal_daily_progress",
        limit=limit,
        predicate=lambda item: (
            (user_id is None or item.get("userId") == user_id)
            and (goal_id is None or item.get("goalId") == goal_id)
        ),
    )
    return {"items": items}


@router.post("/goal-daily-progress")
async def create_goal_daily_progress(payload: Dict[str, Any]):
    item_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": item_id}
    user_id = str(payload.get("userId") or "").strip() or None
    return _upsert_collection_row("goal_daily_progress", payload, row_id=item_id, user_id=user_id)


@router.get("/point-events")
async def get_point_events(user_id: str | None = None, limit: int = 500):
    items = _select_collection_items(
        "point_events",
        limit=limit,
        predicate=lambda item: user_id is None or item.get("userId") == user_id,
    )
    return {"items": items}


@router.post("/point-events")
async def create_point_event(payload: Dict[str, Any]):
    item_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": item_id}
    user_id = str(payload.get("userId") or "").strip() or None
    return _upsert_collection_row("point_events", payload, row_id=item_id, user_id=user_id)


@router.get("/collections/{collection_name}")
async def list_collection(
    collection_name: str,
    user_id: str | None = None,
    goal_id: str | None = None,
    status: str | None = None,
    action: str | None = None,
    include_actions: bool = False,
    limit: int = 500,
):
    name = _ensure_collection(collection_name)
    items = _select_collection_items(
        name,
        limit=limit,
        predicate=lambda item: _match_item(
            item,
            user_id=user_id,
            goal_id=goal_id,
            status=status,
            action=action,
            include_actions=include_actions,
        ),
    )
    return {"items": items}


@router.get("/collections/{collection_name}/{item_id}")
async def get_collection_item(collection_name: str, item_id: str):
    name = _ensure_collection(collection_name)
    items = _select_collection_items(
        name,
        predicate=lambda item: item.get("id") == item_id,
    )
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return items[0]


@router.post("/collections/{collection_name}")
async def create_collection_item(collection_name: str, payload: Dict[str, Any]):
    name = _ensure_collection(collection_name)
    item_id = str(payload.get("id") or uuid4().hex).strip()
    payload = {**payload, "id": item_id}
    user_id = str(payload.get("userId") or payload.get("user_id") or "").strip() or None
    return _upsert_collection_row(name, payload, row_id=item_id, user_id=user_id)


@router.patch("/collections/{collection_name}/{item_id}")
async def patch_collection_item(collection_name: str, item_id: str, payload: Dict[str, Any]):
    name = _ensure_collection(collection_name)
    return _merge_collection_row(name, item_id, payload)


@router.delete("/collections/{collection_name}/{item_id}")
async def delete_collection_item(collection_name: str, item_id: str):
    name = _ensure_collection(collection_name)
    delete_where(name, "id", item_id)
    return {"status": "ok"}
