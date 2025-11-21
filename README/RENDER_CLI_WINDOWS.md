# Installing Render CLI on Windows

## Option 1: Deploy Without CLI (Recommended for Windows)

**You don't need the CLI to deploy!** You can deploy directly through Render's web dashboard:

1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Sign up or log in
3. Click "New +" → "Web Service"
4. Connect your GitHub repository
5. Render will automatically detect your `render.yaml` file
6. Set your environment variables in the dashboard
7. Deploy!

This is the easiest method for Windows users.

## Option 2: Install Render CLI via WSL (Windows Subsystem for Linux)

If you really want the CLI, you can use WSL:

1. **Install WSL** (if not already installed):
   ```powershell
   wsl --install
   ```
   Restart your computer after installation.

2. **Open WSL terminal** and run:
   ```bash
   sudo apt update
   sudo apt install -y build-essential curl git
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Add Homebrew to PATH** (follow the instructions shown after installation)

4. **Install Render CLI**:
   ```bash
   brew install render
   ```

5. **Verify installation**:
   ```bash
   render --version
   ```

6. **Login**:
   ```bash
   render login
   ```

## Option 3: Use Scoop (Windows Package Manager)

1. **Install Scoop** (if not already installed):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   irm get.scoop.sh | iex
   ```

2. **Add the extras bucket**:
   ```powershell
   scoop bucket add extras
   ```

3. **Install Render CLI** (if available):
   ```powershell
   scoop install render
   ```

   Note: This may not be available in Scoop. If it fails, use Option 1 or 2.

## Option 4: Manual Download (If Available)

Check the official Render documentation for Windows binaries:
- Visit: https://render.com/docs/cli
- Look for Windows download links or installation instructions

## Recommendation

**For Windows users, I strongly recommend Option 1** (using the web dashboard). It's:
- ✅ Easier to set up
- ✅ No additional software needed
- ✅ Full-featured deployment interface
- ✅ Better for managing environment variables
- ✅ Visual logs and monitoring

The CLI is mainly useful for:
- Automating deployments in CI/CD pipelines
- Managing multiple services from command line
- Advanced scripting scenarios

For most use cases, the web dashboard is sufficient and easier to use on Windows.

