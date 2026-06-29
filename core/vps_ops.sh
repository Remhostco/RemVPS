#!/usr/bin/env bash
# =============================================================================
# REMVPS — core/vps_ops.sh
# All VPS management actions: create, list, open, start, stop, restart, delete, info
# =============================================================================

# ---------------------------------------------------------------------------
# remvps_op_create — interactive VPS creation wizard
# ---------------------------------------------------------------------------
remvps_op_create() {
    remvps_clear
    remvps_box_top "  Create New VPS  "
    remvps_box_empty
    remvps_box_row "  ${REMVPS_ACCENT_DIM}Configure your new virtual server below.${REMVPS_RESET}"
    remvps_box_empty
    remvps_box_bottom

    # --- OS selection -------------------------------------------------------
    remvps_section "Operating System"
    local os_choices=(
        "Ubuntu 24.04  (ubuntu:24.04)"
        "Debian 12     (debian:12)"
        "Alpine Linux  (alpine:latest)"
    )
    local os_choice
    if ! remvps_select_from_list os_choice "Select OS" "${os_choices[@]}"; then
        remvps_msg_err "No OS selected."
        remvps_pause; return 1
    fi
    local os_image
    os_image=$(remvps_os_image_from_choice "$os_choice")

    # --- Container name -----------------------------------------------------
    local container_name
    while true; do
        remvps_input container_name "Container Name" "remvps-$(date +%s)"
        if ! remvps_validate_container_name "$container_name"; then
            remvps_msg_err "Invalid name. Use letters, numbers, dash, underscore, dot only (max 128 chars)."
            continue
        fi
        if remvps_container_exists "$container_name"; then
            remvps_msg_err "A container named '${container_name}' already exists. Choose another name."
            continue
        fi
        break
    done

    # --- Hostname -----------------------------------------------------------
    local vps_hostname
    while true; do
        remvps_input vps_hostname "Hostname" "$container_name"
        if ! remvps_validate_hostname "$vps_hostname"; then
            remvps_msg_err "Invalid hostname. Use letters, numbers, dash only (max 63 chars)."
            continue
        fi
        break
    done

    # --- Root password ------------------------------------------------------
    local root_pass
    while true; do
        remvps_input_secret root_pass "Root Password"
        if ! remvps_validate_password "$root_pass"; then
            remvps_msg_err "Password must be at least 4 characters."
            continue
        fi
        local root_pass_confirm
        remvps_input_secret root_pass_confirm "Confirm Password"
        if [[ "$root_pass" != "$root_pass_confirm" ]]; then
            remvps_msg_err "Passwords do not match."
            continue
        fi
        break
    done

    # --- Optional CPU limit -------------------------------------------------
    local cpu_limit=""
    local cpu_raw
    remvps_input cpu_raw "CPU Limit (e.g. 1, 0.5 — leave blank to skip)" ""
    if [[ -n "$cpu_raw" ]]; then
        if remvps_validate_cpu "$cpu_raw"; then
            cpu_limit="$cpu_raw"
        else
            remvps_msg_warn "Invalid CPU value — no CPU limit applied."
        fi
    fi

    # --- Optional RAM limit -------------------------------------------------
    local ram_limit=""
    local ram_raw
    remvps_input ram_raw "RAM Limit (e.g. 512m, 1g — leave blank to skip)" ""
    if [[ -n "$ram_raw" ]]; then
        if remvps_validate_memory "$ram_raw"; then
            ram_limit="$ram_raw"
        else
            remvps_msg_warn "Invalid RAM value — no RAM limit applied."
        fi
    fi

    # --- Confirmation -------------------------------------------------------
    printf '\n'
    remvps_box_top "  Summary  "
    remvps_box_empty
    remvps_box_row "  $(remvps_kv 'Container Name' "$container_name")"
    remvps_box_row "  $(remvps_kv 'Hostname'       "$vps_hostname")"
    remvps_box_row "  $(remvps_kv 'OS Image'       "$(remvps_os_label "$os_image")")"
    remvps_box_row "  $(remvps_kv 'CPU Limit'      "${cpu_limit:-(none)}")"
    remvps_box_row "  $(remvps_kv 'RAM Limit'      "${ram_limit:-(none)}")"
    remvps_box_empty
    remvps_box_bottom

    remvps_confirm "Create this VPS?" || { remvps_msg_info "Cancelled."; remvps_pause; return 0; }

    printf '\n'

    # --- Pull base image if needed ------------------------------------------
    remvps_msg_info "Checking base image: ${os_image} ..."
    if ! remvps_docker_image_exists "$os_image"; then
        remvps_msg_info "Pulling ${os_image} from Docker Hub..."
        if ! remvps_docker_pull_image "$os_image"; then
            remvps_dialog_error "Image Pull Failed" "Could not pull ${os_image}. Check your internet connection."
            remvps_pause; return 1
        fi
        remvps_msg_ok "Image pulled."
    else
        remvps_msg_ok "Base image already present."
    fi

    # --- Build REMVPS image -------------------------------------------------
    local tag
    tag=$(remvps_docker_image_tag "$os_image")
    remvps_msg_info "Building REMVPS image for ${os_image}..."
    (remvps_docker_build_image "$os_image") &
    local build_pid=$!
    remvps_spinner "$build_pid" "Building Docker image"
    if ! wait "$build_pid"; then
        remvps_dialog_error "Build Failed" "Failed to build the REMVPS Docker image. Check Docker and try again."
        remvps_pause; return 1
    fi
    remvps_msg_ok "Image built: ${tag}"

    # --- Create container ---------------------------------------------------
    remvps_msg_info "Creating container '${container_name}'..."
    if ! remvps_docker_create \
            "$container_name" "$vps_hostname" "$os_image" \
            "$root_pass" "$cpu_limit" "$ram_limit"; then
        remvps_dialog_error "Create Failed" "Could not create container '${container_name}'."
        remvps_pause; return 1
    fi

    remvps_log_info "Created VPS: name=${container_name} os=${os_image} hostname=${vps_hostname}"

    remvps_dialog_success "VPS Created" \
        "Container '${container_name}' is ready.  Open it from the main menu."

    remvps_pause
}

