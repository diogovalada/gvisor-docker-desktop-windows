Set-StrictMode -Version Latest

function Test-DockerReady {
    docker info *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-DockerRuntimesJson {
    $output = docker info --format '{{json .Runtimes}}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }
    return ($output -join "`n")
}

function Test-RunscRegistered {
    $runtimes = Get-DockerRuntimesJson
    return ($runtimes -match '"runsc"')
}

function Invoke-RunscInstaller {
    param(
        [switch]$DefaultRuntime
    )

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "docker.exe not found. Start Docker Desktop and ensure Docker CLI is on PATH."
    }

    if (-not (Test-DockerReady)) {
        throw "Docker Desktop daemon is not reachable. Start Docker Desktop first."
    }

    $setDefault = if ($DefaultRuntime) { "true" } else { "false" }

    $installerScript = @'
set -eux

apk add --no-cache ca-certificates curl jq procps

case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

URL="https://storage.googleapis.com/gvisor/releases/release/latest/${ARCH}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

curl -fsSLO "${URL}/runsc"
curl -fsSLO "${URL}/runsc.sha512"
curl -fsSLO "${URL}/containerd-shim-runsc-v1"
curl -fsSLO "${URL}/containerd-shim-runsc-v1.sha512"

sha512sum -c runsc.sha512
sha512sum -c containerd-shim-runsc-v1.sha512

chmod 0755 runsc containerd-shim-runsc-v1

mkdir -p "${RUNSC_HOST_DIR}"

BIN_CHANGED=0

if ! cmp -s runsc "${RUNSC_HOST_DIR}/runsc" 2>/dev/null; then
  cp runsc "${RUNSC_HOST_DIR}/runsc"
  BIN_CHANGED=1
fi

if ! cmp -s containerd-shim-runsc-v1 "${RUNSC_HOST_DIR}/containerd-shim-runsc-v1" 2>/dev/null; then
  cp containerd-shim-runsc-v1 "${RUNSC_HOST_DIR}/containerd-shim-runsc-v1"
  BIN_CHANGED=1
fi

chmod 0755 "${RUNSC_HOST_DIR}/runsc" "${RUNSC_HOST_DIR}/containerd-shim-runsc-v1"

RUNSC_PATH="${RUNSC_HOST_DIR}/runsc"
CONFIG_CHANGED=0
CONFIG_TMP="$(mktemp)"

jq \
  --arg runsc_path "$RUNSC_PATH" \
  --arg set_default "$SET_DEFAULT_RUNTIME" \
  '
  .runtimes = (.runtimes // {}) |
  .runtimes.runsc = {
    "path": $runsc_path,
    "runtimeArgs": []
  } |
  if (($set_default | ascii_downcase) == "true") then
    ."default-runtime" = "runsc"
  else
    .
  end
  ' "$CONFIG_FILE" > "$CONFIG_TMP"

if ! cmp -s "$CONFIG_TMP" "$CONFIG_FILE"; then
  cat "$CONFIG_TMP" > "$CONFIG_FILE"
  CONFIG_CHANGED=1
fi

rm -f "$CONFIG_TMP"

if [ "$CONFIG_CHANGED" = "1" ]; then
  pkill -HUP dockerd || true
fi

echo "runsc path: ${RUNSC_PATH}"
echo "binary changed: ${BIN_CHANGED}"
echo "config changed: ${CONFIG_CHANGED}"
echo "done"
'@

    $dockerArgs = @(
        "run",
        "--rm",
        "--pid=host",
        "--mount", "type=volume,source=runsc-runtime-binaries,target=/var/lib/docker/volumes/runsc-runtime-binaries/_data",
        "--mount", "type=bind,source=/run/config/docker/daemon.json,target=/run/config/docker/daemon.json",
        "--env", "SET_DEFAULT_RUNTIME=$setDefault",
        "--env", "CONFIG_FILE=/run/config/docker/daemon.json",
        "--env", "RUNSC_HOST_DIR=/var/lib/docker/volumes/runsc-runtime-binaries/_data",
        "alpine:3.20",
        "sh",
        "-euxc",
        $installerScript
    )

    & docker @dockerArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Installer container failed with exit code $LASTEXITCODE."
    }
}
