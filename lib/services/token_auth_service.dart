import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/config/env_config.dart';

/// Service to handle token-based authentication from external systems
/// Tokens are now directly in JWT format (no Fernet encryption)
class TokenAuthService {
  TokenAuthService._internal();
  static final TokenAuthService instance = TokenAuthService._internal();

  // Note: JWT tokens are now used directly without Fernet encryption
  // JWT_SECRET_KEY is reserved for future signature verification if needed
  // ignore: unused_element
  static String? get _jwtSecretKey {
    // Priority 1: Try build-time injected config (for web deployments on Render)
    if (EnvConfig.jwtSecretKey != null && EnvConfig.jwtSecretKey!.isNotEmpty) {
      debugPrint('JWT_SECRET_KEY loaded from build-time config');
      return EnvConfig.jwtSecretKey;
    }

    // Priority 2: Try .env file (for local development)
    final envKey = dotenv.env['JWT_SECRET_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      debugPrint('JWT_SECRET_KEY loaded from .env file');
      return envKey;
    }

    debugPrint('JWT_SECRET_KEY not found - JWT verification will not work');
    return null;
  }

  /// Extract token from URL query parameters
  /// Supports both web (dart:html) and mobile (deep links)
  /// Automatically handles URL encoding/decoding
  Future<String?> extractTokenFromUrl() async {
    try {
      if (kIsWeb) {
        // For web, use Uri to parse current URL
        final uri = Uri.base;

        // Try to get token from query parameters
        String? token = uri.queryParameters['token'];

        // If token is found, decode it (in case it's URL-encoded)
        if (token != null && token.isNotEmpty) {
          // Uri.queryParameters already decodes URL-encoded values, but let's ensure it's clean
          token = Uri.decodeComponent(token);
          debugPrint(
            'Token extracted from query parameters: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
          );
          return token;
        }

        // Also check hash fragment for SPA routing (common in single-page apps)
        final hash = uri.fragment;
        if (hash.isNotEmpty) {
          // Try to parse hash as query string
          if (hash.contains('token=')) {
            final hashParams = Uri.splitQueryString(hash);
            token = hashParams['token'];
            if (token != null && token.isNotEmpty) {
              token = Uri.decodeComponent(token);
              debugPrint(
                'Token extracted from hash fragment: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
              );
              return token;
            }
          }
        }

        // Also check the full URL string in case token is embedded differently
        final fullUrl = uri.toString();
        if (fullUrl.contains('token=')) {
          final urlUri = Uri.parse(fullUrl);
          token = urlUri.queryParameters['token'];
          if (token != null && token.isNotEmpty) {
            token = Uri.decodeComponent(token);
            debugPrint(
              'Token extracted from full URL: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
            );
            return token;
          }
        }

        debugPrint('No token found in URL');
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

  /// Decode JWT token directly (no decryption needed)
  /// Token is now directly in JWT format
  /// Returns the decoded JWT payload, or null if decoding fails
  Map<String, dynamic>? decodeJwtToken(String jwtToken) {
    try {
      // Check expiration first
      if (JwtDecoder.isExpired(jwtToken)) {
        debugPrint('JWT token is expired');
        return null;
      }

      // Decode the JWT
      final decoded = JwtDecoder.decode(jwtToken);

      // Validate required fields
      if (!decoded.containsKey('email') && !decoded.containsKey('user_id')) {
        debugPrint('JWT token missing required fields (email or user_id)');
        return null;
      }

      debugPrint(
        'JWT decoded successfully. Fields: ${decoded.keys.join(", ")}',
      );
      return decoded;
    } catch (e) {
      debugPrint('Error decoding JWT token: $e');
      return null;
    }
  }

  /// Validate token structure and expiration
  /// Returns true if token is a valid JWT and not expired
  bool validateTokenStructure(String jwtToken) {
    try {
      // First, check if token looks like a JWT (has 3 parts separated by dots)
      final parts = jwtToken.split('.');
      if (parts.length != 3) {
        debugPrint(
          'Token does not have JWT format (expected 3 parts, got ${parts.length})',
        );
        return false;
      }

      // Try to decode to check if it's valid
      try {
        final decoded = JwtDecoder.decode(jwtToken);
        debugPrint(
          'Token decoded successfully. Claims: ${decoded.keys.join(", ")}',
        );
      } catch (decodeError) {
        debugPrint('Token decode failed: $decodeError');
        return false;
      }

      // Check expiration
      if (JwtDecoder.isExpired(jwtToken)) {
        debugPrint('Token is expired');
        return false;
      }

      debugPrint('Token structure is valid and not expired');
      return true;
    } catch (e) {
      debugPrint('Error validating token structure: $e');
      debugPrint(
        'Token value (first 50 chars): ${jwtToken.length > 50 ? jwtToken.substring(0, 50) : jwtToken}...',
      );
      return false;
    }
  }

  /// Decode JWT token to extract user information
  ///
  /// Expected JWT payload structure (from Khonobuzz):
  /// {
  ///   "user_id": "firebase_user_id",
  ///   "email": "user@example.com",
  ///   "module_role": "PDH - Employee" or "PDH - Manager",
  ///   "exp": 1234567890,  // Expiration timestamp
  ///   "iat": 1234567890   // Issued at timestamp
  /// }
  Map<String, dynamic>? decodeToken(String jwtToken) {
    return decodeJwtToken(jwtToken);
  }

  /// Extract user information from decoded JWT payload
  /// Matches the Khonobuzz JWT payload structure
  Map<String, dynamic>? extractUserInfo(Map<String, dynamic> decodedToken) {
    try {
      final userId = decodedToken['user_id'] as String?;
      final email = decodedToken['email'] as String?;
      final moduleRole = decodedToken['module_role'] as String?;
      final exp = decodedToken['exp'] as int?;
      final iat = decodedToken['iat'] as int?;

      if (email == null && userId == null) {
        debugPrint('JWT token missing both email and user_id');
        return null;
      }

      return {
        'userId': userId,
        'email': email,
        'moduleRole': moduleRole,
        'expiresAt': exp != null
            ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            : null,
        'issuedAt': iat != null
            ? DateTime.fromMillisecondsSinceEpoch(iat * 1000)
            : null,
      };
    } catch (e) {
      debugPrint('Error extracting user info from JWT: $e');
      return null;
    }
  }

  /// Process JWT token: decode directly (no decryption needed)
  /// Handles the full flow: JWT decode
  Future<Map<String, dynamic>?> processJwtToken(String jwtToken) async {
    try {
      // Decode the JWT directly
      final decoded = decodeToken(jwtToken);
      if (decoded == null) {
        debugPrint('Failed to decode JWT token');
        return null;
      }

      return decoded;
    } catch (e) {
      debugPrint('Error processing JWT token: $e');
      return null;
    }
  }

  /// Query onboarding collection to validate token and get user info
  /// This method can work with or without email - it queries by token directly
  Future<Map<String, dynamic>?> validateTokenWithOnboarding(
    String token,
    String? email,
  ) async {
    try {
      // First, try to query by token directly (most reliable)
      QuerySnapshot querySnapshot;

      try {
        querySnapshot = await FirebaseFirestore.instance
            .collection('onboarding')
            .where('token', isEqualTo: token)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) {
            debugPrint('Onboarding document has no data');
            return null;
          }

          // Get fields from onboarding document based on actual collection structure
          // Fields: moduleAccessRole (or role), status, user_id, token, etc.
          // Note: Some documents may use 'role' instead of 'moduleAccessRole'
          // Email is optional and will be retrieved from users collection if needed

          // Try moduleAccessRole first, then fall back to role
          final moduleAccessRole =
              data['moduleAccessRole'] as String? ??
              data['moduleRole'] as String? ??
              data['role'] as String?;
          final status = data['status'] as String?;
          // Try multiple field names for user_id, and use document ID as fallback
          final userId =
              data['user_id'] as String? ??
              data['userId'] as String? ??
              data['onboarding_id'] as String? ??
              doc.id; // Use document ID as fallback if no user_id field exists

          if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
            debugPrint('No moduleAccessRole/role found in onboarding document');
            debugPrint('Available fields: ${data.keys.join(", ")}');
            return null;
          }

          // Check if user status is Active (required for login)
          if (status != null && status != 'Active') {
            debugPrint(
              'User status is not Active: $status. Cannot proceed with login.',
            );
            return null;
          }

          debugPrint(
            'Token validated successfully by querying onboarding collection directly',
          );

          // Validate that user_id exists (required for authentication)
          // Since we use doc.id as fallback, userId should always have a value, but check for empty string
          if (userId.isEmpty) {
            debugPrint(
              'No user_id found in onboarding document - cannot proceed with authentication',
            );
            debugPrint('Available fields: ${data.keys.join(", ")}');
            return null;
          }

          debugPrint(
            'Onboarding validation - Status: $status, User ID: $userId, ModuleAccessRole: $moduleAccessRole',
          );
          debugPrint('Onboarding document fields: ${data.keys.join(", ")}');

          // Try to get email from users collection using user_id (optional, for user document)
          String? resolvedEmail;
          if (userId.isNotEmpty) {
            try {
              debugPrint('Checking users collection for user_id: $userId');
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data();
                if (userData is Map<String, dynamic>) {
                  resolvedEmail = userData['email'] as String?;
                  if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
                    debugPrint(
                      'Email retrieved from users collection: $resolvedEmail',
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint('Error querying users collection: $e');
            }
          }

          // Return all relevant data from onboarding collection
          // user_id is the primary identifier, email is optional
          return {
            'email': resolvedEmail ?? '', // Optional - may be empty
            'moduleAccessRole': moduleAccessRole,
            'token': token,
            'onboardingDocId': doc.id,
            'status': status,
            'userId': userId,
            'user_id': userId, // Primary identifier - required
          };
        }
      } catch (e) {
        debugPrint('Error querying onboarding by token: $e');
      }

      // Fallback: If email is provided, query by email and verify token
      if (email != null && email.isNotEmpty) {
        try {
          querySnapshot = await FirebaseFirestore.instance
              .collection('onboarding')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (querySnapshot.docs.isEmpty) {
            debugPrint('No onboarding record found for email: $email');
            return null;
          }

          final doc = querySnapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) {
            debugPrint('Onboarding document has no data for email: $email');
            return null;
          }

          // Check if token matches
          final storedToken = data['token'] as String?;
          if (storedToken == null || storedToken != token) {
            debugPrint('Token mismatch for email: $email');
            return null;
          }

          // Get moduleAccessRole - try multiple field names
          final moduleAccessRole =
              data['moduleAccessRole'] as String? ??
              data['moduleRole'] as String? ??
              data['role'] as String?;
          if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
            debugPrint('No moduleAccessRole/role found for email: $email');
            debugPrint('Available fields: ${data.keys.join(", ")}');
            return null;
          }

          debugPrint(
            'Token validated successfully by querying onboarding collection by email',
          );
          return {
            'email': email,
            'moduleAccessRole': moduleAccessRole,
            'token': token,
            'onboardingDocId': doc.id,
          };
        } catch (e) {
          debugPrint('Error querying onboarding by email: $e');
        }
      }

      debugPrint(
        'Token validation failed - token not found in onboarding collection',
      );
      return null;
    } catch (e) {
      debugPrint('Error validating token with onboarding: $e');
      return null;
    }
  }