# ---------------------------------------------------------------------------
# remvps_op_list — display all REMVPS containers in a table
# ---------------------------------------------------------------------------
remvps_op_list() {
    remvps_clear
    remvps_box_top "  VPS List  "
    remvps_box_empty

    local raw
    raw=$(remvps_docker_list_all)

    if [[ -z "$raw" ]]; then
        remvps_box_row "  ${REMVPS_ACCENT_DIM}No REMVPS containers found. Create one from the main menu.${REMVPS_RESET}"
        remvps_box_empty
        remvps_box_bottom
        remvps_pause; return 0
    fi

    # Header row
    printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_BOLD}%-28s  %-22s  %-12s  %-14s  %-13s${REMVPS_RESET}\n" \
        "NAME" "STATUS" "OS" "HOSTNAME" "CONTAINER ID"
    remvps_hline2

    while IFS=$'\t' read -r cname cstatus cid; do
        # Fetch labels
        local cos chostname
        cos=$(docker inspect --format '{{index .Config.Labels "remvps.os"}}' "$cname" 2>/dev/null)
        chostname=$(docker inspect --format '{{index .Config.Labels "remvps.hostname"}}' "$cname" 2>/dev/null)
        local os_display
        os_display=$(remvps_os_label "${cos:-unknown}")

        # Color status
        local status_color
        if [[ "$cstatus" == Up* ]]; then
            status_color="${REMVPS_ACCENT_GOOD}"
        else
            status_color="${REMVPS_ACCENT_DIM}"
        fi

        printf "  ${REMVPS_BOLD_WHITE}%-28s${REMVPS_RESET}  ${status_color}%-22s${REMVPS_RESET}  %-12s  %-14s  ${REMVPS_ACCENT_DIM}%.13s${REMVPS_RESET}\n" \
            "$cname" "$cstatus" "$os_display" "${chostname:-n/a}" "$cid"
    done <<< "$raw"

    remvps_box_empty
    remvps_box_bottom
    remvps_pause
}

