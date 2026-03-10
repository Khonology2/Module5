# Manager Portal – Screens Overview

This document describes every screen in the **Manager Portal** of the Personal Development Hub (PDH). Use it to prepare demos for the CEO and stakeholders: what each screen contains, what it does, and how the features work.

---

## 1. Dashboard

**Route:** `/dashboard`  
**Sidebar label:** Dashboard

### What the screen has
- **Welcome card** – Time-based greeting (e.g. “Good morning, [Name]!”), manager photo, and short tagline.
- **Daily motivation card** – Rotating motivational message to set the tone for the day.
- **Quick actions** – Shortcuts to common tasks (e.g. Team Review, Manager IBox, Team Alerts).
- **Team KPIs** – High-level metrics: total team members, goals in progress, completed goals, overdue goals, average progress.
- **Team health** – Visual summary of how the team is doing (e.g. distribution of progress, risk indicators).
- **Activity summary** – Recent team activity (e.g. goal updates, completions).
- **Season progress alerts** – Notices related to the current growth season (e.g. deadlines, milestones).
- **Top performers** – Highlights for the top two performers (e.g. points, progress).

### What it can do
- Give the manager a single place to see team status at a glance.
- Navigate quickly to Team Review, Manager IBox, or Team Alerts via quick actions.
- Spot overdue goals, low progress, and season-related issues without opening other screens.

### How it works
- Data is loaded in real time from Firestore via `ManagerRealtimeService` (team members, goals, metrics).
- KPIs and team health are computed from the current list of employees and their goals.
- If the manager opens the portal outside the main app flow, they are redirected into the Manager Portal with the dashboard as the initial route. An optional sidebar tutorial can run on first visit.

---

## 2. Goal Workspace (My PDP)

**Route:** `/my_pdp`  
**Sidebar label:** Goal Workspace

### What the screen has
- **Personal development plan (PDP)** – The manager’s own goals, grouped by area (e.g. Operational, Customer, Financial, Organisational, People).
- **Goal cards** – Each goal shows title, category, progress, target date, and status.
- **Quick actions** – e.g. quick progress increment (e.g. +10%), view details, add evidence.
- **Excellence mapping** – Goals can be mapped to excellence areas (Operational, Customer, Financial, etc.) for alignment.

### What it can do
- Let the manager manage their **own** goals and PDP, same structure as employees.
- Update progress, view goal details, and link evidence.
- Keep the manager’s development visible and aligned to the same framework the team uses.

### How it works
- Goals are loaded from Firestore (top-level `goals` and user subcollection `users/{uid}/goals`).
- Progress updates and evidence use the same services as the employee experience (e.g. `DatabaseService`, evidence upload). The manager uses this screen for their personal goals, not for editing team members’ goals.

---

## 3. Manager IBox

**Route:** `/manager_inbox`  
**Sidebar label:** Manager IBox

### What the screen has
- **Unified inbox** – All manager-relevant items: alerts, approval requests, and nudges in one place.
- **Filters** – Type (All, Alerts, Approval requests, Nudges), Unread only, Priority, Audience (personal/team), and search by title/message.
- **Mark all as read** – One-click to mark all alerts as read.
- **Alert cards** – Each alert shows title, message, priority, date; optional actions (e.g. open goal, open badge, reschedule).
- **Approval request cards** – When type is “Approval requests”: goal title, employee, optional SMART rubric (Clarity, Measurability, Achievability, Relevance, Timeline) and notes; **Approve** and **Reject** actions.
- **Nudge feedback section** – When viewing nudges: employee replies and reactions to manager nudges, plus the list of manager nudge alerts.

### What it can do
- Central place to triage everything that needs manager attention.
- **Approve or reject** goal approval requests, with optional SMART review and notes.
- **Review nudge feedback** – See how employees reacted to nudges (e.g. “Helpful”, “Not now”, or free text).
- **Act on alerts** – Open linked goals, reschedule goals, or open badge details from alert actions.
- **Mark items read** – Individually or in bulk to keep the inbox manageable.

