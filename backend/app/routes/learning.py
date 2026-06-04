"""
Learning tutorials and assignments for manager-assigned Udemy-style training.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query, status

from app.postgres_store import (
    _learning_assignment_to_api,
    _learning_tutorial_to_api,
    fetch_learning_assignment_by_id,
    fetch_learning_assignments,
    fetch_learning_tutorial_by_id,
    fetch_learning_tutorials_by_manager,
    update_learning_assignment,
    update_learning_tutorial,
    upsert_learning_assignment,
    upsert_learning_tutorial,
)
from app.routes.users import _upsert_collection_row

logger = logging.getLogger(__name__)

router = APIRouter(tags=["learning"])


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    raw = str(value).strip()
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _camel_tutorial_payload(body: Dict[str, Any], manager_id: str) -> Dict[str, Any]:
    extra = body.get("payload") if isinstance(body.get("payload"), dict) else {}
    return {
        "manager_id": manager_id,
        "title": (body.get("title") or "").strip(),
        "description": (body.get("description") or "").strip() or None,
        "video_url": (body.get("videoUrl") or body.get("video_url") or "").strip(),
        "provider": (body.get("provider") or "udemy").strip() or "udemy",
        "duration_minutes": body.get("durationMinutes") or body.get("duration_minutes"),
        "thumbnail_url": body.get("thumbnailUrl") or body.get("thumbnail_url"),
        "status": (body.get("status") or "active").strip() or "active",
        "payload": {**extra, **{k: v for k, v in body.items() if k not in {
            "title", "description", "videoUrl", "video_url", "provider",
            "durationMinutes", "duration_minutes", "thumbnailUrl", "thumbnail_url",
            "status", "managerId", "manager_id", "id", "payload",
        }}},
    }


@router.get("/learning-manager-dashboard")
def get_learning_manager_dashboard(
    manager_id: str = Query(..., min_length=1),
    limit: int = 500,
):
    """Single round-trip for manager learning screen (tutorials + assignments)."""
    tutorials = fetch_learning_tutorials_by_manager(manager_id, limit=limit)
    assignments = fetch_learning_assignments(manager_id=manager_id, limit=limit)
    return {
        "tutorials": [_learning_tutorial_to_api(row) for row in tutorials],
        "assignments": [_learning_assignment_to_api(row) for row in assignments],
    }


@router.get("/learning-tutorials")
def list_learning_tutorials(
    manager_id: str = Query(..., min_length=1),
    status: str | None = None,
    limit: int = 500,
):
    rows = fetch_learning_tutorials_by_manager(manager_id, status=status, limit=limit)
    items = [_learning_tutorial_to_api(row) for row in rows]
    return {"items": items}


@router.post("/learning-tutorials", status_code=status.HTTP_201_CREATED)
def create_learning_tutorial(payload: Dict[str, Any]):
    manager_id = str(
        payload.get("managerId") or payload.get("manager_id") or ""
    ).strip()
    if not manager_id:
        raise HTTPException(status_code=400, detail="managerId is required")

    title = (payload.get("title") or "").strip()
    video_url = (payload.get("videoUrl") or payload.get("video_url") or "").strip()
    if not title:
        raise HTTPException(status_code=400, detail="title is required")
    if not video_url:
        raise HTTPException(status_code=400, detail="videoUrl is required")

    tutorial_id = str(payload.get("id") or uuid4().hex).strip()
    row = upsert_learning_tutorial(tutorial_id, _camel_tutorial_payload(payload, manager_id))
    return _learning_tutorial_to_api(row)


@router.get("/learning-tutorials/{tutorial_id}")
def get_learning_tutorial(tutorial_id: str):
    row = fetch_learning_tutorial_by_id(tutorial_id)
    if not row:
        raise HTTPException(status_code=404, detail="Tutorial not found")
    return _learning_tutorial_to_api(row)


@router.patch("/learning-tutorials/{tutorial_id}")
def patch_learning_tutorial(tutorial_id: str, payload: Dict[str, Any]):
    existing = fetch_learning_tutorial_by_id(tutorial_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Tutorial not found")

    manager_id = str(
        payload.get("managerId")
        or payload.get("manager_id")
        or existing.get("manager_id")
        or ""
    ).strip()
    if existing.get("manager_id") != manager_id and (
        payload.get("managerId") or payload.get("manager_id")
    ):
        raise HTTPException(status_code=403, detail="Cannot change tutorial owner")

    updates: Dict[str, Any] = {}
    if "title" in payload:
        updates["title"] = str(payload["title"]).strip()
    if "description" in payload:
        updates["description"] = str(payload["description"]).strip() or None
    if "videoUrl" in payload or "video_url" in payload:
        updates["video_url"] = str(
            payload.get("videoUrl") or payload.get("video_url") or ""
        ).strip()
    if "durationMinutes" in payload or "duration_minutes" in payload:
        updates["duration_minutes"] = (
            payload.get("durationMinutes") or payload.get("duration_minutes")
        )
    if "thumbnailUrl" in payload or "thumbnail_url" in payload:
        updates["thumbnail_url"] = (
            payload.get("thumbnailUrl") or payload.get("thumbnail_url")
        )
    if "status" in payload:
        updates["status"] = str(payload["status"]).strip()

    row = update_learning_tutorial(tutorial_id, updates)
    if not row:
        raise HTTPException(status_code=404, detail="Tutorial not found")
    return _learning_tutorial_to_api(row)


def _enrich_assignment_with_tutorial(item: Dict[str, Any]) -> Dict[str, Any]:
    tutorial_id = item.get("tutorialId")
    if not tutorial_id:
        return item
    tutorial = fetch_learning_tutorial_by_id(str(tutorial_id))
    if not tutorial:
        return item
    api_tutorial = _learning_tutorial_to_api(tutorial)
    return {
        **item,
        "videoUrl": api_tutorial.get("videoUrl"),
        "tutorialTitle": api_tutorial.get("title"),
        "tutorialDescription": api_tutorial.get("description"),
        "durationMinutes": api_tutorial.get("durationMinutes"),
    }


@router.get("/learning-assignments")
def list_learning_assignments(
    manager_id: str | None = None,
    employee_user_id: str | None = None,
    status: str | None = None,
    limit: int = 500,
    enrich_tutorial: bool = False,
):
    if not manager_id and not employee_user_id:
        raise HTTPException(
            status_code=400,
            detail="manager_id or employee_user_id is required",
        )
    rows = fetch_learning_assignments(
        manager_id=manager_id,
        employee_user_id=employee_user_id,
        status=status,
        limit=limit,
    )
    items = [_learning_assignment_to_api(row) for row in rows]
    if enrich_tutorial:
        items = [_enrich_assignment_with_tutorial(item) for item in items]
    return {"items": items}


def _create_linked_goal_and_alert(
    *,
    assignment_id: str,
    tutorial: Dict[str, Any],
    employee_user_id: str,
    manager_id: str,
    due_date: datetime | None,
    points: int,
    notes: str | None,
) -> str:
    goal_id = uuid4().hex
    title = (tutorial.get("title") or "Learning tutorial").strip()
    video_url = (tutorial.get("video_url") or "").strip()
    description_parts = [
        tutorial.get("description") or "",
        f"Watch: {video_url}" if video_url else "",
    ]
    if notes:
        description_parts.append(f"Manager note: {notes}")
    description = "\n\n".join(p for p in description_parts if p).strip()

    target_iso = (
        due_date.isoformat()
        if due_date
        else datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        ).isoformat()
    )

    goal_payload: Dict[str, Any] = {
        "id": goal_id,
        "goalId": goal_id,
        "userId": employee_user_id,
        "title": title,
        "description": description,
        "category": "learning",
        "priority": "medium",
        "status": "notStarted",
        "progress": 0,
        "points": points,
        "targetDate": target_iso,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "approvalStatus": "approved",
        "approvedByUserId": manager_id,
        "goalType": "udemy_learning",
        "learningAssignmentId": assignment_id,
        "tutorialId": tutorial.get("id"),
        "videoUrl": video_url,
        "isSeasonGoal": False,
    }
    _upsert_collection_row("goals", goal_payload, row_id=goal_id, user_id=employee_user_id)

    alert_payload: Dict[str, Any] = {
        "type": "goalCreated",
        "audience": "personal",
        "priority": "high",
        "title": "New learning assignment",
        "message": f'Your manager assigned you to complete: "{title}".',
        "actionText": "View Goal",
        "actionRoute": "/my_pdp",
        "actionData": {"goalId": goal_id, "learningAssignmentId": assignment_id},
        "relatedGoalId": goal_id,
        "fromUserId": manager_id,
        "isRead": False,
        "isDismissed": False,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "expiresAt": (
            due_date.isoformat()
            if due_date
            else datetime.now(timezone.utc).replace(
                day=datetime.now(timezone.utc).day + 14
            ).isoformat()
        ),
    }
    _upsert_collection_row("alerts", alert_payload, user_id=employee_user_id)
    return goal_id


@router.post("/learning-assignments", status_code=status.HTTP_201_CREATED)
def create_learning_assignment(payload: Dict[str, Any]):
    manager_id = str(
        payload.get("managerId") or payload.get("manager_id") or ""
    ).strip()
    employee_user_id = str(
        payload.get("employeeUserId") or payload.get("employee_user_id") or ""
    ).strip()
    tutorial_id = str(
        payload.get("tutorialId") or payload.get("tutorial_id") or ""
    ).strip()

    if not manager_id:
        raise HTTPException(status_code=400, detail="managerId is required")
    if not employee_user_id:
        raise HTTPException(status_code=400, detail="employeeUserId is required")
    if not tutorial_id:
        raise HTTPException(status_code=400, detail="tutorialId is required")

    tutorial = fetch_learning_tutorial_by_id(tutorial_id)
    if not tutorial:
        raise HTTPException(status_code=404, detail="Tutorial not found")
    if tutorial.get("manager_id") != manager_id:
        raise HTTPException(status_code=403, detail="Tutorial does not belong to manager")

    due_date = _parse_dt(payload.get("dueDate") or payload.get("due_date"))
    points_raw = payload.get("points", 10)
    try:
        points = int(points_raw)
    except (TypeError, ValueError):
        points = 10

    assignment_id = str(payload.get("id") or uuid4().hex).strip()
    title = (payload.get("title") or tutorial.get("title") or "Learning assignment").strip()
    notes = (payload.get("notes") or "").strip() or None

    assignment_row = upsert_learning_assignment(
        assignment_id,
        {
            "tutorial_id": tutorial_id,
            "employee_user_id": employee_user_id,
            "manager_id": manager_id,
            "title": title,
            "status": "assigned",
            "due_date": due_date,
            "assigned_at": datetime.now(timezone.utc),
            "points": points,
            "watch_progress": 0,
            "notes": notes,
            "payload": {},
        },
    )

    try:
        goal_id = _create_linked_goal_and_alert(
            assignment_id=assignment_id,
            tutorial=tutorial,
            employee_user_id=employee_user_id,
            manager_id=manager_id,
            due_date=due_date,
            points=points,
            notes=notes,
        )
        assignment_row = update_learning_assignment(
            assignment_id,
            {"goal_id": goal_id},
        ) or assignment_row
    except Exception as exc:
        logger.error("Failed to create linked goal/alert for assignment %s: %s", assignment_id, exc)
        raise HTTPException(
            status_code=500,
            detail="Assignment saved but failed to create linked goal or alert",
        ) from exc

    return _learning_assignment_to_api(assignment_row or {})


@router.patch("/learning-assignments/{assignment_id}")
def patch_learning_assignment(assignment_id: str, payload: Dict[str, Any]):
    existing = fetch_learning_assignment_by_id(assignment_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Assignment not found")

    actor_id = str(
        payload.get("employeeUserId")
        or payload.get("employee_user_id")
        or ""
    ).strip()
    if actor_id and existing.get("employee_user_id") != actor_id:
        raise HTTPException(status_code=403, detail="Not allowed to update this assignment")

    updates: Dict[str, Any] = {}
    if "status" in payload:
        updates["status"] = str(payload["status"]).strip()
        if updates["status"] == "completed":
            updates["completed_at"] = datetime.now(timezone.utc)
    if "watchProgress" in payload or "watch_progress" in payload:
        raw = payload.get("watchProgress", payload.get("watch_progress"))
        try:
            updates["watch_progress"] = max(0, min(100, int(raw)))
        except (TypeError, ValueError):
            pass
    if "notes" in payload:
        updates["notes"] = str(payload["notes"]).strip() or None
    if "dueDate" in payload or "due_date" in payload:
        updates["due_date"] = _parse_dt(
            payload.get("dueDate") or payload.get("due_date")
        )

    row = update_learning_assignment(assignment_id, updates)
    if not row:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return _learning_assignment_to_api(row)
