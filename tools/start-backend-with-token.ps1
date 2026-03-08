# start-backend-with-token.ps1
# Starts the FastAPI backend with a named TUNNEL_TOKEN environment variable.
# Usage (interactive):
#   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\projects\tools\start-backend-with-token.ps1" -Token "dev-token"
# If no token is provided, the script will prompt for one.
param(
  [string]$Token
)

if (-not $Token -or $Token.Trim() -eq "") {
  $Token = Read-Host -Prompt "Enter TUNNEL_TOKEN to use for backend (will be set only for this process)"
}

Write-Output "Starting backend with TUNNEL_TOKEN=$($Token)
";

# Set env var for this process
$env:TUNNEL_TOKEN = $Token

# Move to backend folder and start uvicorn
Push-Location "C:\projects\backend"

# Use python -m uvicorn api:app so logs appear in this console. To run in background use Start-Process.
Write-Output "Running: python -m uvicorn api:app --host 0.0.0.0 --port 8000"

# Start in interactive mode so you can see logs; if you want background launch, use Start-Process instead.
python -m uvicorn api:app --host 0.0.0.0 --port 8000

Pop-Location

