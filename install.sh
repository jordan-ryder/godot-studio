#!/usr/bin/env bash
# Downloads a self-contained Godot engine binary into ./.godot-bin and
# pre-imports the project so the first launch is instant. No root required;
# nothing is installed system-wide.
# NOTE: the engine version is pinned in tools/godot-version.txt — ONE place,
# read by every platform launcher (this script, run-editor.bat). Keep it in
# sync with project.godot's config/features — the project uses 4.6 features,
# so a 4.3 download produced a broken fresh install.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_VERSION="$(tr -d '[:space:]' < "${DIR}/tools/godot-version.txt")"
ARCH_NAME="linux.x86_64"
ZIP_NAME="Godot_v${GODOT_VERSION}_${ARCH_NAME}.zip"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
BIN_DIR="${DIR}/.godot-bin"
GODOT="${BIN_DIR}/godot"

echo "==> Godot Studio — installer"
echo "    Project:  ${DIR}"
echo "    Engine:   Godot ${GODOT_VERSION} (${ARCH_NAME})"

# --- 0. sanity: this machine ------------------------------------------------
machine="$(uname -m)"
if [[ "${machine}" != "x86_64" ]]; then
	echo "!! This installer targets x86_64; detected '${machine}'." >&2
	echo "   Edit ARCH_NAME at the top of install.sh for your platform." >&2
	exit 1
fi

# --- 1. already installed? --------------------------------------------------
if [[ -x "${GODOT}" ]] && "${GODOT}" --version >/dev/null 2>&1; then
	echo "==> Godot already present: $("${GODOT}" --version 2>/dev/null | head -n1)"
else
	mkdir -p "${BIN_DIR}"
	tmp="$(mktemp -d)"
	trap 'rm -rf "${tmp}"' EXIT

	echo "==> Downloading ${ZIP_NAME} ..."
	curl -fL --retry 3 --retry-delay 2 -o "${tmp}/${ZIP_NAME}" "${BASE_URL}/${ZIP_NAME}"

	# Optional integrity check against the official sums file.
	echo "==> Verifying checksum (best effort) ..."
	if curl -fsL -o "${tmp}/SHA512-SUMS.txt" "${BASE_URL}/SHA512-SUMS.txt"; then
		( cd "${tmp}" && grep "  ${ZIP_NAME}\$" SHA512-SUMS.txt | sha512sum -c - ) \
			&& echo "    checksum OK" \
			|| { echo "!! Checksum verification FAILED — aborting." >&2; exit 1; }
	else
		echo "    (sums file unavailable; skipping checksum)"
	fi

	echo "==> Extracting ..."
	unzip -o -q "${tmp}/${ZIP_NAME}" -d "${tmp}"
	extracted="$(find "${tmp}" -maxdepth 1 -type f -name 'Godot_v*' ! -name '*.zip' | head -n1)"
	if [[ -z "${extracted}" ]]; then
		echo "!! Could not find the Godot binary inside the zip." >&2
		exit 1
	fi
	mv -f "${extracted}" "${GODOT}"
	chmod +x "${GODOT}"
	echo "==> Installed: $("${GODOT}" --version 2>/dev/null | head -n1)"
fi

# --- 2. pre-import the project ---------------------------------------------
echo "==> Importing project assets (first time only, may take a few seconds) ..."
# --import imports and quits. We don't treat a non-zero exit as fatal because
# the editor sometimes returns non-zero on harmless import warnings.
if "${GODOT}" --headless --path "${DIR}" --import 2>"${DIR}/.import.log"; then
	echo "    import OK"
else
	echo "    import finished with warnings (see .import.log)"
fi

echo ""
echo "==> Done. Launch the prototype with:"
echo "      ./run.sh"
echo ""
echo "    Then click \"Host / Play solo\" to start building."
