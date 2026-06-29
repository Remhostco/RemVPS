#!/usr/bin/env bash
# =============================================================================
# REMVPS — ui/draw.sh
# Terminal UI primitives: boxes, separators, progress bars, dialogs
# =============================================================================

# Source colors if not already loaded
[[ -z "${REMVPS_RESET:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# -----------------------------------------------------------------------------
# remvps_clear — clear the screen
# -----------------------------------------------------------------------------
remvps_clear() { clear; }

# -----------------------------------------------------------------------------
# remvps_term_width — get terminal width with a safe fallback
# -----------------------------------------------------------------------------
remvps_term_width() {
    local w
    w=$(tput cols 2>/dev/null) || w=80
    echo "$w"
}

# -----------------------------------------------------------------------------
# remvps_repeat CHAR N — print a character N times
# -----------------------------------------------------------------------------
remvps_repeat() {
    local char="$1" count="$2"
    printf '%0.s'"$char" $(seq 1 "$count")
}

# -----------------------------------------------------------------------------
# remvps_hline — full-width double-line separator
# -----------------------------------------------------------------------------
remvps_hline() {
    local w
    w=$(remvps_term_width)
    printf "${REMVPS_ACCENT_BORDER}"
    remvps_repeat "${REMVPS_H}" "$w"
    printf "${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_hline2 — full-width single-line separator
# -----------------------------------------------------------------------------
remvps_hline2() {
    local w
    w=$(remvps_term_width)
    printf "${REMVPS_ACCENT_BORDER}"
    remvps_repeat "${REMVPS_H2}" "$w"
    printf "${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_box_top TITLE — draw the top of a titled double-border box
# -----------------------------------------------------------------------------
remvps_box_top() {
    local title="${1:-}" w inner pad_left pad_right title_len
    w=$(remvps_term_width)
    inner=$((w - 2))
    title_len=${#title}
    if [[ $title_len -gt 0 ]]; then
        pad_left=$(( (inner - title_len - 2) / 2 ))
        pad_right=$(( inner - title_len - 2 - pad_left ))
        printf "${REMVPS_ACCENT_BORDER}${REMVPS_TL}"
        remvps_repeat "${REMVPS_H}" "$pad_left"
        printf "${REMVPS_ACCENT_TITLE}${REMVPS_BOLD} %s ${REMVPS_RESET}${REMVPS_ACCENT_BORDER}" "$title"
        remvps_repeat "${REMVPS_H}" "$pad_right"
        printf "${REMVPS_TR}${REMVPS_RESET}\n"
    else
        printf "${REMVPS_ACCENT_BORDER}${REMVPS_TL}"
        remvps_repeat "${REMVPS_H}" "$inner"
        printf "${REMVPS_TR}${REMVPS_RESET}\n"
    fi
}

# -----------------------------------------------------------------------------
# remvps_box_bottom — draw the bottom of a double-border box
# -----------------------------------------------------------------------------
remvps_box_bottom() {
    local w inner
    w=$(remvps_term_width)
    inner=$((w - 2))
    printf "${REMVPS_ACCENT_BORDER}${REMVPS_BL}"
    remvps_repeat "${REMVPS_H}" "$inner"
    printf "${REMVPS_BR}${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_box_mid — draw a middle separator inside a box
# -----------------------------------------------------------------------------
remvps_box_mid() {
    local w inner
    w=$(remvps_term_width)
    inner=$((w - 2))
    printf "${REMVPS_ACCENT_BORDER}${REMVPS_ML}"
    remvps_repeat "${REMVPS_H}" "$inner"
    printf "${REMVPS_MR}${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_box_row TEXT — print a padded row inside a box
# -----------------------------------------------------------------------------
remvps_box_row() {
    local text="${1:-}" w inner text_len pad
    w=$(remvps_term_width)
    inner=$((w - 4))
    # Strip ANSI codes to get visual length
    local stripped
    stripped=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
    text_len=${#stripped}
    pad=$((inner - text_len))
    [[ $pad -lt 0 ]] && pad=0
    printf "${REMVPS_ACCENT_BORDER}${REMVPS_V}${REMVPS_RESET} %b" "$text"
    printf '%*s' "$pad" ''
    printf "${REMVPS_ACCENT_BORDER}${REMVPS_V}${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_box_empty — print an empty row inside a box
# -----------------------------------------------------------------------------
remvps_box_empty() {
    local w inner
    w=$(remvps_term_width)
    inner=$((w - 2))
    printf "${REMVPS_ACCENT_BORDER}${REMVPS_V}"
    printf '%*s' "$inner" ''
    printf "${REMVPS_V}${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_print_logo — load and print the ASCII logo in brand color
# -----------------------------------------------------------------------------
remvps_print_logo() {
    local logo_path
    logo_path="$(dirname "${BASH_SOURCE[0]}")/../assets/logo.txt"
    if [[ -f "$logo_path" ]]; then
        printf "${REMVPS_ACCENT_LOGO}"
        cat "$logo_path"
        printf "${REMVPS_RESET}"
    fi
}

# -----------------------------------------------------------------------------
# remvps_print_title — centered application title line
# -----------------------------------------------------------------------------
remvps_print_title() {
    local w title
    w=$(remvps_term_width)
    title="R E M V P S"
    local subtitle="Virtual Private Server Manager"
    local tlen=${#title}
    local slen=${#subtitle}
    local tpad=$(( (w - tlen) / 2 ))
    local spad=$(( (w - slen) / 2 ))
    printf '\n'
    printf "%${tpad}s${REMVPS_BOLD_WHITE}${REMVPS_BOLD}%s${REMVPS_RESET}\n" '' "$title"
    printf "%${spad}s${REMVPS_ACCENT_DIM}%s${REMVPS_RESET}\n\n" '' "$subtitle"
}

# -----------------------------------------------------------------------------
# remvps_progress_bar LABEL PERCENT — animated progress bar
# -----------------------------------------------------------------------------
remvps_progress_bar() {
    local label="${1:-Working}" pct="${2:-0}"
    local bar_width=40 filled empty
    filled=$(( pct * bar_width / 100 ))
    empty=$(( bar_width - filled ))
    printf "\r  ${REMVPS_ACCENT_DIM}%-20s${REMVPS_RESET} ${REMVPS_ACCENT_BORDER}[${REMVPS_RESET}" "$label"
    printf "${REMVPS_ACCENT_GOOD}%${filled}s${REMVPS_RESET}" | tr ' ' '█'
    printf "${REMVPS_ACCENT_BORDER}%${empty}s${REMVPS_RESET}" | tr ' ' '░'
    printf "${REMVPS_ACCENT_BORDER}]${REMVPS_RESET} ${REMVPS_BOLD_WHITE}%3d%%${REMVPS_RESET}" "$pct"
}

# -----------------------------------------------------------------------------
# remvps_spinner PID LABEL — show spinner next to LABEL while PID is running
# -----------------------------------------------------------------------------
remvps_spinner() {
    local pid="$1" label="${2:-Please wait}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${REMVPS_ACCENT_HL}%s${REMVPS_RESET}  ${REMVPS_ACCENT_DIM}%s${REMVPS_RESET}  " \
            "${frames[$i]}" "$label"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done
    printf "\r%*s\r" "$(remvps_term_width)" ''
    tput cnorm 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# remvps_fake_progress LABEL — animated fake progress bar (for build steps)
# -----------------------------------------------------------------------------
remvps_fake_progress() {
    local label="${1:-Building}" total="${2:-30}" delay="${3:-0.07}"
    for i in $(seq 1 "$total"); do
        local pct=$(( i * 100 / total ))
        remvps_progress_bar "$label" "$pct"
        sleep "$delay"
    done
    printf '\n'
}

# -----------------------------------------------------------------------------
# remvps_msg_ok TEXT — success message line
# -----------------------------------------------------------------------------
remvps_msg_ok() {
    printf "  ${REMVPS_ACCENT_GOOD}${REMVPS_ICON_OK}${REMVPS_RESET}  %b\n" "$*"
}

# -----------------------------------------------------------------------------
# remvps_msg_err TEXT — error message line
# -----------------------------------------------------------------------------
remvps_msg_err() {
    printf "  ${REMVPS_ACCENT_ERR}${REMVPS_ICON_FAIL}${REMVPS_RESET}  ${REMVPS_BOLD_RED}%b${REMVPS_RESET}\n" "$*" >&2
}

# -----------------------------------------------------------------------------
# remvps_msg_warn TEXT — warning message line
# -----------------------------------------------------------------------------
remvps_msg_warn() {
    printf "  ${REMVPS_ACCENT_WARN}${REMVPS_ICON_WARN}${REMVPS_RESET}  ${REMVPS_YELLOW}%b${REMVPS_RESET}\n" "$*"
}

# -----------------------------------------------------------------------------
# remvps_msg_info TEXT — informational message line
# -----------------------------------------------------------------------------
remvps_msg_info() {
    printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_INFO}${REMVPS_RESET}  %b\n" "$*"
}

# -----------------------------------------------------------------------------
# remvps_section TITLE — print a section header
# -----------------------------------------------------------------------------
remvps_section() {
    printf "\n  ${REMVPS_ACCENT_TITLE}${REMVPS_BOLD}%s${REMVPS_RESET}\n" "$1"
    printf "  ${REMVPS_ACCENT_BORDER}"
    remvps_repeat "${REMVPS_H2}" $(( ${#1} ))
    printf "${REMVPS_RESET}\n"
}

# -----------------------------------------------------------------------------
# remvps_kv KEY VALUE [VALUE_COLOR] — key/value pair display
# -----------------------------------------------------------------------------
remvps_kv() {
    local key="$1" value="$2" color="${3:-${REMVPS_BOLD_WHITE}}"
    printf "  ${REMVPS_ACCENT_DIM}%-22s${REMVPS_RESET} ${color}%s${REMVPS_RESET}\n" "${key}:" "$value"
}

# -----------------------------------------------------------------------------
# remvps_confirm PROMPT — yes/no confirmation dialog; returns 0 for yes
# -----------------------------------------------------------------------------
remvps_confirm() {
    local prompt="${1:-Are you sure?}"
    local answer
    printf "\n  ${REMVPS_ACCENT_WARN}${REMVPS_ICON_WARN}${REMVPS_RESET}  ${REMVPS_BOLD_YELLOW}%s${REMVPS_RESET}" "$prompt"
    printf " ${REMVPS_ACCENT_DIM}[y/N]${REMVPS_RESET} "
    read -r answer
    [[ "${answer,,}" == 'y' || "${answer,,}" == 'yes' ]]
}

# -----------------------------------------------------------------------------
# remvps_pause — press-enter-to-continue
# -----------------------------------------------------------------------------
remvps_pause() {
    printf "\n  ${REMVPS_ACCENT_DIM}Press Enter to continue...${REMVPS_RESET}"
    read -r _
}

# -----------------------------------------------------------------------------
# remvps_input VARNAME PROMPT [DEFAULT] — styled prompt with optional default
# -----------------------------------------------------------------------------
remvps_input() {
    local __var="$1" prompt="$2" default="${3:-}"
    local display_default=""
    [[ -n "$default" ]] && display_default=" ${REMVPS_ACCENT_DIM}[${default}]${REMVPS_RESET}"
    printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}%s${REMVPS_RESET}%b : " \
        "$prompt" "$display_default"
    local __val
    read -r __val
    [[ -z "$__val" && -n "$default" ]] && __val="$default"
    printf -v "$__var" '%s' "$__val"
}

# -----------------------------------------------------------------------------
# remvps_input_secret VARNAME PROMPT — styled prompt, hides input
# -----------------------------------------------------------------------------
remvps_input_secret() {
    local __var="$1" prompt="$2"
    printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}%s${REMVPS_RESET} : " "$prompt"
    local __val
    read -rs __val
    printf '\n'
    printf -v "$__var" '%s' "$__val"
}

# -----------------------------------------------------------------------------
# remvps_select_from_list VARNAME TITLE ITEM... — numbered select menu
# Returns 1 if list is empty
# -----------------------------------------------------------------------------
remvps_select_from_list() {
    local __result_var="$1"; shift
    local title="$1"; shift
    local -a items=("$@")

    if [[ ${#items[@]} -eq 0 ]]; then
        remvps_msg_warn "No items available."
        return 1
    fi

    printf '\n'
    remvps_section "$title"
    local i
    for i in "${!items[@]}"; do
        printf "  ${REMVPS_ACCENT_TITLE}%2d${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}%s${REMVPS_RESET}\n" \
            "$((i + 1))" "${items[$i]}"
    done
    printf '\n'

    local choice
    while true; do
        printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}Select${REMVPS_RESET} ${REMVPS_ACCENT_DIM}[1-%d]${REMVPS_RESET} : " "${#items[@]}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && \
           [[ "$choice" -ge 1 ]] && \
           [[ "$choice" -le "${#items[@]}" ]]; then
            printf -v "$__result_var" '%s' "${items[$((choice - 1))]}"
            return 0
        fi
        remvps_msg_err "Invalid selection. Enter a number between 1 and ${#items[@]}."
    done
}

# -----------------------------------------------------------------------------
# remvps_dialog_error TITLE MSG — full-width error dialog
# -----------------------------------------------------------------------------
remvps_dialog_error() {
    local title="${1:-Error}" msg="${2:-An error occurred.}"
    printf '\n'
    remvps_box_top "  ${REMVPS_ICON_FAIL}  ${title}  "
    remvps_box_empty
    remvps_box_row "  ${REMVPS_ACCENT_ERR}${msg}${REMVPS_RESET}"
    remvps_box_empty
    remvps_box_bottom
    printf '\n'
}

# -----------------------------------------------------------------------------
# remvps_dialog_success TITLE MSG — full-width success dialog
# -----------------------------------------------------------------------------
remvps_dialog_success() {
    local title="${1:-Success}" msg="${2:-Operation completed.}"
    printf '\n'
    remvps_box_top "  ${REMVPS_ICON_OK}  ${title}  "
    remvps_box_empty
    remvps_box_row "  ${REMVPS_ACCENT_GOOD}${msg}${REMVPS_RESET}"
    remvps_box_empty
    remvps_box_bottom
    printf '\n'
}
