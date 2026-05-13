param(
    [Alias("RunTest")]
    [switch]$RunSmokeTest
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

if (-not (Test-DockerReady)) {
    throw "Docker Desktop daemon is not reachable."
}

docker info --format 'Default runtime: {{.DefaultRuntime}}'
docker info --format 'Runtimes: {{json .Runtimes}}'

if (-not (Test-RunscRegistered)) {
    throw "runsc is not registered."
}

if (-not (Test-RunscConfigured)) {
    throw "runsc is registered, but not with the expected runtime path. Expected: $script:RunscPath; actual: $(Get-RunscRuntimePath)"
}

Write-Host "OK: runsc is registered."
Write-Host "runsc path: $(Get-RunscRuntimePath)"

if ($RunSmokeTest) {
    Write-Host "Running a small container with --runtime=runsc..."
    docker run --rm --runtime=runsc alpine:3.20 sh -c 'echo container ok; uname -a; dmesg 2>/dev/null | head -20 || true'

    if ($LASTEXITCODE -ne 0) {
        throw "runsc test container failed."
    }
}
