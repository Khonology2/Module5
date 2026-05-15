# Start PDH FastAPI backend (OpenRouter keys from backend/app/.env).
# Usage (repo root): .\tool\start_backend.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$appDir = Join-Path $root "backend\app"
$envFile = Join-Path $appDir ".env"

if (-not (Test-Path $envFile)) {
  Write-Warning "Missing $envFile — add OPENROUTER_* keys (see backend/OPENROUTER_ENV.template)."
}

# Match: cd backend\app && py main.py
Set-Location $appDir
$env:PYTHONPATH = (Join-Path $root "backend")
Write-Host "PDH API: http://127.0.0.1:8000"
Write-Host "  AI status: GET /ai/status"
Write-Host "  AI chat:   POST /ai/chat (logged in this terminal)"
Write-Host "  Docs:      http://127.0.0.1:8000/docs"
python main.py
