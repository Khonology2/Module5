# Manager Screens - Functions & Features
## Demo Documentation for Seniors and Stakeholders

---

## 1. Manager Dashboard Screen
**Purpose:** Central command center providing real-time team overview and quick access to key management functions.

### Key Functions:
- **Welcome Card**: Personalized greeting with manager name and profile photo, time-based greeting (Good morning/afternoon/evening)
- **Daily Motivation**: Rotating motivational quotes for leadership inspiration
- **Quick Actions Panel**: Direct access buttons to:
  - Manager Review (team performance dashboard)
  - Progress Visuals (team analytics)
  - Leaderboard (team rankings)
  - Badges & Points (gamification overview)
- **Team KPIs**: Real-time metrics showing:
  - Total team members
  - Active employees (last 7 days)
  - Average team progress percentage
  - Team engagement percentage
- **Team Health Metrics**: Goal status tracking:
  - On Track goals count
  - At Risk goals count
  - Overdue goals count
- **Activity Summary**: Employee activity breakdown:
  - Active today
  - Active this week
  - Inactive employees
  - Overdue status
  - At Risk status
  - On Track status
- **Top Performers**: Displays top 2 team members by points with active status indicators
- **Season Progress Alerts**: Shows active Growth Seasons with:
  - Completion progress (employees completed/total)
  - Visual progress bars
  - "Complete Season" button when all participants finish
- **Tutorial System**: Interactive onboarding tutorial for first-time managers

---

## 2. Manager Portal Screen
**Purpose:** Main navigation hub that routes to all manager-specific screens.

### Key Functions:
- **Responsive Sidebar Navigation**: Access to all manager screens:
  - Dashboard
  - My PDP (Personal Development Plan)
  - Manager Profile
  - Team Challenges & Seasons
  - Progress Visuals
  - Manager Alerts & Nudges
  - Manager Inbox
  - Personal Alerts
  - Manager Badges & Points
  - Personal Badges & Points
  - Leaderboard
  - Repository Audit
  - Settings
  - Manager Review Team Dashboard
- **Profile Button**: Quick access to manager profile in top-right corner
- **Tutorial System**: Sidebar tutorial for new managers
- **Route Management**: Handles navigation between embedded screens without full page reloads

---

## 3. Manager Inbox Screen
**Purpose:** Centralized communication hub for managing alerts, nudges, and approval requests.

### Key Functions:
- **Dual Inbox Views**:
  - Personal Inbox: Manager's own alerts and notifications
  - Team Inbox: Team-wide alerts and notifications
- **Advanced Filtering**:
  - Type filters: All, Alerts, Nudges, Approvals
  - Priority filters: All, Low, Medium, High, Urgent
  - Unread-only toggle
  - Search functionality
- **Goal Approval System**:
  - SMART rubric review (5-point scale for each criterion):
    - Clarity (Specific)
    - Measurability
    - Achievability
    - Relevance
    - Timeline
  - Total SMART score (out of 25)
  - Review notes field
  - Actions: Approve, Request Changes, Reject
- **Alert Management**:
  - Mark as read/unread
  - Dismiss alerts
  - Bulk "Mark all as read" functionality
  - Quick navigation to related goals, badges, or leaderboards
- **Alert Types Handled**:
  - Goal approval requests
  - Goal milestones completed
  - Goal created/completed/overdue
  - Badge earned notifications
  - Team goal availability
  - Season progress updates
- **Visual Indicators**: Color-coded priority levels and read/unread status

---

## 4. Manager Alerts & Nudges Screen
**Purpose:** Comprehensive system for sending nudges, managing alerts, and tracking team engagement.

### Key Functions:
- **Four-Tab Interface**:
  1. **Send Nudges Tab**: Create and send motivational nudges to team members
  2. **Team Alerts Tab**: View and manage team-wide alerts
  3. **Approvals Tab**: Review and approve/reject employee goals
  4. **Analytics Tab**: View nudge effectiveness and team insights
