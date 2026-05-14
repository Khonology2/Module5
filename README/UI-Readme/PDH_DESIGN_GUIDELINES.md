# Personal Development Hub (PDH) System Design - Visual Style Guidelines

## Overview
This guide helps you create a system architecture diagram matching the Facebook System Design style - clean, colorful, icon-rich, and professionally organized.

---

## 1. COLOR SCHEME & COMPONENT TYPES

### Yellow Components
- **Client** (laptop icon style)
- **Queues** (cylinders)
- **Cache** (trash can icon)
- **Feed Generation Task** (trash can icon)

### Red Components
- **Load Balancers** (server rack icons)
- **Internal Load Balancer** (server rack icon)
- **Core Services** (rectangular boxes):
  - Points Service
  - Badge Service
  - Season Service
  - Leaderboard Service
  - Team Management Service
  - Repository Service
  - Database Service
  - Alert Service
  - Role Service
  - Onboarding Service
  - Streak Service
- **Directory Based Partitioning** (red box)
- **Shard Manager** (red box)
- **Feed Generation Service** (red box)
- **Workers** (small red boxes)

### Blue Components
- **APP Read Server** (server rack icon with gears)
- **APP Write Server** (server rack icon with gears)
- **Database Instances** (Master, slave 1, slave 2) - light blue boxes

### Purple Components
- **API Gateway** (large box with 3 purple circles inside)
- **Evidence Processing Service** (purple box)
- **AI Chatbot Service** (purple box)
- **Speech Recognition Service** (purple box)

### Green Components
- **Real-time Updates (Firestore Streams)** (green box)
- **Goal Approval Service** (green box)
- **Content Delivery Network (CDN)** (green box)

### Light Blue Components
- **DNS** (cloud icon)
- **Metadata/User DB** (container with light blue background)
- **Photo/Video Storage (Cloudinary)** (cloud icon)
- **Collections** (light blue box)

---

## 2. SHAPE TYPES & ICONS

### Server Rack Icons (with gears/horizontal bars)
- Load Balancer
- Internal Load Balancer
- APP Read Server
- APP Write Server

### Cloud Icons
- DNS
- Photo/Video Storage (Cloudinary)

### Cylinder Shapes (Queues)
- Notification Queue (yellow cylinder)
- Feed Generation Queue (yellow cylinder)
- Evidence Processing Queue (yellow cylinder)

### Trash Can Icon (Cache)
- Cache (yellow trash can with 'C' or without)
- Feed Generation Task (yellow trash can)

### Rectangular Boxes
- All Services (various colors based on type)
- Database containers
- Partitioning/Shard Manager

### Circles (inside API Gateway)
- 3 purple circles arranged horizontally inside the API Gateway box

---

## 3. ARROW STYLES & COLORS

### Solid Green Arrows
- Load Balancer → API Gateway
- API Gateway → APP Read Server
- API Gateway → APP Write Server
- DNS → Load Balancer
- Real-time Updates → Metadata/User DB

### Solid Red Arrows
- Load Balancer → API Gateway (alternative path)
- Services → Database
- Feed Generation Service → Database

### Solid Brown Arrows
- APP Write Server → Feed Generation Task
- APP Write Server → Evidence Processing Task
- Feed Generation Task → Feed Generation Queue
- Evidence Processing Task → Evidence Processing Queue

### Solid Yellow Arrows
- Notification Queue → Notification Service
- Notification Service → Email Service

### Solid Purple Arrows
- Evidence Processing Queue → Evidence Processing Service
- Client → DNS (bidirectional)

### Dashed Purple Arrows
- Client → CDN
- CDN → Static Content
- Static Content → Cloudinary
- Cloudinary ↔ Evidence Processing Service (bidirectional)

### Dashed Blue Arrows
- APP Read Server → Notification Queue
- Feed Generation Queue → Feed Generation Service
- Notification Service ↔ Client (bidirectional)

### Dashed Red Arrows
- APP Read Server → Cache (with label "Metadata (goals, progress)")
- Cache ↔ Metadata/User DB (bidirectional)
- Cache → Directory Based Partitioning
- Directory Based Partitioning → Shard Manager
- Shard Manager → Metadata/User DB
- Feed Generation Service → Cache
- Feed Generation Service → Metadata/User DB (with label "Dashboard Data")

### Dashed Green Arrows
- Real-time Updates → APP Read Server

### Dashed Purple Arrows (Workers)
- Evidence Processing Service → worker 1
- Evidence Processing Service → worker 2
- Evidence Processing Service → worker 3

---

## 4. LAYOUT ORGANIZATION

### Top Layer (Entry Points)
- **Left:** Client (yellow)
- **Center-Left:** DNS (light blue cloud)
- **Center:** Load Balancer (red server rack)
- **Center-Right:** API Gateway (purple box with 3 circles)
- **Right:** CDN → Static Content → Cloudinary (vertical stack)

