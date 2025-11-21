# Email Toggle Setup - Verification Guide

## ✅ Current Setup Status

The email notification toggle is **fully set up** and should work correctly. Here's the complete flow:

### 1. **UI Toggle** (`lib/settings_screen.dart`)
- ✅ Toggle exists in Settings → Notifications section
- ✅ Calls `_updateSetting('emailNotifications', value)` when toggled
- ✅ Shows success message when updated

### 2. **Settings Service** (`lib/services/settings_service.dart`)
- ✅ `updateSetting()` method saves to Firestore
- ✅ Uses `set()` with `merge: true` to handle both create and update cases
- ✅ Saves to `users/{userId}` document with field `emailNotifications`

### 3. **Email Notification Service** (`lib/services/email_notification_service.dart`)
- ✅ Checks `emailNotifications` preference before sending emails
- ✅ Reads from Firestore: `users/{userId}/emailNotifications`
- ✅ Defaults to `true` (send emails) if field doesn't exist
- ✅ Returns `false` only if field is explicitly set to `false`

### 4. **Firestore Rules** (`firestore.rules`)
- ✅ Users can update their own `users/{userId}` document (line 74-79)
- ✅ No additional rules needed - existing rules allow the toggle

### 5. **Alert Service Integration** (`lib/services/alert_service.dart`)
- ✅ All alert creation methods call `EmailNotificationService.sendAlertEmail()`
- ✅ Email service checks the toggle before sending

---

## 🔍 How to Verify It Works

### Step 1: Check Current Toggle State
1. Open your app
2. Go to Settings → Notifications
3. Check if "Email Notifications" toggle is ON or OFF
4. Note the current state

### Step 2: Toggle It OFF
1. Turn the "Email Notifications" toggle OFF
2. You should see a success message: "Email notifications disabled."
3. Check Firestore Console:
   - Go to `users/{yourUserId}` document
   - Verify `emailNotifications` field is set to `false`

### Step 3: Test Email Blocking
1. With toggle OFF, trigger an alert (e.g., complete a goal)
2. Check debug console - you should see:
   ```
   User {userId} has email notifications disabled
   ```
3. **You should NOT receive an email**

### Step 4: Toggle It ON
1. Turn the "Email Notifications" toggle ON
2. You should see: "Email notifications enabled."
3. Check Firestore - `emailNotifications` should be `true`

### Step 5: Test Email Sending
1. With toggle ON, trigger an alert (e.g., complete a goal)
2. Check debug console - you should see:
   ```
   Email sent successfully
   ```
3. **You should receive an email**

---

## 🐛 Troubleshooting

### Issue: Toggle doesn't save
**Check:**
- Firestore rules allow user to update their own document ✅
- User is authenticated ✅
- Check browser console for errors

**Fix:**
- The code now uses `set()` with `merge: true` instead of `update()`, so it works even if the document doesn't exist yet

### Issue: Emails still sent when toggle is OFF
**Check:**
1. Verify Firestore document has `emailNotifications: false`
2. Check debug console for the log: "User {userId} has email notifications disabled"
3. If you see that log, the toggle is working - check if emails are coming from another source

**Fix:**
- The email service checks the preference before sending, so if emails are still sent, there might be another code path sending them

### Issue: No emails when toggle is ON
**Check:**
1. Verify `emailNotifications: true` in Firestore
2. Check debug console for errors
3. Verify Vercel function is deployed and accessible
4. Check SendGrid API key is set in Vercel

**Fix:**
- Check the email notification service logs
- Verify Vercel function URL is correct
- Test Vercel function directly

---

## 📋 Code Flow Summary

```
User Toggles Email Notifications
    ↓
settings_screen.dart: _updateSetting('emailNotifications', value)
    ↓
settings_service.dart: updateSetting() → Firestore.set(merge: true)
    ↓
Firestore: users/{userId}/emailNotifications = true/false
    ↓
Alert Created → alert_service.dart: _createAlert()
    ↓
EmailNotificationService.sendAlertEmail()
    ↓
_shouldSendEmail() → Reads users/{userId}/emailNotifications
    ↓
If false → Skip email (log message)
If true → Send email via Vercel API
```

---

## ✅ Verification Checklist

- [ ] Toggle exists in Settings UI
- [ ] Toggle saves to Firestore when changed
- [ ] Firestore document shows `emailNotifications: true/false`
- [ ] With toggle OFF, no emails are sent (check console logs)
- [ ] With toggle ON, emails are sent (check inbox)
- [ ] Default behavior: emails sent if field doesn't exist (defaults to true)
- [ ] No console errors when toggling

---

## 🎯 Quick Test

Run this quick test sequence:

1. **Toggle OFF** → Complete a goal → Check console → Should see "disabled" message
2. **Toggle ON** → Complete a goal → Check console → Should see "Email sent successfully"
3. **Check inbox** → Should only receive email from step 2

If all steps work, the toggle is fully functional! ✅

