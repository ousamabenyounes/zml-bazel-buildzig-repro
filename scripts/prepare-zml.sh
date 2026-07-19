#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOCK_FILE="$REPO_ROOT/repro.lock"
DEFAULT_ZML_DIR="$REPO_ROOT/.work/zml"
ZML_DIR="${1:-$DEFAULT_ZML_DIR}"
ZML_PARENT_DIR=$(dirname "$ZML_DIR")
CLONED_ZML_DIR=0

. "$LOCK_FILE"

cleanup_failed_clone() {
  if [ "$CLONED_ZML_DIR" = 1 ]; then
    rm -rf "$ZML_DIR"
  fi
}

if [ -d "$ZML_DIR/.git" ]; then
  git -C "$ZML_DIR" fetch --quiet origin "$ZML_COMMIT"
else
  mkdir -p "$ZML_PARENT_DIR"
  git clone "$ZML_REPO" "$ZML_DIR"
  CLONED_ZML_DIR=1
fi

if ! git -C "$ZML_DIR" checkout --quiet "$ZML_COMMIT"; then
  cleanup_failed_clone
  exit 1
fi

cat <<EOF
Prepared ZML checkout:
  path: $ZML_DIR
  commit: $ZML_COMMIT

Next:
  scripts/docker-run.sh "$ZML_DIR" run
  scripts/docker-run.sh "$ZML_DIR" test --summary all
EOF
