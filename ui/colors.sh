#!/usr/bin/env bash
# =============================================================================
# REMVPS — ui/colors.sh
# ANSI color codes and terminal formatting constants
# =============================================================================

# Reset
REMVPS_RESET='\e[0m'

# Standard colors
REMVPS_BLACK='\e[0;30m'
REMVPS_RED='\e[0;31m'
REMVPS_GREEN='\e[0;32m'
REMVPS_YELLOW='\e[0;33m'
REMVPS_BLUE='\e[0;34m'
REMVPS_MAGENTA='\e[0;35m'
REMVPS_CYAN='\e[0;36m'
REMVPS_WHITE='\e[0;37m'

# Bold colors
REMVPS_BOLD_RED='\e[1;31m'
REMVPS_BOLD_GREEN='\e[1;32m'
REMVPS_BOLD_YELLOW='\e[1;33m'
REMVPS_BOLD_BLUE='\e[1;34m'
REMVPS_BOLD_MAGENTA='\e[1;35m'
REMVPS_BOLD_CYAN='\e[1;36m'
REMVPS_BOLD_WHITE='\e[1;37m'

# 256-color palette (brand accents)
REMVPS_ACCENT_LOGO='\e[38;5;208m'     # Orange  — logo highlight
REMVPS_ACCENT_TITLE='\e[38;5;39m'     # Sky blue — section titles
REMVPS_ACCENT_BORDER='\e[38;5;240m'   # Dark grey — borders
REMVPS_ACCENT_GOOD='\e[38;5;82m'      # Bright green — success
REMVPS_ACCENT_WARN='\e[38;5;220m'     # Amber — warnings
REMVPS_ACCENT_ERR='\e[38;5;196m'      # Bright red — errors
REMVPS_ACCENT_DIM='\e[38;5;245m'      # Grey — secondary text
REMVPS_ACCENT_HL='\e[38;5;51m'        # Aqua — highlights / running state

# Background accents
REMVPS_BG_ERR='\e[41m'
REMVPS_BG_SUCCESS='\e[42m'

# Text styles
REMVPS_BOLD='\e[1m'
REMVPS_DIM='\e[2m'
REMVPS_UNDERLINE='\e[4m'

# Unicode box-drawing characters
REMVPS_TL='╔'
REMVPS_TR='╗'
REMVPS_BL='╚'
REMVPS_BR='╝'
REMVPS_H='═'
REMVPS_V='║'
REMVPS_ML='╠'
REMVPS_MR='╣'

REMVPS_TL2='┌'
REMVPS_TR2='┐'
REMVPS_BL2='└'
REMVPS_BR2='┘'
REMVPS_H2='─'
REMVPS_V2='│'
REMVPS_ML2='├'
REMVPS_MR2='┤'

# Symbols
REMVPS_ICON_OK='✔'
REMVPS_ICON_FAIL='✘'
REMVPS_ICON_WARN='⚠'
REMVPS_ICON_INFO='ℹ'
REMVPS_ICON_ARROW='▶'
REMVPS_ICON_BULLET='•'
REMVPS_ICON_DOT='·'
REMVPS_ICON_STAR='★'