### How it works
- Alerts come from `AlertService.getUserAlertsStream(managerId)` (personal + team alerts).
- Filtering is in-memory: by type (alert vs `goalApprovalRequested` vs `managerNudge`), priority, audience, unread, and search text.
- Approve/Reject call `DatabaseService.approveGoal` / `rejectGoal` and may trigger notifications to the employee.
- Nudge feedback is read from a separate Firestore stream (e.g. nudge feedback collection), filtered by manager ID/name so only this manager’s nudges are shown.

---

## 4. Team Alerts & Nudges

**Route:** `/manager_alerts_nudges`  
**Sidebar label:** Team Alerts & Nudges

### What the screen has
- **Stats row** – Team-level counts (e.g. team size, pending approvals, overdue goals, alerts).
- **Filter bar** – Search, alert type (e.g. inactive, overdue, performance, risk), sort (newest, oldest, priority).
- **Alert sections** – Alerts grouped by severity, e.g.:
  - **Critical issues** – Urgent (e.g. overdue goals, serious risk).
  - **Performance concerns** – High/medium priority (e.g. low progress, inactivity).
  - **Monitoring** – Lower priority items to watch.
- **Alert cards** – Each shows employee, goal/context, priority, date; actions such as **View employee**, **Reschedule goal**, **Send nudge**.
- **Approvals tab/section** – List of goals this manager has already approved or rejected (view-only), with employee and goal details.
- **Reschedule goal** – Date picker and optional note; updates goal `targetDate` and sends a motivational alert to the employee.
- **Send nudge** – Open employee detail or send a check-in nudge that can earn manager badges (e.g. “Replan helped”).

### What it can do
- Focus on **supervision**: see all team alerts in one view and act on them.
- **Reschedule** overdue or at-risk goals and notify the employee.
- **Send nudges** and get credit toward manager badges (e.g. supporting replanning).
- **View employee** – Navigate to the employee detail screen for 1:1s or deeper actions.
- **Review past approvals** – See what was approved/rejected for accountability.

### How it works
- Combines the manager’s own alert stream with **team** alerts (e.g. from each team member’s recent alerts, overdue goals, inactivity).
- Reschedule updates the goal in Firestore and creates a motivational alert for the employee; optional logging for `ManagerBadgeEvaluator` (e.g. “Replan helped”).
- Nudges and approvals integrate with the same approval and badge services used elsewhere in the portal.

---

## 5. Team Challenges & Growth Seasons

**Route:** `/team_challenges_seasons`  
**Sidebar label:** Team Challenges

### What the screen has
- **Three tabs:**
  - **Active Seasons** – List of current growth seasons; join/leave; view season details (theme, dates, points, badges).
  - **Create Season** – Form to create a new season: name, theme, start/end dates, optional pause.
  - **Season History** – Past seasons with theme filter and “Paused only” toggle.
- **Season cards** – Theme, dates, status (active/paused/ended), and entry points to details or management.
- **Season details** – From here the manager can open full season view (e.g. `SeasonDetailsScreen`) or celebration (`SeasonCelebrationScreen`). Season management (e.g. pause/resume, edit) is available where implemented (`SeasonManagementScreen`).

### What it can do
- **See active seasons** – Which growth seasons are running and their themes.
- **Create a new season** – Define name, theme, and date range for a new team challenge.
- **Browse history** – Review past seasons, filter by theme or paused only.
- **Manage seasons** – Where supported, pause, resume, or adjust seasons.

### How it works
- Seasons are stored in Firestore (e.g. `seasons` or similar). `SeasonService` is used to fetch and create seasons.
- Active tab shows live data; Create Season writes a new document; History uses filters and date ranges. Manager-specific logic (e.g. “my department”) can be applied so they only see relevant seasons.

---

## 6. Team Review

**Route:** `/manager_review_team_dashboard`  
**Sidebar label:** Team Review

