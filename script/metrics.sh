#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v carp >/dev/null 2>&1; then
  echo "Carp is the chosen metrics command for the ambiguous 'crab/Carp' request, but 'carp' is not installed." >&2
  exit 2
fi

carp --version
carp --path "$ROOT_DIR/pika" --format plain