- **Nudge Creation**:
  - Select target employee(s)
  - Custom message composition
  - Priority level assignment
  - Goal association (optional)
- **Goal Rescheduling**: 
  - Extend deadlines for at-risk goals
  - Add reschedule notes
  - Automatic notifications to employees
- **Nudge Analytics**:
  - Nudges sent count
  - Response rates
  - Trend visualization
  - Team insights and recommendations
- **Approval Workflow**:
  - View pending goal approvals
  - SMART criteria evaluation
  - Batch approval capabilities
- **Team Insights**: AI-powered recommendations for team management actions

---

## 5. Manager Badges & Points Screen
**Purpose:** Gamification system tracking manager's leadership performance and achievements.

### Key Functions:
- **Manager Points System**:
  - Total leadership score calculation based on:
    - Goal approvals (10 points each)
    - Nudges sent (2 points each)
    - High team completion bonus (100 points if ≥60%)
    - Engagement bonus (50 points if ≥70%)
  - Progress to next level indicator
  - Current level display (1-5)
- **Manager Levels**:
  - **Level 1 - Starter Coach**: Initial coaching and acknowledgements
  - **Level 2 - Active Coach**: Consistent feedback & check-ins
  - **Level 3 - Growth Enabler**: Team motivation, replans & engagement
  - **Level 4 - Strategic Mentor**: Growth Seasons leadership
  - **Level 5 - Master Coach**: Elite mentoring & results
- **Badge Organization**:
  - Badges grouped by level (1-5)
  - Progress tracking per level (earned/total)
  - Visual level sections with expandable details
  - Season badges integration
- **Badge Categories**:
  - Active coaching badges
  - Feedback champion badges
  - Growth enabler badges
  - Season leadership badges
  - Master coach achievements
- **Metrics Display**:
  - Approvals count
  - Nudges sent count
  - Team completion rate
  - Team engagement percentage
- **Recent Actions**: Timeline of recent manager activities (nudges, approvals)

---

## 6. Manager Profile Screen
**Purpose:** Personal profile management and AI-powered development plan generation.

### Key Functions:
- **Basic Information**:
  - Full name, job title, department
  - Work email, phone number
  - Employee ID (read-only)
  - Profile photo upload/removal
- **Development & Skills Context**:
  - Current skills/strengths (taggable list)
  - Areas for development (taggable list)
  - **AI Development Plan Generator**:
    - Interactive questionnaire (4 questions):
      - Short-term impact goals (3-6 months)
      - Long-term role/capability goals (12-24 months)
      - Current projects/business priorities
      - Career aspirations
    - AI-powered plan generation using Gemini
    - Auto-populates development areas, goals, and recommended activities
- **Goal & Learning Preferences**:
  - Learning style selection (Visual, Hands-on, Reading, Collaborative)
  - Preferred development activities (Courses, Mentorship, Projects)
  - Short-term goals (3-6 months)
  - Long-term goals (1-3 years)
  - Notification frequency preferences
- **Profile Management**: Save and update profile information

---

## 7. Manager Review Team Dashboard Screen
**Purpose:** Comprehensive team performance monitoring and management interface.

### Key Functions:
- **Time Filter Options**:
  - Today, This Week, This Month, This Quarter, This Year
- **Team Overview**:
  - Real-time employee list with status indicators:
    - On Track (green)
    - At Risk (orange)
    - Overdue (red)
    - Inactive (grey)
- **Employee Cards Display**:
  - Employee name, job title, profile photo
  - Status badge with icon
  - Key metrics:
    - Total goals
    - Completed goals
    - Average progress percentage
    - Total points
    - Weekly activities
    - Engagement score
    - Motivation level
    - Streak days
- **Quick Actions per Employee**:
  - **Nudge**: Send motivational message
  - **1:1**: Schedule one-on-one meeting
  - **Kudos**: Give recognition with points/badges
  - **Activity**: View detailed activity timeline
