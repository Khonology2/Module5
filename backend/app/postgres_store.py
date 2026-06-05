"""
PostgreSQL connection, schema bootstrap, and lightweight data-access helpers.

The app uses PostgreSQL as the source of truth for user/onboarding data and
stores the rest of the application collections in JSON-backed tables so the
schema can be created automatically at startup.
"""

from __future__ import annotations

import json
import logging
from functools import lru_cache
from typing import Any, Dict, Iterable, Optional

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    create_engine,
    delete,
    func,
    select,
    text,
    update,
)
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings

logger = logging.getLogger(__name__)

metadata = MetaData()


def _utc_now_column(name: str = "created_at") -> Column:
    return Column(name, DateTime(timezone=True), server_default=func.now(), nullable=False)


users_table = Table(
    "users",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("user_id", String(255), nullable=False, unique=True, index=True),
    Column("email", String(320), nullable=True, index=True),
    Column("display_name", String(255), nullable=True),
    Column("photo_url", Text, nullable=True),
    Column("department", String(255), nullable=True),
    Column("job_title", String(255), nullable=True),
    Column("role", String(64), nullable=True, index=True),
    Column("private_goals", Boolean, nullable=False, server_default=text("false")),
    Column("manager_only", Boolean, nullable=False, server_default=text("false")),
    Column("team_share", Boolean, nullable=False, server_default=text("true")),
    Column("leaderboard_participation", Boolean, nullable=False, server_default=text("false")),
    Column("profile_visible", Boolean, nullable=False, server_default=text("true")),
    Column("push_notifications", Boolean, nullable=False, server_default=text("true")),
    Column("email_notifications", Boolean, nullable=False, server_default=text("true")),
    Column("sound_alerts", Boolean, nullable=False, server_default=text("true")),
    Column("goal_reminders", Boolean, nullable=False, server_default=text("true")),
    Column("weekly_reports", Boolean, nullable=False, server_default=text("false")),
    Column("dark_mode", Boolean, nullable=False, server_default=text("true")),
    Column("speech_recognition_enabled", Boolean, nullable=False, server_default=text("false")),
    Column("celebration_feed", Boolean, nullable=False, server_default=text("true")),
    Column("auto_sync", Boolean, nullable=False, server_default=text("true")),
    Column("language", String(16), nullable=False, server_default=text("'en'")),
    Column("time_zone", String(64), nullable=False, server_default=text("'UTC'")),
    Column("tutorial_enabled", Boolean, nullable=False, server_default=text("false")),
    Column("two_factor_auth", Boolean, nullable=False, server_default=text("false")),
    Column("session_timeout", Boolean, nullable=False, server_default=text("false")),
    Column("session_timeout_minutes", Integer, nullable=False, server_default=text("30")),
    Column("biometric_auth", Boolean, nullable=False, server_default=text("false")),
    Column("total_points", Integer, nullable=False, server_default=text("0")),
    Column("level", Integer, nullable=False, server_default=text("1")),
    Column("badges", JSON, nullable=False, server_default=text("'[]'::json")),
    Column("goal_visibility", String(32), nullable=False, server_default=text("'private'")),
    Column("notification_frequency", String(32), nullable=False, server_default=text("'daily'")),
    Column("celebration_consent", String(32), nullable=False, server_default=text("'private'")),
    Column("data", JSON, nullable=False, server_default=text("'{}'::json")),
    _utc_now_column(),
    Column("updated_at", DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False),
)

learning_tutorials_table = Table(
    "learning_tutorials",
    metadata,
    Column("id", String(255), primary_key=True),
    Column("manager_id", String(255), nullable=False, index=True),
    Column("title", Text, nullable=False),
    Column("description", Text, nullable=True),
    Column("video_url", Text, nullable=False),
    Column("provider", String(32), nullable=False, server_default=text("'udemy'")),
    Column("duration_minutes", Integer, nullable=True),
    Column("thumbnail_url", Text, nullable=True),
    Column("status", String(32), nullable=False, server_default=text("'active'"), index=True),
    Column("payload", JSON, nullable=False, server_default=text("'{}'::json")),
    _utc_now_column(),
    Column("updated_at", DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False),
)

