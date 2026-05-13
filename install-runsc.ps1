param(
    [switch]$DefaultRuntime
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

Invoke-RunscInstaller -DefaultRuntime:$DefaultRuntime

if (Test-RunscRegistered) {
    Write-Host "OK: runsc is registered."
    docker info --format 'Default runtime: {{.DefaultRuntime}}'
    docker info --format 'Runtimes: {{json .Runtimes}}'
} else {
    throw "runsc was not found in docker info after installation."
}
