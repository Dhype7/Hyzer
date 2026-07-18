# =============================================================================
# ui.sh — Hyzer Core UI Library
# Sourced by the main hyzer script. Defines colors, display, input, and
# command-execution helpers.
# =============================================================================

# -----------------------------------------------------------------------------
# COLOR PALETTE
# -----------------------------------------------------------------------------

# Styles
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"
CLR_ITALIC="\033[3m"
CLR_UNDERLINE="\033[4m"

# Foreground — 256-color
CLR_RED="\033[38;5;196m"
CLR_GREEN="\033[38;5;82m"
CLR_YELLOW="\033[38;5;220m"
CLR_CYAN="\033[38;5;51m"
CLR_MAGENTA="\033[38;5;213m"
CLR_BLUE="\033[38;5;33m"
CLR_ORANGE="\033[38;5;208m"
CLR_WHITE="\033[38;5;255m"
CLR_GRAY="\033[38;5;245m"

# Backgrounds
CLR_BG_RED="\033[48;5;196m"
CLR_BG_GREEN="\033[48;5;22m"
CLR_BG_CYAN="\033[48;5;23m"
CLR_BG_YELLOW="\033[48;5;58m"

# -----------------------------------------------------------------------------
# ui_apply_theme — swap palette for light terminals
# Reads HYZER_CFG_THEME (set by config.sh). Default = dark.
# -----------------------------------------------------------------------------
ui_apply_theme() {
    local theme="${HYZER_CFG_THEME:-dark}"
    if [[ "$theme" == "light" ]]; then
        # Darker text variants for light backgrounds
        CLR_RED="\033[38;5;124m"
        CLR_GREEN="\033[38;5;28m"
        CLR_YELLOW="\033[38;5;136m"
        CLR_CYAN="\033[38;5;30m"
        CLR_MAGENTA="\033[38;5;127m"
        CLR_BLUE="\033[38;5;25m"
        CLR_ORANGE="\033[38;5;166m"
        CLR_WHITE="\033[38;5;16m"
        CLR_GRAY="\033[38;5;240m"
        CLR_BG_GREEN="\033[48;5;157m"
        CLR_BG_CYAN="\033[48;5;152m"
        CLR_BG_YELLOW="\033[48;5;229m"
        CLR_BG_RED="\033[48;5;217m"
    fi
}

# -----------------------------------------------------------------------------
# HYZER ASCII BANNER
# -----------------------------------------------------------------------------
ui_banner() {
    local use_figlet=false
    if command -v figlet &>/dev/null && [[ "${HYZER_CFG_FIGLET:-true}" == "true" ]]; then
        use_figlet=true
    fi

    echo ""
    if $use_figlet; then
        echo -e "${CLR_CYAN}${CLR_BOLD}"
        figlet -f slant "HYZER" 2>/dev/null || {
            # Fallback if the font isn't available
            _ui_banner_hardcoded
        }
        echo -e "${CLR_RESET}"
    else
        _ui_banner_hardcoded
    fi

    echo -e "${CLR_GRAY}  v1.0.0  |  Password Attack Toolkit  |  by dhype7${CLR_RESET}"
    echo -e "${CLR_DIM}$(printf '─%.0s' $(seq 1 60))${CLR_RESET}"
    echo ""
}

