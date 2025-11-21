# Environment Variables Setup Guide

## 📍 Where to Place the `.env` File

Place the `.env` file in the **root directory** of your Flutter project:

```
Personal-Development-Hub-Android_Build/
├── .env                    ← Place it here (root directory)
├── lib/
├── pubspec.yaml
├── android/
├── ios/
└── ...
```

## 🔑 Required Credentials

Your `.env` file must contain these two keys (get them from your Khonobuzz backend team):

```env
ENCRYPTION_KEY=your-fernet-encryption-key-here
JWT_SECRET_KEY=your-jwt-secret-key-here
```

### What Each Key Does:

1. **ENCRYPTION_KEY** (Required)
   - Fernet encryption key (Base64 encoded, 32 bytes)
   - Used to decrypt tokens sent from Khonobuzz app
   - Format: Base64 string (e.g., `6KZRT0MgboM5dmkwTLmHlh81o1P1huopTO3OspUz7LI=`)

2. **JWT_SECRET_KEY** (Optional for now, reserved for future)
   - JWT signature verification key
   - Will be used for JWT signature verification in future updates
   - Format: String (e.g., `HQZsb5lAThMYaDU_9YEAQcFtkIRCbyXSHXS7_ac9O0g`)

## 📝 Setup Steps

### Step 1: Create the `.env` File

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

   Or manually create a new file named `.env` in the root directory.

### Step 2: Add Your Keys

Open `.env` and add your actual keys:

```env
ENCRYPTION_KEY=6KZRT0MgboM5dmkwTLmHlh81o1P1huopTO3OspUz7LI=
JWT_SECRET_KEY=HQZsb5lAThMYaDU_9YEAQcFtkIRCbyXSHXS7_ac9O0g
```

**⚠️ IMPORTANT:** 
- Replace the example values with your actual keys from Khonobuzz backend
- Do NOT include quotes around the values
- Do NOT include spaces around the `=` sign
- Make sure there are no trailing spaces

### Step 3: Verify Setup

1. Run `flutter pub get` to ensure dependencies are installed
2. Run your app and check the console logs
3. You should see: `Environment variables loaded successfully`

If you see a warning about `.env` file not found, check:
- File is named exactly `.env` (not `.env.txt` or `.env.example`)
- File is in the root directory (same level as `pubspec.yaml`)
- File is included in `pubspec.yaml` under `assets:`

## 🔒 Security Notes

1. **Never commit `.env` to version control**
   - The `.env` file is already added to `.gitignore`
   - Only commit `.env.example` (template file)

2. **Keep keys secure**
   - Don't share keys in chat, email, or screenshots
   - Use secure channels to receive keys from backend team
   - Rotate keys if they're ever exposed

3. **Different environments**
   - Use different keys for development, staging, and production
   - Consider using `.env.development`, `.env.staging`, `.env.production`
   - Update `main.dart` to load the appropriate file based on build mode

## ❓ Troubleshooting

### Error: "ENCRYPTION_KEY not found in .env file"

**Solution:**
- Check that `.env` file exists in root directory
- Verify the key name is exactly `ENCRYPTION_KEY` (case-sensitive)
- Ensure no spaces around the `=` sign
- Check that the file is included in `pubspec.yaml` assets

### Error: "Could not load .env file"

**Solution:**
- Verify `.env` file is in the root directory
- Check file permissions (should be readable)
- Ensure file is not corrupted
- Try recreating the file

### Token decryption still not working

**Solution:**
- Verify `ENCRYPTION_KEY` matches the Khonobuzz backend key exactly
- Check for any extra spaces or newlines in the key
- Ensure the key is Base64 encoded correctly
- Check console logs for specific error messages

## 📋 Quick Checklist

- [ ] `.env` file created in root directory
- [ ] `ENCRYPTION_KEY` added with actual value from Khonobuzz
- [ ] `JWT_SECRET_KEY` added (optional for now)
- [ ] `.env` file added to `pubspec.yaml` assets
- [ ] `.env` is in `.gitignore` (already done)
- [ ] Run `flutter pub get`
- [ ] Test app and verify "Environment variables loaded successfully" message

## 🔗 Related Files

- `lib/services/token_auth_service.dart` - Reads keys from `.env`
- `lib/main.dart` - Loads `.env` file on app startup
- `pubspec.yaml` - Includes `.env` in assets
- `.gitignore` - Excludes `.env` from version control

