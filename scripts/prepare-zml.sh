#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOCK_FILE="$REPO_ROOT/repro.lock"
DEFAULT_ZML_DIR="$REPO_ROOT/.work/zml"
ZML_DIR="${1:-$DEFAULT_ZML_DIR}"

. "$LOCK_FILE"

if [ -d "$ZML_DIR/.git" ]; then
  git -C "$ZML_DIR" fetch --quiet origin "$ZML_COMMIT"
else
  mkdir -p "$(dirname "$ZML_DIR")"
  git clone "$ZML_REPO" "$ZML_DIR"
fi

git -C "$ZML_DIR" checkout --quiet "$ZML_COMMIT"

zig build install-facade -Dzml-root="$ZML_DIR"

cat <<EOF
Prepared ZML checkout:
  path: $ZML_DIR
  commit: $ZML_COMMIT

Next:
  zig build run -Dzml-root="$ZML_DIR" -Dbazel=/path/to/bazel
  zig build test -Dzml-root="$ZML_DIR" -Dbazel=/path/to/bazel --summary all
EOF