_ui_banner_hardcoded() {
    echo -e "${CLR_CYAN}${CLR_BOLD}"
    cat <<'BANNER'
 ██╗  ██╗██╗   ██╗███████╗███████╗██████╗ 
 ██║  ██║╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
 ███████║ ╚████╔╝   ███╔╝ █████╗  ██████╔╝
 ██╔══██║  ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
 ██║  ██║   ██║   ███████╗███████╗██║  ██║
 ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
BANNER
    echo -e "${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# NAVIGATION — BREADCRUMB SYSTEM
# -----------------------------------------------------------------------------
HYZER_BREADCRUMB=("Hyzer")

ui_push_breadcrumb() {
    local name="$1"
    HYZER_BREADCRUMB+=("$name")
}

ui_pop_breadcrumb() {
    local len=${#HYZER_BREADCRUMB[@]}
    if (( len > 1 )); then
        unset 'HYZER_BREADCRUMB[len-1]'
    fi
}

ui_get_breadcrumb() {
    local result=""
    local first=true
    for crumb in "${HYZER_BREADCRUMB[@]}"; do
        if $first; then
            result="$crumb"
            first=false
        else
            result="$result > $crumb"
        fi
    done
    echo "$result"
}

# -----------------------------------------------------------------------------
# DISPLAY FUNCTIONS
# -----------------------------------------------------------------------------

# ui_header — clear screen, thin line, breadcrumb, thin line
ui_header() {
    clear
    echo -e "${CLR_DIM}$(printf '─%.0s' $(seq 1 60))${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}  $(ui_get_breadcrumb)${CLR_RESET}"
    echo -e "${CLR_DIM}$(printf '─%.0s' $(seq 1 60))${CLR_RESET}"
}

# ui_section — title in cyan+bold+underline
ui_section() {
    local title="$1"
    echo ""
    echo -e "${CLR_CYAN}${CLR_BOLD}${CLR_UNDERLINE}${title}${CLR_RESET}"
    echo ""
}

# ui_subsection — title in magenta
ui_subsection() {
    local title="$1"
    echo ""
    echo -e "${CLR_MAGENTA}${title}${CLR_RESET}"
}

# ui_line — horizontal line, default char='─', default length=60
ui_line() {
    local char="${1:-─}"
    local length="${2:-60}"
    echo -e "${CLR_DIM}$(printf "${char}%.0s" $(seq 1 "$length"))${CLR_RESET}"
}

# ui_thick_line — '═' in cyan, length 60
ui_thick_line() {
    echo -e "${CLR_CYAN}$(printf '═%.0s' $(seq 1 60))${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# OUTPUT HELPERS
# -----------------------------------------------------------------------------

ui_info() {
    echo -e "${CLR_CYAN}[*]${CLR_RESET} $1"
}

ui_success() {
    echo -e "${CLR_GREEN}[✓]${CLR_RESET} $1"
}

ui_warn() {
    echo -e "${CLR_YELLOW}[!]${CLR_RESET} $1"
}

ui_error() {
    echo -e "${CLR_RED}[✗]${CLR_RESET} $1"
}

ui_tip() {
    echo -e "${CLR_MAGENTA}[TIP]${CLR_RESET} $1"
}

ui_print() {
    echo -e "$1${CLR_RESET}"
}

ui_newline() {
    echo ""
}

# -----------------------------------------------------------------------------
# INPUT HELPERS
# -----------------------------------------------------------------------------

# ui_prompt — yellow prompt with ❯ prefix, reads into REPLY
ui_prompt() {
    local prompt_text="$1"
    echo -ne "${CLR_YELLOW}${prompt_text} ❯ ${CLR_RESET}"
    read -r REPLY
}

# ui_prompt_choice — numeric choice 0..max_num, loops until valid
ui_prompt_choice() {
    local prompt_text="$1"
    local max_num="$2"

    while true; do
        echo -ne "${CLR_YELLOW}${prompt_text} [0-${max_num}] ❯ ${CLR_RESET}"
        read -r REPLY
        # Validate: must be an integer in range
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 0 && REPLY <= max_num )); then
            return 0
        fi
        ui_error "Invalid choice. Please enter a number between 0 and ${max_num}."
    done
}

# ui_prompt_yesno — [Y/n] or [y/N], returns 0=yes, 1=no
ui_prompt_yesno() {
    local prompt_text="$1"
    local default="${2:-y}"

    local hint
    if [[ "$default" == "y" || "$default" == "Y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    while true; do
        echo -ne "${CLR_YELLOW}${prompt_text} ${hint} ❯ ${CLR_RESET}"
        read -r REPLY
        REPLY="${REPLY:-$default}"
        case "${REPLY,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     ui_error "Please answer y or n." ;;
        esac
    done
}

# ui_prompt_file — file path with -f validation, re-prompts on invalid
ui_prompt_file() {
    local prompt_text="$1"

    while true; do
        echo -ne "${CLR_YELLOW}${prompt_text} ❯ ${CLR_RESET}"
        read -r -e REPLY
        if [[ -f "$REPLY" ]]; then
            return 0
        fi
        ui_error "File not found: ${REPLY}"
    done
}

# ui_prompt_text — text input with optional default
ui_prompt_text() {
    local prompt_text="$1"
    local default="${2:-}"

    if [[ -n "$default" ]]; then
        echo -ne "${CLR_YELLOW}${prompt_text} [${default}] ❯ ${CLR_RESET}"
    else
        echo -ne "${CLR_YELLOW}${prompt_text} ❯ ${CLR_RESET}"
    fi
    read -r REPLY
    REPLY="${REPLY:-$default}"
}

# ui_prompt_optional — allows empty input
ui_prompt_optional() {
    local prompt_text="$1"
    echo -ne "${CLR_YELLOW}${prompt_text} ${CLR_DIM}(optional, press Enter to skip)${CLR_YELLOW} ❯ ${CLR_RESET}"
    read -r REPLY
}

# -----------------------------------------------------------------------------
# COMMAND EXECUTION
# -----------------------------------------------------------------------------

# confirm_and_run — the CRITICAL interactive command runner
# Usage: confirm_and_run "command" ["result_callback_function"]
# The optional callback receives (logfile, exit_code) and is called before the pause.
confirm_and_run() {
    local command_string="$1"
    local result_callback="${2:-}"

    _ui_show_command() {
        echo ""
        echo -e "  ${CLR_BOLD}Command to execute:${CLR_RESET}"
        echo ""
        echo -e "  ${CLR_DIM}╭──────────────────────────────────────────────────────────╮${CLR_RESET}"
        # Wrap long commands cleanly: fold at 54 chars, indent continuation lines
        local wrapped
        wrapped=$(echo "$1" | fold -s -w 54)
        local first=true
        while IFS= read -r wline; do
            if $first; then
                echo -e "  ${CLR_DIM}│${CLR_RESET}  ${CLR_GREEN}${CLR_BOLD}\$ ${wline}${CLR_RESET}"
                first=false
            else
                echo -e "  ${CLR_DIM}│${CLR_RESET}    ${CLR_GREEN}${wline}${CLR_RESET}"
            fi
        done <<< "$wrapped"
        echo -e "  ${CLR_DIM}╰──────────────────────────────────────────────────────────╯${CLR_RESET}"
        echo ""
    }

    _ui_show_command "$command_string"

    while true; do
        echo -ne "${CLR_YELLOW}  Execute this command? [Y/n/e=edit] ❯ ${CLR_RESET}"
        read -r _choice
        _choice="${_choice:-y}"

        case "${_choice,,}" in
            y|yes)
                echo ""
                ui_info "Executing..."
                ui_line

                # Start log entry
                if declare -f cfg_log_command &>/dev/null; then
                    cfg_log_command "$command_string"
                fi

                # Append to history
                if declare -f cfg_append_history &>/dev/null; then
                    cfg_append_history "$command_string"
                fi

                # Determine log file path
                local _logfile=""
                if [[ -n "${HYZER_CURRENT_LOG:-}" ]]; then
                    _logfile="$HYZER_CURRENT_LOG"
                fi

                # Save original trap, set up SIGINT handler
                local _old_trap
                _old_trap=$(trap -p INT)
                trap 'echo ""; ui_warn "Command interrupted by Ctrl+C."; trap - INT; eval "$_old_trap" 2>/dev/null; _run_exit_code=130; break' INT

                local _run_exit_code=0

                # Execute with eval, stream output live, tee to log
                if [[ -n "$_logfile" ]]; then
                    eval "$command_string" 2>&1 | tee -a "$_logfile"
                    _run_exit_code=${PIPESTATUS[0]}
                else
                    eval "$command_string"
                    _run_exit_code=$?
                fi

                # Restore original trap
                trap - INT
                eval "$_old_trap" 2>/dev/null

                # Log end
                if declare -f cfg_log_end &>/dev/null; then
                    cfg_log_end "$_run_exit_code"
                fi

                # Collect loot (check for cracks)
                if declare -f cfg_collect_loot &>/dev/null; then
                    cfg_collect_loot
                fi

                echo ""
                ui_line

                # Call tool-specific result parser if provided
                if [[ -n "$result_callback" ]] && declare -f "$result_callback" &>/dev/null; then
                    "$result_callback" "${_logfile:-/dev/null}" "$_run_exit_code" "$command_string"
                    echo ""
                fi

                if (( _run_exit_code == 0 )); then
                    ui_success "Command completed successfully (exit code: 0)"
                else
                    ui_error "Command failed (exit code: ${_run_exit_code})"
                fi

                echo ""
                ui_pause
                return "$_run_exit_code"
                ;;

            n|no)
                echo ""
                ui_warn "Command cancelled."
                return 1
                ;;

            e|edit)
                echo ""
                echo -ne "${CLR_YELLOW}  Edit command ❯ ${CLR_RESET}"
                read -r -e -i "$command_string" command_string
                _ui_show_command "$command_string"
                # Loop back to prompt again
                ;;

            *)
                ui_error "Invalid option. Please choose y, n, or e."
                ;;
        esac
    done
}