# ---------------------------------------------------------------------------
# Helper: select a REMVPS container by name
# Sets REMVPS_SELECTED_CONTAINER on success. Returns 1 if none available.
# ---------------------------------------------------------------------------
_remvps_select_container() {
    local title="${1:-Select VPS}"
    mapfile -t REMVPS_CONTAINER_LIST < <(remvps_docker_names_all)

    if [[ ${#REMVPS_CONTAINER_LIST[@]} -eq 0 ]]; then
        remvps_msg_warn "No REMVPS containers found."
        remvps_pause; return 1
    fi

    remvps_select_from_list REMVPS_SELECTED_CONTAINER "$title" "${REMVPS_CONTAINER_LIST[@]}"
}

# ---------------------------------------------------------------------------
# remvps_op_open — open an interactive shell in a container
# ---------------------------------------------------------------------------
remvps_op_open() {
    remvps_clear
    remvps_section "Open VPS Console"

    _remvps_select_container "Select VPS to open" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    printf '\n'
    remvps_msg_info "Opening console for '${name}'..."
    printf "  ${REMVPS_ACCENT_DIM}Type 'exit' to return to REMVPS.${REMVPS_RESET}\n\n"
    sleep 0.5

    remvps_docker_open "$name"
    remvps_log_info "Opened console: name=${name}"
}

# ---------------------------------------------------------------------------
# remvps_op_start — start a stopped container
# ---------------------------------------------------------------------------
remvps_op_start() {
    remvps_clear
    remvps_section "Start VPS"

    _remvps_select_container "Select VPS to start" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    remvps_msg_info "Starting '${name}'..."
    if remvps_docker_start "$name"; then
        remvps_log_info "Started VPS: name=${name}"
        remvps_dialog_success "Started" "VPS '${name}' is now running."
    else
        remvps_dialog_error "Start Failed" "Could not start '${name}'."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
# remvps_op_stop — stop a running container
# ---------------------------------------------------------------------------
remvps_op_stop() {
    remvps_clear
    remvps_section "Stop VPS"

    _remvps_select_container "Select VPS to stop" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    remvps_confirm "Stop '${name}'?" || { remvps_msg_info "Cancelled."; remvps_pause; return 0; }

    remvps_msg_info "Stopping '${name}'..."
    if remvps_docker_stop "$name"; then
        remvps_log_info "Stopped VPS: name=${name}"
        remvps_dialog_success "Stopped" "VPS '${name}' has been stopped."
    else
        remvps_dialog_error "Stop Failed" "Could not stop '${name}'."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
# remvps_op_restart — restart a container
# ---------------------------------------------------------------------------
remvps_op_restart() {
    remvps_clear
    remvps_section "Restart VPS"

    _remvps_select_container "Select VPS to restart" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    remvps_confirm "Restart '${name}'?" || { remvps_msg_info "Cancelled."; remvps_pause; return 0; }

    remvps_msg_info "Restarting '${name}'..."
    if remvps_docker_restart "$name"; then
        remvps_log_info "Restarted VPS: name=${name}"
        remvps_dialog_success "Restarted" "VPS '${name}' has been restarted."
    else
        remvps_dialog_error "Restart Failed" "Could not restart '${name}'."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
# remvps_op_delete — delete a REMVPS container (with confirmation)
# ---------------------------------------------------------------------------
remvps_op_delete() {
    remvps_clear
    remvps_section "Delete VPS"

    _remvps_select_container "Select VPS to delete" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    # Verify it's actually a REMVPS container (safety guard)
    if ! docker inspect --format '{{index .Config.Labels "remvps"}}' "$name" 2>/dev/null | grep -q 'true'; then
        remvps_dialog_error "Refused" \
            "'${name}' is not a REMVPS container. REMVPS will not delete unrelated containers."
        remvps_pause; return 1
    fi

    printf '\n'
    remvps_msg_warn "This will permanently delete '${name}' and all its data."
    remvps_confirm "Type 'y' to permanently delete '${name}'" || {
        remvps_msg_info "Cancelled — container not deleted."
        remvps_pause; return 0
    }

    remvps_msg_info "Deleting '${name}'..."
    if remvps_docker_delete "$name"; then
        # Clean up init script if present
        rm -f "/tmp/remvps/init_${name}.sh" 2>/dev/null || true
        remvps_log_info "Deleted VPS: name=${name}"
        remvps_dialog_success "Deleted" "VPS '${name}' has been permanently removed."
    else
        remvps_dialog_error "Delete Failed" "Could not delete '${name}'."
    fi
    remvps_pause
}

# ---------------------------------------------------------------------------
# remvps_op_info — display detailed info for a container
# ---------------------------------------------------------------------------
remvps_op_info() {
    remvps_clear
    remvps_section "VPS Information"

    _remvps_select_container "Select VPS" || return 0
    local name="$REMVPS_SELECTED_CONTAINER"

    # Load inspect output into associative array
    declare -A info
    local raw_info
    raw_info=$(remvps_docker_inspect "$name") || {
        remvps_dialog_error "Inspect Failed" "Could not retrieve info for '${name}'."
        remvps_pause; return 1
    }

    while IFS='=' read -r key val; do
        info["$key"]="$val"
    done <<< "$raw_info"

    # Status color
    local status="${info[STATUS]}"
    local status_color
    [[ "$status" == 'running' ]] && status_color="${REMVPS_ACCENT_GOOD}" || status_color="${REMVPS_ACCENT_DIM}"

    printf '\n'
    remvps_box_top "  ${name}  "
    remvps_box_empty
    remvps_box_row "  $(remvps_kv 'Container Name'  "${info[CONTAINER_NAME]}")"
    remvps_box_row "  $(remvps_kv 'Container ID'    "${info[CONTAINER_ID]:0:12}")"
    remvps_box_row "  $(remvps_kv 'Hostname'        "${info[HOSTNAME]}")"
    remvps_box_row "  $(remvps_kv 'Status'          "${status_color}${status}${REMVPS_RESET}")"
    remvps_box_mid
    remvps_box_row "  $(remvps_kv 'Operating System' "$(remvps_os_label "${info[OS_IMAGE]}")")"
    remvps_box_row "  $(remvps_kv 'Docker Image'    "${info[DOCKER_IMAGE]}")"
    remvps_box_row "  $(remvps_kv 'IP Address'      "${info[IP_ADDRESS]}")"
    remvps_box_mid
    remvps_box_row "  $(remvps_kv 'CPU Limit'       "${info[CPU_LIMIT]}")"
    remvps_box_row "  $(remvps_kv 'RAM Limit'       "${info[RAM_LIMIT]}")"
    remvps_box_row "  $(remvps_kv 'Created'         "${info[CREATED]}")"
    remvps_box_empty
    remvps_box_bottom

    remvps_pause
}
