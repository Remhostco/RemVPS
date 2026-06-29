#!/usr/bin/env bash
# =============================================================================
# REMVPS — core/startup.sh
# Pre-flight environment checks before the UI starts
# =============================================================================

# remvps_preflight — run all startup checks; exit on critical failure
remvps_preflight() {
    local errors=0

    remvps_section "System Check"

    # 1. Bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        remvps_msg_err "Bash 4.0 or higher is required (found ${BASH_VERSION})."
        (( errors++ ))
    else
        remvps_msg_ok "Bash ${BASH_VERSION}"
    fi

    # 2. Docker binary
    if ! command -v docker &>/dev/null; then
        remvps_msg_err "Docker is not installed. Install Docker and try again."
        (( errors++ ))
    else
        remvps_msg_ok "Docker binary found: $(command -v docker)"
    fi

    # 3. Docker daemon
    if command -v docker &>/dev/null; then
        if ! docker info &>/dev/null; then
            remvps_msg_err "Docker daemon is not running or you lack permission."
            remvps_msg_info "Try: sudo systemctl start docker  (or add yourself to the 'docker' group)"
            (( errors++ ))
        else
            local dver
            dver=$(remvps_docker_version)
            remvps_msg_ok "Docker daemon running  (v${dver})"
        fi
    fi

    # 4. Internet connectivity (best-effort ping)
    if command -v curl &>/dev/null; then
        if curl -fsSL --max-time 5 https://registry-1.docker.io/v2/ &>/dev/null; then
            remvps_msg_ok "Docker Hub reachable"
        else
            remvps_msg_warn "Docker Hub may be unreachable — image pulls could fail."
        fi
    else
        remvps_msg_warn "curl not found — skipping connectivity check."
    fi

    # 5. Required host tools
    local tools=('docker' 'basename' 'dirname' 'date' 'mktemp' 'sed' 'awk' 'wc')
    local missing_tools=()
    for t in "${tools[@]}"; do
        command -v "$t" &>/dev/null || missing_tools+=("$t")
    done
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        remvps_msg_warn "Some host tools missing: ${missing_tools[*]}"
    else
        remvps_msg_ok "All required host tools present"
    fi

    printf '\n'

    if [[ "$errors" -gt 0 ]]; then
        remvps_dialog_error "Startup Failed" \
            "${errors} critical check(s) failed. Please resolve the issues above."
        exit 1
    fi

    remvps_msg_ok "All checks passed — starting REMVPS"
    sleep 0.6
}

# remvps_init_dirs — ensure all REMVPS data directories exist
remvps_init_dirs() {
    local dirs=(
        "${HOME}/.config/remvps"
        "${HOME}/.local/share/remvps/logs"
        "${HOME}/.local/share/remvps/backups"
        "${HOME}/.cache/remvps"
        "/tmp/remvps"
    )
    for d in "${dirs[@]}"; do
        mkdir -p "$d"
    done
}
