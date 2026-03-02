# PDH Backend API

FastAPI backend service for validating JWT tokens from Khonobuzz and generating Firebase custom tokens for secure auto-login in the PDH Flutter web application.

## Overview

This backend replaces the insecure frontend token validation logic by:
- Validating JWT tokens server-side using `JWT_SECRET`
- Verifying users against Firestore `onboarding` collection
- Generating Firebase custom tokens for secure auto-login
- Keeping all secrets and sensitive operations on the server

## Features

- **JWT Validation**: Verifies token signature and expiration using HS256 algorithm
- **Firestore Integration**: Queries onboarding and users collections to validate user status
- **Firebase Custom Tokens**: Generates secure custom tokens for Firebase Authentication
- **Error Handling**: Comprehensive error handling with appropriate HTTP status codes
- **CORS Support**: Configured for Flutter web app integration
- **Health Checks**: Endpoints for monitoring and load balancers

## Prerequisites

- Python 3.9 or higher
- Firebase project with Admin SDK service account
- JWT secret key (must match Khonobuzz backend)
- Firestore database with `onboarding` and `users` collections

## Installation

### Local Development

1. **Clone the repository** (if not already done)

2. **Navigate to backend directory**:
   ```bash
   cd backend
   ```

3. **Create virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

4. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Create `.env` file**:
   ```bash
   cp .env.example .env
   ```

6. **Configure environment variables** in `.env`:
   ```env
   FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...",...}'
   JWT_SECRET_KEY='your_jwt_secret_here'
   ENCRYPTION_KEY='your_encryption_key_if_using_encrypted_tokens'
   BACKEND_URL='http://localhost:8000'
   ```

   **Note**: `FIREBASE_SERVICE_ACCOUNT_JSON` must be the **entire** service account JSON as a single-line string. No file paths are used; set this in the Render dashboard for production.

7. **Run the server**:
   ```bash
   uvicorn app.main:app --reload
   ```

   The API will be available at `http://localhost:8000`

8. **Access API documentation**:
   - Swagger UI: `http://localhost:8000/docs`
   - ReDoc: `http://localhost:8000/redoc`

## API Endpoints

### POST /validate-token

Validates JWT token and generates Firebase custom token.

**Request Body**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response** (200 OK):
```json
{
  "firebase_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user_id": "user123",
  "email": "user@example.com",
  "roles": ["PDH - Employee"]
}
```

**Error Responses**:
- `400 Bad Request`: Invalid request body
- `401 Unauthorized`: Invalid or expired token
- `403 Forbidden`: User status is not Active
- `404 Not Found`: User not found in Firestore
- `500 Internal Server Error`: Server error

### GET /firebase-config

Returns Firebase web client config (projectId from service account JSON; apiKey, appId, messagingSenderId from env when set). Frontend uses this to initialize Firebase without hardcoded keys when env vars are set.

### GET /health

Health check endpoint for monitoring.

**Response**:
```json
{
  "status": "healthy",
  "service": "pdh-backend"
}
```

## Environment Variables

### Required

- `FIREBASE_SERVICE_ACCOUNT_JSON`: Firebase Admin SDK service account JSON as a **single-line string** (required; no file paths)
- `JWT_SECRET_KEY`: Secret key for validating JWT tokens from Khonobuzz (also accepts `JWT_SECRET`)

### Optional

- `BACKEND_URL`: Backend base URL (for self-reference or logging)
- `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_MESSAGING_SENDER_ID`: When set, `GET /firebase-config` returns these so the frontend can initialize Firebase without hardcoded keys (projectId comes from `FIREBASE_SERVICE_ACCOUNT_JSON`)

## Deployment on Render

### Step 1: Create New Web Service

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click "New +" → "Web Service"
3. Connect your repository

### Step 2: Configure Build Settings

- **Name**: `pdh-backend` (or your preferred name)
- **Environment**: `Python 3`
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### Step 3: Set Environment Variables

In Render dashboard, go to "Environment" tab and add:

1. **FIREBASE_SERVICE_ACCOUNT_JSON**:
   - Copy your Firebase service account JSON
   - Paste as a single-line string (remove newlines or use `\n` for line breaks)
   - Example:
     ```
     {"type":"service_account","project_id":"pdh-fe6eb",...}
     ```

2. **JWT_SECRET**:
   - Your JWT secret key (must match Khonobuzz backend)
   - Example: `your_jwt_secret_here`

3. **BACKEND_URL** (optional):
   - Your Render service URL
   - Example: `https://pdh-backend.onrender.com`

