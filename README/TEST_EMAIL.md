# 🧪 How to Test Email Function

## Step 1: Disable Deployment Protection

**IMPORTANT:** Before testing, disable deployment protection:

1. Go to: https://vercel.com/siphos-projects-c258995d/pdh-email-api/settings/deployment-protection
2. Set **"Deployment Protection"** to **"None"** or **"Off"**
3. Click **Save**

## Step 2: Test with Your Email

### Option A: Using Node.js Test Script

1. Edit `vercel-email-api/test-email-simple.js`
2. Replace `your-email@example.com` with your actual email address
3. Run:
   ```bash
   cd vercel-email-api
   node test-email-simple.js
   ```

### Option B: Using curl (PowerShell)

```powershell
$body = @{
    to = "your-email@example.com"
    userName = "Test User"
    alertType = "goalCompleted"
    title = "Goal Completed! 🎉"
    message = "Congratulations! You completed 'Test Goal' and earned 100 points!"
    goalTitle = "Test Goal"
    points = 100
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://pdh-email-ps5e3klci-siphos-projects-c258995d.vercel.app/api/send-email" -Method Post -Body $body -ContentType "application/json"
```

### Option C: Test from Flutter App

1. Run your Flutter app
2. Create a test alert (e.g., complete a goal)
3. Check the user's email inbox

## Expected Result

✅ **Success (200):** Email sent successfully - check your inbox!
❌ **Error (401/403):** Deployment protection is still enabled - disable it first
❌ **Error (500):** Check Vercel logs for SendGrid API key issues

## Check Logs

To see detailed logs:
```bash
vercel inspect https://pdh-email-ps5e3klci-siphos-projects-c258995d.vercel.app --logs
```

## Troubleshooting

- **401/403 Error:** Deployment protection is enabled - disable it in Vercel settings
- **500 Error:** Check if SendGrid API key is set correctly in Vercel environment variables
- **No email received:** Check spam folder, verify email address is correct