### What the screen has
- **Team overview** – Header and short intro to the team view.
- **Employee search** – Search by name or email; debounced; clear button; count (e.g. “X of Y employees”).
- **Employee list** – Cards per employee: name, photo/avatar, role/department, key metrics (e.g. goals in progress, completed, overdue, average progress, last activity).
- **AI Manager Insights** – Auto-generated insights, e.g.:
  - Overdue goals – “Schedule 1:1 to discuss blockers.”
  - Low progress – “Send nudge or offer resources.”
  - Inactive – “Reach out to check engagement.”
  - High performer – “Consider stretch goals or recognition.”
- **Per-employee actions** – **View details** (opens `ManagerEmployeeDetailScreen`), **Schedule 1:1** (opens 1:1 meeting flow).
- **Deep link** – Can open with `employeeId` and optional `meetingId` in route arguments to land directly on a specific employee or 1:1.

### What it can do
- **Scan the whole team** – See who is active, who is stuck, who is excelling.
- **Search** – Find an employee quickly by name or email.
- **Act on insights** – Use AI suggestions to decide who to nudge, who to meet with, and who to recognise.
- **Open employee detail** – Drill into one person’s goals, progress, and actions.
- **Schedule 1:1** – Start or open a one-on-one meeting (integrated with `OneOnOneMeetingService` and alerts).

### How it works
- Data comes from `ManagerRealtimeService.getTeamDataStream(department, timeFilter)` – real-time list of `EmployeeData` (profile, goals, metrics).
- Insights are computed in the app from that list (overdue count, average progress, days since activity, etc.) and sorted by priority (e.g. urgent → low).
- Employee detail and 1:1 scheduling use the same employee and meeting models and services used elsewhere in the manager flow.

---

## 7. Progress Visuals

**Route:** `/progress_visuals`  
**Sidebar label:** Progress Visuals

### What the screen has
- **Personal progress view** – When used as manager, the same layout as employees: profile summary, level, points, streaks.
- **Charts and trends** – e.g. daily progress over time, goal completion trend (“View trend” from goal or summary).
- **Goal-level progress** – Progress bars and optional trend per goal.
- **Streaks** – Current streak and streak history if the app exposes them here.
- **Badges** – Summary or link to badges earned.

### What it can do
- Let the manager see **their own** progress visuals (points, streaks, trends) in the same way employees do.
- Support “lead by example” – manager’s progress is visible in the same format as the team’s.
- Optional: if the screen has a team or compare mode in the future, it could show team-level visuals; currently it is the same personal view for manager and employee.

### How it works
- Uses `DatabaseService.getUserProfile` and a Firestore stream for the current user’s profile.
- Progress and streak data come from the same services as the employee side (e.g. `StreakService`, goal progress). Manager season points/badges may be synced via `SeasonService` so they appear correctly here.

---

## 8. Leaderboard

**Route:** `/manager_leaderboard`  
**Sidebar label:** Leaderboard

### What the screen has
- **Filters** – Time (This month / All time), metric (Points / Badges / Streaks), scope (My team / Organisation).
- **Ranked list** – Users ordered by the selected metric; shows rank, name, avatar, points/badges/streaks.
- **Current user highlight** – Manager’s own position is clearly marked.
- **Top 3 emphasis** – Podium or special styling for top three.

### What it can do
- **See team vs organisation** – “My team” restricts by department (from manager’s profile); “Organisation” shows everyone.
- **Switch metrics** – Compare on points, badges, or streaks.
- **Switch time** – This month vs all-time to balance current performance and long-term contribution.
- **Drive motivation** – Use leaderboard in conversations and team meetings.

### How it works
- Firestore query on `users` (and optionally onboarding/guest users). “My team” adds `where('department', isEqualTo: currentUser.department)`.
- Sorting and filtering (time window, metric) are applied in the app. Manager sees the same Leaderboard screen as employees; role only affects default filters or visibility (e.g. department) where configured.

---

## 9. Badges & Points

**Route:** `/manager_badges_points`  
**Sidebar label:** Badges & Points

