# Deploying Flutter Web App on Render

This guide explains how to deploy your Flutter web application on Render.

## Prerequisites

1. A Render account (sign up at [render.com](https://render.com))
2. Your Flutter project pushed to a GitHub repository
3. Environment variables configured (if needed)

> **Note for Windows Users:** You don't need the Render CLI to deploy! You can deploy directly through Render's web dashboard. See [RENDER_CLI_WINDOWS.md](./RENDER_CLI_WINDOWS.md) if you want to install the CLI, but it's optional.

## Deployment Steps

### Option 1: Using render.yaml (Recommended)

1. **Push your code to GitHub** (if not already done)
   ```bash
   git add .
   git commit -m "Add Render deployment configuration"
   git push origin main
   ```

2. **Create a new Web Service on Render:**
   - Go to [Render Dashboard](https://dashboard.render.com)
   - Click "New +" → "Web Service"
   - Connect your GitHub repository
   - **Important:** Make sure Render detects your `render.yaml` file
   - If it doesn't auto-detect, you may need to manually set:
     - **Build Command:** (from render.yaml - see below)
     - **Publish Directory:** `build/web`
   - **OR** use the "Infrastructure as Code" option to import from `render.yaml`

3. **Configure Environment Variables:**
   - In the Render dashboard, go to your service → Environment
   - Add your environment variables:
     - `ENCRYPTION_KEY` (from your `.env` file)
     - `JWT_SECRET_KEY` (from your `.env` file)
     - Any Firebase configuration (if not already in code)
   
   **Important:** Never commit your `.env` file to Git. Use Render's environment variables instead.

4. **Deploy:**
   - Render will automatically build and deploy your app
   - The build process will:
     - Clone Flutter SDK
     - Run `flutter pub get`
     - Build the web app with `flutter build web --release`
     - Serve the static files from `build/web`

### Option 2: Manual Configuration

If you prefer to configure manually in the Render dashboard:

1. **Build Command:**
   ```bash
   if [ ! -d "flutter" ]; then
     git clone https://github.com/flutter/flutter.git -b stable --depth 1
   else
     cd flutter && git pull && cd ..
   fi
   export PATH="$PATH:`pwd`/flutter/bin"
   flutter doctor
   flutter pub get
   flutter build web --release
   ```

2. **Publish Directory:**
   ```
   build/web
   ```

3. **Start Command:**
   ```
   cd build/web && python3 -m http.server $PORT
   ```
   
   Or use a Node.js server:
   ```bash
   cd build/web && npx serve -s . -l $PORT
   ```

## Environment Variables

Make sure to set these in Render's environment variables section:

- `ENCRYPTION_KEY` - Your Fernet encryption key
- `JWT_SECRET_KEY` - Your JWT secret key
- Any Firebase configuration variables (if needed)

## Important Notes

1. **Build Time:** The first build may take 10-15 minutes as it needs to download and install Flutter SDK. Subsequent builds are faster.

2. **Static Files:** Flutter web builds are static files, so Render's static site hosting works perfectly.

3. **Environment Variables:** Since `.env` files aren't included in builds, you must set all environment variables in Render's dashboard.

4. **Firebase Configuration:** Ensure your Firebase configuration is properly set up for web deployment.

5. **Custom Domain:** You can add a custom domain in Render's dashboard after deployment.

## Troubleshooting

### Build Fails
- Check the build logs in Render dashboard
- Ensure all dependencies are in `pubspec.yaml`
- Verify Flutter SDK installation in build logs

### Environment Variables Not Working
- Double-check variable names match exactly (case-sensitive)
- Ensure variables are set in Render dashboard, not just in `.env`
- Restart the service after adding new variables

### App Not Loading
- Check browser console for errors
- Verify Firebase configuration
- Ensure all assets are included in `pubspec.yaml`

## Alternative Hosting Options

If Render doesn't work for your needs, consider:
- **Firebase Hosting** - Great for Flutter web apps with Firebase
- **Netlify** - Simple static site hosting
- **Vercel** - Fast deployment with good Flutter support
- **GitHub Pages** - Free hosting for public repos

## Support

For Render-specific issues, check:
- [Render Documentation](https://render.com/docs)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)

