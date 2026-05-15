# Run Flutter web with OpenRouter keys from backend/app/.env (Chrome cannot read that file at runtime).
# Usage (repo root): .\tool\run_web_with_backend_env.ps1
# Optional args are passed to flutter run, e.g. -d chrome

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envFile = Join-Path $root "backend\app\.env"
if (-not (Test-Path $envFile)) {
  Write-Error "Missing $envFile"
}

function Get-EnvValue([string]$name) {
  foreach ($line in Get-Content $envFile) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    if ($t -match "^\s*$name\s*=\s*(.+)\s*$") {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return $null
}

$primary = Get-EnvValue "OPENROUTER_API_KEY_PRIMARY"
$secondary = Get-EnvValue "OPENROUTER_API_KEY_SECONDARY"
$model = Get-EnvValue "OPENROUTER_MODEL"

if ([string]::IsNullOrWhiteSpace($primary)) {
  Write-Error "OPENROUTER_API_KEY_PRIMARY not set in $envFile"
}

$defines = @(
  "--dart-define=OPENROUTER_API_KEY_PRIMARY=$primary"
)
if (-not [string]::IsNullOrWhiteSpace($secondary)) {
  $defines += "--dart-define=OPENROUTER_API_KEY_SECONDARY=$secondary"
}
if (-not [string]::IsNullOrWhiteSpace($model)) {
  $defines += "--dart-define=OPENROUTER_MODEL=$model"
}

Set-Location $root
Write-Host "Starting flutter run -d chrome with OpenRouter keys from backend/app/.env"
& flutter run -d chrome @defines @args