### What the screen has
- **Manager points** – How points are earned: e.g. approvals (e.g. 10 pts), nudges/check-ins (e.g. 2 pts), high team completion bonus (e.g. 100 pts), engagement bonus (e.g. 50 pts). Exact weights are in the app constants.
- **Season points** – Current season total; synced from season metrics into the manager’s user document.
- **Badge categories** – Manager-specific categories, e.g. Leadership, Goals, Collaboration, Innovation, Community, Achievement.
- **Earned badges** – List/grid of badges the manager has earned; rarity (Common, Rare, Epic, Legendary) with distinct styling.
- **Badge celebration** – When a new manager badge is earned, a celebration dialog (and optional sound) appears; uncelebrated badges are fetched and shown once, then marked as celebrated.

### What it can do
- **Understand manager gamification** – See how approvals, nudges, and team outcomes translate into points and badges.
- **Track progress** – Current season points and list of earned badges.
- **Explore categories** – Open category detail (e.g. `ManagerBadgeCategoryDetailScreen`) to see criteria and next badges to earn.
- **Celebrate** – New badges trigger an in-app celebration for recognition.

### How it works
- Manager points are calculated from actions (approve/reject, nudges, team completion, engagement) and optionally synced to the user document; season points are synced via `SeasonService.syncCurrentManagerSeasonPoints()` and badges via `SeasonService.syncCurrentManagerSeasonBadges()`.
- Badges are stored in `users/{uid}/badges`; categories are migrated/defined via `BadgeService.migrateManagerBadgeCategories`. New badge writes are listened to so the celebration can run when the manager earns a badge (including when returning to the screen).

---

## 10. Repository & Audit

**Route:** `/repository_audit`  
**Sidebar label:** Repository & Audit

### What the screen has
- **Search and filters** – Search (e.g. completed goals, audit logs); filter by status (All, Verified, Pending, Rejected).
- **Role summary bar** – For managers: summary of verified/pending/rejected counts for their scope (e.g. department).
- **Audit entries list** – Entries from the audit service: goal title, user, date, status, evidence count. For managers: can show department-wide verified entries.
- **Milestone audit section** – Milestone-level verification and history (unified milestone audit).
- **Repository section** – Link or list of repository-backed goals and evidence (e.g. from `RepositoryService`).
- **Approved goals section** – Goals that have been approved; link to goal detail or audit trail.
- **Manager-specific** – Backfill of verified entries for the manager’s department; auto-sync of repository with verified audits.

### What it can do
- **Audit proof of work** – See which goals are verified, pending, or rejected and by whom.
- **Search and filter** – Find specific goals or statuses quickly.
- **Compliance and evidence** – Trace from goal → milestones → evidence and repository.
- **Department view** – Managers see their department’s verified/audit data where applicable.

### How it works
- Uses `ApprovedGoalAuditService`, `AuditService`, `RepositoryService`, `UnifiedMilestoneAudit`, and `RepositoryExportService`. Repository auto-sync is started on screen load and stopped on dispose.
- Backfill of verified entries runs once (e.g. on init): for managers, `RepositoryService.backfillVerifiedEntriesForDepartment(department)`; for employees, backfill for current user. List and filters are bound to this data and search/filter state.

---

## 11. My Profile (Manager Profile)

**Route:** `/manager_profile`  
**Sidebar label:** My Profile

### What the screen has
- **Profile photo** – Upload (e.g. via Cloudinary); displayed in header and elsewhere.
- **Basic info** – Full name, job title (e.g. Director, Manager, Developer, …), department (e.g. Management, Operations, Finance, HR, Sales), work email.
- **Skills & development** – Skills list, development areas, career aspirations, current projects, learning style, preferred development activities.
- **Goals** – Short-term and long-term goals (free text).
- **Notification preferences** – Frequency (e.g. daily), email/push toggles.
- **AI development plan** – Button to “Generate development plan” using Firebase AI; result is JSON (narrative, short/long-term goals, career vision, focus areas, strengths, recommended activities) and can be written into the profile or shown in a dialog.

### What it can do
- **Edit profile** – Update name, title, department, email, skills, aspirations, goals, and notification settings.
- **Upload photo** – Change profile picture (stored via Cloudinary, URL saved on profile).
- **Generate development plan** – One-click AI-generated plan that can be saved or copied into the profile fields.
- **Save** – Persist all changes to Firestore (`DatabaseService` / user document).

