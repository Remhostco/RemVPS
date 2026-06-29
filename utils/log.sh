#!/usr/bin/env bash
# =============================================================================
# REMVPS — utils/log.sh
# Structured logging to file and stderr
# =============================================================================

REMVPS_LOG_DIR="${REMVPS_LOG_DIR:-${HOME}/.local/share/remvps/logs}"
REMVPS_LOG_FILE="${REMVPS_LOG_DIR}/remvps.log"

remvps_log_init() {
    mkdir -p "${REMVPS_LOG_DIR}"
    touch "${REMVPS_LOG_FILE}"
}

# Internal: write a log line
_remvps_log() {
    local level="$1"; shift
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] [%-5s] %s\n' "$ts" "$level" "$*" >> "${REMVPS_LOG_FILE}"
}

remvps_log_info()  { _remvps_log 'INFO'  "$*"; }
remvps_log_warn()  { _remvps_log 'WARN'  "$*"; }
remvps_log_err()   { _remvps_log 'ERROR' "$*"; }
remvps_log_debug() { [[ "${REMVPS_DEBUG:-0}" == '1' ]] && _remvps_log 'DEBUG' "$*" || true; }

# remvps_log_rotate — keep only the last 500 lines
remvps_log_rotate() {
    if [[ -f "${REMVPS_LOG_FILE}" ]]; then
        local lines
        lines=$(wc -l < "${REMVPS_LOG_FILE}")
        if [[ "$lines" -gt 500 ]]; then
            tail -n 400 "${REMVPS_LOG_FILE}" > "${REMVPS_LOG_FILE}.tmp"
            mv "${REMVPS_LOG_FILE}.tmp" "${REMVPS_LOG_FILE}"
        fi
    fi
}
