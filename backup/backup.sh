#!/usr/bin/env bash
# =============================================================================
# REMVPS — backup/backup.sh
# Backup and restore system for REMVPS configuration and container data
# =============================================================================

REMVPS_BACKUP_DIR="${HOME}/.local/share/remvps/backups"
REMVPS_BACKUP_QUEUE_FILE="${HOME}/.cache/remvps/backup_queue"
REMVPS_BACKUP_DAEMON_PID_FILE="${HOME}/.cache/remvps/backup_daemon.pid"

# ---------------------------------------------------------------------------
# remvps_backup_create — create a timestamped backup archive
# Backs up: REMVPS config, logs, and Docker metadata for all REMVPS containers
# ---------------------------------------------------------------------------
remvps_backup_create() {
    local label="${1:-manual}"
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local archive_name="remvps_backup_${label}_${ts}.tar.gz"
    local archive_path="${REMVPS_BACKUP_DIR}/${archive_name}"
    local staging_dir
    staging_dir=$(mktemp -d /tmp/remvps/backup_XXXXXX)

    mkdir -p "${REMVPS_BACKUP_DIR}" "$staging_dir"

    # 1. REMVPS configuration
    if [[ -d "${HOME}/.config/remvps" ]]; then
        cp -r "${HOME}/.config/remvps" "${staging_dir}/config" 2>/dev/null || true
    fi

    # 2. REMVPS logs
    if [[ -d "${HOME}/.local/share/remvps/logs" ]]; then
        cp -r "${HOME}/.local/share/remvps/logs" "${staging_dir}/logs" 2>/dev/null || true
    fi

    # 3. Docker metadata for every REMVPS container
    local containers_dir="${staging_dir}/containers"
    mkdir -p "$containers_dir"
    while IFS= read -r cname; do
        [[ -z "$cname" ]] && continue
        local cdir="${containers_dir}/${cname}"
        mkdir -p "$cdir"
        # Inspect JSON
        docker inspect "$cname" > "${cdir}/inspect.json" 2>/dev/null || true
        # Container config labels
        docker inspect --format '{{json .Config.Labels}}' "$cname" \
            > "${cdir}/labels.json" 2>/dev/null || true
        # List of installed packages (best effort)
        _remvps_backup_pkg_list "$cname" "${cdir}/packages.txt"
    done < <(remvps_docker_names_all)

    # 4. Build manifest
    cat > "${staging_dir}/manifest.json" <<MANIFEST
{
  "remvps_version": "1.0",
  "backup_label": "${label}",
  "created_at": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "user": "$(whoami)"
}
MANIFEST

    # 5. Compress
    if tar -czf "$archive_path" -C "$staging_dir" . 2>/dev/null; then
        # 6. Verify integrity
        if tar -tzf "$archive_path" &>/dev/null; then
            rm -rf "$staging_dir"
            remvps_log_info "Backup created: ${archive_path}"
            printf '%s' "$archive_path"
            return 0
        else
            remvps_log_err "Backup integrity check failed: ${archive_path}"
            rm -f "$archive_path"
            rm -rf "$staging_dir"
            return 1
        fi
    else
        remvps_log_err "Backup compression failed."
        rm -rf "$staging_dir"
        return 1
    fi
}

# Helper: export the installed package list from a container
_remvps_backup_pkg_list() {
    local cname="$1" output="$2"
    local os_image
    os_image=$(docker inspect --format '{{index .Config.Labels "remvps.os"}}' "$cname" 2>/dev/null)

    case "$os_image" in
        alpine:*)
            docker exec "$cname" apk info 2>/dev/null > "$output" || true ;;
        *)
            docker exec "$cname" dpkg -l 2>/dev/null > "$output" || true ;;
    esac
}

# ---------------------------------------------------------------------------
# remvps_backup_list — list available backups
# ---------------------------------------------------------------------------
remvps_backup_list() {
    find "${REMVPS_BACKUP_DIR}" -maxdepth 1 -name 'remvps_backup_*.tar.gz' \
        -printf '%T@ %f\n' 2>/dev/null | sort -rn | awk '{print $2}'
}

# ---------------------------------------------------------------------------
# remvps_backup_delete_old MAX_COUNT
# Keep only the MAX_COUNT most recent backups; delete the rest.
# ---------------------------------------------------------------------------
remvps_backup_delete_old() {
    local max="${1:-10}"
    local count=0
    while IFS= read -r fname; do
        (( count++ ))
        if [[ "$count" -gt "$max" ]]; then
            rm -f "${REMVPS_BACKUP_DIR}/${fname}"
            remvps_log_info "Deleted old backup: ${fname}"
        fi
    done < <(remvps_backup_list)
}