### How it works
- Load: `DatabaseService.getUserProfile(uid)` fills the form. Save: same service (or dedicated profile update method) writes back to `users/{uid}`. Photo upload uses `CloudinaryService`. AI plan uses Firebase AI with a system instruction that constrains the model to return JSON; the app parses it and maps fields to the profile or to a preview dialog.

---

## 12. Settings & Privacy

**Route:** `/settings`  
**Sidebar label:** Settings & Privacy

### What the screen has
- **Account** – Display name, email, photo; department/job title if exposed in settings.
- **Privacy & visibility** – e.g. Private goals, Manager only, Team share, Leaderboard participation, Profile visible.
- **Notifications** – Push, email, sound alerts, goal reminders, weekly reports.
- **Preferences** – Dark mode, speech recognition, celebration feed, auto-sync, language, time zone.
- **Security** – Tutorial on/off, two-factor auth, session timeout, biometric auth (where supported).
- **Data & export** – Export data (e.g. PDF), delete account or data (if implemented).
- **About** – App version, terms, privacy policy (if present).

### What it can do
- **Control visibility** – Who sees goals and profile; whether the manager appears on the leaderboard.
- **Control notifications** – How and how often the manager is notified.
- **Tune experience** – Language, theme, time zone, tutorial.
- **Security** – 2FA, session timeout, biometrics.
- **Export/delete** – Comply with data requests or self-service data export.

### How it works
- Settings are read and written via `SettingsService` (e.g. Firestore `users/{uid}/settings` or similar). Some values are cached in `SharedPreferences` for fast load. Toggles and dropdowns update the in-memory model and call the service to persist. Notifications and auth options hook into the app’s notification and auth code where implemented.

---

## 13. Manager Employee Detail (drill-down)

**Route:** Opened from Team Review, Team Alerts, or other screens; not a sidebar item.

### What the screen has
- **Header** – Employee name, job title, total points; back button.
- **Add Stretch Objective** – Button to add a stretch goal for this employee.
- **Approved goals list** – Only goals with status “Approved”; each as a tile with title, progress, target date, status.
- **Per-goal actions** – View goal detail, add/ review milestones, approve/reject if applicable, or open milestone review widget.

### What it can do
- **Focus on one person** – See all approved goals and progress for that employee.
- **Add stretch objective** – Create an additional goal for the employee (workflow may prompt for title, target date, etc.).
- **Open goal detail** – Navigate to full goal screen for evidence, milestones, or history.
- **Milestone review** – Use `ManagerMilestoneReviewWidget` to verify or comment on milestones.

### How it works
- Receives `EmployeeData employee` as a parameter. Goals are loaded from Firestore: top-level `goals` and `users/{uid}/goals`, merged and filtered to `GoalApprovalStatus.approved`. Stretch goal creation and milestone review use the same database and alert services as the rest of the manager flow.

---

## Quick reference: Sidebar order

| Order | Label             | Route                          |
|-------|-------------------|--------------------------------|
| 1     | Dashboard         | `/dashboard`                   |
| 2     | Goal Workspace    | `/my_pdp`                      |
| 3     | Manager IBox      | `/manager_inbox`               |
| 4     | Team Alerts & Nudges | `/manager_alerts_nudges`    |
| 5     | Team Challenges   | `/team_challenges_seasons`     |
| 6     | Team Review       | `/manager_review_team_dashboard` |
| 7     | Progress Visuals  | `/progress_visuals`            |
| 8     | Leaderboard       | `/manager_leaderboard`         |
| 9     | Badges & Points   | `/manager_badges_points`       |
| 10    | Repository & Audit| `/repository_audit`            |
| 11    | My Profile        | `/manager_profile`             |
| 12    | Settings & Privacy| `/settings`                    |

---

*This README reflects the Manager Portal as implemented in the codebase (sidebar config, routes, and screen behaviour). Use it to walk stakeholders through each screen and explain capabilities and data flow.*
