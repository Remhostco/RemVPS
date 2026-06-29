#!/usr/bin/env bash
# =============================================================================
# REMVPS — install.sh
# Bootstrap installer: install REMVPS to /usr/local/bin and set up data dirs
# Run once on the host machine. Requires sudo for /usr/local/bin placement.
# =============================================================================
set -euo pipefail

REMVPS_INSTALL_PREFIX="${REMVPS_INSTALL_PREFIX:-/usr/local/lib/remvps}"
REMVPS_BIN_PATH="${REMVPS_BIN_PATH:-/usr/local/bin/remvps}"
REMVPS_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for installer output (no dependency on ui/colors.sh yet)
_C_OK='\e[1;32m'
_C_WARN='\e[1;33m'
_C_ERR='\e[1;31m'
_C_INFO='\e[1;34m'
_C_RESET='\e[0m'

_ok()   { printf "${_C_OK}  ✔  %s${_C_RESET}\n" "$*"; }
_warn() { printf "${_C_WARN}  ⚠  %s${_C_RESET}\n" "$*"; }
_err()  { printf "${_C_ERR}  ✘  %s${_C_RESET}\n" "$*" >&2; }
_info() { printf "${_C_INFO}  ℹ  %s${_C_RESET}\n" "$*"; }

printf '\n'
printf "${_C_OK}  ============================================${_C_RESET}\n"
printf "${_C_OK}    REMVPS Installer${_C_RESET}\n"
printf "${_C_OK}  ============================================${_C_RESET}\n\n"

# --- Requirement checks -------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    _err "Bash 4+ required (found ${BASH_VERSION})."
    exit 1
fi

if ! command -v docker &>/dev/null; then
    _warn "Docker not found. Install Docker before using REMVPS."
fi

# --- Create user data directories ---------------------------------------------
_info "Creating REMVPS data directories..."
mkdir -p \
    "${HOME}/.config/remvps" \
    "${HOME}/.local/share/remvps/logs" \
    "${HOME}/.local/share/remvps/backups" \
    "${HOME}/.cache/remvps" \
    /tmp/remvps
_ok "Data directories ready."

# --- Copy REMVPS source -------------------------------------------------------
_info "Installing REMVPS to ${REMVPS_INSTALL_PREFIX}..."
if [[ -w "$(dirname "${REMVPS_INSTALL_PREFIX}")" ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

${SUDO} mkdir -p "${REMVPS_INSTALL_PREFIX}"
${SUDO} cp -r "${REMVPS_SRC_DIR}/." "${REMVPS_INSTALL_PREFIX}/"
${SUDO} chmod -R 755 "${REMVPS_INSTALL_PREFIX}"
_ok "REMVPS installed to ${REMVPS_INSTALL_PREFIX}."

# --- Create /usr/local/bin/remvps symlink/wrapper ----------------------------
_info "Creating 'remvps' command at ${REMVPS_BIN_PATH}..."
${SUDO} bash -c "cat > '${REMVPS_BIN_PATH}' <<'WRAPPER'
#!/usr/bin/env bash
exec \"${REMVPS_INSTALL_PREFIX}/remvps.sh\" \"\$@\"
WRAPPER"
${SUDO} chmod 755 "${REMVPS_BIN_PATH}"
_ok "'remvps' command installed."

printf '\n'
printf "${_C_OK}  ============================================${_C_RESET}\n"
printf "${_C_OK}    Installation complete!${_C_RESET}\n"
printf "${_C_OK}    Run: remvps${_C_RESET}\n"
printf "${_C_OK}  ============================================${_C_RESET}\n\n"
