<#
start-cloudflared-publish.ps1

Starts an ephemeral Cloudflare (trycloudflare) tunnel that points to a local port
and publishes the current public URL to a stable GitHub Gist so mobile clients can
fetch the latest URL automatically.

Usage examples:
# Create a new gist and start cloudflared (script prints the raw gist URL):
PowerShell -ExecutionPolicy Bypass -File "C:\projects\tools\start-cloudflared-publish.ps1" -GitHubToken "ghp_xxx" -LocalPort 8000

# Use an existing gist id (script will update the given gist):
PowerShell -ExecutionPolicy Bypass -File "C:\projects\tools\start-cloudflared-publish.ps1" -GitHubToken "ghp_xxx" -GistId "YOUR_GIST_ID" -LocalPort 8000

Notes:
- Keep the GitHub token secret and only on the machine running this script.
- cloudflared must be installed; the script assumes it is at "%ProgramFiles%\cloudflared\cloudflared.exe".
- The gist file that will be updated is named by default "current_tunnel_url.txt".
#>

param(
    [Parameter(Mandatory=$true)] [string]$GitHubToken,
    [string]$GistId = "",
    [int]$LocalPort = 8000,
    [string]$FileName = "current_tunnel_url.txt",
    [string]$CloudflaredPath = "$env:ProgramFiles\\cloudflared\\cloudflared.exe",
    [int]$StartupTimeoutSeconds = 10
)

function Write-ErrAndExit([string]$msg) {
    Write-Error $msg
    exit 1
}

if (-not (Test-Path $CloudflaredPath)) {
    Write-ErrAndExit "cloudflared not found at $CloudflaredPath. Install cloudflared or pass the -CloudflaredPath parameter."
}

# Helper: create a private gist with an initial empty file
function Create-Gist {
    param($token, $filename)
    $body = @{ public = $false; files = @{ $filename = @{ content = "" } } } | ConvertTo-Json -Depth 5
    $headers = @{ Authorization = "token $token"; "User-Agent" = "cloudflared-updater-script" }
    try {
        $resp = Invoke-RestMethod -Uri "https://api.github.com/gists" -Method Post -Headers $headers -Body $body -ContentType "application/json"
        return $resp
    } catch {
        Write-Error "Failed to create gist: $($_.Exception.Message)"
        return $null
    }
}

# Helper: update gist file content
function Update-Gist {
    param($token, $gistId, $filename, $content)
    $body = @{ files = @{ $filename = @{ content = $content } } } | ConvertTo-Json -Depth 5
    $headers = @{ Authorization = "token $token"; "User-Agent" = "cloudflared-updater-script" }
    try {
        $resp = Invoke-RestMethod -Uri "https://api.github.com/gists/$gistId" -Method Patch -Headers $headers -Body $body -ContentType "application/json"
        return $resp
    } catch {
        Write-Error "Failed to update gist $gistId: $($_.Exception.Message)"
        return $null
    }
}

function Get-Gist-Info {
    param($token, $gistId)
    $headers = @{ Authorization = "token $token"; "User-Agent" = "cloudflared-updater-script" }
    try {
        $resp = Invoke-RestMethod -Uri "https://api.github.com/gists/$gistId" -Method Get -Headers $headers
        return $resp
    } catch {
        Write-Error "Failed to fetch gist info for $gistId: $($_.Exception.Message)"
        return $null
    }
}

# Create gist if not provided
if ([string]::IsNullOrEmpty($GistId)) {
    Write-Host "Creating new private gist..."
    $created = Create-Gist -token $GitHubToken -filename $FileName
    if ($null -eq $created) { Write-ErrAndExit "Could not create gist. Exiting." }
    $GistId = $created.id
    $rawUrl = $created.files.$FileName.raw_url
    Write-Host "Created gist id: $GistId"
    Write-Host "Raw gist URL (use this in your mobile app to fetch the current tunnel URL):"
    Write-Host $rawUrl
} else {
    # Validate gist exists and ensure file exists
    $info = Get-Gist-Info -token $GitHubToken -gistId $GistId
    if ($null -eq $info) { Write-ErrAndExit "Could not find gist $GistId. Exiting." }
    if (-not $info.files.ContainsKey($FileName)) {
        Write-Host "Gist found but file $FileName missing. Creating file entry..."
        $upd = Update-Gist -token $GitHubToken -gistId $GistId -filename $FileName -content ""
        if ($null -eq $upd) { Write-ErrAndExit "Could not add $FileName to gist. Exiting." }
        $info = Get-Gist-Info -token $GitHubToken -gistId $GistId
    }
    $rawUrl = $info.files.$FileName.raw_url
    Write-Host "Using existing gist id $GistId"
    Write-Host "Raw gist URL (use this in your mobile app):"
    Write-Host $rawUrl
}

# Start cloudflared ephemeral tunnel and stream stdout
$procInfo = New-Object System.Diagnostics.ProcessStartInfo
$procInfo.FileName = $CloudflaredPath
$procInfo.Arguments = "--url http://127.0.0.1:$LocalPort"
$procInfo.RedirectStandardOutput = $true
$procInfo.RedirectStandardError = $true
$procInfo.UseShellExecute = $false
$procInfo.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $procInfo
$started = $proc.Start()
if (-not $started) { Write-ErrAndExit "Failed to start cloudflared process." }

Write-Host "Started cloudflared (PID $($proc.Id)). Waiting for public URL..."

$regex = 'https://[A-Za-z0-9\-]+\.trycloudflare\.com'
$currentUrl = ""
$stdout = $proc.StandardOutput
$stderr = $proc.StandardError
$lastPublished = Get-Date 0

# Monitor output and update gist when URL changes
while (-not $proc.HasExited) {
    $line = $stdout.ReadLine()
    if ($null -ne $line) {
        Write-Host $line
        if ($line -match $regex) {
            $newUrl = $Matches[0]
            if ($newUrl -ne $currentUrl) {
                $currentUrl = $newUrl
                Write-Host "Detected new tunnel URL: $currentUrl"
                $updateResp = Update-Gist -token $GitHubToken -gistId $GistId -filename $FileName -content $currentUrl
                if ($null -ne $updateResp) {
                    $rawUrl = $updateResp.files.$FileName.raw_url
                    Write-Host "Gist updated. Raw URL: $rawUrl"
                    $lastPublished = Get-Date
                } else {
                    Write-Warning "Gist update failed. Will retry on next URL change or cloudflared restart."
                }
            }
        }
    } else {
        Start-Sleep -Milliseconds 100
    }
}

Write-Host "cloudflared exited with code $($proc.ExitCode)"
if ($currentUrl -eq "") { Write-Warning "No tunnel URL was detected before cloudflared exited." }

