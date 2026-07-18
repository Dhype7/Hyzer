WL_PASS_PATHS=(
    "/usr/share/wordlists/rockyou.txt"
    "/usr/share/wordlists/fasttrack.txt"
    "/usr/share/wordlists/john.lst"
    "/usr/share/wordlists/nmap.lst"
    "/usr/share/wordlists/metasploit/password.lst"
    "/usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
    "/usr/share/seclists/Passwords/Common-Credentials/best1050.txt"
    "/usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt"
    "/usr/share/seclists/Passwords/darkc0de.txt"
    "/usr/share/seclists/Passwords/Leaked-Databases/rockyou-75.txt"
    "/usr/share/seclists/Passwords/xato-net-10-million-passwords-1000000.txt"
)

WL_USER_PATHS=(
    "/usr/share/seclists/Usernames/top-usernames-shortlist.txt"
    "/usr/share/seclists/Usernames/xato-net-10-million-usernames.txt"
    "/usr/share/seclists/Usernames/Names/names.txt"
    "/usr/share/seclists/Usernames/cirt-default-usernames.txt"
)

wl_check_rockyou_gz() {
    if [[ -f "/usr/share/wordlists/rockyou.txt.gz" && ! -f "/usr/share/wordlists/rockyou.txt" ]]; then
        ui_newline
        ui_warn "rockyou.txt.gz found but not decompressed."
        if ui_prompt_yesno "Decompress rockyou.txt.gz now (requires sudo)?" "Y"; then
            echo -e "${CLR_CYAN}Running: sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz${CLR_RESET}"
            if sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz; then
                ui_success "rockyou.txt decompressed successfully."
            else
                ui_error "Failed to decompress rockyou.txt."
            fi
            ui_pause
        fi
    fi
}

wl_scan_directory() {
    local dir="$1"
    local pattern="$2"
    local results=()
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' file; do
            results+=("$file")
        done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null | sort -z)
    fi
    echo "${results[@]}"
}

wl_format_path() {
    local filepath="$1"
    local base=$(basename "$filepath")
    local size=$(du -h "$filepath" 2>/dev/null | cut -f1)
    echo -e "${CLR_WHITE}${CLR_BOLD}${base}${CLR_RESET} ${CLR_DIM}(${filepath}) [${size}]${CLR_RESET}"
}

wl_file_info() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        ui_info "File: $filepath"
        ui_info "Size: $(du -h "$filepath" | cut -f1)"
        ui_info "Lines: $(wc -l < "$filepath")"
        ui_newline
        ui_print "First 5 entries:"
        head -n 5 "$filepath" | while read -r line; do
            ui_print "  $line"
        done
        ui_newline
    else
        ui_error "File not found: $filepath"
    fi
}

wl_generate_menu() {
    ui_push_breadcrumb "Generate Wordlist"
    ui_header
    ui_section "Wordlist Generation"
    ui_menu_item 1 "Crunch" "Generate using patterns and charsets"
    ui_menu_item 2 "CeWL" "Scrape a website for a targeted wordlist"
    ui_menu_back
    
    ui_newline
    ui_prompt_choice "Select tool" 2
    case "$REPLY" in
        1)
            if ! command -v crunch >/dev/null 2>&1; then
                ui_error "crunch is not installed."
                ui_pause
                ui_pop_breadcrumb
                return 1
            fi
            ui_prompt_text "Min length" "1"
            local c_min="$REPLY"
            ui_prompt_text "Max length" "8"
            local c_max="$REPLY"
            ui_prompt_text "Charset (leave empty for default)" ""
            local c_char="$REPLY"
            ui_prompt_optional "Pattern (-t) e.g. pass@@@@"
            local c_pat=""
            if [[ -n "$REPLY" ]]; then c_pat="-t $REPLY"; fi
            ui_prompt_text "Output file path" "/tmp/custom_crunch.txt"
            local c_out="$REPLY"
            
            local cmd="crunch $c_min $c_max $c_char $c_pat -o \"$c_out\""
            cmd=$(echo "$cmd" | tr -s ' ')
            if confirm_and_run "$cmd"; then
                REPLY="$c_out"
                ui_pop_breadcrumb
                return 0
            fi
            ;;
        2)
            if ! command -v cewl >/dev/null 2>&1; then
                ui_error "cewl is not installed."
                ui_pause
                ui_pop_breadcrumb
                return 1
            fi
            ui_prompt_text "Target URL (e.g. http://example.com)"
            local c_url="$REPLY"
            ui_prompt_text "Min word length (-m)" "5"
            local c_min="$REPLY"
            ui_prompt_text "Search depth (-d)" "2"
            local c_depth="$REPLY"
            ui_prompt_text "Output file path" "/tmp/custom_cewl.txt"
            local c_out="$REPLY"
            
            local cmd="cewl -d $c_depth -m $c_min -w \"$c_out\" \"$c_url\""
            if confirm_and_run "$cmd"; then
                REPLY="$c_out"
                ui_pop_breadcrumb
                return 0
            fi
            ;;
    esac
    ui_pop_breadcrumb
    return 1
}

