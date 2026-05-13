# gVisor runtime injection toolkit for Docker Desktop on Windows

## Problem

Docker Desktop for Windows exposes Docker Engine JSON settings, but it does not currently document a supported way to install and persist an additional OCI runtime binary such as gVisor `runsc` inside its managed Linux backend and register it for Docker Desktop containers. I've opened a feature request for this with Docker: https://github.com/docker/desktop-feedback/issues/364

A practical alternative is to install Docker Engine directly inside a WSL distro and configure `runsc` there like on a normal Linux system. That works, but it means using a separate Docker installation/context and losing the Docker Desktop for Windows app integration for those containers, images, volumes, settings, and UI workflows. Docker's WSL documentation also warns that running Docker Desktop alongside Docker Engine or Docker CLI installed directly in a WSL distro can cause conflicts.

This toolkit is an unofficial workaround for users who want to keep using Docker Desktop for Windows while making `--runtime=runsc` available to its Linux container backend.

Control flow:

```text
Windows Task Scheduler
  -> PowerShell
  -> docker run temporary installer container (installs gVisor/runsc into the Docker distro)
  -> Docker Desktop Linux backend
  -> patch Docker daemon runtime config
```

## Requirements

- Docker Desktop running Linux containers
- `docker.exe` available in PowerShell
- Docker Desktop WSL backend is fine, but no WSL distro is required to run these scripts

Check:

```powershell
docker info
docker version
```

## Usage (after installation)

Run a container with gVisor:

```powershell
docker run --rm --runtime=runsc alpine:3.20 uname -a
```

Or use the wrapper:

```powershell
.\gvisor-docker-run.ps1 --rm alpine:3.20 uname -a
```

## Installation

### Simple installation/repair

From this folder in PowerShell:

```powershell
Get-ChildItem -Recurse | Unblock-File # This unblocks running the scripts on this folder. Only needs running once.
.\install-runsc.ps1
```

**Important**: Docker updates and other actions may undo these changes. You can install again
simply by rerunning the `install-runsc.ps1` script. Or you may install the automated self-healing
task.


### Install self-healing scheduled task

```powershell
.\install-scheduled-task.ps1
# Or, if you want to immediately run the healer:
.\install-scheduled-task.ps1 -RunNow
```

This copies the scripts into:

```text
%LOCALAPPDATA%\gvisor-docker-desktop-toolkit
```

and schedules the copied reconciler. Because the scheduled task uses the copied location, you can move or delete the extracted toolkit folder afterward.



Defaults:

```text
Task name:        Reconcile gVisor Docker Desktop runtime
Check interval:   10 minutes
Install location: %LOCALAPPDATA%\gvisor-docker-desktop-toolkit
```

You can also run it with no flags:

```powershell
.\install-scheduled-task.ps1
```

Remove the scheduled task:

```powershell
.\uninstall-scheduled-task.ps1
```

Remove task plus installed copy:

```powershell
.\uninstall-scheduled-task.ps1 -RemoveInstalledFiles
```

### Installation manual verification

`install-runsc.ps1` checks that `runsc` is registered after setup.
You can also run lightweight verification manually:

```powershell
.\verify.ps1
```

To actually start a small container with `--runtime=runsc`, run the smoke test:

```powershell
.\verify.ps1 -RunSmokeTest
```

### Installation details and Idempotence

`install-runsc.ps1` is idempotent. It is safe to rerun.

It:

- downloads latest gVisor binaries;
- verifies SHA-512 checksums;
- copies binaries only if changed;
- rewrites Docker Desktop daemon config only if changed;
- reloads `dockerd` only if config changed.

`reconcile-once.ps1` is also safe to rerun.

It:

- exits quietly if Docker Desktop is not running;
- does nothing if `runsc` is already registered with the expected runtime path;
- verifies that the Docker named volume used to store the `runsc` binaries still exists;
- runs the installer only if the lightweight checks fail.

The scheduled task uses these lightweight checks. It does not start a test container every interval.

## Make runsc the default runtime

Not recommended at first. Test selected containers first.
Note that gVisor doesn't reimplement all syscalls. Non-reimplemented syscalls are blocked.
If the app relies in one of these, it may simply crash.

```powershell
.\install-runsc.ps1 -DefaultRuntime
```

Then:

```powershell
docker info --format 'Default runtime: {{.DefaultRuntime}}'
```

If you also use the self-healing scheduled task and want it to restore this default-runtime setting if Docker Desktop resets it, install the task with:

```powershell
.\install-scheduled-task.ps1 -DefaultRuntime
```

## Security note

This is an unofficial Docker Desktop workaround. The temporary installer container gets:

```text
--pid=host
bind mount: /run/config/docker/daemon.json
```

That is intentional so it can patch Docker Desktop's internal daemon config and signal `dockerd`.
