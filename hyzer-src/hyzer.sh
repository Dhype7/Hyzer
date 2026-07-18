#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
HYZER_LIB_DIR="${SCRIPT_DIR}/lib"

# Load modules
if [[ -d "$HYZER_LIB_DIR" ]]; then
    source "${HYZER_LIB_DIR}/ui.sh"
    source "${HYZER_LIB_DIR}/config.sh"
    source "${HYZER_LIB_DIR}/wordlists.sh"
    source "${HYZER_LIB_DIR}/hashid.sh"
    source "${HYZER_LIB_DIR}/hashcat.sh"
    source "${HYZER_LIB_DIR}/john.sh"
    source "${HYZER_LIB_DIR}/hydra.sh"
else
    echo -e "\033[31m[✗] Error: Cannot find lib/ directory. Make sure Hyzer is installed correctly.\033[0m"
    exit 1
fi

# Initialize Config & Loot
cfg_init
cfg_load
ui_apply_theme

# Global Ctrl+C handler for main menu
trap 'echo -e "\n${CLR_YELLOW}[!] Exiting Hyzer. Good luck!${CLR_RESET}"; exit 0' SIGINT

check_dependencies() {
    local missing=0
    ui_newline
    ui_section "Dependency Check"
    
    if command -v hashcat >/dev/null 2>&1; then
        ui_success "Hashcat found"
    else
        ui_error "Hashcat missing"
        missing=1
    fi
    
    if command -v john >/dev/null 2>&1; then
        ui_success "John the Ripper found"
    else
        ui_error "John the Ripper missing"
        missing=1
    fi
    
    if command -v hydra >/dev/null 2>&1; then
        ui_success "Hydra found"
    else
        ui_error "Hydra missing"
        missing=1
    fi
    
    if command -v hashid >/dev/null 2>&1; then
        ui_success "hashid found"
    else
        ui_warn "hashid missing (used for Hash Identification)"
    fi
    
    if command -v crunch >/dev/null 2>&1; then
        ui_success "crunch found"
    else
        ui_warn "crunch missing (used for wordlist generation)"
    fi
    
    if command -v cewl >/dev/null 2>&1; then
        ui_success "cewl found"
    else
        ui_warn "cewl missing (used for web scraping wordlists)"
    fi
    
    if (( missing > 0 )); then
        ui_newline
        ui_warn "Some core tools are missing. Hyzer will still run, but commands using missing tools will fail."
        ui_pause
    fi
}

show_disclaimer() {
    # Check if disclaimer has been agreed to in config
    local agreed=$(cfg_get "disclaimer_agreed")
    if [[ "$agreed" != "true" ]]; then
        clear
        ui_banner
        ui_newline
        ui_warn "LEGAL & ETHICAL DISCLAIMER"
        ui_print "Hyzer is provided for CTF practice, academic study, and authorized"
        ui_print "penetration testing only."
        ui_newline
        ui_print "By continuing, you agree that you will only use this toolkit against"
        ui_print "systems you explicitly own or have documented permission to test."
        ui_print "The author assumes no liability for illegal or malicious use."
        ui_newline
        ui_prompt_yesno "Do you agree to these terms?" "N"
        if (( $? == 0 )); then
            cfg_save "disclaimer_agreed" "true"
        else
            ui_error "You must agree to the terms to use Hyzer."
            exit 1
        fi
    fi
}

main_menu() {
    while true; do
        ui_header
        ui_banner
        
        ui_menu_item 1 "Hash Identification" "Identify unknown hashes via hashid"
        ui_menu_item 2 "Hashcat" "GPU-accelerated offline hash cracking"
        ui_menu_item 3 "John the Ripper" "CPU-based offline cracking & format helpers"
        ui_menu_item 4 "Hydra" "Network-service login brute-forcing"
        ui_menu_item 5 "Loot & Config" "View cracked passwords, set defaults, themes"
        ui_menu_item 6 "Credits" "About this tool"
        ui_menu_exit
        
        ui_newline
        ui_prompt_choice "Select an option" 6
        case "$REPLY" in
            1) hashid_menu ;;
            2) hashcat_menu ;;
            3) john_menu ;;
            4) hydra_menu ;;
            5) cfg_menu ;;
            6) cfg_credits ;;
            0) 
                ui_newline
                ui_success "Exiting Hyzer. Happy hunting!"
                exit 0 
                ;;
        esac
    done
}

# --- Main Execution ---
show_disclaimer
check_dependencies
main_menu
