#!/usr/bin/env bash
# =============================================================================
# REMVPS — config/config.sh
# Load, save, and manage persistent application settings
# =============================================================================

REMVPS_CONFIG_DIR="${HOME}/.config/remvps"
REMVPS_CONFIG_FILE="${REMVPS_CONFIG_DIR}/remvps.conf"

# Defaults
REMVPS_DEFAULT_OS="ubuntu:24.04"
REMVPS_DEFAULT_CPU=""
REMVPS_DEFAULT_RAM=""
REMVPS_THEME="dark"
REMVPS_BACKUP_ENABLED="false"
REMVPS_BACKUP_INTERVAL="3600"
REMVPS_BACKUP_GIT_URL=""
REMVPS_BACKUP_GIT_BRANCH="main"

# remvps_config_init — create config dir and file if missing
remvps_config_init() {
    mkdir -p "${REMVPS_CONFIG_DIR}"
    if [[ ! -f "${REMVPS_CONFIG_FILE}" ]]; then
        remvps_config_write_defaults
    fi
    remvps_config_load
}

# remvps_config_write_defaults — write the default config file
remvps_config_write_defaults() {
    cat > "${REMVPS_CONFIG_FILE}" <<EOF
# REMVPS Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Do not edit while REMVPS is running.

REMVPS_DEFAULT_OS="ubuntu:24.04"
REMVPS_DEFAULT_CPU=""
REMVPS_DEFAULT_RAM=""
REMVPS_THEME="dark"
REMVPS_BACKUP_ENABLED="false"
REMVPS_BACKUP_INTERVAL="3600"
REMVPS_BACKUP_GIT_URL=""
REMVPS_BACKUP_GIT_BRANCH="main"
EOF
}

# remvps_config_load — source the config file into current shell
remvps_config_load() {
    if [[ -f "${REMVPS_CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${REMVPS_CONFIG_FILE}"
    fi
}

# remvps_config_set KEY VALUE — update a key in the config file
remvps_config_set() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "${REMVPS_CONFIG_FILE}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "${REMVPS_CONFIG_FILE}"
    else
        printf '%s="%s"\n' "$key" "$value" >> "${REMVPS_CONFIG_FILE}"
    fi
    # Update the live variable
    printf -v "$key" '%s' "$value"
}

# remvps_config_get KEY DEFAULT — get a value, returning DEFAULT if unset
remvps_config_get() {
    local key="$1" default="${2:-}"
    local val="${!key:-}"
    printf '%s' "${val:-$default}"
}
remvps_validate_container_name() {
    local name="$1"

    # empty check
    [[ -z "$name" ]] && return 1

    # length check
    [[ ${#name} -gt 128 ]] && return 1

    # allowed characters only
    [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || return 1

    return 0
}
remvps_validate_hostname() {
    local name="$1"

    # empty check
    [[ -z "$name" ]] && return 1

    # length limit (RFC safe hostname max is 63 chars per label)
    [[ ${#name} -gt 63 ]] && return 1

    # allowed: letters, numbers, hyphen only
    [[ "$name" =~ ^[a-zA-Z0-9-]+$ ]] || return 1

    # must not start or end with hyphen
    [[ "$name" =~ ^- ]] && return 1
    [[ "$name" =~ -$ ]] && return 1

    return 0
}
remvps_validate_password() {
    local pass="$1"

    [[ -z "$pass" ]] && return 1

    # minimum length
    [[ ${#pass} -lt 6 ]] && return 1

    # avoid spaces
    [[ "$pass" =~ [[:space:]] ]] && return 1

    return 0
}
