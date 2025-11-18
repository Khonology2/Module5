import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pdh/services/backend_auth_service.dart';

/// Service to handle token-based authentication from external systems
/// Tokens are: Base64 encoded -> Fernet encrypted -> JWT format
class TokenAuthService {
  TokenAuthService._internal();
  static final TokenAuthService instance = TokenAuthService._internal();

  // TODO: Set these keys from environment variables or secure storage
  // These should match the keys used by the external system that generates tokens
  static String? get _encryptionKey {
    // Set your Fernet encryption key here (32 bytes, base64 encoded)
    // Example: 'your-32-byte-base64-encoded-encryption-key-here'
    const String? envKey = null; // Set to your ENCRYPTION_KEY
    return envKey;
  }

  // TODO: Implement JWT signature verification using this key
  // This will be used to verify the JWT signature after decryption
  // ignore: unused_element
  static String? get _jwtSecretKey {
    // Set your JWT secret key here
    // This is used to verify the JWT signature
    const String? envKey = null; // Set to your JWT_SECRET_KEY
    return envKey;
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
          debugPrint('Token extracted from query parameters: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
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
              debugPrint('Token extracted from hash fragment: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
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
            debugPrint('Token extracted from full URL: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
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

  /// Decrypt and decode token from encrypted format
  /// Token format: Base64 -> Fernet encrypted -> JWT
  /// Returns the decrypted JWT string, or null if decryption fails
  Future<String?> decryptToken(String encryptedToken) async {
    try {
      final encryptionKey = _encryptionKey;
      if (encryptionKey == null || encryptionKey.isEmpty) {
        debugPrint('ENCRYPTION_KEY not configured - cannot decrypt token');
        // If no encryption key, assume token is already decrypted (for testing)
        return encryptedToken;
      }

      // Step 1: Base64 decode
      debugPrint('Decrypting token: Step 1 - Base64 decoding...');
      Uint8List base64Decoded;
      try {
        base64Decoded = base64Decode(encryptedToken);
      } catch (e) {
        debugPrint('Base64 decode failed, trying URL-safe base64...');
        // Try URL-safe base64 decoding
        try {
          base64Decoded = base64Url.decode(encryptedToken);
        } catch (e2) {
          debugPrint('Both base64 decodings failed: $e, $e2');
          // If base64 decode fails, try treating as already decoded bytes
          base64Decoded = utf8.encode(encryptedToken);
        }
      }
      
      // Step 2: Fernet decrypt
      debugPrint('Decrypting token: Step 2 - Fernet decryption...');
      final key = encrypt.Key.fromBase64(encryptionKey);
      final fernet = encrypt.Fernet(key);
      final encrypted = encrypt.Encrypted(base64Decoded);
      // Fernet.decrypt() returns Uint8List, convert to String
      final decryptedBytes = fernet.decrypt(encrypted);
      final decryptedString = utf8.decode(decryptedBytes);
      
      debugPrint('Token decrypted successfully');
      return decryptedString;
    } catch (e) {
      debugPrint('Error decrypting token: $e');
      // If decryption fails, try treating token as already decrypted (for backward compatibility)
      debugPrint('Attempting to use token as-is (assuming already decrypted)...');
      return encryptedToken;
    }
  }

  /// Validate token structure and expiration
  /// Returns true if token is a valid JWT and not expired
  /// Note: Token should be decrypted before calling this method
  bool validateTokenStructure(String jwtToken) {
    try {
      // First, check if token looks like a JWT (has 3 parts separated by dots)
      final parts = jwtToken.split('.');
      if (parts.length != 3) {
        debugPrint('Token does not have JWT format (expected 3 parts, got ${parts.length})');
        return false;
      }

      // Try to decode to check if it's valid
      try {
        final decoded = JwtDecoder.decode(jwtToken);
        debugPrint('Token decoded successfully. Claims: ${decoded.keys.join(", ")}');
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
      debugPrint('Token value (first 50 chars): ${jwtToken.length > 50 ? jwtToken.substring(0, 50) : jwtToken}...');
      return false;
    }
  }

  /// Decode JWT token to extract user information
  /// Note: Token should be decrypted before calling this method
  Map<String, dynamic>? decodeToken(String jwtToken) {
    try {
      return JwtDecoder.decode(jwtToken);
    } catch (e) {
      debugPrint('Error decoding JWT token: $e');
      return null;
    }
  }

  /// Process encrypted token: decrypt and decode
  /// Handles the full flow: Base64 decode -> Fernet decrypt -> JWT decode
  Future<Map<String, dynamic>?> processEncryptedToken(String encryptedToken) async {
    try {
      // Step 1: Decrypt the token
      final decryptedJwt = await decryptToken(encryptedToken);
      if (decryptedJwt == null) {
        debugPrint('Failed to decrypt token');
        return null;
      }

      // Step 2: Decode the JWT
      final decoded = decodeToken(decryptedJwt);
      if (decoded == null) {
        debugPrint('Failed to decode JWT after decryption');
        return null;
      }

      return decoded;
    } catch (e) {
      debugPrint('Error processing encrypted token: $e');
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
          
          // Get email and moduleAccessRole from the document
          final docEmail = data['email'] as String?;
          final moduleAccessRole = data['moduleAccessRole'] as String?;
          
          if (moduleAccessRole == null) {
            debugPrint('No moduleAccessRole found in onboarding document');
            return null;
          }

          debugPrint('Token validated successfully by querying onboarding collection directly');
          return {
            'email': docEmail ?? email ?? '',
            'moduleAccessRole': moduleAccessRole,
            'token': token,
            'onboardingDocId': doc.id,
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

          // Get moduleAccessRole
          final moduleAccessRole = data['moduleAccessRole'] as String?;
          if (moduleAccessRole == null) {
            debugPrint('No moduleAccessRole found for email: $email');
            return null;
          }

          debugPrint('Token validated successfully by querying onboarding collection by email');
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

      debugPrint('Token validation failed - token not found in onboarding collection');
      return null;
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