learning_assignments_table = Table(
    "learning_assignments",
    metadata,
    Column("id", String(255), primary_key=True),
    Column("tutorial_id", String(255), nullable=False, index=True),
    Column("employee_user_id", String(255), nullable=False, index=True),
    Column("manager_id", String(255), nullable=False, index=True),
    Column("goal_id", String(255), nullable=True, index=True),
    Column("title", Text, nullable=False),
    Column("status", String(32), nullable=False, server_default=text("'assigned'"), index=True),
    Column("due_date", DateTime(timezone=True), nullable=True),
    Column("assigned_at", DateTime(timezone=True), server_default=func.now(), nullable=False),
    Column("completed_at", DateTime(timezone=True), nullable=True),
    Column("points", Integer, nullable=False, server_default=text("10")),
    Column("watch_progress", Integer, nullable=False, server_default=text("0")),
    Column("notes", Text, nullable=True),
    Column("payload", JSON, nullable=False, server_default=text("'{}'::json")),
    _utc_now_column(),
    Column("updated_at", DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False),
)

onboarding_table = Table(
    "onboarding",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("user_id", String(255), nullable=False, unique=True, index=True),
    Column("email", String(320), nullable=True, index=True),
    Column("display_name", String(255), nullable=True),
    Column("full_name", String(255), nullable=True),
    Column("first_name", String(255), nullable=True),
    Column("last_name", String(255), nullable=True),
    Column("module_access_role", Text, nullable=True),
    Column("module_role", Text, nullable=True),
    Column("role", String(64), nullable=True),
    Column("status", String(64), nullable=True, index=True),
    Column("theme", String(64), nullable=True),
    Column("data", JSON, nullable=False, server_default=text("'{}'::json")),
    _utc_now_column(),
    Column("updated_at", DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False),
)


def _generic_json_table(name: str) -> Table:
    return Table(
        name,
        metadata,
        Column("id", String(255), primary_key=True),
        Column("user_id", String(255), nullable=True, index=True),
        Column("email", String(320), nullable=True, index=True),
        Column("title", Text, nullable=True),
        Column("status", String(64), nullable=True, index=True),
        Column("payload", JSON, nullable=False, server_default=text("'{}'::json")),
        _utc_now_column(),
        Column("updated_at", DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False),
    )


COLLECTION_TABLE_NAMES = [
    "goals",
    "milestones",
    "goal_daily_progress",
    "activities",
    "daily_activities",
    "milestone_evidence",
    "badges",
    "alerts",
    "streaks",
    "point_events",
    "team_goals",
    "team_chat",
    "one_on_one_meetings",
    "audit_entries",
    "audit_errors",
    "approved_goals_audit",
    "audit_timelines",
    "repositories",
    "manager_actions",
    "manager_metrics",
    "deleted_accounts",
    "seasons",
    "evidence_files",
    "season_celebrations",
]

_GENERIC_TABLES: dict[str, Table] = {name: _generic_json_table(name) for name in COLLECTION_TABLE_NAMES}


def _build_database_url() -> str:
    settings = get_settings()
    host = (settings.postgres_host or "").strip()
    port = (settings.postgres_port or "").strip() or "5432"
    user = (settings.postgres_user or "").strip()
    password = (settings.postgres_password or "").strip()
    db = (settings.postgres_db or "").strip()
    missing = [name for name, value in [
        ("POSTGRES_HOST", host),
        ("POSTGRES_USER", user),
        ("POSTGRES_PASSWORD", password),
        ("POSTGRES_DB", db),
    ] if not value]
    if missing:
        raise ValueError(
            "Missing PostgreSQL environment variables: " + ", ".join(missing)
        )
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{db}"


@lru_cache(maxsize=1)
def get_engine() -> Engine:
    url = _build_database_url()
    return create_engine(
        url,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
        future=True,
    )


@lru_cache(maxsize=1)
def get_session_factory() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), expire_on_commit=False, future=True)


def init_postgres_schema() -> None:
    """
    Create all tables if they are missing.
    """
    try:
        engine = get_engine()
        metadata.create_all(engine)
        with engine.begin() as conn:
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_learning_tutorials_status_created "
                    "ON learning_tutorials (status, created_at DESC)"
                )
            )
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_learning_assignments_employee_assigned "
                    "ON learning_assignments (employee_user_id, assigned_at DESC)"
                )
            )
        logger.info("PostgreSQL schema ensured successfully")
    except SQLAlchemyError as exc:
        logger.error("Failed to initialize PostgreSQL schema: %s", exc)
        raise


def _row_to_dict(row: Any) -> Dict[str, Any]:
    if row is None:
        return {}
    mapping = dict(row._mapping)
    for key, value in list(mapping.items()):
        if isinstance(value, (dict, list)):
            continue
        if hasattr(value, "isoformat"):
            mapping[key] = value.isoformat()
    return mapping