# ui_pause — wait for Enter
ui_pause() {
    echo -ne "${CLR_DIM}  Press Enter to continue...${CLR_RESET}"
    read -r
}

# ui_wait_key — wait for single keypress
ui_wait_key() {
    local msg="${1:-Press any key to continue...}"
    echo -ne "${CLR_DIM}  ${msg}${CLR_RESET}"
    read -r -n 1 -s
    echo ""
}

# -----------------------------------------------------------------------------
# MENU HELPERS
# -----------------------------------------------------------------------------

# ui_menu_item — formatted menu entry with optional description
ui_menu_item() {
    local number="$1"
    local text="$2"
    local description="${3:-}"

    echo -e "  ${CLR_CYAN}[${number}]${CLR_RESET} ${CLR_WHITE}${text}${CLR_RESET}"
    if [[ -n "$description" ]]; then
        echo -e "       ${CLR_GRAY}${description}${CLR_RESET}"
    fi
}

# ui_menu_back — [0] Back in gray
ui_menu_back() {
    echo -e "  ${CLR_GRAY}[0] Back${CLR_RESET}"
}

# ui_menu_exit — [0] Exit in gray
ui_menu_exit() {
    echo -e "  ${CLR_GRAY}[0] Exit${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# CHEAT SHEET DISPLAY
# -----------------------------------------------------------------------------

# ui_cheatsheet_start — boxed header with ═ borders
ui_cheatsheet_start() {
    local title="$1"
    local width=60
    local title_len=${#title}
    local pad_total=$(( width - title_len - 4 ))  # 4 = "║ " + " ║"
    local pad_left=$(( pad_total / 2 ))
    local pad_right=$(( pad_total - pad_left ))

    echo ""
    echo -e "${CLR_CYAN}╔$(printf '═%.0s' $(seq 1 $((width - 2))))╗${CLR_RESET}"
    echo -e "${CLR_CYAN}║${CLR_RESET}$(printf ' %.0s' $(seq 1 "$pad_left"))${CLR_BOLD}${CLR_WHITE}${title}${CLR_RESET}$(printf ' %.0s' $(seq 1 "$pad_right"))${CLR_CYAN}║${CLR_RESET}"
    echo -e "${CLR_CYAN}╠$(printf '═%.0s' $(seq 1 $((width - 2))))╣${CLR_RESET}"
}

# ui_cheatsheet_cmd — description + indented green command
ui_cheatsheet_cmd() {
    local description="$1"
    local command="$2"

    echo -e "${CLR_CYAN}║${CLR_RESET}  ${CLR_WHITE}${description}${CLR_RESET}"
    echo -e "${CLR_CYAN}║${CLR_RESET}    ${CLR_GREEN}${command}${CLR_RESET}"
    echo -e "${CLR_CYAN}║${CLR_RESET}"
}

# ui_cheatsheet_table_row — aligned columns (2 or 3)
ui_cheatsheet_table_row() {
    local col1="$1"
    local col2="$2"
    local col3="${3:-}"

    if [[ -n "$col3" ]]; then
        printf "${CLR_CYAN}║${CLR_RESET}  ${CLR_WHITE}%-18s${CLR_RESET} ${CLR_GREEN}%-18s${CLR_RESET} ${CLR_GRAY}%-16s${CLR_RESET}\n" \
            "$col1" "$col2" "$col3"
    else
        printf "${CLR_CYAN}║${CLR_RESET}  ${CLR_WHITE}%-24s${CLR_RESET} ${CLR_GREEN}%-30s${CLR_RESET}\n" \
            "$col1" "$col2"
    fi
}

# ui_cheatsheet_end — bottom ═ border
ui_cheatsheet_end() {
    echo -e "${CLR_CYAN}╚$(printf '═%.0s' $(seq 1 58))╝${CLR_RESET}"
    echo ""
}
