# Start PDH FastAPI backend (OpenRouter keys from backend/app/.env).
# Usage (repo root): .\tool\start_backend.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$backend = Join-Path $root "backend"
$envFile = Join-Path $root "backend\app\.env"

if (-not (Test-Path $envFile)) {
  Write-Warning "Missing $envFile — copy from backend/OPENROUTER_ENV.template and add secrets."
}

Set-Location $backend
Write-Host "Starting PDH API at http://127.0.0.1:8000 (AI: GET /ai/status, POST /ai/chat)"
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
