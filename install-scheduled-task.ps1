param(
    [int]$IntervalMinutes = 10,
    [string]$TaskName = "Reconcile gVisor Docker Desktop runtime",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "gvisor-docker-desktop-toolkit"),
    [switch]$DefaultRuntime,
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"

if ($IntervalMinutes -lt 1) {
    throw "IntervalMinutes must be at least 1."
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot "*.ps1") -Destination $InstallDir -Force

$Reconciler = Join-Path $InstallDir "reconcile-once.ps1"
$ReconcilerArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Reconciler`""
if ($DefaultRuntime) {
    $ReconcilerArgs += " -DefaultRuntime"
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $ReconcilerArgs

$TriggerLogin = New-ScheduledTaskTrigger -AtLogOn

$TriggerPeriodic = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $TriggerLogin, $TriggerPeriodic `
    -Settings $Settings `
    -Description "Ensures Docker Desktop has the runsc/gVisor runtime registered." `
    -Force | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Installed scripts to: $InstallDir"
Write-Host "Interval: every $IntervalMinutes minutes, plus at logon"
Write-Host "No WSL distro is used by this scheduled task."

if ($RunNow) {
    Write-Host "Running reconciler once now..."
    $runNowArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Reconciler)
    if ($DefaultRuntime) {
        $runNowArgs += "-DefaultRuntime"
    }
    & powershell.exe @runNowArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Initial reconciler run failed with exit code $LASTEXITCODE."
    }
}
