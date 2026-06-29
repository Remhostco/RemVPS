#!/usr/bin/env bash
# =============================================================================
# REMVPS — core/dashboard.sh
# Dashboard: logo, system metrics, VPS summary
# =============================================================================

# remvps_dashboard_cpu — get CPU usage percentage as integer
remvps_dashboard_cpu() {
    # Read /proc/stat twice, 0.3s apart for a real measurement
    local cpu1 cpu2 idle1 idle2 total1 total2 used
    cpu1=$(grep '^cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8, $5+$6}')
    sleep 0.3
    cpu2=$(grep '^cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8, $5+$6}')
    local t1 i1 t2 i2
    read -r t1 i1 <<< "$cpu1"
    read -r t2 i2 <<< "$cpu2"
    total1=$t1; idle1=$i1; total2=$t2; idle2=$i2
    local dtotal=$(( total2 - total1 ))
    local didle=$(( idle2 - idle1 ))
    if [[ "$dtotal" -eq 0 ]]; then printf '0'; return; fi
    used=$(( (dtotal - didle) * 100 / dtotal ))
    printf '%d' "$used"
}

# remvps_dashboard_ram — get RAM usage as "USED / TOTAL (PCT%)"
remvps_dashboard_ram() {
    local total used free pct
    if ! read -r _ total _ <<< "$(grep '^MemTotal:' /proc/meminfo 2>/dev/null)"; then
        printf 'unavailable'; return
    fi
    if ! read -r _ free <<< "$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null)"; then
        printf 'unavailable'; return
    fi
    used=$(( (total - free) / 1024 ))
    total_mb=$(( total / 1024 ))
    pct=$(( (total - free) * 100 / total ))
    printf '%d MiB / %d MiB (%d%%)' "$used" "$total_mb" "$pct"
}

# remvps_dashboard_disk — get disk usage for /
remvps_dashboard_disk() {
    df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}' || printf 'unavailable'
}

# remvps_dashboard_draw — render the full dashboard
remvps_dashboard_draw() {
    remvps_clear

    # Logo
    remvps_print_logo
    remvps_print_title

    # System stats
    local docker_status docker_version vps_running vps_stopped vps_total
    local cpu_pct ram_info disk_info

    cpu_pct=$(remvps_dashboard_cpu)
    ram_info=$(remvps_dashboard_ram)
    disk_info=$(remvps_dashboard_disk)

    if docker info &>/dev/null; then
        docker_status="${REMVPS_ACCENT_GOOD}● Running${REMVPS_RESET}"
        docker_version="v$(remvps_docker_version)"
    else
        docker_status="${REMVPS_ACCENT_ERR}● Stopped${REMVPS_RESET}"
        docker_version="unavailable"
    fi

    vps_running=$(remvps_docker_count_running)
    vps_stopped=$(remvps_docker_count_stopped)
    vps_total=$(remvps_docker_count_total)

    # Status color for CPU
    local cpu_color
    if [[ "$cpu_pct" -gt 85 ]]; then cpu_color="${REMVPS_ACCENT_ERR}"
    elif [[ "$cpu_pct" -gt 60 ]]; then cpu_color="${REMVPS_ACCENT_WARN}"
    else cpu_color="${REMVPS_ACCENT_GOOD}"
    fi

    remvps_box_top "  System Overview  "
    remvps_box_empty
    remvps_box_row "  $(remvps_kv 'Docker Status'  "$docker_status")"
    remvps_box_row "  $(remvps_kv 'Docker Version' "$docker_version")"
    remvps_box_row "  $(remvps_kv 'Hostname'       "$(hostname)")"
    remvps_box_row "  $(remvps_kv 'Current User'   "$(whoami)")"
    remvps_box_mid
    remvps_box_row "  $(remvps_kv 'CPU Usage'      "${cpu_color}${cpu_pct}%${REMVPS_RESET}")"
    remvps_box_row "  $(remvps_kv 'RAM Usage'      "$ram_info")"
    remvps_box_row "  $(remvps_kv 'Disk Usage'     "$disk_info")"
    remvps_box_mid
    remvps_box_row "  $(remvps_kv 'Running VPS'    "${REMVPS_ACCENT_GOOD}${vps_running}${REMVPS_RESET}")"
    remvps_box_row "  $(remvps_kv 'Stopped VPS'    "${REMVPS_ACCENT_WARN}${vps_stopped}${REMVPS_RESET}")"
    remvps_box_row "  $(remvps_kv 'Total VPS'      "${REMVPS_BOLD_WHITE}${vps_total}${REMVPS_RESET}")"
    remvps_box_empty
    remvps_box_bottom
    printf '\n'
}
