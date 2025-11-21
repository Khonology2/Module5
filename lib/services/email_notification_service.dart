import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Free alternative to Firebase Functions for sending email notifications
/// Uses a free serverless function (Vercel/Netlify) or EmailJS
class EmailNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Option 1: Use a free Vercel/Netlify serverless function
  // Your deployed Vercel function URL
  static const String _emailApiUrl = 'https://pdh-email-ps5e3klci-siphos-projects-c258995d.vercel.app/api/send-email';
  
  // Option 2: Use EmailJS (free tier: 200 emails/month)
  // static const String _emailjsServiceId = 'your_service_id';
  // static const String _emailjsTemplateId = 'your_template_id';
  // static const String _emailjsPublicKey = 'your_public_key';

  /// Send email notification when alert is created
  /// Call this from your alert creation code
  static Future<void> sendAlertEmail({
    required String userId,
    required String alertType,
    required String title,
    required String message,
    String? goalTitle,
    String? relatedGoalId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if user wants email notifications
      final shouldSend = await _shouldSendEmail(userId);
      if (!shouldSend) {
        developer.log('User $userId has email notifications disabled');
        return;
      }

      // Get user email
      final userEmail = await _getUserEmail(userId);
      if (userEmail == null || userEmail.isEmpty) {
        developer.log('No email found for user $userId');
        return;
      }

      final userName = await _getUserDisplayName(userId);

      // Prepare email data
      final emailData = {
        'to': userEmail,
        'userName': userName,
        'alertType': alertType,
        'title': title,
        'message': message,
        'goalTitle': goalTitle,
        'relatedGoalId': relatedGoalId,
        'metadata': metadata,
      };

      // Send email via free serverless function
      await _sendEmailViaApi(emailData);
      
    } catch (e) {
      developer.log('Error sending email notification: $e');
      // Don't throw - email failures shouldn't break the app
    }
  }

  static Future<bool> _shouldSendEmail(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['emailNotifications'] != false;
      }
      return true; // Default to sending
    } catch (e) {
      developer.log('Error checking email preferences: $e');
      return true;
    }
  }

  static Future<String?> _getUserEmail(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData?['email'] != null) {
          return userData!['email'] as String;
        }
      }
      // Fallback to Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      return user?.email;
    } catch (e) {
      developer.log('Error getting user email: $e');
      return null;
    }
  }

  static Future<String> _getUserDisplayName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData?['displayName'] != null) {
          return userData!['displayName'] as String;
        }
      }
      final user = FirebaseAuth.instance.currentUser;
      return user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  /// Send email via free serverless API (Vercel/Netlify)
  static Future<void> _sendEmailViaApi(Map<String, dynamic> emailData) async {
    try {
      final response = await http.post(
        Uri.parse(_emailApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      if (response.statusCode == 200) {
        developer.log('Email sent successfully');
      } else {
        developer.log('Failed to send email: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error calling email API: $e');
    }
  }

  /// Alternative: Send via EmailJS (free tier: 200 emails/month)
  /// Uncomment and configure if you prefer EmailJS
  /*
  static Future<void> _sendEmailViaEmailJS(Map<String, dynamic> emailData) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _emailjsServiceId,
          'template_id': _emailjsTemplateId,
          'user_id': _emailjsPublicKey,
          'template_params': {
            'to_email': emailData['to'],
            'user_name': emailData['userName'],
            'alert_title': emailData['title'],
            'alert_message': emailData['message'],
          },
        }),
      );

      if (response.statusCode == 200) {
        developer.log('Email sent via EmailJS');
      }
    } catch (e) {
      developer.log('Error sending via EmailJS: $e');
    }
  }
  */
}

