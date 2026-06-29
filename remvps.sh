#!/usr/bin/env bash
# =============================================================================
# REMVPS — remvps.sh
# Main entry point. Sources all modules and starts the application.
# =============================================================================
set -euo pipefail

# Resolve the true directory of this script even through symlinks
REMVPS_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export REMVPS_ROOT

# ---------------------------------------------------------------------------
# Source all modules in dependency order
# ---------------------------------------------------------------------------
source "${REMVPS_ROOT}/ui/colors.sh"
source "${REMVPS_ROOT}/ui/draw.sh"
source "${REMVPS_ROOT}/utils/log.sh"
source "${REMVPS_ROOT}/utils/validate.sh"
source "${REMVPS_ROOT}/config/config.sh"
source "${REMVPS_ROOT}/os/packages.sh"
source "${REMVPS_ROOT}/docker/engine.sh"
source "${REMVPS_ROOT}/core/startup.sh"
source "${REMVPS_ROOT}/core/dashboard.sh"
source "${REMVPS_ROOT}/core/vps_ops.sh"
source "${REMVPS_ROOT}/core/settings.sh"
source "${REMVPS_ROOT}/backup/backup.sh"
source "${REMVPS_ROOT}/core/menu.sh"

# ---------------------------------------------------------------------------
# Trap for clean exit on Ctrl+C / unexpected termination
# ---------------------------------------------------------------------------
_remvps_exit_trap() {
    tput cnorm 2>/dev/null || true   # Restore cursor
    printf '\n'
    remvps_backup_daemon_stop
    remvps_log_info "REMVPS exited."
}
trap '_remvps_exit_trap' EXIT INT TERM

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
remvps_init_dirs
remvps_log_init
remvps_log_rotate
remvps_config_init
remvps_log_info "REMVPS started."

# Run pre-flight checks (exits on critical failure)
remvps_clear
remvps_print_logo
remvps_print_title
remvps_preflight

# Start the auto-backup daemon if enabled
remvps_backup_daemon_start

# Enter the main menu loop
remvps_main_menu
