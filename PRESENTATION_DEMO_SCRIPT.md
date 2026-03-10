# Personal Development Hub — Full Demo Presentation Script

**Audience:** Mixed (technical + non-technical)  
**Duration:** ~1 hour  
**Format:** Live demo with talking points

---

## 0–5 min: Welcome & one-line pitch

- **Who you are**
  - “Hi, I’m [Name], and over the last [X] months I’ve been building the Personal Development Hub.”

- **One-line description**
  - “Personal Development Hub is an app that helps teams set clear goals, approve them, and track progress, so managers and employees stay aligned.”

- **Set expectations**
  - “In this session I’ll quickly explain the problem, then spend most of the time showing you how the app works—every employee screen and every manager screen—and finally I’ll give a short technical overview.”

---

## 5–15 min: Problem & vision (for everyone)

- **Describe the problem in simple terms**
  - “Most teams struggle with personal development goals: goals are vague, buried in documents, and managers only review them once or twice a year.”
  - “Employees don’t know if their goals are ‘good enough’, and managers spend a lot of time chasing updates.”

- **What people do today**
  - “Today this lives in spreadsheets, emails, and generic to‑do apps. Nothing is designed specifically for structured goal setting and approval.”

- **Your vision**
  - “Our vision: a shared space where employees and managers can create, approve, and track development goals in a structured, transparent way.”

---

## 15–30 min: Demo — Employee experience (all screens + functions)

**Set the scenario:** “I’m an employee, Thandi, who wants to improve my project management skills this quarter. I’ll walk through every screen an employee uses.”

---

### Employee Screen 1: **Login / Sign-in** (`/sign_in`)

- **Function:** Authenticate and enter the app; role (employee/manager) is determined after login.
- **What to show:** Sign in with email or Google; land on the correct portal (employee dashboard) based on role.
- **Say:** “Employees sign in here. The app detects my role and sends me to the Employee Portal.”

---

### Employee Screen 2: **Employee Dashboard** (`/employee_dashboard`)

- **Function:** Central hub showing key metrics (active goals, completed goals, points, current streak, today’s activity, badges), quick links to goals and profile, and upcoming deadlines.
- **What to show:** KPI cards, list of recent/upcoming goals, profile completion banner if any, navigation to Goal Workspace and My PDP.
- **Say:** “This is my home screen. I see how many goals I have, my streak, points, and badges. I can jump straight to my goals or create new ones.”

---

### Employee Screen 3: **Goal Workspace / My PDP** (`/my_pdp`)

- **Function:** View and manage personal development plan by KPA (e.g. Operational, Customer, Financial, People). Lists goals per category, supports creating/editing goals and submitting for approval; shows approval status.
- **What to show:** Expandable sections by KPA, list of goals per section, status (draft, pending, approved, completed), “Create goal” or “Add goal” flow from here or via My PDP.
- **Say:** “My PDP is where I see all my goals grouped by area—operational, customer, financial, people. I can see what’s pending approval and what’s already approved.”

---

### Employee Screen 4: **My Goal Workspace** (`/my_goal_workspace`)

- **Function:** Create and edit goals with full form: title, description, category, KPA, start/target dates, success metrics, dependencies; optional AI-assisted SMART scoring; submit for manager approval.
- **What to show:** Full goal form, date pickers, category/KPA dropdowns, success metrics, “Submit for approval” button.
- **Say:** “When I tap to create a goal, I get this workspace. I add a title—e.g. ‘Complete a project management certification by end of Q2’—description, deadline, and clear success criteria. I can optionally use AI to score how SMART the goal is, then submit for approval. My manager will see it in their queue.”

---

### Employee Screen 5: **Goal Detail** (from dashboard or My PDP → open a goal)

- **Function:** View a single goal in full: details, milestones, evidence, approval status; update progress; add milestones/evidence; submit for approval if still draft; see manager feedback if sent back.
- **What to show:** Full goal view, status badge (Pending/Approved/Completed), progress, milestones, “Submit for approval” or “Update progress”.
- **Say:** “From the dashboard or My PDP I open a goal. Here I see everything: status, criteria, and I can update progress or add evidence. If I just submitted it, it shows Pending until my manager approves.”

---

### Employee Screen 6: **Alerts & Nudges** (`/alerts_nudges`)

- **Function:** See personal alerts and nudges: deadline reminders, goal-at-risk alerts, 1:1 meeting reminders, predictive risks; act on them (e.g. open goal, schedule 1:1).
- **What to show:** List of alerts, filters if any, tapping an alert opens the related goal or meeting.
- **Say:** “This screen keeps me on track. I get reminders for deadlines and goals at risk, and prompts to schedule 1:1s with my manager so nothing slips.”