### Middle Layer (Application Servers)
- **Left:** APP Read Server (blue server rack)
- **Center:** APP Write Server (blue server rack)
- **Right:** Internal Load Balancer (red server rack)
- **Far Right:** Cache (yellow cylinder)

### Database Layer (Center-Right)
- **Metadata/User DB** (light blue container):
  - Master (light blue box)
  - slave 1 (light blue box)
  - slave 2 (light blue box)
- **Collections** (light blue box below DB)

### Processing Layer (Right Side)
- **Evidence Processing Task** (yellow box)
- **Evidence Processing Queue** (yellow cylinder)
- **Evidence Processing Service** (purple box)
- **Workers** (3 small red boxes below service)

### Services Layer (Bottom)
- **Left Column:**
  - Notification Queue (yellow cylinder)
  - Notification Service (yellow box)
  - Email Service (yellow box)
  - Points Service (red box)
  - Badge Service (red box)
  - Season Service (red box)
  - Leaderboard Service (red box)

- **Center Column:**
  - Feed Generation Task (yellow cylinder)
  - Feed Generation Queue (yellow cylinder)
  - Feed Generation Service (red box)
  - Dashboard Data (red box)
  - Real-time Updates (green box)
  - Goal Approval Service (green box)
  - Streak Service (red box)
  - Directory Based Partitioning (red box)
  - Shard Manager (red box)

- **Right Column:**
  - AI Chatbot Service (purple box)
  - Speech Recognition Service (purple box)
  - Team Management Service (red box)
  - Repository Service (red box)
  - Database Service (red box)
  - Alert Service (red box)
  - Role Service (red box)
  - Onboarding Service (red box)

---

## 5. TEXT & LABELING

### Title
- **Position:** Top left
- **Style:** Large, bold, dark blue/black
- **Text:** "Personal Development Hub System Design"

### Component Labels
- **Font Size:** 12-14px for main components
- **Font Size:** 10-11px for sub-components
- **Style:** Bold for main components, regular for sub-components
- **Color:** High contrast (white on colored backgrounds, dark on light backgrounds)

### Arrow Labels
- **Font Size:** 10px
- **Position:** Near the middle of the arrow
- **Examples:**
  - "Metadata (goals, progress)" on APP Read → Cache
  - "Dashboard Data" on Feed Generation Service → Database

### Collections List
- **Format:** Bullet list or comma-separated
- **Text:** "Collections: users, goals, seasons, badges, alerts, teams, onboarding"

---

## 6. SPECIFIC VISUAL ELEMENTS

### API Gateway
- Large purple rounded rectangle
- Contains 3 purple circles arranged horizontally
- Label below: "API Gateway (FastAPI Backend)"

### Database Container
- Light blue rounded rectangle with border
- Contains 3 smaller light blue boxes:
  - "Master"
  - "slave 1"
  - "slave 2"
- Label: "Metadata/User DB"

### Cache
- Yellow cylinder (trash can shape)
- Label: "Cache"
- Can have a 'C' inside or be plain

### Queues
- Yellow horizontal cylinders
- Labels: "Notification Queue", "Feed Generation Queue", "Evidence Processing Queue"

### Workers
- 3 small red rectangular boxes
- All labeled "worker"
- Arranged horizontally below Evidence Processing Service

---

## 7. CONNECTION PATTERNS

### Client Flow
1. Client → DNS (dashed purple, bidirectional)
2. Client → CDN (dashed purple)
3. DNS → Load Balancer (solid green)
4. Load Balancer → API Gateway (solid green)

### Read Path
1. API Gateway → APP Read Server (solid green)
2. APP Read Server → Cache (dashed red, labeled "Metadata (goals, progress)")
3. APP Read Server → Notification Queue (dashed blue)
4. Cache ↔ Metadata/User DB (dashed red, bidirectional)

### Write Path
1. API Gateway → APP Write Server (solid green)
2. APP Write Server → Feed Generation Task (solid brown)
3. APP Write Server → Evidence Processing Task (solid brown)
4. Feed Generation Task → Feed Generation Queue (solid brown)
5. Feed Generation Queue → Feed Generation Service (dashed blue)
6. Feed Generation Service → Cache (dashed red)
7. Feed Generation Service → Metadata/User DB (dashed red, labeled "Dashboard Data")

### Processing Path
1. Evidence Processing Task → Evidence Processing Queue (solid brown)
2. Evidence Processing Queue → Evidence Processing Service (solid purple)
3. Evidence Processing Service → Workers (dashed purple, 3 connections)
4. Cloudinary ↔ Evidence Processing Service (dashed purple, bidirectional)

### Notification Path
1. Notification Queue → Notification Service (solid yellow)
2. Notification Service → Email Service (solid yellow)
3. Notification Service ↔ Client (dashed blue, bidirectional)

### Real-time Path
1. Real-time Updates → Metadata/User DB (solid green)
2. Real-time Updates → APP Read Server (dashed green)