# ---------------------------------------------------------------------------
# remvps_backup_restore ARCHIVE_PATH — restore from a backup archive
# ---------------------------------------------------------------------------
remvps_backup_restore() {
    local archive="$1"

    if [[ ! -f "$archive" ]]; then
        remvps_msg_err "Backup file not found: ${archive}"
        return 1
    fi

    # Verify integrity first
    if ! tar -tzf "$archive" &>/dev/null; then
        remvps_msg_err "Backup archive appears corrupt: ${archive}"
        return 1
    fi

    local restore_dir
    restore_dir=$(mktemp -d /tmp/remvps/restore_XXXXXX)

    remvps_msg_info "Extracting backup..."
    if ! tar -xzf "$archive" -C "$restore_dir" 2>/dev/null; then
        remvps_msg_err "Extraction failed."
        rm -rf "$restore_dir"
        return 1
    fi

    # Restore configuration
    if [[ -d "${restore_dir}/config" ]]; then
        mkdir -p "${HOME}/.config/remvps"
        cp -r "${restore_dir}/config/." "${HOME}/.config/remvps/" 2>/dev/null && \
            remvps_msg_ok "Configuration restored." || \
            remvps_msg_warn "Could not restore configuration."
    fi

    # Restore logs
    if [[ -d "${restore_dir}/logs" ]]; then
        mkdir -p "${HOME}/.local/share/remvps/logs"
        cp -r "${restore_dir}/logs/." "${HOME}/.local/share/remvps/logs/" 2>/dev/null && \
            remvps_msg_ok "Logs restored." || \
            remvps_msg_warn "Could not restore logs."
    fi

    # Reload config
    remvps_config_load

    rm -rf "$restore_dir"
    remvps_log_info "Restored from backup: ${archive}"
    remvps_msg_ok "Restore complete. Restart REMVPS to apply all changes."
    return 0
}

