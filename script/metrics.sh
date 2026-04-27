#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v lizard >/dev/null 2>&1; then
  echo "Lizard is the chosen Swift metrics command, but 'lizard' is not installed." >&2
  echo "Install with: python3 -m pip install lizard" >&2
  exit 2
fi

lizard --version
lizard -l swift "$ROOT_DIR/pika"