### Database Management
1. Cache → Directory Based Partitioning (dashed red)
2. Directory Based Partitioning → Shard Manager (dashed red)
3. Shard Manager → Metadata/User DB (dashed red)

---

## 8. SPACING & ALIGNMENT

### Horizontal Spacing
- **Between major components:** 200-300px
- **Between related components:** 100-150px
- **Between services in same column:** 60-80px

### Vertical Spacing
- **Between layers:** 150-200px
- **Between related components:** 80-100px
- **Between services in same column:** 60-80px

### Alignment
- **Top layer:** Align horizontally
- **Middle layer:** Align horizontally
- **Services:** Align in columns
- **Database:** Center-right position

---

## 9. TIPS FOR DRAW.IO

### Creating Server Rack Icons
- Use rounded rectangles
- Add horizontal lines inside (3-4 lines)
- Add small gear icons or use server rack shape from draw.io shapes

### Creating Cloud Icons
- Use cloud shape from draw.io
- Light blue fill, darker blue border

### Creating Cylinders (Queues)
- Use cylinder3 shape from draw.io
- Yellow fill (#FFF59D or #FFE082)
- Orange border (#F57F17 or #F57C00)

### Creating Trash Can (Cache)
- Use cylinder3 shape
- Or use trash can icon from draw.io shapes library
- Yellow fill

### Creating Circles in API Gateway
- Draw 3 ellipses inside the API Gateway box
- Purple fill (#9C27B0)
- Arrange horizontally with spacing

### Arrow Styling
- **Solid arrows:** strokeWidth=3
- **Dashed arrows:** strokeWidth=2, dashed=1
- **Bidirectional:** endFill=0 (for return arrow)

---

## 10. COLOR CODES (Hex Values)

- **Yellow Client:** #FFEB3B
- **Red Load Balancers:** #FF5252
- **Red Services:** #FFCDD2 (light red) or #FF5252 (dark red)
- **Blue App Servers:** #2196F3
- **Purple API Gateway:** #9C27B0
- **Purple Processing:** #E1BEE7 (light purple)
- **Green Real-time:** #C8E6C9 (light green)
- **Green CDN:** #4CAF50
- **Light Blue Database:** #E1F5FE
- **Light Blue DNS:** #E1F5FE
- **Yellow Queues:** #FFF59D or #FFE082
- **Yellow Cache:** #FFE082

---

## 11. CHECKLIST FOR FINAL DESIGN

- [ ] All components use correct colors
- [ ] All arrows use correct colors and styles (solid vs dashed)
- [ ] API Gateway has 3 purple circles inside
- [ ] Database has Master, slave 1, slave 2 clearly visible
- [ ] All queues are yellow cylinders
- [ ] Cache is yellow cylinder/trash can
- [ ] Workers are 3 small red boxes
- [ ] All text labels are clear and readable
- [ ] No duplicate components
- [ ] All connections follow the specified paths
- [ ] Title is prominent at top left
- [ ] Layout is organized and not cluttered
- [ ] Colors match the Facebook System Design style
- [ ] All arrows have correct labels where specified

---

## 12. COMMON MISTAKES TO AVOID

1. ❌ Using wrong colors for components
2. ❌ Making arrows the wrong style (solid vs dashed)
3. ❌ Missing the 3 circles in API Gateway
4. ❌ Duplicating components
5. ❌ Wrong arrow colors
6. ❌ Missing labels on arrows
7. ❌ Inconsistent spacing
8. ❌ Text too small or unclear
9. ❌ Components in wrong positions
10. ❌ Missing connections between components

---

## 13. REFERENCE COMPONENT MAPPING

| Facebook Component | PDH Equivalent | Color | Shape |
|-------------------|----------------|-------|-------|
| Client | Client | Yellow | Rounded Rectangle |
| Load Balancer | Load Balancer | Red | Server Rack |
| API Gateway | API Gateway (FastAPI) | Purple | Box with Circles |
| APP Read Server | APP Read Server | Blue | Server Rack |
| APP Write Server | APP Write Server | Blue | Server Rack |
| Cache | Cache | Yellow | Cylinder/Trash Can |
| Metadata/User DB | Metadata/User DB | Light Blue | Container |
| Video Processing | Evidence Processing | Purple | Box |
| Feed Generation | Feed Generation | Red | Box |
| Notification Service | Notification Service | Yellow | Box |
| Like Service | Points Service | Red | Box |
| Comment Service | Badge Service | Red | Box |

---

## 14. FINAL NOTES

- **Consistency is key:** Use the same colors, shapes, and styles throughout
- **Clarity over complexity:** If something is unclear, simplify it
- **Test readability:** Make sure all text is readable at different zoom levels
- **Follow the flow:** Ensure data flow makes logical sense
- **Match the style:** Keep the Facebook System Design aesthetic throughout

---

**Good luck creating your PDH System Design diagram!** 🎨

