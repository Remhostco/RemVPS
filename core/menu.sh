#!/usr/bin/env bash
# =============================================================================
# REMVPS — core/menu.sh
# Main menu loop
# =============================================================================

remvps_main_menu() {
    while true; do
        remvps_dashboard_draw

        remvps_box_top "  Main Menu  "
        remvps_box_empty
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}1${REMVPS_RESET}  Create VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}2${REMVPS_RESET}  List VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}3${REMVPS_RESET}  Open VPS Console"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}4${REMVPS_RESET}  Start VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}5${REMVPS_RESET}  Stop VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}6${REMVPS_RESET}  Restart VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}7${REMVPS_RESET}  Delete VPS"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}8${REMVPS_RESET}  VPS Information"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}9${REMVPS_RESET}  Backup & Restore"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}S${REMVPS_RESET}  Settings"
        remvps_box_row "  ${REMVPS_ACCENT_TITLE}0${REMVPS_RESET}  Exit"
        remvps_box_empty
        remvps_box_bottom

        printf '\n'
        printf "  ${REMVPS_ACCENT_TITLE}${REMVPS_ICON_ARROW}${REMVPS_RESET}  ${REMVPS_BOLD_WHITE}Choice${REMVPS_RESET} : "
        local choice
        read -r choice

        case "${choice,,}" in
            1) remvps_op_create      ;;
            2) remvps_op_list        ;;
            3) remvps_op_open        ;;
            4) remvps_op_start       ;;
            5) remvps_op_stop        ;;
            6) remvps_op_restart     ;;
            7) remvps_op_delete      ;;
            8) remvps_op_info        ;;
            9) remvps_op_backup_menu ;;
            s) remvps_op_settings    ;;
            0)
                remvps_clear
                remvps_print_logo
                remvps_print_title
                printf "  ${REMVPS_ACCENT_GOOD}${REMVPS_ICON_OK}${REMVPS_RESET}  Goodbye.\n\n"
                remvps_backup_daemon_stop
                exit 0
                ;;
            *)
                remvps_msg_warn "Invalid selection. Press 0 to exit."
                sleep 0.8
                ;;
        esac
    done
}
