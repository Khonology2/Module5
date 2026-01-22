# Free Email API for Personal Development Hub

This is a **FREE** Vercel serverless function that sends emails via SendGrid. No billing required!

## Quick Setup (5 minutes)

### 1. Create Vercel Account
- Go to https://vercel.com
- Sign up with GitHub (free, no credit card needed)

### 2. Install Vercel CLI
```bash
npm install -g vercel
```

### 3. Deploy
```bash
cd vercel-email-api
vercel
```

Follow the prompts:
- Link to existing project? **No**
- Project name: **pdh-email-api** (or any name)
- Directory: **./**

### 4. Set Environment Variable
After deployment:
1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add:
   - **Key**: `SENDGRID_API_KEY`
   - **Value**: Your SendGrid API key (`SG.07Ws0ehbTWC5wNTDb0nAKA...`)
   - **Environment**: Production, Preview, Development (select all)
3. Click **Save**

### 5. Redeploy (to apply environment variable)
```bash
vercel --prod
```

### 6. Get Your Function URL
- Go to Vercel Dashboard → Your Project → Deployments
- Click on the latest deployment
- Copy the URL (e.g., `https://pdh-email-api.vercel.app`)

### 7. Update Flutter Code
In `lib/services/email_notification_service.dart`, update:
```dart
static const String _emailApiUrl = 'https://your-function-url.vercel.app/api/send-email';
```

## Free Tier Limits

Vercel Free Tier includes:
- ✅ 100GB bandwidth/month
- ✅ Unlimited function executions
- ✅ Perfect for email notifications!

**Cost: $0/month** (stays within free tier for typical usage)

## Testing

Test the function:
```bash
curl -X POST https://your-function-url.vercel.app/api/send-email \
  -H "Content-Type: application/json" \
  -d '{
    "to": "test@example.com",
    "userName": "Test User",
    "alertType": "goalCompleted",
    "title": "Goal Completed! 🎉",
    "message": "Congratulations!",
    "goalTitle": "Test Goal",
    "points": 100
  }'
```

## Integration

After setup, call from your Flutter app:
```dart
await EmailNotificationService.sendAlertEmail(
  userId: userId,
  alertType: 'goalCompleted',
  title: 'Goal Completed! 🎉',
  message: 'Congratulations!',
  goalTitle: 'My Goal',
);
```

That's it! **No billing, completely free!** 🎉

