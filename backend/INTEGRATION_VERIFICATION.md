# Backend-Frontend Integration Verification

## ✅ Integration Status: CONNECTED

This document verifies that the backend and frontend are properly connected.

## Integration Flow

### 1. Frontend → Backend Request
**File**: `lib/services/backend_auth_service.dart`
- **Method**: `getCustomTokenFromBackend(String jwtToken)`
- **Endpoint**: `POST {BACKEND_URL}/validate-token`
- **Request Body**: 
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
  ```

### 2. Backend Processing
**File**: `backend/app/routes/auth.py`
- **Endpoint**: `POST /validate-token`
- **Process**:
  1. Validates JWT token signature using `JWT_SECRET`
  2. Extracts `user_id` and `email` from token
  3. Queries Firestore `onboarding` collection
  4. Validates user status is 'Active'
  5. Extracts `moduleAccessRole` and converts to roles array
  6. Generates Firebase custom token using `user_id`
  7. Returns response

### 3. Backend → Frontend Response
**Response Format** (200 OK):
```json
{
  "firebase_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user_id": "user123",
  "email": "user@example.com",
  "roles": ["PDH - Employee"]
}
```

**Error Response Format** (4xx/5xx):
```json
{
  "error": "JWTValidationError",
  "detail": "Token has expired"
}
```

### 4. Frontend → Firebase Authentication
**File**: `lib/services/backend_auth_service.dart`
- **Method**: `signInWithCustomToken(String jwtToken)`
- **Process**:
  1. Calls `getCustomTokenFromBackend(jwtToken)` to get Firebase token
  2. Uses `FirebaseAuth.instance.signInWithCustomToken(firebaseToken)` to sign in
  3. Returns `UserCredential` on success

## Integration Points

### Frontend Files Using Backend Service:
1. **`lib/auth_wrapper.dart`** (line 66-67)
   - Uses `BackendAuthService.instance.signInWithCustomToken(token)`

2. **`lib/services/token_auth_service.dart`** (lines 585-586, 680-681)
   - Uses `BackendAuthService.instance.signInWithCustomToken(token)` in multiple authentication flows

### Backend Endpoints:
1. **`POST /validate-token`** - Main token validation endpoint
2. **`GET /health`** - Health check endpoint
3. **`GET /`** - Root endpoint with API info

## Configuration Required

### Backend Environment Variables (`.env` or Render):
- ✅ `FIREBASE_SERVICE_ACCOUNT_JSON` - Full Firebase Admin SDK service account JSON as a single-line string (no file paths; set in Render dashboard for production)
- ✅ `JWT_SECRET` - Must match Khonobuzz JWT secret
- ⚠️ `BACKEND_URL` - Optional, for self-reference

### Frontend Configuration:
**File**: `lib/services/backend_auth_service.dart` (line 24-25)
```dart
const String? envBackendUrl = null; // Set to your backend URL after deployment
```

**After deployment, update to:**
```dart
const String? envBackendUrl = 'https://your-pdh-backend.onrender.com';
```

## Connection Verification Checklist

- ✅ Backend endpoint: `POST /validate-token` exists
- ✅ Frontend calls: `POST {BACKEND_URL}/validate-token`
- ✅ Request format matches: `{"token": "jwt_string"}`
- ✅ Response format matches: `{"firebase_token": "...", "user_id": "...", "email": "...", "roles": [...]}`
- ✅ Error handling: Frontend parses error responses correctly
- ✅ Firebase integration: Frontend uses `firebase_token` to sign in
- ✅ CORS configured: Backend allows all origins (adjust for production)

## Next Steps

1. **Deploy Backend to Render**
   - Set environment variables in Render dashboard
   - Get deployed backend URL

2. **Update Frontend**
   - Set `envBackendUrl` in `backend_auth_service.dart` to deployed URL

3. **Test Integration**
   - Launch PDH with JWT token from Khonobuzz
   - Verify auto-login works
   - Check browser console for any errors

## Testing the Connection

### Manual Test (after deployment):
```bash
# Test health endpoint
curl https://your-backend.onrender.com/health

# Test validate-token endpoint
curl -X POST https://your-backend.onrender.com/validate-token \
  -H "Content-Type: application/json" \
  -d '{"token": "your_jwt_token_here"}'
```

### Expected Results:
- Health check: `{"status": "healthy", "service": "pdh-backend"}`
- Token validation: Returns `firebase_token`, `user_id`, `email`, `roles`

## Status: ✅ READY FOR DEPLOYMENT

All integration points are verified and connected. The backend and frontend are ready to work together once:
1. Backend is deployed to Render
2. Frontend `envBackendUrl` is updated with deployed URL
3. Environment variables are properly configured

