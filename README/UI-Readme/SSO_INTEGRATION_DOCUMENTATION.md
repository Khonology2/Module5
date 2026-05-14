# Single Sign-On (SSO) Integration Documentation

## Overview

This document provides a comprehensive overview of the Single Sign-On (SSO) integration between the Personal Development Hub (PDH) Flutter application and the Khonobuzz/ConoBuzz authentication system. The integration uses JWT tokens for seamless authentication and automatic user login.

## Architecture Summary

The SSO integration follows this flow:
1. **Khonobuzz/ConoBuzz** generates a JWT token for authenticated users
2. **Token Delivery**: Token is passed to PDH via URL query parameter or manual entry
3. **Backend Validation**: PDH backend validates the JWT token and generates Firebase custom tokens
4. **Firebase Authentication**: Flutter app signs in with Firebase custom token
5. **Role-Based Routing**: Users are routed to appropriate dashboards based on their roles

## Key Components

### Backend Components

#### 1. JWT Validator (`backend/app/jwt_validator.py`)
- **Purpose**: Validates JWT tokens from Khonobuzz/ConoBuzz
- **Features**:
  - Supports both raw JWT and Fernet-encrypted tokens
  - Validates token signature using `JWT_SECRET_KEY`
  - Checks token expiration
  - Extracts user information (user_id, email) with flexible field mapping
- **Supported Field Names**:
  - User ID: `user_id`, `uid`, `sub`, `userId`
  - Email: `email`, `user_email`, `email_address`

#### 2. Authentication Routes (`backend/app/routes/auth.py`)
- **`/validate-token` endpoint**: Main token validation endpoint
  - Validates JWT token
  - Queries Firestore for user validation
  - Generates Firebase custom token
  - Returns user information and roles
- **`/auth-callback` endpoint**: Notifies backend of successful authentication

#### 3. Firestore Service (`backend/app/firestore_service.py`)
- Queries `onboarding` collection by user_id or email
- Validates user status is 'Active'
- Extracts `moduleAccessRole` for role determination
- Resolves email from Firestore if missing in JWT

#### 4. Configuration (`backend/app/config.py`)
- Environment variables:
  - `JWT_SECRET_KEY`: Secret for JWT validation
  - `ENCRYPTION_KEY`: For Fernet token decryption
  - `FIREBASE_SERVICE_ACCOUNT_JSON`: Firebase service account credentials

### Frontend Components

#### 1. Landing Screen (`lib/landing_screen.dart`)
- **Primary SSO entry point**
- Automatically extracts tokens from URL parameters
- Manual token input fallback
- Calls backend API for token validation
- Handles Firebase custom token sign-in
- Routes users based on role determination

#### 2. Token Auth Service (`lib/services/token_auth_service.dart`)
- Extracts tokens from URL query parameters
- Supports both web and mobile platforms
- Handles URL encoding/decoding
- Checks hash fragments for SPA routing

#### 3. Backend Auth Service (`lib/services/backend_auth_service.dart`)
- Communicates with backend API
- Handles token validation requests
- Manages Firebase custom token retrieval
- Implements retry logic with exponential backoff
- Calls authentication callback endpoint

#### 4. Auth Wrapper (`lib/auth_wrapper.dart`)
- Monitors Firebase authentication state
- Handles role-based routing after successful authentication
- Routes to `/manager_dashboard` or `/employee_dashboard`

#### 5. Environment Configuration (`lib/config/env_config.dart`)
- Auto-generated during build time
- Contains encryption keys and JWT secrets
- Injected from environment variables

## Token Flow Details

### 1. Token Extraction
```dart
// From URL parameter
final token = await TokenAuthService.extractTokenFromUrl();
```

### 2. Backend Validation
```dart
// Validate token and get Firebase custom token
final validationResponse = await BackendAuthService.instance.validateTokenWithBackend(token);
```

### 3. Firebase Sign-In
```dart
// Sign in with Firebase custom token
final userCredential = await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
```

### 4. Role Determination
```dart
// Extract PDH role from backend response
String? pdhRole;
if (roles.contains('PDH - Employee')) {
  pdhRole = 'PDH - Employee';
} else if (roles.contains('PDH - Admin')) {
  pdhRole = 'PDH - Admin';
}
```

## Environment Configuration

### Backend Environment Variables
```bash
JWT_SECRET_KEY=your_jwt_secret_here
ENCRYPTION_KEY=your_encryption_key_here
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
BACKEND_URL=https://pdh-backend.onrender.com
```

### Frontend Environment Variables
Injected during build time from `scripts/inject_env_vars.sh`:
```dart
static const String? encryptionKey = "your_encryption_key_here";
static const String? jwtSecretKey = "your_jwt_secret_here";
static const String? backendUrl = "https://pdh-backend.onrender.com";
```

## Role Mapping

The system maps external roles to internal PDH roles:

| External Role | Internal Role | Dashboard Route |
|---------------|---------------|-----------------|
| PDH - Employee | employee | `/employee_dashboard` |
| PDH - Admin | manager | `/manager_dashboard` |

## URL Structure

### SSO Login URL Format
```
https://your-pdh-app.com/?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Hash Fragment Support (for SPA routing)
```
https://your-pdh-app.com/#token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Security Features

### 1. Token Validation
- JWT signature verification using HS256 algorithm
- Token expiration checking
- Encrypted token support (Fernet)

### 2. User Validation
- Firestore user existence verification
- User status validation ('Active' only)
- Role-based access control

### 3. Network Security
- HTTPS requirement for production
- CORS configuration
- Request timeout handling (90 seconds)
- Retry logic with exponential backoff

## Error Handling

### Common Error Scenarios
1. **Missing Token**: Shows manual token input
2. **Invalid Token**: Displays error message, allows retry
3. **Expired Token**: Shows token expired message
4. **User Not Found**: Redirects to login screen
5. **Inactive User**: Shows access denied message
6. **Network Issues**: Retry with exponential backoff

### Error Response Format
```json
{
  "error": "JWTValidationError",
  "detail": "Token has expired"
}
```

## Integration Points

### Khonobuzz/ConoBuzz Integration
1. Generate JWT token with required claims:
   ```json
   {
     "user_id": "user123",
     "email": "user@example.com",
     "exp": 1640995200,
     "iat": 1640991600
   }
   ```

2. Sign token with shared `JWT_SECRET_KEY`
3. Redirect user to PDH with token in URL parameter

### Firebase Integration
1. Use Firebase Admin SDK for custom token generation
2. Custom tokens use user_id as UID
3. Firebase handles session management
4. Real-time authentication state monitoring

## Deployment Configuration

### Render Deployment
1. Set environment variables in Render dashboard
2. Configure build script to inject environment variables
3. Ensure CORS allows your domain
4. Set up health check endpoint

### Local Development
1. Create `.env` file with required variables
2. Use `http://127.0.0.1:8000` for backend URL
3. Test with both web and mobile platforms

## Monitoring and Logging

### Backend Logging
- Token validation attempts
- Firebase custom token generation
- Firestore query performance
- Error details with stack traces

### Frontend Logging
- Token extraction success/failure
- Backend API response times
- Authentication state changes
- Navigation events

## Testing Checklist

### Token Validation Testing
- [ ] Valid JWT token acceptance
- [ ] Invalid JWT token rejection
- [ ] Expired token handling
- [ ] Encrypted token decryption
- [ ] Missing token scenarios

### User Authentication Testing
- [ ] Active user login success
- [ ] Inactive user login rejection
- [ ] Non-existent user handling
- [ ] Email resolution from Firestore
- [ ] Role extraction and mapping

### Navigation Testing
- [ ] Employee dashboard routing
- [ ] Manager dashboard routing
- [ ] Invalid role fallback
- [ ] Authentication state persistence

### Error Handling Testing
- [ ] Network timeout scenarios
- [ ] Backend unavailable handling
- [ ] Malformed token responses
- [ ] Firebase authentication failures

## Troubleshooting Guide

### Common Issues

1. **Token Not Found in URL**
   - Check URL parameter formatting
   - Verify URL encoding/decoding
   - Ensure proper redirect from Khonobuzz

2. **JWT Validation Failed**
   - Verify `JWT_SECRET_KEY` matches between systems
   - Check token algorithm (HS256)
   - Validate token structure (3 parts)

3. **Firebase Custom Token Error**
   - Verify Firebase service account JSON
   - Check Firebase project configuration
   - Ensure user_id format compatibility

4. **User Not Found in Firestore**
   - Verify onboarding collection data
   - Check user_id/email matching
   - Validate user status field

5. **Role Determination Issues**
   - Check `moduleAccessRole` field format
   - Verify role mapping logic
   - Validate PDH role prefixes

## Future Enhancements

### Potential Improvements
1. **OAuth 2.0 Integration**: Standard OAuth flow for broader compatibility
2. **Multi-Provider Support**: Support for multiple identity providers
3. **Token Refresh**: Automatic token refresh for extended sessions
4. **Enhanced Logging**: Structured logging with correlation IDs
5. **Rate Limiting**: API rate limiting for security
6. **Audit Trail**: Comprehensive authentication audit logging

### Scalability Considerations
1. **Caching**: Implement Redis caching for token validation
2. **Load Balancing**: Multiple backend instances with session affinity
3. **Database Optimization**: Indexed queries for user lookups
4. **Monitoring**: Application performance monitoring (APM)

## Conclusion

This SSO integration provides a seamless authentication experience for users moving between Khonobuzz/ConoBuzz and the Personal Development Hub. The system is designed with security, reliability, and scalability in mind, while maintaining flexibility for future enhancements.

The integration successfully bridges the gap between external authentication systems and Firebase-based applications, providing a robust foundation for single sign-on capabilities.