wl_select_wordlist() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select a Wordlist${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_UNDERLINE}                 ${CLR_RESET}"
    ui_newline
    
    local options=()
    local display_options=()
    local idx=1
    
    # 1. Config Default
    if [[ -n "${HYZER_CFG_DEFAULT_WORDLIST:-}" && -f "$HYZER_CFG_DEFAULT_WORDLIST" ]]; then
        options+=("$HYZER_CFG_DEFAULT_WORDLIST")
        display_options+=("${CLR_GREEN}[DEFAULT]${CLR_RESET} $(wl_format_path "$HYZER_CFG_DEFAULT_WORDLIST")")
        ((idx++))
    fi
    
    # Check rockyou.gz
    wl_check_rockyou_gz
    
    # 2. Known Paths
    for path in "${WL_PASS_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            # Skip if it's the same as default
            if [[ "$path" != "${HYZER_CFG_DEFAULT_WORDLIST:-}" ]]; then
                options+=("$path")
                display_options+=("$(wl_format_path "$path")")
                ((idx++))
            fi
        fi
    done
    
    # 3. SecLists Browse Option
    local seclists_idx=0
    if [[ -d "/usr/share/seclists/Passwords" ]]; then
        options+=("SECLISTS_BROWSE")
        display_options+=("${CLR_CYAN}Browse SecLists Passwords...${CLR_RESET}")
        seclists_idx=$idx
        ((idx++))
    fi
    
    # 4. Custom Path Option
    options+=("CUSTOM_PATH")
    display_options+=("${CLR_YELLOW}Enter custom path...${CLR_RESET}")
    local custom_idx=$idx
    
    # 5. Generate Option
    options+=("GENERATE")
    display_options+=("${CLR_MAGENTA}Generate new wordlist (crunch/cewl)...${CLR_RESET}")
    
    if [[ ${#options[@]} -eq 2 ]]; then
        ui_warn "No common wordlists found on this system."
        ui_tip "Install wordlists with: sudo apt install wordlists seclists"
        ui_newline
    fi
    
    # Display menu
    for (( i=0; i<${#display_options[@]}; i++ )); do
        local num=$((i+1))
        echo -e "  ${CLR_CYAN}${CLR_BOLD}[$num]${CLR_RESET} ${display_options[$i]}"
    done
    ui_menu_back
    ui_newline
    
    ui_prompt_choice "Select wordlist" "${#options[@]}"
    local choice=$REPLY
    
    if (( choice == 0 )); then
        return 1
    fi
    
    local selected_option="${options[$((choice-1))]}"
    
    if [[ "$selected_option" == "SECLISTS_BROWSE" ]]; then
        # Handle SecLists browsing
        ui_header
        ui_section "Browse SecLists Passwords"
        local dirs=()
        while IFS= read -r -d '' d; do
            dirs+=("$d")
        done < <(find /usr/share/seclists/Passwords -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
        
        for (( i=0; i<${#dirs[@]}; i++ )); do
            ui_menu_item $((i+1)) "$(basename "${dirs[$i]}")"
        done
        ui_menu_back
        ui_newline
        ui_prompt_choice "Select directory" "${#dirs[@]}"
        
        if (( REPLY == 0 )); then
            # Go back to main wordlist selector
            wl_select_wordlist
            return $?
        fi
        
        local selected_dir="${dirs[$((REPLY-1))]}"
        ui_header
        ui_section "Files in $(basename "$selected_dir")"
        
        local files=()
        while IFS= read -r -d '' f; do
            files+=("$f")
        done < <(find "$selected_dir" -maxdepth 1 -type f -name "*.txt" -print0 | sort -z)
        
        if [[ ${#files[@]} -eq 0 ]]; then
            ui_warn "No .txt files found in this directory."
            ui_pause
            wl_select_wordlist
            return $?
        fi
        
        for (( i=0; i<${#files[@]}; i++ )); do
            echo -e "  ${CLR_CYAN}${CLR_BOLD}[$((i+1))]${CLR_RESET} $(wl_format_path "${files[$i]}")"
        done
        ui_menu_back
        ui_newline
        ui_prompt_choice "Select file" "${#files[@]}"
        
        if (( REPLY == 0 )); then
            wl_select_wordlist
            return $?
        fi
        
        REPLY="${files[$((REPLY-1))]}"
        return 0
        
    elif [[ "$selected_option" == "CUSTOM_PATH" ]]; then
        ui_prompt_file "Enter absolute path to wordlist"
        return 0
    elif [[ "$selected_option" == "GENERATE" ]]; then
        if wl_generate_menu; then
            return 0
        else
            wl_select_wordlist
            return $?
        fi
    else
        REPLY="$selected_option"
        return 0
    fi
}

wl_select_userlist() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select a Userlist${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_UNDERLINE}                 ${CLR_RESET}"
    ui_newline
    
    local options=()
    local display_options=()
    local idx=1
    
    if [[ -n "${HYZER_CFG_DEFAULT_USERLIST:-}" && -f "$HYZER_CFG_DEFAULT_USERLIST" ]]; then
        options+=("$HYZER_CFG_DEFAULT_USERLIST")
        display_options+=("${CLR_GREEN}[DEFAULT]${CLR_RESET} $(wl_format_path "$HYZER_CFG_DEFAULT_USERLIST")")
        ((idx++))
    fi
    
    for path in "${WL_USER_PATHS[@]}"; do
        if [[ -f "$path" && "$path" != "${HYZER_CFG_DEFAULT_USERLIST:-}" ]]; then
            options+=("$path")
            display_options+=("$(wl_format_path "$path")")
            ((idx++))
        fi
    done
    
    if [[ -d "/usr/share/seclists/Usernames" ]]; then
        options+=("SECLISTS_BROWSE")
        display_options+=("${CLR_CYAN}Browse SecLists Usernames...${CLR_RESET}")
        ((idx++))
    fi
    
    options+=("CUSTOM_PATH")
    display_options+=("${CLR_YELLOW}Enter custom path...${CLR_RESET}")
    
    for (( i=0; i<${#display_options[@]}; i++ )); do
        local num=$((i+1))
        echo -e "  ${CLR_CYAN}${CLR_BOLD}[$num]${CLR_RESET} ${display_options[$i]}"
    done
    ui_menu_back
    ui_newline
    
    ui_prompt_choice "Select userlist" "${#options[@]}"
    local choice=$REPLY
    
    if (( choice == 0 )); then return 1; fi
    
    local selected_option="${options[$((choice-1))]}"
    
    if [[ "$selected_option" == "SECLISTS_BROWSE" ]]; then
        # Simplified browse for usernames
        ui_prompt_file "Enter path in /usr/share/seclists/Usernames/"
        return 0
    elif [[ "$selected_option" == "CUSTOM_PATH" ]]; then
        ui_prompt_file "Enter absolute path to userlist"
        return 0
    else
        REPLY="$selected_option"
        return 0
    fi
}

wl_select_wordlist_or_single() {
    local prompt_label="$1" # e.g., "Username" or "Password"
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select ${prompt_label} Input Mode${CLR_RESET}"
    ui_menu_item 1 "Single ${prompt_label}" "Type a specific ${prompt_label}"
    ui_menu_item 2 "${prompt_label} List" "Select a wordlist file"
    ui_newline
    ui_prompt_choice "Select option" 2
    
    if (( REPLY == 1 )); then
        ui_prompt_text "Enter single ${prompt_label}"
        if [[ "$prompt_label" == "Username" ]]; then
            WL_FLAG="-l"
        else
            WL_FLAG="-p"
        fi
        WL_VALUE="$REPLY"
        return 0
    elif (( REPLY == 2 )); then
        if [[ "$prompt_label" == "Username" ]]; then
            if wl_select_userlist; then
                WL_FLAG="-L"
                WL_VALUE="$REPLY"
                return 0
            else
                return 1
            fi
        else
            if wl_select_wordlist; then
                WL_FLAG="-P"
                WL_VALUE="$REPLY"
                return 0
            else
                return 1
            fi
        fi
    fi
    return 1
}