---

### Employee Screen 7: **Progress Visuals** (`/progress_visuals`)

- **Function:** Visualize progress over time: charts (e.g. goal completion, activity), trends, streaks; compare to team or benchmarks if available.
- **What to show:** Charts, progress over time, any “view trend” or comparison views.
- **Say:** “Progress Visuals show how I’m doing over time—completion rates, activity, streaks—so I can see if I’m on track or need to adjust.”

---

### Employee Screen 8: **Badges & Points** (`/badges_points`)

- **Function:** View earned badges and points; see badge categories and what’s needed to unlock more; gamification summary.
- **What to show:** Badge list, points total, categories or rarity.
- **Say:** “Here I see the badges I’ve earned and my points. It shows what I’ve achieved and what I can aim for next.”

---

### Employee Screen 9: **Season Challenges** (`/season_challenges`)

- **Function:** View active season challenges and goals; join or track progress on seasonal objectives.
- **What to show:** List of seasons/challenges, progress on season goals.
- **Say:** “Season Challenges show time-bound team or company challenges. I can see what’s active and how I’m doing against them.”

---

### Employee Screen 10: **Leaderboard** (`/leaderboard`)

- **Function:** See ranking by points or activity (e.g. team or org leaderboard); optional filters.
- **What to show:** Leaderboard list, own position.
- **Say:** “The leaderboard shows how I rank with my colleagues on points or activity—adds a bit of healthy competition.”

---

### Employee Screen 11: **Repository & Audit** (`/repository_audit`)

- **Function:** Access evidence repository and audit trail: documents/evidence linked to goals and milestones; audit log of changes for transparency.
- **What to show:** List of evidence/repository items and/or audit entries.
- **Say:** “Repository & Audit is where I find evidence I’ve uploaded for goals and a history of changes—useful for reviews and compliance.”

---

### Employee Screen 12: **My Profile** (`/my_profile`)

- **Function:** View and edit personal profile (name, photo, role, department, etc.); profile completion; used for display in goals and manager views.
- **What to show:** Profile form, photo, completion state.
- **Say:** “My Profile holds my details. Keeping it up to date helps my manager and the system show the right information everywhere.”

---

### Employee Screen 13: **Settings & Privacy** (`/settings`)

- **Function:** App settings, notifications, privacy preferences, account/logout.
- **What to show:** Settings list, notification toggles, logout.
- **Say:** “Here I control notifications and privacy and can sign out.”

---

### Employee flow summary (what to say)

- “For employees, the flow is: **Dashboard** → **Goal Workspace / My PDP** to see all goals → **My Goal Workspace** to create a new goal with clear criteria → **Goal Detail** to track and submit for approval. **Alerts & Nudges**, **Progress Visuals**, **Badges & Points**, and **Leaderboard** keep them engaged and informed.”

---

## 30–45 min: Demo — Manager workflows (all screens + functions)

**Set the scenario:** “Now I switch to the manager view. I’m the manager of a small team and need to review and approve goals and support my team. I’ll show every manager screen.”

---

### Manager Screen 1: **Manager login / role switch**

- **Function:** Same login; app shows manager portal and manager sidebar based on role.
- **What to show:** Log in as manager (or switch account), land on Manager Dashboard.
- **Say:** “Managers use the same login. The app recognizes my role and shows the Manager Portal with team-focused screens.”

---

### Manager Screen 2: **Manager Dashboard** (`/dashboard`)

- **Function:** Team overview: list of direct reports, summary of goals (e.g. pending approval, on track, at risk); quick links to inbox, team review, and alerts.
- **What to show:** Team list/cards, counts of pending approvals, links to Manager Inbox and Team Review.
- **Say:** “The Manager Dashboard is my command center. I see everyone who reports to me and how many goals are waiting for my approval or need attention.”

---

### Manager Screen 3: **Goal Workspace (manager view)** (`/my_pdp` in manager context)

- **Function:** Manager’s own PDP view (their personal goals); same structure as employee PDP for consistency.
- **What to show:** Same PDP layout, with manager’s own goals.
- **Say:** “As a manager I also have my own goals. I use the same Goal Workspace so my goals are visible and approvable by my manager.”

---

### Manager Screen 4: **Manager Inbox** (`/manager_inbox`)