4. **Firebase web client config** (optional; lets frontend avoid hardcoded API keys):
   - `FIREBASE_WEB_API_KEY`: Web API key from Firebase Console → Project settings → General
   - `FIREBASE_WEB_APP_ID`: Web app ID (e.g. `1:638896632756:web:...`)
   - `FIREBASE_WEB_MESSAGING_SENDER_ID`: Messaging sender ID (e.g. `638896632756`)

### Step 4: Deploy

Click "Save Changes" and Render will automatically deploy your service.

### Step 5: Verify Deployment

1. Check health endpoint: `https://your-service.onrender.com/health`
2. Check API docs: `https://your-service.onrender.com/docs`

## Frontend Integration

### Update Flutter Backend Auth Service

The Flutter app needs to be updated to use the new backend endpoint. Update `lib/services/backend_auth_service.dart`:

```dart
// Update _backendBaseUrl to point to your Render backend
static String? get _backendBaseUrl {
  const String? envBackendUrl = 'https://your-pdh-backend.onrender.com';
  return envBackendUrl;
}

// Update getCustomTokenFromBackend method
Future<String?> getCustomTokenFromBackend(String jwtToken) async {
  final baseUrl = _backendBaseUrl;
  if (baseUrl == null || baseUrl.isEmpty) {
    debugPrint('Backend API URL not configured.');
    return null;
  }

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/validate-token'),  // Updated endpoint
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': jwtToken,
      }),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['firebase_token'] as String?;  // Updated field name
    } else {
      debugPrint('Backend API error: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('Error getting custom token from backend: $e');
    return null;
  }
}
```

### Integration Flow

1. **Frontend extracts JWT** from URL query parameter (`?token=<jwt>&email=<email>`)
2. **Frontend calls backend**: `POST /validate-token` with JWT in request body
3. **Backend validates JWT** and queries Firestore
4. **Backend generates Firebase custom token**
5. **Frontend receives response** with `firebase_token`
6. **Frontend signs in**: `FirebaseAuth.instance.signInWithCustomToken(firebase_token)`
7. **User is authenticated** and routed to appropriate dashboard

## Testing

### Using curl

```bash
# Health check
curl https://your-backend.onrender.com/health

# Validate token
curl -X POST https://your-backend.onrender.com/validate-token \
  -H "Content-Type: application/json" \
  -d '{"token": "your_jwt_token_here"}'
```

### Using Python

```python
import requests

# Health check
response = requests.get("https://your-backend.onrender.com/health")
print(response.json())

# Validate token
response = requests.post(
    "https://your-backend.onrender.com/validate-token",
    json={"token": "your_jwt_token_here"}
)
print(response.json())
```

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app entry point
│   ├── config.py             # Environment variable configuration
│   ├── firebase_client.py    # Firebase Admin SDK initialization
│   ├── jwt_validator.py      # JWT token validation logic
│   ├── firestore_service.py  # Firestore queries
│   ├── models.py             # Pydantic request/response models
│   └── routes/
│       ├── __init__.py
│       └── auth.py           # Authentication endpoints
├── requirements.txt          # Python dependencies
├── .env.example             # Example environment variables
├── .gitignore
└── README.md                # This file
```

## Troubleshooting

### Firebase Initialization Errors

- **Error**: "Failed to initialize Firebase"
- **Solution**: Verify `FIREBASE_SERVICE_ACCOUNT_JSON` is valid JSON and contains all required fields

### JWT Validation Errors

- **Error**: "Invalid token signature"
- **Solution**: Ensure `JWT_SECRET` matches the secret used by Khonobuzz backend

### Firestore Query Errors

- **Error**: "User not found in onboarding collection"
- **Solution**: Verify user exists in Firestore `onboarding` collection with correct `user_id` or `email`

### CORS Errors

- **Error**: CORS policy errors in browser
- **Solution**: Update `allow_origins` in `main.py` to include your Flutter web app domain

## Security Considerations

- ✅ JWT signature verification using secret
- ✅ Token expiration validation
- ✅ User status validation (Active only)
- ✅ Environment variables for sensitive data
- ✅ CORS configuration
- ✅ Input validation using Pydantic models
- ⚠️ **Production**: Restrict CORS origins to specific domains
- ⚠️ **Production**: Use HTTPS only
- ⚠️ **Production**: Implement rate limiting
- ⚠️ **Production**: Add request logging and monitoring

## License

[Your License Here]

## Support

For issues or questions, please contact [Your Contact Information]

