#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOCK_FILE="$REPO_ROOT/repro.lock"
DEFAULT_ZML_DIR="$REPO_ROOT/.work/zml"
ZML_DIR="${ZML_REPRO_ZML_ROOT:-$DEFAULT_ZML_DIR}"
DEFAULT_CACHE_DIR="$REPO_ROOT/.work/docker-cache"
DOCKER_CACHE_DIR="${ZML_REPRO_DOCKER_CACHE:-$DEFAULT_CACHE_DIR}"
KEEP_DOCKER_CACHE="${ZML_REPRO_KEEP_DOCKER_CACHE:-0}"
CONTAINER_WORKDIR=/work/repro
CONTAINER_ZML_DIR=/work/zml
CONTAINER_CACHE_DIR=/work/cache
HOST_UID=$(id -u)
HOST_GID=$(id -g)

. "$LOCK_FILE"

if [ "$#" -gt 0 ] && [ -d "$1/.git" ]; then
  ZML_DIR=$1
  shift
fi

if [ "$#" = 0 ]; then
  set -- test --summary all
fi

mkdir -p "$DOCKER_CACHE_DIR/bazel" "$DOCKER_CACHE_DIR/zig"

set +e
docker run --rm \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  -e USE_BAZEL_VERSION="$BAZEL_VERSION" \
  -e ZIG_TARBALL_URL="$ZIG_TARBALL_URL" \
  -e ZIG_TARBALL_SHA256="$ZIG_TARBALL_SHA256" \
  -e BAZELISK_URL="$BAZELISK_URL" \
  -e BAZELISK_SHA256="$BAZELISK_SHA256" \
  -e CONTAINER_WORKDIR="$CONTAINER_WORKDIR" \
  -e CONTAINER_ZML_DIR="$CONTAINER_ZML_DIR" \
  -e CONTAINER_CACHE_DIR="$CONTAINER_CACHE_DIR" \
  -v "$REPO_ROOT:$CONTAINER_WORKDIR" \
  -v "$ZML_DIR:$CONTAINER_ZML_DIR" \
  -v "$DOCKER_CACHE_DIR:$CONTAINER_CACHE_DIR" \
  -w "$CONTAINER_WORKDIR" \
  "$DOCKER_IMAGE" \
  sh -eu -c '
    export HOME="$CONTAINER_CACHE_DIR/home"
    export XDG_CACHE_HOME="$CONTAINER_CACHE_DIR"
    TOOLS_DIR=/tmp/zml-repro-tools
    ZIG_ARCHIVE="$TOOLS_DIR/zig.tar.xz"
    BAZELISK_BIN="$TOOLS_DIR/bazel"

    cleanup() {
      rm -rf "$CONTAINER_ZML_DIR/repro/cabi"
      chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_WORKDIR/.zig-cache" "$CONTAINER_WORKDIR/zig-out" "$CONTAINER_CACHE_DIR" "$CONTAINER_ZML_DIR/repro" 2>/dev/null || true
    }
    trap cleanup EXIT

    apt-get update >/dev/null
    apt-get install -y --no-install-recommends ca-certificates xz-utils >/dev/null
    rm -rf /var/lib/apt/lists/*

    mkdir -p "$TOOLS_DIR" "$HOME" "$XDG_CACHE_HOME"
    curl -fsSL -o "$ZIG_ARCHIVE" "$ZIG_TARBALL_URL"
    printf "%s  %s\n" "$ZIG_TARBALL_SHA256" "$ZIG_ARCHIVE" | sha256sum -c -
    tar -C "$TOOLS_DIR" -xf "$ZIG_ARCHIVE"

    curl -fsSL -o "$BAZELISK_BIN" "$BAZELISK_URL"
    printf "%s  %s\n" "$BAZELISK_SHA256" "$BAZELISK_BIN" | sha256sum -c -
    chmod +x "$BAZELISK_BIN"

    ZIG_BIN=$(find "$TOOLS_DIR" -type f -name zig -perm /111 | head -n 1)
    "$ZIG_BIN" build install-facade -Dzml-root="$CONTAINER_ZML_DIR"
    "$ZIG_BIN" build "$@" -Dzml-root="$CONTAINER_ZML_DIR" -Dbazel="$BAZELISK_BIN"
  ' docker-run "$@"
DOCKER_STATUS=$?
set -e

if [ "$KEEP_DOCKER_CACHE" != 1 ]; then
  rm -rf "$DOCKER_CACHE_DIR"
fi

exit "$DOCKER_STATUS"