  /// Extract module role from JWT token or onboarding data
  /// Handles both 'module_role' (from JWT) and 'moduleAccessRole' (from database)
  /// Also handles comma-separated roles and extracts the PDH role
  String? extractModuleRole(
    Map<String, dynamic>? jwtToken,
    Map<String, dynamic>? onboardingData,
  ) {
    // First try JWT token (module_role)
    if (jwtToken != null) {
      final moduleRole = jwtToken['module_role'] as String?;
      if (moduleRole != null && moduleRole.isNotEmpty) {
        // Extract PDH role from comma-separated list if needed
        final pdhRole = _extractPdhRole(moduleRole);
        if (pdhRole != null) {
          debugPrint(
            'Module role found in JWT token: $pdhRole (extracted from: $moduleRole)',
          );
          return pdhRole;
        }
      }
    }

    // Fallback to onboarding collection (moduleAccessRole, moduleRole, or role)
    if (onboardingData != null) {
      // Try multiple field names for module access role
      final moduleAccessRole =
          onboardingData['moduleAccessRole'] as String? ??
          onboardingData['moduleRole'] as String? ??
          onboardingData['role'] as String?;
      if (moduleAccessRole != null && moduleAccessRole.isNotEmpty) {
        // Extract PDH role from comma-separated list if needed
        final pdhRole = _extractPdhRole(moduleAccessRole);
        if (pdhRole != null) {
          debugPrint(
            'Module role found in onboarding data: $pdhRole (extracted from: $moduleAccessRole)',
          );
          return pdhRole;
        }
      }
    }

    debugPrint('No module role found in JWT token or onboarding data');
    return null;
  }

