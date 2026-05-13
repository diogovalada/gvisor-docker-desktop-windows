param(
    [switch]$DefaultRuntime
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    exit 0
}

if (-not (Test-DockerReady)) {
    exit 0
}

if (Test-RunscRegistered) {
    exit 0
}

Write-Host "runsc runtime missing; repairing Docker Desktop runtime config..."
Invoke-RunscInstaller -DefaultRuntime:$DefaultRuntime

if (-not (Test-RunscRegistered)) {
    throw "Repair ran, but runsc still is not registered."
}

Write-Host "OK: runsc is registered."
