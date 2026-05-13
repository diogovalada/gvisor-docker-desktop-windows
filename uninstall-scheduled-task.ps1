param(
    [string]$TaskName = "Reconcile gVisor Docker Desktop runtime",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "gvisor-docker-desktop-toolkit"),
    [switch]$RemoveInstalledFiles
)

$ErrorActionPreference = "Stop"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $task) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task: $TaskName"
} else {
    Write-Host "Scheduled task not found: $TaskName"
}

if ($RemoveInstalledFiles -and (Test-Path $InstallDir)) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "Removed installed scripts: $InstallDir"
}