  /// Extract PDH role from a comma-separated list of roles
  /// Looks for "PDH - Employee" or "PDH - Manager" in the string
  String? _extractPdhRole(String rolesString) {
    if (rolesString.isEmpty) return null;

    // Split by comma and trim each role
    final roles = rolesString.split(',').map((r) => r.trim()).toList();

    // Look for PDH roles
    for (final role in roles) {
      if (role.contains('PDH')) {
        // Extract the full PDH role (e.g., "PDH - Employee" or "PDH - Manager")
        if (role.contains('PDH - Employee') || role.contains('PDH-Employee')) {
          return 'PDH - Employee';
        } else if (role.contains('PDH - Manager') ||
            role.contains('PDH-Manager')) {
          return 'PDH - Manager';
        } else if (role.contains('PDH')) {
          // If it just says "PDH", try to determine from context
          // Check if it's followed by Employee or Manager
          final lowerRole = role.toLowerCase();
          if (lowerRole.contains('employee')) {
            return 'PDH - Employee';
          } else if (lowerRole.contains('manager')) {
            return 'PDH - Manager';
          }
        }
      }
    }

    // If no PDH role found, return the original string (for backward compatibility)
    return rolesString;
  }

  /// Map moduleAccessRole to internal role
  /// Handles both database field (moduleAccessRole) and JWT field (module_role)
  String? mapModuleAccessRoleToRole(String? moduleAccessRole) {
    if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
      return null;
    }

