param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$DockerRunArgs
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

& "$PSScriptRoot\reconcile-once.ps1"

if (-not (Test-RunscRegistered)) {
    throw "runsc runtime is not registered and repair did not succeed."
}

& docker run --runtime=runsc @DockerRunArgs
exit $LASTEXITCODE
