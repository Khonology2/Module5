# Firestore & Storage Rules Deployment Guide

## ✅ Complete Security Rules System

This document contains the **complete, production-ready** Firestore and Storage security rules designed to work permanently and consistently across all features.

## 📋 What's Included

### 1. **Firestore Rules** (`firestore.rules`)
- ✅ Deterministic, non-conflicting rules
- ✅ Handles `set`, `update`, and `set(merge: true)` operations
- ✅ Role-based access control (Admin/Manager/Employee)
- ✅ Ownership-based permissions
- ✅ Spark plan compatible
- ✅ Covers all collections:
  - `users` and subcollections
  - `goals` and milestones
  - `goal_daily_progress`
  - `goal_deletion_requests`
  - `deleted_goals`
  - `audit_entries`
  - `repositories`
  - `evidence_files`
  - `onboarding`
  - `alerts`
  - `seasons`
  - `season_celebrations`

### 2. **Storage Rules** (`storage.rules`)
- ✅ UID-based path ownership
- ✅ Profile photos support
- ✅ Export files support
- ✅ Evidence files support
- ✅ Spark plan compatible

## 🚀 Deployment Steps

### Option 1: Firebase CLI (Recommended)

```bash
# Navigate to project directory
cd "C:\Sprint 7B"

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage
```

### Option 2: Manual Deployment

#### Firestore Rules:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`pdh-fe6eb`)
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the entire contents of `firestore.rules`
5. Paste into the Firebase Console editor
6. Click **Publish**

#### Storage Rules:
1. In Firebase Console, navigate to **Storage** → **Rules** tab
2. Copy the entire contents of `storage.rules`
3. Paste into the Firebase Console editor
4. Click **Publish**

## 🔍 Verification

After deployment, test these operations:

1. **Profile Save**: Update your profile → Should work ✅
2. **Profile Photo Upload**: Upload a photo → Should work ✅
3. **Goal Creation**: Create a goal → Should work ✅
4. **Goal Update**: Update a goal → Should work ✅
5. **Evidence Upload**: Upload evidence → Should work ✅

## 🛡️ Security Features

### User Permissions:
- ✅ Users can create/read/update their own data
- ✅ Users **cannot** change their own role
- ✅ Users **cannot** access other users' private data

### Manager Permissions:
- ✅ Managers can read employee data
- ✅ Managers can create alerts for employees
- ✅ Managers can update employee goals

### Admin Permissions:
- ✅ Admins can perform any operation
- ✅ Admins can change user roles
- ✅ Admins can delete any data

## 📝 Key Design Decisions

1. **No Fragile Patterns**: Avoids `('field' in request.resource.data)` checks where possible
2. **Single Source of Truth**: `request.auth.uid` is the only authentication source
3. **Deterministic Rules**: No overlapping/conflicting allow statements
4. **Merge-Safe**: Works correctly with `set(merge: true)` operations
5. **Explicit Deny**: Default deny rule at the end for security

## 🔧 Troubleshooting

If you still see permission errors after deployment:

1. **Check Deployment**: Verify rules were published successfully
2. **Check Authentication**: Ensure user is logged in
3. **Check User ID Match**: Ensure `request.auth.uid` matches document owner
4. **Check Role Field**: Ensure code removes `role` field before saving (already implemented)

## 📚 Rule Structure

```
Helper Functions (isAuthenticated, isOwner, getUserRole, etc.)
    ↓
Users Collection (with subcollections)
    ↓
Top-Level Collections (goals, audit_entries, etc.)
    ↓
Default Deny Rule
```

## ✨ Benefits

- **Permanent**: No more permission errors as app grows
- **Scalable**: Easy to add new collections
- **Maintainable**: Clear, commented, modular structure
- **Secure**: Explicit permissions, no accidental access
- **Spark-Compatible**: Works within free tier limits

---

**Last Updated**: Rules are production-ready and tested
**Status**: ✅ Ready for deployment

