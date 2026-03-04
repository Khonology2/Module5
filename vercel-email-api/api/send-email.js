const sgMail = require('@sendgrid/mail');

// Get SendGrid API key from environment variable (set in Vercel dashboard)
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Email templates matching your Firebase Functions templates
const emailTemplates = {
  goalDueSoon: (userName, goalTitle, daysLeft) => ({
    subject: `⏰ Goal Due Soon: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Goal Due Soon ⏰</h2>
        <p>Hi ${userName},</p>
        <p>Your goal <strong>"${goalTitle}"</strong> is due in ${daysLeft} day${daysLeft === 1 ? '' : 's'}.</p>
        <p>Keep pushing! You've got this! 💪</p>
        <a href="https://pdh-v2.web.app/my_goal_workspace" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Goal</a>
      </div>
    `,
  }),
  goalOverdue: (userName, goalTitle, daysOverdue) => ({
    subject: `⚠️ Goal Overdue: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Goal Overdue ⚠️</h2>
        <p>Hi ${userName},</p>
        <p>Your goal <strong>"${goalTitle}"</strong> is overdue by ${daysOverdue} day${daysOverdue === 1 ? '' : 's'}.</p>
        <p>Don't give up! You can still complete it! 💪</p>
        <a href="https://pdh-v2.web.app/my_goal_workspace" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Goal</a>
      </div>
    `,
  }),
  goalCompleted: (userName, goalTitle, points) => ({
    subject: `🎉 Goal Completed: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Goal Completed! 🎉</h2>
        <p>Hi ${userName},</p>
        <p>Congratulations! You completed <strong>"${goalTitle}"</strong> and earned <strong>${points} points</strong>!</p>
        <p>Keep up the amazing work! 🌟</p>
        <a href="https://pdh-v2.web.app/progress_visuals" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Progress</a>
      </div>
    `,
  }),
  managerNudge: (userName, managerName, goalTitle, nudgeMessage) => ({
    subject: `📢 Manager Nudge: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Manager Nudge 📢</h2>
        <p>Hi ${userName},</p>
        <p><strong>${managerName}</strong> sent you a nudge about your goal <strong>"${goalTitle}"</strong>:</p>
        <p style="background-color: #f5f5f5; padding: 15px; border-left: 4px solid #C10D00; margin: 20px 0;">${nudgeMessage}</p>
        <a href="https://pdh-v2.web.app/my_goal_workspace" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Goal</a>
      </div>
    `,
  }),
  goalApprovalRequested: (managerName, employeeName, goalTitle) => ({
    subject: `Goal Approval Needed: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Goal Approval Needed</h2>
        <p>Hi ${managerName},</p>
        <p><strong>${employeeName}</strong> submitted a new goal: <strong>"${goalTitle}"</strong>.</p>
        <p>Please review and approve or reject.</p>
        <a href="https://pdh-v2.web.app/manager_alerts_nudges" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">Review Goal</a>
      </div>
    `,
  }),
  goalApprovalDecision: (userName, goalTitle, approved, reason) => ({
    subject: approved ? `✅ Goal Approved: "${goalTitle}"` : `❌ Goal Rejected: "${goalTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">${approved ? 'Goal Approved ✅' : 'Goal Rejected ❌'}</h2>
        <p>Hi ${userName},</p>
        <p>Your goal <strong>"${goalTitle}"</strong> has been ${approved ? 'approved' : 'rejected'}.</p>
        ${reason ? `<p><strong>Reason:</strong> ${reason}</p>` : ''}
        ${approved ? '<p>You can start working on your goal now!</p>' : ''}
        <a href="https://pdh-v2.web.app/my_goal_workspace" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Goal</a>
      </div>
    `,
  }),
  newSeason: (userName, seasonTitle, theme) => ({
    subject: `🎉 New Season Started: "${seasonTitle}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">New Season Started! 🎉</h2>
        <p>Hi ${userName},</p>
        <p>A new <strong>"${seasonTitle}"</strong> season on theme <strong>"${theme}"</strong> has started!</p>
        <p>Join and earn points! 🏆</p>
        <a href="https://pdh-v2.web.app/season_challenges" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Seasons</a>
      </div>
    `,
  }),
  badgeEarned: (userName, badgeName) => ({
    subject: `🏆 Badge Earned: "${badgeName}"`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Badge Earned! 🏆</h2>
        <p>Hi ${userName},</p>
        <p>You've earned the <strong>"${badgeName}"</strong> badge!</p>
        <p>Keep up the great work! 🌟</p>
        <a href="https://pdh-v2.web.app/badges_points" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Badges</a>
      </div>
    `,
  }),
  levelUp: (userName, newLevel) => ({
    subject: `🚀 Level Up! You've reached Level ${newLevel}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #C10D00;">Level Up! 🚀</h2>
        <p>Hi ${userName},</p>
        <p>Congratulations! You've reached <strong>Level ${newLevel}</strong>!</p>
        <p>Your dedication is paying off! 💪</p>
        <a href="https://pdh-v2.web.app/employee_profile" style="background-color: #C10D00; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px;">View Profile</a>
      </div>
    `,
  }),
};

export default async function handler(req, res) {
  // CORS headers for Flutter web
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const {
      to,
      userName,
      alertType,
      title,
      message,
      goalTitle,
      relatedGoalId,
      metadata,
    } = req.body;

    // Validate required fields
    if (!to || !userName || !alertType) {
      return res.status(400).json({ error: 'Missing required fields: to, userName, alertType' });
    }

    // Check if SendGrid is configured
    if (!process.env.SENDGRID_API_KEY) {
      console.error('SENDGRID_API_KEY not configured');
      return res.status(500).json({ error: 'Email service not configured' });
    }

    let emailContent;

    // Determine email template based on alert type
    switch (alertType) {
      case 'goalDueSoon':
      case 'goal_due_soon': {
        const daysLeft = parseInt(message?.match(/(\d+)\s+day/)?.[1] || '7');
        emailContent = emailTemplates.goalDueSoon(userName, goalTitle || 'Your goal', daysLeft);
        break;
      }
      case 'goalOverdue':
      case 'goal_overdue': {
        const daysOverdue = parseInt(message?.match(/(\d+)\s+day/)?.[1] || '1');
        emailContent = emailTemplates.goalOverdue(userName, goalTitle || 'Your goal', daysOverdue);
        break;
      }
      case 'goalCompleted':
      case 'goal_completed': {
        const points = parseInt(message?.match(/(\d+)\s+points/)?.[1] || '0');
        emailContent = emailTemplates.goalCompleted(userName, goalTitle || 'Your goal', points);
        break;
      }
      case 'managerNudge':
      case 'manager_nudge': {
        const managerName = metadata?.managerName || 'Your manager';
        const nudgeMessage = message?.split(': ')?.[1] || message;
        emailContent = emailTemplates.managerNudge(userName, managerName, goalTitle || 'your goal', nudgeMessage);
        break;
      }
      case 'goalApprovalRequested':
      case 'goal_approval_requested': {
        const employeeName = message?.split(' submitted')[0] || 'An employee';
        emailContent = emailTemplates.goalApprovalRequested(userName, employeeName, goalTitle || 'a goal');
        break;
      }
      case 'goalApprovalApproved':
      case 'goal_approval_approved':
      case 'goalApprovalRejected':
      case 'goal_approval_rejected': {
        const approved = alertType === 'goalApprovalApproved' || alertType === 'goal_approval_approved';
        const reason = metadata?.reason || null;
        emailContent = emailTemplates.goalApprovalDecision(userName, goalTitle || 'your goal', approved, reason);
        break;
      }
      case 'season_available':
      case 'seasonAvailable': {
        const seasonTitle = metadata?.seasonTitle || message?.match(/"([^"]+)"/)?.[1] || 'New Season';
        const theme = metadata?.theme || message?.match(/theme "([^"]+)"/)?.[1] || 'Development';
        emailContent = emailTemplates.newSeason(userName, seasonTitle, theme);
        break;
      }
      case 'badgeEarned':
      case 'badge_earned': {
        const badgeName = message?.match(/"([^"]+)"/)?.[1] || 'a badge';
        emailContent = emailTemplates.badgeEarned(userName, badgeName);
        break;
      }
      case 'levelUp':
      case 'level_up': {
        const level = parseInt(message?.match(/Level (\d+)/)?.[1] || '1');
        emailContent = emailTemplates.levelUp(userName, level);
        break;
      }
      default:
        // Generic email for unknown types
        emailContent = {
          subject: title || 'Notification from Personal Development Hub',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #C10D00;">${title || 'Notification'}</h2>
              <p>Hi ${userName},</p>
              <p>${message || 'You have a new notification.'}</p>
            </div>
          `,
        };
    }

    // Send email via SendGrid
    await sgMail.send({
      to,
      from: 'personaldevhub@hotmail.com',
      subject: emailContent.subject,
      html: emailContent.html,
    });

    return res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error) {
    console.error('Error sending email:', error);
    return res.status(500).json({
      error: 'Failed to send email',
      details: error.message,
    });
  }
}