def _coalesce_data(row: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("data") or row.get("payload") or {}
    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except Exception:
            payload = {}
    if not isinstance(payload, dict):
        payload = {}
    return {**payload, **row}


def fetch_onboarding_by_user_id(user_id: str) -> Optional[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(onboarding_table).where(onboarding_table.c.user_id == user_id).limit(1)
        row = session.execute(stmt).first()
        return _coalesce_data(_row_to_dict(row)) if row else None


def fetch_onboarding_by_email(email: str) -> Optional[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(onboarding_table).where(onboarding_table.c.email == email).limit(1)
        row = session.execute(stmt).first()
        return _coalesce_data(_row_to_dict(row)) if row else None


def fetch_onboarding_records(*, limit: int = 500) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(onboarding_table).limit(max(1, min(limit, 2000)))
        rows = session.execute(stmt).fetchall()
    return [_coalesce_data(_row_to_dict(row)) for row in rows]


def fetch_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(users_table).where(users_table.c.user_id == user_id).limit(1)
        row = session.execute(stmt).first()
        return _coalesce_data(_row_to_dict(row)) if row else None


def upsert_user(user_id: str, values: Dict[str, Any]) -> Dict[str, Any]:
    payload = {
        "user_id": user_id,
        **values,
    }
    with get_session_factory()() as session:
        stmt = pg_insert(users_table).values(**payload)
        update_values = {
            key: stmt.excluded[key]
            for key in payload.keys()
            if key != "user_id"
        }
        stmt = stmt.on_conflict_do_update(
            index_elements=[users_table.c.user_id],
            set_=update_values,
        ).returning(users_table)
        row = session.execute(stmt).first()
        session.commit()
        if row is None:
            return payload
        return _coalesce_data(_row_to_dict(row))


def update_user(user_id: str, values: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    if not values:
        return fetch_user_by_id(user_id)
    with get_session_factory()() as session:
        stmt = (
            update(users_table)
            .where(users_table.c.user_id == user_id)
            .values(**values)
            .returning(users_table)
        )
        row = session.execute(stmt).first()
        session.commit()
        return _coalesce_data(_row_to_dict(row)) if row else None


def upsert_onboarding(user_id: str, values: Dict[str, Any]) -> Dict[str, Any]:
    payload = {
        "user_id": user_id,
        **values,
    }
    with get_session_factory()() as session:
        stmt = pg_insert(onboarding_table).values(**payload)
        update_values = {
            key: stmt.excluded[key]
            for key in payload.keys()
            if key != "user_id"
        }
        stmt = stmt.on_conflict_do_update(
            index_elements=[onboarding_table.c.user_id],
            set_=update_values,
        ).returning(onboarding_table)
        row = session.execute(stmt).first()
        session.commit()
        if row is None:
            return payload
        return _coalesce_data(_row_to_dict(row))


def update_onboarding(user_id: str, values: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    if not values:
        return fetch_onboarding_by_user_id(user_id)
    with get_session_factory()() as session:
        stmt = (
            update(onboarding_table)
            .where(onboarding_table.c.user_id == user_id)
            .values(**values)
            .returning(onboarding_table)
        )
        row = session.execute(stmt).first()
        session.commit()
        return _coalesce_data(_row_to_dict(row)) if row else None


def delete_where(table_name: str, column_name: str, value: Any) -> int:
    table = _GENERIC_TABLES.get(table_name)
    if table is None:
        raise KeyError(f"Unknown collection table: {table_name}")
    if column_name not in table.c:
        raise KeyError(f"Unknown column {column_name} for table {table_name}")
    with get_session_factory()() as session:
        stmt = delete(table).where(table.c[column_name] == value)
        result = session.execute(stmt)
        session.commit()
        return int(result.rowcount or 0)


def list_generic_tables() -> Iterable[str]:
    return tuple(COLLECTION_TABLE_NAMES)


def fetch_users(
    *,
    role: str | None = None,
    department: str | None = None,
    limit: int = 500,
) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(users_table)
        if role:
            stmt = stmt.where(users_table.c.role == role)
        if department:
            stmt = stmt.where(users_table.c.department == department)
        stmt = stmt.limit(max(1, min(limit, 2000)))
        rows = session.execute(stmt).fetchall()
    return [_coalesce_data(_row_to_dict(row)) for row in rows]


def _learning_tutorial_to_api(
    row: Dict[str, Any],
    *,
    include_extra_payload: bool = True,
) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("payload") or {}
    if not isinstance(payload, dict):
        payload = {}
    base = {
        "id": row.get("id"),
        "managerId": row.get("manager_id"),
        "title": row.get("title"),
        "description": row.get("description"),
        "videoUrl": row.get("video_url"),
        "provider": row.get("provider"),
        "durationMinutes": row.get("duration_minutes"),
        "thumbnailUrl": row.get("thumbnail_url"),
        "status": row.get("status"),
        "createdAt": _iso_value(row.get("created_at")),
        "updatedAt": _iso_value(row.get("updated_at")),
    }
    if include_extra_payload:
        return {**payload, **base}
    return base


def _learning_assignment_to_api(row: Dict[str, Any]) -> Dict[str, Any]:
    if not row:
        return {}
    payload = row.get("payload") or {}
    if not isinstance(payload, dict):
        payload = {}
    return {
        **payload,
        "id": row.get("id"),
        "tutorialId": row.get("tutorial_id"),
        "employeeUserId": row.get("employee_user_id"),
        "managerId": row.get("manager_id"),
        "goalId": row.get("goal_id"),
        "title": row.get("title"),
        "status": row.get("status"),
        "dueDate": _iso_value(row.get("due_date")),
        "assignedAt": _iso_value(row.get("assigned_at")),
        "completedAt": _iso_value(row.get("completed_at")),
        "points": row.get("points"),
        "watchProgress": row.get("watch_progress"),
        "notes": row.get("notes"),
        "createdAt": _iso_value(row.get("created_at")),
        "updatedAt": _iso_value(row.get("updated_at")),
    }


def _iso_value(value: Any) -> Any:
    if hasattr(value, "isoformat"):
        return value.isoformat()
    if isinstance(value, list):
        return [_iso_value(item) for item in value]
    if isinstance(value, dict):
        return {key: _iso_value(item) for key, item in value.items()}
    return value


def fetch_learning_tutorial_by_id(tutorial_id: str) -> Optional[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(learning_tutorials_table).where(
            learning_tutorials_table.c.id == tutorial_id
        ).limit(1)
        row = session.execute(stmt).first()
        return _row_to_dict(row) if row else None


def fetch_learning_tutorials_by_manager(
    manager_id: str,
    *,
    status: str | None = None,
    limit: int = 500,
) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(learning_tutorials_table).where(
            learning_tutorials_table.c.manager_id == manager_id
        )
        if status:
            stmt = stmt.where(learning_tutorials_table.c.status == status)
        stmt = stmt.order_by(learning_tutorials_table.c.created_at.desc()).limit(
            max(1, min(limit, 2000))
        )
        rows = session.execute(stmt).fetchall()
    return [_row_to_dict(row) for row in rows]


def fetch_learning_tutorials(
    *,
    status: str | None = None,
    limit: int = 500,
) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(learning_tutorials_table)
        if status:
            stmt = stmt.where(learning_tutorials_table.c.status == status)
        stmt = stmt.order_by(learning_tutorials_table.c.created_at.desc()).limit(
            max(1, min(limit, 2000))
        )
        rows = session.execute(stmt).fetchall()
    return [_row_to_dict(row) for row in rows]


def fetch_learning_tutorials_by_ids(
    tutorial_ids: Iterable[str],
) -> list[Dict[str, Any]]:
    ids = [str(tid).strip() for tid in tutorial_ids if tid]
    if not ids:
        return []
    with get_session_factory()() as session:
        stmt = select(learning_tutorials_table).where(
            learning_tutorials_table.c.id.in_(ids)
        )
        rows = session.execute(stmt).fetchall()
    return [_row_to_dict(row) for row in rows]


def fetch_learning_employee_feed(
    employee_user_id: str,
    *,
    limit: int = 500,
) -> tuple[list[Dict[str, Any]], list[Dict[str, Any]]]:
    """Active tutorials + employee assignments in one DB session (two queries)."""
    cap = max(1, min(limit, 2000))
    with get_session_factory()() as session:
        tutorial_stmt = (
            select(learning_tutorials_table)
            .where(learning_tutorials_table.c.status == "active")
            .order_by(learning_tutorials_table.c.created_at.desc())
            .limit(cap)
        )
        tutorials = [
            _row_to_dict(row) for row in session.execute(tutorial_stmt).fetchall()
        ]

        assignment_stmt = (
            select(learning_assignments_table)
            .where(
                learning_assignments_table.c.employee_user_id == employee_user_id
            )
            .order_by(learning_assignments_table.c.assigned_at.desc())
            .limit(cap)
        )
        assignments = [
            _row_to_dict(row) for row in session.execute(assignment_stmt).fetchall()
        ]
    return tutorials, assignments


def upsert_learning_tutorial(tutorial_id: str, values: Dict[str, Any]) -> Dict[str, Any]:
    payload = {"id": tutorial_id, **values}
    with get_session_factory()() as session:
        stmt = pg_insert(learning_tutorials_table).values(**payload)
        update_values = {
            key: stmt.excluded[key]
            for key in payload.keys()
            if key != "id"
        }
        stmt = stmt.on_conflict_do_update(
            index_elements=[learning_tutorials_table.c.id],
            set_=update_values,
        ).returning(learning_tutorials_table)
        row = session.execute(stmt).first()
        session.commit()
        return _row_to_dict(row) if row else payload


def update_learning_tutorial(
    tutorial_id: str,
    values: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    if not values:
        return fetch_learning_tutorial_by_id(tutorial_id)
    with get_session_factory()() as session:
        stmt = (
            update(learning_tutorials_table)
            .where(learning_tutorials_table.c.id == tutorial_id)
            .values(**values)
            .returning(learning_tutorials_table)
        )
        row = session.execute(stmt).first()
        session.commit()
        return _row_to_dict(row) if row else None


def fetch_learning_assignments(
    *,
    manager_id: str | None = None,
    employee_user_id: str | None = None,
    status: str | None = None,
    limit: int = 500,
) -> list[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(learning_assignments_table)
        if manager_id:
            stmt = stmt.where(learning_assignments_table.c.manager_id == manager_id)
        if employee_user_id:
            stmt = stmt.where(
                learning_assignments_table.c.employee_user_id == employee_user_id
            )
        if status:
            stmt = stmt.where(learning_assignments_table.c.status == status)
        stmt = stmt.order_by(learning_assignments_table.c.assigned_at.desc()).limit(
            max(1, min(limit, 2000))
        )
        rows = session.execute(stmt).fetchall()
    return [_row_to_dict(row) for row in rows]


def fetch_learning_assignment_by_id(assignment_id: str) -> Optional[Dict[str, Any]]:
    with get_session_factory()() as session:
        stmt = select(learning_assignments_table).where(
            learning_assignments_table.c.id == assignment_id
        ).limit(1)
        row = session.execute(stmt).first()
        return _row_to_dict(row) if row else None


def upsert_learning_assignment(assignment_id: str, values: Dict[str, Any]) -> Dict[str, Any]:
    payload = {"id": assignment_id, **values}
    with get_session_factory()() as session:
        stmt = pg_insert(learning_assignments_table).values(**payload)
        update_values = {
            key: stmt.excluded[key]
            for key in payload.keys()
            if key != "id"
        }
        stmt = stmt.on_conflict_do_update(
            index_elements=[learning_assignments_table.c.id],
            set_=update_values,
        ).returning(learning_assignments_table)
        row = session.execute(stmt).first()
        session.commit()
        return _row_to_dict(row) if row else payload


def update_learning_assignment(
    assignment_id: str,
    values: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    if not values:
        return fetch_learning_assignment_by_id(assignment_id)
    with get_session_factory()() as session:
        stmt = (
            update(learning_assignments_table)
            .where(learning_assignments_table.c.id == assignment_id)
            .values(**values)
            .returning(learning_assignments_table)
        )
        row = session.execute(stmt).first()
        session.commit()
        return _row_to_dict(row) if row else None


def fetch_deleted_account_ids(limit: int = 2000) -> list[str]:
    table = _GENERIC_TABLES.get("deleted_accounts")
    if table is None:
        return []
    with get_session_factory()() as session:
        rows = session.execute(table.select().limit(max(1, min(limit, 5000)))).fetchall()
    ids: list[str] = []
    for row in rows:
        mapping = dict(row._mapping)
        payload = mapping.get("payload") or {}
        if isinstance(payload, dict):
            uid = payload.get("userId") or payload.get("user_id") or mapping.get("user_id")
            if uid:
                ids.append(str(uid))
        elif mapping.get("user_id"):
            ids.append(str(mapping["user_id"]))
        elif mapping.get("id"):
            ids.append(str(mapping["id"]))
    return ids

