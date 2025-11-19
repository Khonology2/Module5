#!/bin/bash
# Script to inject environment variables into Flutter web build
# This script creates a config.dart file with environment variables from Render

set -e

CONFIG_FILE="lib/config/env_config.dart"
CONFIG_DIR="lib/config"

# Create the config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Get environment variables from Render (or use defaults for local dev)
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
JWT_SECRET_KEY="${JWT_SECRET_KEY:-}"

# Generate the config file
cat > "$CONFIG_FILE" << EOF
// This file is auto-generated during build time
// DO NOT commit this file with actual keys - it's generated from environment variables
// Environment variables are injected from Render dashboard during build

class EnvConfig {
  // Encryption key for Fernet decryption (must match Khonobuzz backend)
  static const String? encryptionKey = $([ -n "$ENCRYPTION_KEY" ] && echo "\"$ENCRYPTION_KEY\"" || echo "null");
  
  // JWT secret key for token verification (must match Khonobuzz backend)
  static const String? jwtSecretKey = $([ -n "$JWT_SECRET_KEY" ] && echo "\"$JWT_SECRET_KEY\"" || echo "null");
  
  // Check if encryption is configured
  static bool get isEncryptionConfigured => encryptionKey != null && encryptionKey!.isNotEmpty;
  
  // Check if JWT verification is configured
  static bool get isJwtVerificationConfigured => jwtSecretKey != null && jwtSecretKey!.isNotEmpty;
}
EOF

if [ -n "$ENCRYPTION_KEY" ]; then
  echo "✅ ENCRYPTION_KEY injected (length: ${#ENCRYPTION_KEY} chars)"
else
  echo "⚠️  ENCRYPTION_KEY not set - token decryption will not work"
fi

if [ -n "$JWT_SECRET_KEY" ]; then
  echo "✅ JWT_SECRET_KEY injected (length: ${#JWT_SECRET_KEY} chars)"
else
  echo "⚠️  JWT_SECRET_KEY not set - JWT verification will not work"
fi

echo "✅ Environment variables injected into $CONFIG_FILE"

