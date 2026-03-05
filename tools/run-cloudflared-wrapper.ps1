# run-cloudflared-wrapper.ps1
# Wrapper that reads user-scoped environment variables and runs the
# start-cloudflared-publish.ps1 script with those credentials in a loop.

# Expected environment variables (User scope):
# - GITHUB_GIST_TOKEN : your GitHub PAT with gist scope
# - GIST_ID (optional) : existing gist id to update
# - LOCAL_PORT (optional) : local FastAPI port (default 8000)

$scriptPath = "C:\projects\tools\start-cloudflared-publish.ps1"

function Log($msg) {
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$t] $msg" | Out-File -FilePath "$env:TEMP\cloudflared-wrapper.log" -Append -Encoding utf8
}

# Read user environment variables
$token = [Environment]::GetEnvironmentVariable('GITHUB_GIST_TOKEN', 'User')
$gistId = [Environment]::GetEnvironmentVariable('GIST_ID', 'User')
$localPort = [Environment]::GetEnvironmentVariable('LOCAL_PORT', 'User')
if ([string]::IsNullOrWhiteSpace($localPort)) { $localPort = '8000' }

if (-not (Test-Path $scriptPath)) {
    Log "ERROR: start script not found at $scriptPath"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($token)) {
    Log "ERROR: GITHUB_GIST_TOKEN environment variable not set for current user. Scheduled task will exit."
    exit 2
}

# Build arguments
$argList = @()
$argList += '-GitHubToken'
$argList += $token
if (-not [string]::IsNullOrWhiteSpace($gistId)) {
    $argList += '-GistId'
    $argList += $gistId
}
$argList += '-LocalPort'
$argList += $localPort

# Run in a loop so that if cloudflared or the start script exits, wrapper restarts it
while ($true) {
    try {
        Log "Starting start-cloudflared-publish.ps1 with args: $($argList -join ' ')"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @argList
        $exitCode = $LASTEXITCODE
        Log "start-cloudflared-publish.ps1 exited with code $exitCode"
    } catch {
        Log "Wrapper caught exception: $_"
    }
    # small backoff before restart
    Start-Sleep -Seconds 5
}

