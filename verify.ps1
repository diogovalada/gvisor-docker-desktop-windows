param(
    [switch]$RunTest
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

Write-Host "OK: runsc is registered."

if ($RunTest) {
    Write-Host "Running a small container with --runtime=runsc..."
    docker run --rm --runtime=runsc alpine:3.20 sh -c 'echo container ok; uname -a; dmesg 2>/dev/null | head -20 || true'

    if ($LASTEXITCODE -ne 0) {
        throw "runsc test container failed."
    }
}