- **AI Manager Insights**:
  - Priority-based insights (Urgent, High, Medium, Low)
  - Actionable recommendations
  - "View Full Analysis" for detailed insights
- **Employee Detail Navigation**: Click employee card to view detailed profile and goals
- **Activity Viewing**: Detailed timeline of employee activities with timestamps

---

## 8. Manager Team Workspace Screen
**Purpose:** Create and manage team goals for collaborative team activities.

### Key Functions:
- **Team Goal Creation**:
  - Title and description
  - Points reward per participant
  - Deadline selection
  - Automatic notification to all employees
- **Active Team Goals Display**:
  - Goal cards showing:
    - Title and description
    - Status (Active, In Progress, Completed, Cancelled)
    - Participant count
    - Points reward
    - Deadline countdown
  - Color-coded status indicators
- **Team Goal Management**:
  - View team details
  - Manage team members
  - Track participation
- **Empty State**: Guidance for creating first team goal
- **Notifications**: Automatic alerts sent to all employees when new team goals are created

---

## 9. Manager Leaderboard Screen
**Purpose:** Competitive ranking system to motivate and recognize top performers.

### Key Functions:
- **Metric Selection**:
  - Points-based ranking
  - Streaks-based ranking
  - Progress-based ranking
- **Podium Display**:
  - Top 3 performers with visual podium (gold, silver, bronze)
  - Height-based visualization
  - Points display
- **Full Leaderboard List**:
  - Rankings 4+ with employee cards
  - Avatar, name, department
  - Selected metric value display
- **Privacy Respect**: Only shows employees who opted into leaderboard participation
- **Empty State**: Message encouraging team to enable leaderboard participation
- **Real-time Updates**: Live data stream from team metrics

---

## 10. Manager Employee Detail Screen
**Purpose:** Detailed view of individual employee performance and goals.

### Key Functions:
- **Employee Header**:
  - Profile photo/avatar
  - Name and job title
  - Total points
  - Current level
- **Goals List**:
  - All employee goals (from both top-level and nested collections)
  - Goal title and description
  - Status chips (Completed, In Progress, Not Started, Paused, Burnout)
  - Progress bars with percentage
  - Sorted by creation date (newest first)
- **Real-time Updates**: Live stream of goal changes
- **Empty State**: Message when employee has no goals yet

---

## Common Features Across All Screens

### Navigation & Access:
- Consistent sidebar navigation
- Profile button access
- Logout functionality
- Responsive design for different screen sizes

### Real-time Data:
- Live Firestore streams for real-time updates
- Automatic refresh on data changes
- Loading states and error handling

### Visual Design:
- Consistent dark theme with glassmorphism effects
- Background image (khono_bg.png) with gradient overlays
- Color-coded status indicators
- Icon-based visual cues

### Tutorial System:
- First-time user onboarding
- Interactive showcase views
- Step-by-step guidance
- Skip/complete options

---

## Key Business Value Propositions

1. **Real-time Visibility**: Managers can see team performance instantly without manual reporting
2. **Proactive Management**: Alerts and insights help managers intervene before issues escalate
3. **Gamification**: Badge and points system motivates managers to engage more with their teams
4. **AI-Powered Insights**: Automated recommendations help managers make data-driven decisions
5. **Streamlined Workflows**: Quick actions reduce time spent on administrative tasks
6. **Team Engagement**: Leaderboards and team goals foster healthy competition and collaboration
7. **Personal Development**: AI-generated development plans help managers grow their leadership skills

---

## Technical Highlights

- **Firebase Integration**: Real-time Firestore streams for live data
- **AI Integration**: Gemini AI for development plan generation
- **Responsive Design**: Works across desktop, tablet, and mobile
- **Offline Support**: Cached data for offline viewing
- **Security**: Role-based access control ensuring only managers can access these screens

---

*This document provides a comprehensive overview of all manager screen functions for stakeholder demos and presentations.*