- **Function:** Central queue for approval requests and nudges: see all pending goal approvals, filter by type/priority/audience; approve, reject, or request changes with comments; optional SMART rubric scoring; bulk actions (e.g. mark read).
- **What to show:** Inbox list, filters, open a pending goal → show Approve / Request changes, add comment.
- **Say:** “Manager Inbox is where every new goal from my team lands. I see who submitted what and when. I open Thandi’s goal, review the details and criteria, add feedback if needed, then Approve. Once I approve, her Goal Detail screen updates immediately. I can also request changes so she can refine and resubmit.”

---

### Manager Screen 5: **Team Alerts & Nudges** (`/manager_alerts_nudges`)

- **Function:** Team-level alerts: goals at risk, overdue items, 1:1 reminders, nudges to approve or follow up; act from here (e.g. open goal, open employee).
- **What to show:** List of team alerts, opening one goes to the right goal or employee.
- **Say:** “Team Alerts & Nudges surface what needs my attention across the team—goals at risk, overdue approvals, 1:1s to schedule—so I can act quickly.”

---

### Manager Screen 6: **Team Challenges / Seasons** (`/team_challenges_seasons`)

- **Function:** Create and manage team or org season challenges; set time-bound goals and track participation.
- **What to show:** List of seasons/challenges, creating or editing one, viewing participation.
- **Say:** “Here I manage team or company-wide challenges and seasons. I can set up a challenge and see who’s participating and how they’re doing.”

---

### Manager Screen 7: **Team Review** (`/manager_review_team_dashboard`)

- **Function:** Review team performance: list of direct reports with goal counts, status, and risk; search/filter by department; drill into an employee to see all their goals; schedule 1:1 meetings; optional deep link from alerts to open a specific 1:1.
- **What to show:** Team list, search, open one employee → full goal list and statuses, “Schedule 1:1” or similar.
- **Say:** “Team Review is where I do the bulk of my manager work. I see every team member, how many goals they have and their status. I can search by name or department, open one person and see all their goals in one place, and schedule 1:1s. This is what I use before performance conversations.”

---

### Manager Screen 8: **Employee Profile Detail** (`/employee_profile_detail`)

- **Function:** View a single employee’s profile and goal summary (opened from Team Review or Inbox); used for context when approving or in 1:1s.
- **What to show:** Employee profile info and their goals summary.
- **Say:** “When I need full context on someone, I open their profile. I see their details and a summary of their goals—handy before a 1:1 or when deciding on an approval.”

---

### Manager Screen 9: **Progress Visuals (manager)** (`/progress_visuals` in manager context)

- **Function:** Team or individual progress charts; compare progress across the team; same visualizations as employee but with manager scope.
- **What to show:** Team/individual progress charts if available.
- **Say:** “Progress Visuals for managers show team-level or per-person progress so I can see who’s on track and who might need support.”

---

### Manager Screen 10: **Manager Leaderboard** (`/manager_leaderboard`)

- **Function:** Leaderboard view for the team (points, activity); see rankings and top performers.
- **What to show:** Leaderboard with team members.
- **Say:** “The Manager Leaderboard shows how my team ranks—useful for recognition and spotting top performers.”

---

### Manager Screen 11: **Manager Badges & Points** (`/manager_badges_points`)

- **Function:** View team members’ badges and points; optional breakdown by person or category.
- **What to show:** Team badges/points summary or list.
- **Say:** “Here I see badges and points across my team so I can recognize achievement and balance workload.”

---

### Manager Screen 12: **Repository & Audit (manager)** (`/repository_audit`)

- **Function:** Access team or org evidence repository and audit trail; verify evidence and compliance.
- **What to show:** Repository/audit view with manager scope.
- **Say:** “Repository & Audit for managers lets me see evidence and audit history for my team when needed for reviews or compliance.”

---

### Manager Screen 13: **Manager Profile** (`/manager_profile`)

- **Function:** Manager’s own profile (name, photo, role, team); used for display in 1:1s and team views.
- **What to show:** Manager profile form/summary.
- **Say:** “My Profile as a manager is where I keep my own details and ensure my team sees the right info.”

---

### Manager Screen 14: **Settings & Privacy (manager)** (`/settings`)

- **Function:** Same as employee: app settings, notifications, privacy, logout.
- **What to show:** Same settings screen.
- **Say:** “Settings work the same for managers—notifications and account options.”

---

### Manager Screen 15: **Team Details** (`/team_details`)

- **Function:** Detail view for a specific team goal or team challenge (e.g. season goal); see who’s involved and progress.
- **What to show:** One team goal/challenge with members and progress.
- **Say:** “When we have a team or season goal, Team Details shows who’s in it and how we’re progressing.”

---

### Manager Screen 16: **Team Management** (`/team_management`)