    // Normalize the role string (trim whitespace, handle variations)
    final normalized = moduleAccessRole.trim();

    if (normalized == 'PDH - Employee' || normalized == 'PDH-Employee') {
      return 'employee';
    } else if (normalized == 'PDH - Manager' || normalized == 'PDH-Manager') {
      return 'manager';
    }

    debugPrint('Unknown moduleAccessRole: $moduleAccessRole');
    return null;
  }

  /// Auto-login user based on JWT token authentication
  /// Decodes JWT, validates with onboarding, and sets user role
  Future<Map<String, dynamic>?> autoLoginWithToken(String token) async {
    try {
      // Step 1: Validate token structure and check expiration
      if (!validateTokenStructure(token)) {
        return {'success': false, 'error': 'Token is invalid or expired'};
      }

      // Step 2: Decode JWT token directly
      final decodedToken = decodeToken(token);
      if (decodedToken == null) {
        return {'success': false, 'error': 'Failed to decode token'};
      }

      // Step 3: Extract email from token
      final email =
          decodedToken['email'] as String? ??
          decodedToken['sub'] as String? ??
          decodedToken['user_email'] as String?;

      if (email == null || email.isEmpty) {
        return {'success': false, 'error': 'Email not found in token'};
      }

      // Step 4: Validate token with onboarding Firestore collection
      final onboardingData = await validateTokenWithOnboarding(token, email);
      if (onboardingData == null) {
        return {
          'success': false,
          'error': 'Token validation failed or user not found in onboarding',
        };
      }

      // Step 5: Map moduleAccessRole to role
      final moduleAccessRole = onboardingData['moduleAccessRole'] as String?;
      if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
        return {
          'success': false,
          'error': 'No moduleAccessRole found in onboarding data',
        };
      }

      final role = mapModuleAccessRoleToRole(moduleAccessRole);
      if (role == null) {
        return {
          'success': false,
          'error': 'Invalid moduleAccessRole: $moduleAccessRole',
        };
      }

      // Step 6: Try to sign in with custom token from backend
      UserCredential? userCredential;
      try {
        userCredential = await BackendAuthService.instance
            .signInWithCustomToken(token);
        if (userCredential == null) {
          debugPrint('Backend service not available for custom token creation');
        }
      } catch (e) {
        debugPrint('Error during auto-login: $e');
        // Continue with role setup even if auth fails
      }

      // Step 7: Set user role in Firestore
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

  /// Authenticate user with JWT token and validate with onboarding Firestore
  /// Decodes JWT, extracts email, validates with onboarding collection, and routes based on role
  Future<Map<String, dynamic>?> authenticateExistingUserWithToken(
    String token,
  ) async {
    try {
      // Step 1: Validate token structure and check expiration
      if (!validateTokenStructure(token)) {
        return {'success': false, 'error': 'Token is invalid or expired'};
      }

      // Step 2: Decode JWT token directly
      final decodedToken = decodeToken(token);
      if (decodedToken == null) {
        return {'success': false, 'error': 'Failed to decode token'};
      }

      // Step 3: Extract email from decoded token
      final email =
          decodedToken['email'] as String? ??
          decodedToken['sub'] as String? ??
          decodedToken['user_email'] as String?;

      if (email == null || email.isEmpty) {
        return {'success': false, 'error': 'Email not found in token'};
      }

      // Step 4: Validate token with onboarding Firestore collection
      final onboardingData = await validateTokenWithOnboarding(token, email);
      if (onboardingData == null) {
        return {
          'success': false,
          'error': 'Token validation failed or user not found in onboarding',
        };
      }

      // Step 5: Extract moduleAccessRole from onboarding data
      final moduleAccessRole = onboardingData['moduleAccessRole'] as String?;
      if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
        return {
          'success': false,
          'error': 'No moduleAccessRole found in onboarding data',
        };
      }

      // Step 6: Map moduleAccessRole to internal role
      final role = mapModuleAccessRoleToRole(moduleAccessRole);
      if (role == null) {
        return {
          'success': false,
          'error': 'Invalid moduleAccessRole: $moduleAccessRole',
        };
      }

      // Step 7: Get or create Firebase Auth user
      User? user = FirebaseAuth.instance.currentUser;

      // If no current user, try to sign in with custom token from backend
      if (user == null) {
        try {
          final userCredential = await BackendAuthService.instance
              .signInWithCustomToken(token);
          if (userCredential != null && userCredential.user != null) {
            user = userCredential.user;
          }
        } catch (e) {
          debugPrint('Error signing in with custom token: $e');
          // Continue without Firebase Auth user - we can still set role
        }
      }

      // Step 8: Update user role in Firestore if we have a user
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
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
        'userId': user?.uid,
      };
    } catch (e) {
      debugPrint('Error in authenticateExistingUserWithToken: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
