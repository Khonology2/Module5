import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:pdh/services/backend_auth_service.dart';

/// Service to handle token-based authentication from external systems
class TokenAuthService {
  TokenAuthService._internal();
  static final TokenAuthService instance = TokenAuthService._internal();

  /// Extract token from URL query parameters
  /// Supports both web (dart:html) and mobile (deep links)
  Future<String?> extractTokenFromUrl() async {
    try {
      if (kIsWeb) {
        // For web, use Uri to parse current URL
        final uri = Uri.base;
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          return token;
        }
        
        // Also check hash fragment for SPA routing
        final hash = uri.fragment;
        if (hash.isNotEmpty) {
          final hashUri = Uri.parse('?$hash');
          return hashUri.queryParameters['token'];
        }
        
        return null;
      } else {
        // For mobile, check if we have a stored initial link
        // This would be set when app is opened via deep link
        // For now, we'll need to implement platform-specific handling
        // You can use uni_links package or handle via MethodChannel
        return null;
      }
    } catch (e) {
      debugPrint('Error extracting token from URL: $e');
      return null;
    }
  }
  
  /// Extract token from a specific URL string (useful for deep links)
  String? extractTokenFromUrlString(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      return uri.queryParameters['token'];
    } catch (e) {
      debugPrint('Error extracting token from URL string: $e');
      return null;
    }
  }

  /// Validate token structure and expiration
  bool validateTokenStructure(String token) {
    try {
      if (!JwtDecoder.isExpired(token)) {
        return true;
      }
      debugPrint('Token is expired');
      return false;
    } catch (e) {
      debugPrint('Error validating token structure: $e');
      return false;
    }
  }

  /// Decode JWT token to extract user information
  Map<String, dynamic>? decodeToken(String token) {
    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      debugPrint('Error decoding token: $e');
      return null;
    }
  }

  /// Query onboarding collection to validate token and get user info
  Future<Map<String, dynamic>?> validateTokenWithOnboarding(
    String token,
    String email,
  ) async {
    try {
      // Query onboarding collection by email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('onboarding')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No onboarding record found for email: $email');
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Check if token matches
      final storedToken = data['token'] as String?;
      if (storedToken == null || storedToken != token) {
        debugPrint('Token mismatch for email: $email');
        return null;
      }

      // Get moduleAccessRole
      final moduleAccessRole = data['moduleAccessRole'] as String?;
      if (moduleAccessRole == null) {
        debugPrint('No moduleAccessRole found for email: $email');
        return null;
      }

      return {
        'email': email,
        'moduleAccessRole': moduleAccessRole,
        'token': token,
        'onboardingDocId': doc.id,
      };
    } catch (e) {
      debugPrint('Error validating token with onboarding: $e');
      return null;
    }
  }

  /// Map moduleAccessRole to internal role
  String? mapModuleAccessRoleToRole(String moduleAccessRole) {
    if (moduleAccessRole == 'PDH - Employee') {
      return 'employee';
    } else if (moduleAccessRole == 'PDH - Manager') {
      return 'manager';
    }
    return null;
  }

  /// Auto-login user based on token authentication
  /// Creates or signs in the user and sets their role
  Future<Map<String, dynamic>?> autoLoginWithToken(String token) async {
    try {
      // Step 1: Validate token structure
      if (!validateTokenStructure(token)) {
        return {'success': false, 'error': 'Token is invalid or expired'};
      }

      // Step 2: Decode token to get user info
      final decodedToken = decodeToken(token);
      if (decodedToken == null) {
        return {'success': false, 'error': 'Failed to decode token'};
      }

      // Extract email from token (adjust field name based on your JWT structure)
      final email = decodedToken['email'] as String? ??
          decodedToken['sub'] as String? ??
          decodedToken['user_email'] as String?;
      
      if (email == null || email.isEmpty) {
        return {'success': false, 'error': 'Email not found in token'};
      }

      // Step 3: Validate token with onboarding collection
      final onboardingData =
          await validateTokenWithOnboarding(token, email);
      if (onboardingData == null) {
        return {
          'success': false,
          'error': 'Token validation failed or user not found in onboarding'
        };
      }

      // Step 4: Map moduleAccessRole to role
      final moduleAccessRole = onboardingData['moduleAccessRole'] as String;
      final role = mapModuleAccessRoleToRole(moduleAccessRole);
      if (role == null) {
        return {
          'success': false,
          'error': 'Invalid moduleAccessRole: $moduleAccessRole'
        };
      }

      // Step 5: Create or sign in user
      // Note: For token-based authentication, use BackendAuthService
      // to get a Firebase custom token from your backend API
      // This method is kept for backward compatibility but should use
      // BackendAuthService.instance.signInWithCustomToken() instead
      UserCredential? userCredential;
      
      // Try to use backend service to get custom token
      try {
        userCredential = await BackendAuthService.instance.signInWithCustomToken(token);
        if (userCredential == null) {
          debugPrint('Backend service not available for custom token creation');
        }
      } catch (e) {
        debugPrint('Error during auto-login: $e');
        // Continue with role setup even if auth fails
      }

      // Step 6: Set user role in Firestore
      final userId = userCredential?.user?.uid;
      if (userId != null) {
        // Update users collection with role and email
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'email': email,
          'role': role,
          'tokenAuthenticated': true,
          'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return {
        'success': true,
        'email': email,
        'role': role,
        'moduleAccessRole': moduleAccessRole,
        'userId': userId,
      };
    } catch (e) {
      debugPrint('Error in autoLoginWithToken: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Alternative method: Sign in existing user and set role based on token
  /// This assumes the user already has a Firebase Auth account
  Future<Map<String, dynamic>?> authenticateExistingUserWithToken(
    String token,
  ) async {
    try {
      // Validate and decode token
      if (!validateTokenStructure(token)) {
        return {'success': false, 'error': 'Token is invalid or expired'};
      }

      final decodedToken = decodeToken(token);
      if (decodedToken == null) {
        return {'success': false, 'error': 'Failed to decode token'};
      }

      final email = decodedToken['email'] as String? ??
          decodedToken['sub'] as String? ??
          decodedToken['user_email'] as String?;

      if (email == null || email.isEmpty) {
        return {'success': false, 'error': 'Email not found in token'};
      }

      // Validate with onboarding
      final onboardingData = await validateTokenWithOnboarding(token, email);
      if (onboardingData == null) {
        return {
          'success': false,
          'error': 'Token validation failed'
        };
      }

      // Get current user or find by email
      User? user = FirebaseAuth.instance.currentUser;
      
      // If no current user, try to find user by email
      if (user == null) {
        // Note: Firebase Auth doesn't provide a direct way to get user by email
        // You'll need to maintain a mapping or use Admin SDK
        // For now, we'll just set the role if user signs in later
        return {
          'success': false,
          'error': 'No authenticated user. Please sign in first.',
        };
      }

      // Map role
      final moduleAccessRole = onboardingData['moduleAccessRole'] as String;
      final role = mapModuleAccessRoleToRole(moduleAccessRole);
      if (role == null) {
        return {
          'success': false,
          'error': 'Invalid moduleAccessRole: $moduleAccessRole'
        };
      }

      // Update user role
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'role': role,
        'tokenAuthenticated': true,
        'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'success': true,
        'email': email,
        'role': role,
        'moduleAccessRole': moduleAccessRole,
        'userId': user.uid,
      };
    } catch (e) {
      debugPrint('Error in authenticateExistingUserWithToken: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

