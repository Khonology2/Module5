# Firebase Functions Setup Guide

## Overview
This Firebase Functions setup sends email notifications via SendGrid when alerts are created in your Personal Development Hub app.

## Prerequisites
✅ SendGrid API key is already configured in Firebase Functions config

## Next Steps

### 1. Install Dependencies
Navigate to the `functions` directory and install the required packages:

```bash
cd functions
npm install
```

### 2. Update Sender Email
Before deploying, you need to update the sender email in `functions/index.js`:

1. Go to your SendGrid account
2. Verify a sender email address (Settings → Sender Authentication)
3. Update line 99 in `functions/index.js`:
   ```javascript
   from: 'your-verified-email@yourdomain.com', // Replace with your verified sender email
   ```

### 3. Deploy Functions
Deploy the functions to Firebase:

```bash
# From the project root directory
firebase deploy --only functions
```

Or from the functions directory:
```bash
cd functions
npm run deploy
```

### 4. Verify Deployment
After deployment, check that the function is active:

```bash
firebase functions:list
```

## How It Works

The function `sendAlertEmail` is triggered automatically when a new document is created in the `alerts` Firestore collection. It:

1. Checks if the user has email notifications enabled
2. Retrieves the user's email address
3. Determines the alert type and generates appropriate email content
4. Sends the email via SendGrid

## Supported Email Types

- ⏰ Goal Due Soon
- ⚠️ Goal Overdue
- 🎉 Goal Completed
- 📢 Manager Nudges
- Goal Approval Requests (for managers)
- Goal Approval Decisions (approved/rejected)
- 🎉 New Season Started
- 🏆 Badge Earned
- 🚀 Level Up

## Testing

To test locally (requires Firebase Emulator Suite):

```bash
firebase emulators:start --only functions,firestore
```

## Troubleshooting

### Email Not Sending
1. Check Firebase Functions logs:
   ```bash
   firebase functions:log
   ```

2. Verify SendGrid API key is set:
   ```bash
   firebase functions:config:get
   ```

3. Ensure sender email is verified in SendGrid

### Function Not Triggering
1. Check Firestore security rules allow alert creation
2. Verify the function is deployed:
   ```bash
   firebase functions:list
   ```

## Important Notes

⚠️ **Sender Email**: You MUST update the sender email in `functions/index.js` with a verified SendGrid sender email, otherwise emails will fail to send.

⚠️ **Email Preferences**: Users can disable email notifications in their settings. The function respects this preference.

⚠️ **Rate Limits**: SendGrid has rate limits. For high-volume apps, consider implementing batching or queuing.

