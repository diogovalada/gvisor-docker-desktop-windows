param(
    [switch]$DefaultRuntime
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    return
}

if (-not (Test-DockerReady)) {
    return
}

if (Test-RunscLightweightHealthy -DefaultRuntime:$DefaultRuntime) {
    return
}

Write-Host "runsc runtime is missing or not configured as expected; repairing Docker Desktop runtime config..."
Invoke-RunscInstaller -DefaultRuntime:$DefaultRuntime

if (-not (Test-RunscLightweightHealthy -DefaultRuntime:$DefaultRuntime)) {
    throw "Repair ran, but runsc still is not configured as expected."
}

Write-Host "OK: runsc is registered."