# ---------------------------------------------------------------------------
# remvps_backup_push_git ARCHIVE_PATH
# Push a backup to the configured Git repository.
# If the network is unavailable, the path is queued for later.
# ---------------------------------------------------------------------------
remvps_backup_push_git() {
    local archive="$1"

    if [[ -z "${REMVPS_BACKUP_GIT_URL:-}" ]]; then
        remvps_log_warn "Git backup URL not configured — skipping push."
        return 0
    fi

    local git_dir
    git_dir=$(mktemp -d /tmp/remvps/gitpush_XXXXXX)

    # Clone or init the repo
    if ! git clone --depth=1 --branch "${REMVPS_BACKUP_GIT_BRANCH:-main}" \
            "${REMVPS_BACKUP_GIT_URL}" "$git_dir" &>/dev/null; then
        # Repo may not have the branch yet — init fresh
        git -C "$git_dir" init &>/dev/null
        git -C "$git_dir" remote add origin "${REMVPS_BACKUP_GIT_URL}" &>/dev/null
    fi

    # Copy archive
    local fname
    fname=$(basename "$archive")
    cp "$archive" "${git_dir}/${fname}"

    # Commit and push
    git -C "$git_dir" config user.email "remvps@localhost" &>/dev/null
    git -C "$git_dir" config user.name  "REMVPS Backup" &>/dev/null
    git -C "$git_dir" add "${fname}" &>/dev/null
    git -C "$git_dir" commit -m "REMVPS backup: ${fname}" &>/dev/null

    if git -C "$git_dir" push origin "HEAD:${REMVPS_BACKUP_GIT_BRANCH:-main}" \
            --force &>/dev/null; then
        remvps_log_info "Backup pushed to Git: ${REMVPS_BACKUP_GIT_URL}"
        rm -rf "$git_dir"
        return 0
    else
        remvps_log_warn "Git push failed — queuing for retry."
        echo "$archive" >> "${REMVPS_BACKUP_QUEUE_FILE}"
        rm -rf "$git_dir"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# remvps_backup_retry_queue — attempt to push any queued backup archives
# ---------------------------------------------------------------------------
remvps_backup_retry_queue() {
    [[ ! -f "${REMVPS_BACKUP_QUEUE_FILE}" ]] && return 0
    [[ -z "${REMVPS_BACKUP_GIT_URL:-}" ]] && return 0

    local tmp_queue
    tmp_queue=$(mktemp)
    while IFS= read -r path; do
        [[ -z "$path" || ! -f "$path" ]] && continue
        if remvps_backup_push_git "$path"; then
            remvps_log_info "Queued backup successfully pushed: ${path}"
        else
            echo "$path" >> "$tmp_queue"
        fi
    done < "${REMVPS_BACKUP_QUEUE_FILE}"
    mv "$tmp_queue" "${REMVPS_BACKUP_QUEUE_FILE}"
}

# ---------------------------------------------------------------------------
# remvps_backup_daemon_start — start the background auto-backup daemon
# ---------------------------------------------------------------------------
remvps_backup_daemon_start() {
    [[ "${REMVPS_BACKUP_ENABLED:-false}" != 'true' ]] && return 0

    # Only one daemon at a time
    if [[ -f "${REMVPS_BACKUP_DAEMON_PID_FILE}" ]]; then
        local old_pid
        old_pid=$(cat "${REMVPS_BACKUP_DAEMON_PID_FILE}")
        if kill -0 "$old_pid" 2>/dev/null; then
            return 0   # Already running
        fi
    fi

    (
        while true; do
            sleep "${REMVPS_BACKUP_INTERVAL:-3600}"
            local archive
            archive=$(remvps_backup_create "auto") || continue
            remvps_backup_push_git "$archive" || true
            remvps_backup_retry_queue || true
            remvps_backup_delete_old 10
        done
    ) &
    echo $! > "${REMVPS_BACKUP_DAEMON_PID_FILE}"
    remvps_log_info "Backup daemon started (PID $(cat "${REMVPS_BACKUP_DAEMON_PID_FILE}"), interval=${REMVPS_BACKUP_INTERVAL}s)."
}

# ---------------------------------------------------------------------------
# remvps_backup_daemon_stop — stop the background backup daemon
# ---------------------------------------------------------------------------
remvps_backup_daemon_stop() {
    if [[ -f "${REMVPS_BACKUP_DAEMON_PID_FILE}" ]]; then
        local pid
        pid=$(cat "${REMVPS_BACKUP_DAEMON_PID_FILE}")
        kill "$pid" 2>/dev/null && remvps_log_info "Backup daemon stopped."
        rm -f "${REMVPS_BACKUP_DAEMON_PID_FILE}"
    fi
}

# ---------------------------------------------------------------------------
# remvps_op_backup_menu — interactive backup/restore UI
# ---------------------------------------------------------------------------
remvps_op_backup_menu() {
    while true; do
        remvps_clear
        remvps_box_top "  Backup & Restore  "
        remvps_box_empty
        local daemon_status="Disabled"
        [[ "${REMVPS_BACKUP_ENABLED:-false}" == 'true' ]] && daemon_status="${REMVPS_ACCENT_GOOD}Enabled${REMVPS_RESET}"
        remvps_box_row "  ${REMVPS_ACCENT_DIM}Auto Backup: ${daemon_status}${REMVPS_ACCENT_DIM}   Interval: ${REMVPS_BACKUP_INTERVAL}s${REMVPS_RESET}"
        remvps_box_empty
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}1${REMVPS_RESET}  Create Backup Now"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}2${REMVPS_RESET}  List Backups"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}3${REMVPS_RESET}  Restore from Backup"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}4${REMVPS_RESET}  Push Queued Backups to Git"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}0${REMVPS_RESET}  Back"
        remvps_box_empty
        remvps_box_bottom

        printf '\n'
        printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}Choice${REMVPS_RESET} : "
        local choice
        read -r choice

        case "$choice" in
            1)
                remvps_section "Creating Backup"
                remvps_msg_info "Running backup..."
                local archive
                archive=$(remvps_backup_create "manual")
                if [[ -n "$archive" ]]; then
                    remvps_dialog_success "Backup Complete" "Saved to: ${archive}"
                    # Attempt git push if configured
                    if [[ -n "${REMVPS_BACKUP_GIT_URL:-}" ]]; then
                        remvps_msg_info "Pushing to Git..."
                        remvps_backup_push_git "$archive" && \
                            remvps_msg_ok "Pushed to Git." || \
                            remvps_msg_warn "Git push failed — queued for retry."
                    fi
                else
                    remvps_dialog_error "Backup Failed" "Could not create backup archive."
                fi
                remvps_pause ;;
            2)
                remvps_section "Available Backups"
                local backups
                mapfile -t backups < <(remvps_backup_list)
                if [[ ${#backups[@]} -eq 0 ]]; then
                    remvps_msg_info "No backups found."
                else
                    local i=1
                    for b in "${backups[@]}"; do
                        printf "  ${REMVPS_ACCENT_TITLE}%2d${REMVPS_RESET}  %s\n" "$i" "$b"
                        (( i++ ))
                    done
                fi
                remvps_pause ;;
            3)
                remvps_section "Restore from Backup"
                mapfile -t backups < <(remvps_backup_list)
                if [[ ${#backups[@]} -eq 0 ]]; then
                    remvps_msg_warn "No backups available."
                    remvps_pause; continue
                fi
                local sel_backup
                if remvps_select_from_list sel_backup "Select Backup" "${backups[@]}"; then
                    remvps_confirm "Restore from '${sel_backup}'? Existing config will be overwritten." || {
                        remvps_msg_info "Cancelled."
                        remvps_pause; continue
                    }
                    remvps_backup_restore "${REMVPS_BACKUP_DIR}/${sel_backup}"
                fi
                remvps_pause ;;
            4)
                remvps_section "Retry Queued Git Pushes"
                remvps_backup_retry_queue
                remvps_msg_ok "Retry complete."
                remvps_pause ;;
            0) return 0 ;;
            *) remvps_msg_warn "Invalid choice."; sleep 0.8 ;;
        esac
    done
}
