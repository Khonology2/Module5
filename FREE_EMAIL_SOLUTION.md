# Free Email Notification Solution (No Billing Required)

Since you can't use Firebase Blaze plan, here are **FREE alternatives** that don't require billing:

## Option 1: Vercel Serverless Functions (Recommended - FREE)

Vercel offers free serverless functions that can send emails via SendGrid.

### Setup Steps:

1. **Create a Vercel account** (free): https://vercel.com

2. **Create the serverless function**:
   - Create a new folder: `vercel-email-api`
   - Create `api/send-email.js`:

```javascript
const sgMail = require('@sendgrid/mail');

// Set your SendGrid API key as environment variable in Vercel
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { to, userName, alertType, title, message, goalTitle } = req.body;

  const emailTemplates = {
    goalDueSoon: {
      subject: `⏰ Goal Due Soon: "${goalTitle}"`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #C10D00;">Goal Due Soon ⏰</h2>
          <p>Hi ${userName},</p>
          <p>Your goal <strong>"${goalTitle}"</strong> is due soon.</p>
          <p>Keep pushing! You've got this! 💪</p>
        </div>
      `,
    },
    // Add other templates...
  };

  const template = emailTemplates[alertType] || {
    subject: title,
    html: `<p>${message}</p>`,
  };

  try {
    await sgMail.send({
      to,
      from: 'personaldevhub@hotmail.com',
      subject: template.subject,
      html: template.html,
    });
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).json({ error: 'Failed to send email' });
  }
}
```

3. **Deploy to Vercel**:
   ```bash
   npm install -g vercel
   cd vercel-email-api
   vercel
   ```

4. **Set environment variable**:
   - In Vercel dashboard → Settings → Environment Variables
   - Add: `SENDGRID_API_KEY` = your SendGrid API key

5. **Update Flutter code**:
   - Update `lib/services/email_notification_service.dart`
   - Replace `_emailApiUrl` with your Vercel function URL

---

## Option 2: EmailJS (FREE - 200 emails/month)

EmailJS is completely free for up to 200 emails/month.

### Setup Steps:

1. **Sign up**: https://www.emailjs.com (free)

2. **Create email service**:
   - Connect your SendGrid account or use EmailJS's email service
   - Create email templates

3. **Get credentials**:
   - Service ID
   - Template ID  
   - Public Key

4. **Update Flutter code**:
   - Uncomment the EmailJS method in `email_notification_service.dart`
   - Add your credentials

---

## Option 3: Netlify Functions (FREE)

Similar to Vercel, Netlify offers free serverless functions.

1. **Sign up**: https://www.netlify.com (free)
2. **Create function**: `netlify/functions/send-email.js`
3. **Deploy**: Connect your GitHub repo or use Netlify CLI
4. **Set environment variables**: Add SendGrid API key

---

## Option 4: Railway (FREE tier available)

Railway offers a free tier with $5 credit/month.

1. **Sign up**: https://railway.app
2. **Create Express.js API**
3. **Deploy and set environment variables**

---

## Integration with Your Flutter App

After setting up one of the above options, update your alert creation code:

```dart
// In alert_service.dart, after creating an alert:
await EmailNotificationService.sendAlertEmail(
  userId: userId,
  alertType: alert.type.name,
  title: alert.title,
  message: alert.message,
  goalTitle: goal?.title,
  relatedGoalId: alert.relatedGoalId,
);
```

---

## Recommendation

**Use Vercel** - It's:
- ✅ Completely free
- ✅ Easy to set up
- ✅ No credit card required
- ✅ Generous free tier
- ✅ Works with SendGrid

The free tier includes:
- 100GB bandwidth/month
- Unlimited serverless function executions
- Perfect for email notifications

---

## Quick Start with Vercel

1. Install Vercel CLI: `npm install -g vercel`
2. Create the function file (see Option 1 above)
3. Run: `vercel` in the function directory
4. Add SendGrid API key as environment variable
5. Update Flutter code with the function URL

This solution requires **ZERO billing** and works perfectly for email notifications!

