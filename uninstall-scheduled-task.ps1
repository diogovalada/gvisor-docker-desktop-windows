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

if ($RemoveInstalledFiles -and (Test-Path -LiteralPath $InstallDir)) {
    $resolvedInstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedInstallDir)

    if ($resolvedInstallDir -eq $pathRoot) {
        throw "Refusing to remove filesystem root: $resolvedInstallDir"
    }

    $expectedFiles = @("common.ps1", "install-runsc.ps1", "reconcile-once.ps1")
    foreach ($file in $expectedFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $resolvedInstallDir $file))) {
            throw "Refusing to remove '$resolvedInstallDir' because it does not look like an installed gVisor toolkit directory."
        }
    }

    Remove-Item -LiteralPath $resolvedInstallDir -Recurse -Force
    Write-Host "Removed installed scripts: $resolvedInstallDir"
}
