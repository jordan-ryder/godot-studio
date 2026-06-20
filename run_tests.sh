#!/usr/bin/env bash
# Run the headless logic-test suite (one process per test, single exit code).
# Usage: ./run_tests.sh
set -u
cd "$(dirname "$0")"
# Isolate user:// so tests that touch it don't clobber a real save.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$(mktemp -d)}"
exec ./.godot-bin/godot --headless --script res://tests/run_all.gd
