# Fixing Render Build Error: "flutter: command not found"

## Problem
The build is failing because Flutter SDK is not installed in Render's build environment.

## Solution

### Option 1: Use render.yaml (Recommended)

Make sure your `render.yaml` file is in the root of your repository and contains the full build command that installs Flutter first.

The `render.yaml` file should have a `buildCommand` that:
1. Clones Flutter SDK
2. Adds it to PATH
3. Runs `flutter pub get`
4. Builds the web app

### Option 2: Manual Configuration in Render Dashboard

If `render.yaml` isn't being detected, manually set these in the Render dashboard:

1. **Go to your service settings** in Render dashboard
2. **Build Command** - Use this exact command:
   ```bash
   set -e && if [ -d "flutter" ]; then rm -rf flutter; fi && git clone https://github.com/flutter/flutter.git -b stable --depth 1 && export PATH="$PATH:$(pwd)/flutter/bin" && flutter doctor -v || true && flutter pub get && flutter build web --release --base-href /
   ```
   
   **Important:** This command removes any existing `flutter` directory first (in case it's corrupted from a previous build), then clones a fresh Flutter SDK.

3. **Publish Directory:**
   ```
   build/web
   ```

4. **Environment:** 
   - Select "Static Site" or "Web Service" with static environment

### Option 3: Verify render.yaml is Being Used

1. Check that `render.yaml` is in the root of your repository
2. Make sure it's committed and pushed to GitHub
3. In Render dashboard, check if it says "Infrastructure as Code" or shows your render.yaml file
4. If not detected, you may need to:
   - Delete the current service
   - Create a new service and select "Import from render.yaml"

### Quick Fix Steps

1. **Update render.yaml** (already done in the repo)
2. **Commit and push:**
   ```bash
   git add render.yaml
   git commit -m "Fix Render build command to install Flutter"
   git push origin pdh-deployed
   ```
3. **In Render Dashboard:**
   - Go to your service
   - Click "Manual Deploy" → "Deploy latest commit"
   - OR delete and recreate the service to pick up render.yaml

### Alternative: Pre-build Locally

If the build keeps failing, you can build locally and deploy the static files:

1. **Build locally:**
   ```bash
   flutter build web --release
   ```

2. **Create a simple static site service** on Render:
   - Build Command: `echo "No build needed"`
   - Publish Directory: `build/web`
   - Deploy the `build/web` folder

But this requires manual builds for each deployment.

## Expected Build Output

When working correctly, you should see:
```
Starting Flutter build process...
Installing Flutter SDK...
Flutter path: /opt/render/project/src/flutter/bin/flutter
Running flutter doctor...
Getting Flutter dependencies...
Building Flutter web app...
Build completed successfully!
```

## Still Having Issues?

1. Check the full build logs in Render dashboard
2. Verify your branch name matches (you're using `pdh-deployed`)
3. Make sure `render.yaml` is on that branch
4. Try creating a new service from scratch

