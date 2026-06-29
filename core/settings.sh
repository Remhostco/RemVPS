#!/usr/bin/env bash
# =============================================================================
# REMVPS — core/settings.sh
# Interactive settings menu for REMVPS configuration
# =============================================================================

remvps_op_settings() {
    while true; do
        remvps_clear
        remvps_box_top "  Settings  "
        remvps_box_empty
        remvps_box_row "  ${REMVPS_ACCENT_DIM}Stored in: ${REMVPS_CONFIG_FILE}${REMVPS_RESET}"
        remvps_box_empty
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}1${REMVPS_RESET}  Default Operating System  ${REMVPS_ACCENT_DIM}(current: $(remvps_os_label "${REMVPS_DEFAULT_OS}"))${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}2${REMVPS_RESET}  Default CPU Limit         ${REMVPS_ACCENT_DIM}(current: ${REMVPS_DEFAULT_CPU:-(none)})${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}3${REMVPS_RESET}  Default RAM Limit         ${REMVPS_ACCENT_DIM}(current: ${REMVPS_DEFAULT_RAM:-(none)})${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}4${REMVPS_RESET}  Backup Settings"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}0${REMVPS_RESET}  Back to Main Menu"
        remvps_box_empty
        remvps_box_bottom

        printf '\n'
        printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}Choice${REMVPS_RESET} : "
        local choice
        read -r choice

        case "$choice" in
            1) _settings_default_os     ;;
            2) _settings_default_cpu    ;;
            3) _settings_default_ram    ;;
            4) _settings_backup         ;;
            0) return 0                 ;;
            *) remvps_msg_warn "Invalid choice."; sleep 0.8 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
_settings_default_os() {
    remvps_section "Default Operating System"
    local os_choices=(
        "Ubuntu 24.04  (ubuntu:24.04)"
        "Debian 12     (debian:12)"
        "Alpine Linux  (alpine:latest)"
    )
    local os_choice
    if remvps_select_from_list os_choice "Select default OS" "${os_choices[@]}"; then
        local os_image
        os_image=$(remvps_os_image_from_choice "$os_choice")
        remvps_config_set "REMVPS_DEFAULT_OS" "$os_image"
        remvps_msg_ok "Default OS set to: $(remvps_os_label "$os_image")"
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
_settings_default_cpu() {
    remvps_section "Default CPU Limit"
    remvps_msg_info "Enter a CPU limit (e.g. 0.5, 1, 2) or leave blank to clear."
    local val
    remvps_input val "CPU Limit" "${REMVPS_DEFAULT_CPU}"
    if [[ -z "$val" ]]; then
        remvps_config_set "REMVPS_DEFAULT_CPU" ""
        remvps_msg_ok "CPU limit cleared."
    elif remvps_validate_cpu "$val"; then
        remvps_config_set "REMVPS_DEFAULT_CPU" "$val"
        remvps_msg_ok "Default CPU limit set to: ${val}"
    else
        remvps_msg_err "Invalid value — CPU limit not changed."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
_settings_default_ram() {
    remvps_section "Default RAM Limit"
    remvps_msg_info "Enter a RAM limit (e.g. 512m, 1g) or leave blank to clear."
    local val
    remvps_input val "RAM Limit" "${REMVPS_DEFAULT_RAM}"
    if [[ -z "$val" ]]; then
        remvps_config_set "REMVPS_DEFAULT_RAM" ""
        remvps_msg_ok "RAM limit cleared."
    elif remvps_validate_memory "$val"; then
        remvps_config_set "REMVPS_DEFAULT_RAM" "$val"
        remvps_msg_ok "Default RAM limit set to: ${val}"
    else
        remvps_msg_err "Invalid value — RAM limit not changed."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
_settings_backup() {
    while true; do
        remvps_clear
        remvps_box_top "  Backup Settings  "
        remvps_box_empty
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}1${REMVPS_RESET}  Enable Automatic Backups    ${REMVPS_ACCENT_DIM}(current: ${REMVPS_BACKUP_ENABLED})${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}2${REMVPS_RESET}  Backup Interval (seconds)   ${REMVPS_ACCENT_DIM}(current: ${REMVPS_BACKUP_INTERVAL}s)${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}3${REMVPS_RESET}  Git Repository URL          ${REMVPS_ACCENT_DIM}(current: ${REMVPS_BACKUP_GIT_URL:-(none)})${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}4${REMVPS_RESET}  Git Branch                  ${REMVPS_ACCENT_DIM}(current: ${REMVPS_BACKUP_GIT_BRANCH})${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}0${REMVPS_RESET}  Back"
        remvps_box_empty
        remvps_box_bottom

        printf '\n'
        printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}Choice${REMVPS_RESET} : "
        local bchoice
        read -r bchoice

        case "$bchoice" in
            1)
                if [[ "$REMVPS_BACKUP_ENABLED" == 'true' ]]; then
                    remvps_config_set "REMVPS_BACKUP_ENABLED" "false"
                    remvps_msg_ok "Automatic backups disabled."
                else
                    remvps_config_set "REMVPS_BACKUP_ENABLED" "true"
                    remvps_msg_ok "Automatic backups enabled."
                fi
                remvps_pause ;;
            2)
                remvps_msg_info "Common intervals: 900 (15 min), 1800 (30 min), 3600 (1 hr), 7200 (2 hr)"
                local interval
                remvps_input interval "Interval in seconds" "$REMVPS_BACKUP_INTERVAL"
                if [[ "$interval" =~ ^[0-9]+$ ]] && [[ "$interval" -ge 60 ]]; then
                    remvps_config_set "REMVPS_BACKUP_INTERVAL" "$interval"
                    remvps_msg_ok "Backup interval set to ${interval}s."
                else
                    remvps_msg_err "Invalid interval. Must be a number >= 60."
                fi
                remvps_pause ;;
            3)
                local git_url
                remvps_input git_url "Git Repository URL" "$REMVPS_BACKUP_GIT_URL"
                remvps_config_set "REMVPS_BACKUP_GIT_URL" "$git_url"
                remvps_msg_ok "Git URL set."
                remvps_pause ;;
            4)
                local git_branch
                remvps_input git_branch "Git Branch" "$REMVPS_BACKUP_GIT_BRANCH"
                remvps_config_set "REMVPS_BACKUP_GIT_BRANCH" "${git_branch:-main}"
                remvps_msg_ok "Git branch set to: ${git_branch:-main}"
                remvps_pause ;;
            0) return 0 ;;
            *) remvps_msg_warn "Invalid choice."; sleep 0.8 ;;
        esac
    done
}
