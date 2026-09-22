#!/usr/bin/env bash
set -Eeuo pipefail

port="${1:-5078}"
script_dir="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"

exec "$BASH" "$script_dir/manage-service.sh" install "$port"
