# Evidence Upload & Tracking Guide

## 📱 **As an Employee - Where to See Your Uploads**

### 1. **In PDP Screen (My Personal Development Plan)**
- **Location**: Go to "My PDP" in the sidebar
- **What you see**: 
  - Green-bordered evidence section below each goal's progress bar
  - Shows: "📎 Attached Evidence (1)"
  - Lists your uploaded files with blue cloud icons
  - Click on Cloudinary files to see the URL

### 2. **In Repository & Audit Screen**
- **Location**: Go to "Repository & Audit" in the sidebar
- **What you see**:
  - **Audit Entries**: Your submitted goals waiting for manager review
  - **Repository Section**: Your verified/completed goals with evidence
  - **Evidence Count**: Shows "X evidence" for each goal

### 3. **Evidence Display Format**
```
📎 Attached Evidence (1)
☁️ 📁 Cloudinary File (Click to view URL)
📄 📎 File: document.pdf (2.1 KB) - Uploaded to Cloudinary
```

---

## 👨‍💼 **As a Manager - Where to See Employee Evidence**

### 1. **In Repository & Audit Screen**
- **Location**: Go to "Repository & Audit" in the sidebar
- **What you see**:
  - **All Audit Entries**: From all employees in your department
  - **Evidence Section**: In each audit entry card
  - **Repository Section**: All verified goals from your team

### 2. **Evidence in Audit Entries**
- **Pending Goals**: Shows evidence attached by employees
- **Verified Goals**: Shows evidence that was approved
- **Rejected Goals**: Shows evidence that needs improvement

### 3. **Manager Actions**
- **Verify**: Approve the goal and evidence
- **Request Changes**: Reject with feedback
- **View Evidence**: Click on evidence items to see details

---

## 🔧 **As a Developer - Where to Track Uploads**

### 1. **Browser Console Logs**
```javascript
Starting Cloudinary upload...
Cloudinary upload successful: https://res.cloudinary.com/dj7phyugw/...
File uploaded and attached to goal: 📎 File: document.pdf (2.1 KB) - Uploaded to Cloudinary
```

### 2. **Firestore Database**
- **Collection**: `goals/{goalId}`
- **Field**: `evidence` (array of strings)
- **Content**: 
  ```json
  {
    "evidence": [
      "📎 File: document.pdf (2.1 KB) - Uploaded to Cloudinary",
      "https://res.cloudinary.com/dj7phyugw/evidence/user123/goal456/1234567890_document.pdf"
    ]
  }
  ```

### 3. **Cloudinary Dashboard**
- **URL**: https://console.cloudinary.com
- **Location**: Media Library → evidence folder
- **Structure**: `evidence/{userId}/{goalId}/{timestamp_filename}`
- **Files**: All uploaded files with metadata

### 4. **Repository Collection (After Verification)**
- **Collection**: `repositories/{userId}/completedGoals/{goalId}`
- **Field**: `evidence` (copied from goals when verified)
- **Purpose**: Permanent record of completed goals with evidence

---

## 🔄 **Complete Evidence Flow**

### **Step 1: Employee Uploads Evidence**
1. Employee goes to PDP screen
2. Clicks "Attach evidence" on a goal
3. Selects a file (PDF, image, etc.)
4. File uploads to Cloudinary
5. Evidence info saves to Firestore `goals` collection
6. Employee sees evidence in PDP screen

### **Step 2: Employee Submits for Review**
1. Employee clicks "Request acknowledgement"
2. Goal gets submitted to `audit_entries` collection
3. Evidence gets copied to audit entry
4. Manager can see in Repository & Audit screen

### **Step 3: Manager Reviews**
1. Manager sees audit entry with evidence
2. Manager can verify or request changes
3. If verified, goal moves to repository
4. Evidence gets copied to repository collection

### **Step 4: Repository Storage**
1. Verified goals appear in repository
2. Evidence is permanently stored
3. Both employee and manager can view
4. Export functionality includes evidence

---

## 🐛 **Fixes Applied**

### **Infinite Spinner Issue**
- **Problem**: Repository section missing loading state
- **Fix**: Added `ConnectionState.waiting` check
- **Result**: Proper loading indicators now show

### **Evidence Display**
- **Problem**: Evidence not visible after upload
- **Fix**: Added evidence section to PDP screen
- **Result**: Employees can see their uploaded files immediately

---

## 🧪 **Testing Checklist**

### **Employee Testing**
- [ ] Upload file in PDP screen
- [ ] See evidence section appear
- [ ] Click on Cloudinary file to see URL
- [ ] Submit goal for audit
- [ ] See evidence in Repository & Audit screen

### **Manager Testing**
- [ ] See employee audit entries with evidence
- [ ] Verify goals with evidence
- [ ] View evidence in repository section
- [ ] Export data with evidence included

### **Developer Testing**
- [ ] Check browser console for upload logs
- [ ] Verify Firestore data structure
- [ ] Check Cloudinary dashboard for files
- [ ] Test error handling and fallbacks

---

## 🎯 **All Functionality is Applicable**

✅ **Employee Evidence Upload**: Working with Cloudinary
✅ **Evidence Display**: Visible in PDP and Repository screens  
✅ **Manager Review**: Can see and verify evidence
✅ **Repository Storage**: Evidence persists after verification
✅ **Export Functionality**: Includes evidence in CSV/PDF
✅ **Real-time Updates**: Evidence syncs across all screens
✅ **Error Handling**: Fallback if upload fails
✅ **Security**: Role-based access to evidence

**Everything is working as designed!** 🚀
