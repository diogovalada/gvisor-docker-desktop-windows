# gVisor runtime injection toolkit for Docker Desktop on Windows

Control flow:

```text
Windows Task Scheduler
  -> PowerShell
  -> docker run temporary installer container (installs gvisor/runsc into the Docker distro)
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
.\scripts\gvisor-docker-run.ps1 --rm alpine:3.20 uname -a
```

## Installation

### Simple installation/repair

From this folder in PowerShell:

```powershell
Get-ChildItem -Recurse | Unblock-File # This unblocks running the scripts on this folder. Only needs running once.
.\scripts\install-runsc.ps1
```

**Important**: Docker updates and other actions may undo these changes. You can install again
simply by rerunning the `install-runsc.ps1` script. Or you may install the automated self-healing
task.


### Install self-healing scheduled task

```powershell
.\scripts\install-scheduled-task.ps1 
# Or, if you want to immediately run the healer:
.\scripts\install-scheduled-task.ps1 -RunNow
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
.\scripts\install-scheduled-task.ps1
```

Remove the scheduled task:

```powershell
.\scripts\uninstall-scheduled-task.ps1
```

Remove task plus installed copy:

```powershell
.\scripts\uninstall-scheduled-task.ps1 -RemoveInstalledFiles
```

### Installation manual verification

`install-runsc.ps1` already runs this at the end of the setup. 
This is just for manual verification purposes

```powershell
.\scripts\verify.ps1 -RunTest 
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
- does nothing if `runsc` is already registered;
- runs the installer only if `runsc` is missing.

## Make runsc the default runtime

Not recommended at first. Test selected containers first.
Note that gVisor doesn't reimplement all syscalls. Non-reimplemented syscalls are blocked.
If the app relies in one of these, it may simply crash.

```powershell
.\scripts\install-runsc.ps1 -DefaultRuntime
```

Then:

```powershell
docker info --format 'Default runtime: {{.DefaultRuntime}}'
```

## Security note

This is an unofficial Docker Desktop workaround. The temporary installer container gets:

```text
--pid=host
bind mount: /run/config/docker/daemon.json
```

That is intentional so it can patch Docker Desktop's internal daemon config and signal `dockerd`.


