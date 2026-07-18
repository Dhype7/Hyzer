hashid_identify() {
    ui_push_breadcrumb "Identify Hash"
    ui_header
    ui_section "Hash Identification (hashid)"
    
    if ! command -v hashid >/dev/null 2>&1; then
        ui_error "hashid is not installed. Please run: sudo apt install hashid"
        ui_pause
        ui_pop_breadcrumb
        return 1
    fi
    
    ui_print "You can enter a single hash string, or the absolute path to a file."
    ui_prompt_text "Enter hash string or file path"
    local input="$REPLY"
    
    if [[ -z "$input" ]]; then
        ui_pop_breadcrumb
        return 1
    fi
    
    ui_newline
    echo -e "${CLR_CYAN}--- Hash Identification Results ---${CLR_RESET}"
    local output=""
    if [[ -f "$input" ]]; then
        output=$(hashid -mj "$input")
    else
        output=$(echo "$input" | hashid -mj)
    fi
    echo "$output"
    echo -e "${CLR_CYAN}-----------------------------------${CLR_RESET}"
    ui_newline
    
    # Parse the first suggested Hashcat Mode and John Format
    local hc_mode
    hc_mode=$(echo "$output" | grep -oP '\[Hashcat Mode: \K[0-9]+' | head -1)
    local john_fmt
    john_fmt=$(echo "$output" | grep -oP '\[JtR Format: \K[^]]+' | head -1)

    if [[ -n "$hc_mode" || -n "$john_fmt" ]]; then
        ui_tip "Recommended Next Steps:"
        local hc_opt=0
        local john_opt=0
        local opts_cnt=0

        if [[ -n "$hc_mode" ]]; then
            ((opts_cnt++))
            hc_opt=$opts_cnt
            ui_menu_item $hc_opt "Launch Hashcat Dictionary Attack (Mode $hc_mode)"
        fi
        if [[ -n "$john_fmt" ]]; then
            ((opts_cnt++))
            john_opt=$opts_cnt
            ui_menu_item $john_opt "Launch John the Ripper Wordlist Attack (Format $john_fmt)"
        fi
        ui_menu_back
        
        ui_newline
        ui_prompt_choice "Select an option" $opts_cnt
        local choice=$REPLY

        if (( choice > 0 )); then
            # If input was a string, write it to a temp file for the tools
            local target_file="$input"
            if [[ ! -f "$input" ]]; then
                target_file="/tmp/hyzer_target_hash.txt"
                echo "$input" > "$target_file"
                ui_info "Saved hash string to temporary file: $target_file"
            fi

            if (( choice == hc_opt )); then
                export HASHID_CHAIN_FILE="$target_file"
                export HASHID_CHAIN_HC_MODE="$hc_mode"
                hashcat_quick_dictionary
            elif (( choice == john_opt )); then
                export JOHN_CHAIN_HASHFILE="$target_file"
                export HASHID_CHAIN_JOHN_FMT="$john_fmt"
                john_quick_wordlist
            fi
        fi
    else
        ui_pause
    fi
    
    ui_pop_breadcrumb
}

hashid_menu() {
    ui_push_breadcrumb "Hash Identification"
    while true; do
        ui_header
        ui_menu_item 1 "Identify Hash" "Analyze a hash string or file to find its type"
        ui_menu_back
        
        ui_newline
        ui_prompt_choice "Select an option" 1
        case "$REPLY" in
            1) hashid_identify ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}