- **Function:** Manage a team goal or challenge: add/remove members, edit goal, track progress.
- **What to show:** Editing a team goal, member list, progress.
- **Say:** “Team Management is where I configure a team goal—who’s in it and how we track it.”

---

### Manager Screen 17: **Season Management** (`/season_management`)

- **Function:** Create or edit seasons; set dates, goals, and rules for a season.
- **What to show:** Season list, create/edit season form.
- **Say:** “Season Management is where I create or edit time-bound seasons and attach goals or challenges.”

---

### Manager flow summary (what to say)

- “For managers, the main workflow is: **Dashboard** to see the team → **Manager Inbox** to approve or send back goals → **Team Review** to drill into each person and schedule 1:1s. **Team Alerts & Nudges** and **Progress Visuals** help me spot risk and support the team. **Team Challenges**, **Team Details**, and **Team Management** cover team and season goals.”

---

## 45–55 min: Short technical overview (for technical audience)

- **Stack:** Flutter (Android build shown); Firebase (Auth, Firestore); Google services (e.g. from `google-services.json`) for auth/analytics as needed.
- **Architecture:** Role-based routing (employee vs manager); shared screens (e.g. Progress Visuals, Settings) with different data scope; real-time listeners for goals and approvals so both sides stay in sync.
- **Key flows:** Goal creation → Firestore; approval request → alert/queue in Manager Inbox; approve/reject → goal status and alerts updated; manager views use streams (e.g. `ManagerRealtimeService`) for team data.
- **Screens:** Routes defined in `main.dart`; employee sidebar from `SidebarConfig.employeeItems`; manager sidebar from `SidebarConfig.managerItems`; `RoleGate` enforces employee vs manager access per route.

---

## 55–60 min: Closing & Q&A

- **Summarize:** “We walked through every employee screen—from login and dashboard to goal creation, approval flow, alerts, progress, badges, and profile—and every manager screen—dashboard, inbox, approvals, team review, team challenges, and team management. The app is built so employees get clear goal creation and transparency, and managers get one place to approve goals and oversee the team.”
- **Invite questions:** “I’m happy to take questions on the user experience or the technical implementation.”

---

## Quick reference: All screens by role

| Role     | Route / Screen              | Main function |
|----------|-----------------------------|----------------|
| Shared   | `/sign_in`                  | Login; role detection |
| Employee | `/employee_dashboard`       | Hub: KPIs, goals, streak, badges, links |
| Employee | `/my_pdp`                   | PDP by KPA; list goals, status, create/edit |
| Employee | `/my_goal_workspace`        | Full goal form; create/edit; submit for approval |
| Employee | Goal Detail                 | View one goal; progress; submit for approval; evidence |
| Employee | `/alerts_nudges`            | Personal alerts, deadlines, 1:1 reminders |
| Employee | `/progress_visuals`         | Charts, trends, streaks |
| Employee | `/badges_points`            | Badges and points |
| Employee | `/season_challenges`        | Season challenges and progress |
| Employee | `/leaderboard`              | Rankings |
| Employee | `/repository_audit`         | Evidence and audit trail |
| Employee | `/my_profile`               | Personal profile |
| Employee | `/settings`                 | Settings, notifications, logout |
| Manager  | `/dashboard`                | Team overview, pending counts |
| Manager  | `/my_pdp` (manager)         | Manager’s own PDP |
| Manager  | `/manager_inbox`            | Pending approvals; approve/reject/comment |
| Manager  | `/manager_alerts_nudges`     | Team alerts and nudges |
| Manager  | `/team_challenges_seasons`  | Team seasons/challenges |
| Manager  | `/manager_review_team_dashboard` | Team list; per-person goals; 1:1s |
| Manager  | `/employee_profile_detail`  | One employee’s profile and goals |
| Manager  | `/progress_visuals` (manager) | Team progress visuals |
| Manager  | `/manager_leaderboard`      | Team leaderboard |
| Manager  | `/manager_badges_points`     | Team badges and points |
| Manager  | `/repository_audit` (manager) | Team repository/audit |
| Manager  | `/manager_profile`          | Manager profile |
| Manager  | `/settings` (manager)       | Settings |
| Manager  | `/team_details`             | One team goal/challenge detail |
| Manager  | `/team_management`         | Manage team goal members and progress |
| Manager  | `/season_management`        | Create/edit seasons |

---

*Use this script to rehearse the demo and keep timing: ~10 min intro + problem/vision, ~15 min employee screens, ~15 min manager screens, ~10 min technical, ~5 min Q&A.*
