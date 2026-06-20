#!/usr/bin/env bash
# Launch Godot Studio (the project's main scene). Run ./install.sh once first.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${DIR}/.godot-bin/godot"

if [[ ! -x "${GODOT}" ]]; then
	echo "Godot is not installed yet. Run ./install.sh first." >&2
	exit 1
fi

# --editor (or -e) opens the Godot editor instead of the Godot Studio tool:
#   ./run.sh -e
exec "${GODOT}" --path "${DIR}" "$@"
