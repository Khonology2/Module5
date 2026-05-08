# 🆓 FREE Email Solution Setup Guide

Since you can't use Firebase Blaze plan, here's a **100% FREE** solution using Vercel (no billing, no credit card needed).

## ✅ What You Get

- ✅ **FREE** - No billing, no credit card required
- ✅ **Unlimited** function executions (within free tier)
- ✅ **100GB** bandwidth/month (more than enough for emails)
- ✅ **Same functionality** as Firebase Functions
- ✅ **Easy setup** - 5 minutes

## 🚀 Quick Setup Steps

### Step 1: Create Vercel Account (FREE)
1. Go to https://vercel.com
2. Sign up with GitHub (completely free, no credit card)

### Step 2: Install Vercel CLI
```bash
npm install -g vercel
```

### Step 3: Deploy the Function
```bash
cd vercel-email-api
vercel
```

When prompted:
- **Link to existing project?** → No
- **Project name?** → `pdh-email-api` (or any name)
- **Directory?** → `./` (current directory)

### Step 4: Add SendGrid API Key
1. Go to Vercel Dashboard → Your Project → **Settings** → **Environment Variables**
2. Click **Add New**
3. Add:
   - **Key**: `SENDGRID_API_KEY`
   - **Value**: `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`
   - **Environment**: Select all (Production, Preview, Development)
4. Click **Save**

### Step 5: Redeploy
```bash
vercel --prod
```

### Step 6: Get Your Function URL
1. Go to Vercel Dashboard → Your Project → **Deployments**
2. Click on the latest deployment
3. Copy the URL (e.g., `https://pdh-email-api-xyz.vercel.app`)

### Step 7: Update Flutter Code
1. Open `lib/services/email_notification_service.dart`
2. Replace line 15:
   ```dart
   static const String _emailApiUrl = 'https://YOUR-FUNCTION-URL.vercel.app/api/send-email';
   ```
   (Replace `YOUR-FUNCTION-URL` with your actual Vercel URL)

### Step 8: Enable Email Notifications in Alert Service
1. Open `lib/services/alert_service.dart`
2. Add import at the top:
   ```dart
   import 'package:pdh/services/email_notification_service.dart';
   ```
3. Uncomment the email code in `_createAlert` method (around line 450)

## 🎯 How It Works

1. Your Flutter app creates an alert in Firestore
2. The alert service calls `EmailNotificationService.sendAlertEmail()`
3. This sends an HTTP request to your free Vercel function
4. Vercel function sends the email via SendGrid
5. User receives email! ✉️

## 💰 Cost Breakdown

**Vercel Free Tier:**
- 100GB bandwidth/month = ~500,000 emails/month
- Unlimited function executions
- **Cost: $0/month**

**SendGrid Free Tier:**
- 100 emails/day = 3,000 emails/month
- **Cost: $0/month**

**Total Cost: $0/month** 🎉

## ✅ That's It!

Your email notifications will work exactly like Firebase Functions, but **completely FREE**!

## 🧪 Test It

After setup, create an alert in your app and check if the email is sent. You can also test directly:

```bash
curl -X POST https://your-function-url.vercel.app/api/send-email \
  -H "Content-Type: application/json" \
  -d '{
    "to": "your-email@example.com",
    "userName": "Test User",
    "alertType": "goalCompleted",
    "title": "Test Email",
    "message": "This is a test",
    "goalTitle": "Test Goal"
  }'
```

## 📝 Notes

- The Vercel function uses the same email templates as Firebase Functions
- All alert types are supported
- Respects user email notification preferences
- No billing alerts needed - it's completely free!

