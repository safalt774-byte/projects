# install-cloudflared-scheduledtask.ps1
# Installs a user-scoped Scheduled Task that runs the cloudflared wrapper at user logon.

param(
  [Parameter(Mandatory=$true)] [string]$GitHubToken,
  [string]$GistId = "",
  [string]$LocalPort = "8000",
  [string]$TaskName = "Cloudflared Gist Updater"
)

# Save token and optional GistId and LocalPort to user environment variables
Write-Host "Saving GITHUB_GIST_TOKEN to current user environment variables (will not be visible to others)."
[Environment]::SetEnvironmentVariable('GITHUB_GIST_TOKEN', $GitHubToken, 'User')
if ($GistId -ne "") {
    [Environment]::SetEnvironmentVariable('GIST_ID', $GistId, 'User')
}
[Environment]::SetEnvironmentVariable('LOCAL_PORT', $LocalPort, 'User')

$wrapperPath = "C:\projects\tools\run-cloudflared-wrapper.ps1"
if (-not (Test-Path $wrapperPath)) {
    Write-Error "Wrapper script not found at $wrapperPath. Ensure path is correct."; exit 1
}

# Build action: powershell -NoProfile -ExecutionPolicy Bypass -File "path\to\run-cloudflared-wrapper.ps1"
$action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`""

# Create scheduled task XML to run at logon for the current user
$taskXml = "<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">`n" +
"  <RegistrationInfo><Author>auto-installer</Author></RegistrationInfo>`n" +
"  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>`n" +
"  <Principals><Principal id=\"Author\"><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>`n" +
"  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries></Settings>`n" +
"  <Actions Context=\"Author\"><Exec><Command>powershell.exe</Command><Arguments>-NoProfile -ExecutionPolicy Bypass -File \"$wrapperPath\"</Arguments></Exec></Actions>`n" +
"</Task>"

# Save to temp file
$xmlPath = Join-Path $env:TEMP "cloudflared_task.xml"
$taskXml | Out-File -FilePath $xmlPath -Encoding UTF8

# Register the scheduled task for the current user
try {
    schtasks.exe /Create /TN "$TaskName" /XML "$xmlPath" /F | Out-Null
    Write-Host "Scheduled Task '$TaskName' created for current user. It will run at next logon and start the wrapper."
    Write-Host "If the task already exists you can delete it with: schtasks.exe /Delete /TN `"$TaskName`" /F"
} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}

Write-Host "Installation complete. The wrapper will run at user logon and manage cloudflared/start script."
