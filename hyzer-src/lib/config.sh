HYZER_DIR="${HOME}/.hyzer"
HYZER_LOG_DIR="${HYZER_DIR}/logs"
HYZER_LOOT_FILE="${HYZER_DIR}/loot.txt"
HYZER_HISTORY_FILE="${HYZER_DIR}/history"
HYZER_CONFIG_FILE="${HYZER_DIR}/config"
HYZER_VERSION="1.0.0"
HYZER_CURRENT_LOG="/dev/null"

cfg_init() {
    mkdir -p "$HYZER_DIR"
    mkdir -p "$HYZER_LOG_DIR"
    touch "$HYZER_LOOT_FILE"
    touch "$HYZER_HISTORY_FILE"
    
    if [[ ! -f "$HYZER_CONFIG_FILE" ]]; then
        cat <<EOF > "$HYZER_CONFIG_FILE"
# Hyzer Configuration
default_wordlist=
default_userlist=
theme=dark
log_enabled=true
EOF
    fi
}

cfg_load() {
    if [[ -f "$HYZER_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            case "$key" in
                default_wordlist) HYZER_CFG_DEFAULT_WORDLIST="$value" ;;
                default_userlist) HYZER_CFG_DEFAULT_USERLIST="$value" ;;
                theme) HYZER_CFG_THEME="$value" ;;
                log_enabled) HYZER_CFG_LOG_ENABLED="$value" ;;
            esac
        done < "$HYZER_CONFIG_FILE"
    fi
    
    # Apply defaults if missing
    HYZER_CFG_THEME="${HYZER_CFG_THEME:-dark}"
    HYZER_CFG_LOG_ENABLED="${HYZER_CFG_LOG_ENABLED:-true}"
}

cfg_save() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}=" "$HYZER_CONFIG_FILE" 2>/dev/null; then
        # Replace existing key using sed.  Handle delimiter collisions by escaping or using a different delimiter.
        # Use # as delimiter for sed to avoid path issues with / in values
        sed -i "s#^${key}=.*#${key}=${value}#" "$HYZER_CONFIG_FILE"
    else
        # Append if not exists
        echo "${key}=${value}" >> "$HYZER_CONFIG_FILE"
    fi
}

cfg_get() {
    local key="$1"
    if [[ -f "$HYZER_CONFIG_FILE" ]]; then
        grep "^${key}=" "$HYZER_CONFIG_FILE" | cut -d'=' -f2- | xargs
    fi
}

# LOGGING

cfg_log_start() {
    local cmd="$1"
    if [[ "${HYZER_CFG_LOG_ENABLED,,}" == "true" ]]; then
        local timestamp=$(date +"%Y-%m-%d_%H%M%S")
        HYZER_CURRENT_LOG="${HYZER_LOG_DIR}/${timestamp}.log"
        
        cat <<EOF > "$HYZER_CURRENT_LOG"
=== Hyzer Command Log ===
Date: $(date)
Command: $cmd
=========================
EOF
    else
        HYZER_CURRENT_LOG="/dev/null"
    fi
    echo "$HYZER_CURRENT_LOG"
}

cfg_log_command() {
    local cmd="$1"
    cfg_log_start "$cmd"
}

cfg_log_output() {
    local text="$1"
    echo "$text" >> "$HYZER_CURRENT_LOG"
}

cfg_log_end() {
    local exit_code="$1"
    if [[ "${HYZER_CFG_LOG_ENABLED,,}" == "true" && "$HYZER_CURRENT_LOG" != "/dev/null" ]]; then
        cat <<EOF >> "$HYZER_CURRENT_LOG"
=========================
Exit Code: $exit_code
Completed: $(date)
EOF
    fi
}

# HISTORY

cfg_append_history() {
    local cmd="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $cmd" >> "$HYZER_HISTORY_FILE"
}

cfg_view_history() {
    ui_push_breadcrumb "Command History"
    while true; do
        ui_header
        ui_section "Command History"
        
        if [[ ! -s "$HYZER_HISTORY_FILE" ]]; then
            ui_info "No commands have been executed yet."
            ui_newline
            ui_pause
            break
        fi
        
        local total_lines=$(wc -l < "$HYZER_HISTORY_FILE")
        local max_show=50
        local start_line=1
        if (( total_lines > max_show )); then
            start_line=$(( total_lines - max_show + 1 ))
        fi
        
        # Display the last 50 lines with their absolute line numbers in the file
        tail -n "$max_show" "$HYZER_HISTORY_FILE" | awk -v start="$start_line" '{
            # Highlight the timestamp in gray and command in white
            match($0, /\[.*\]/);
            ts = substr($0, RSTART, RLENGTH);
            cmd = substr($0, RSTART + RLENGTH + 1);
            printf "  \033[38;5;51m[%d]\033[0m \033[38;5;245m%s\033[0m %s\n", start++, ts, cmd
        }'
        
        ui_newline
        ui_line
        echo -e "  ${CLR_YELLOW}[C]${CLR_RESET} Clear All History"
        echo -e "  ${CLR_YELLOW}[D]${CLR_RESET} Delete specific entry by number"
        ui_menu_back
        ui_newline
        
        ui_prompt_text "Select option" "0"
        local choice="${REPLY,,}"
        
        if [[ "$choice" == "0" ]]; then
            break
        elif [[ "$choice" == "c" ]]; then
            if ui_prompt_yesno "Are you sure you want to delete ALL history?" "N"; then
                > "$HYZER_HISTORY_FILE"
                ui_success "History cleared."
                ui_pause
            fi
        elif [[ "$choice" == "d" ]]; then
            ui_prompt_text "Enter entry number to delete"
            local d_num="$REPLY"
            if [[ "$d_num" =~ ^[0-9]+$ ]] && (( d_num >= 1 && d_num <= total_lines )); then
                # Delete line number d_num
                sed -i "${d_num}d" "$HYZER_HISTORY_FILE"
                ui_success "Entry #${d_num} deleted."
            else
                ui_error "Invalid entry number."
                ui_pause
            fi
        else
            ui_error "Invalid selection."
            ui_pause
        fi
    done
    ui_pop_breadcrumb
}

# LOOT

cfg_collect_loot() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local new_loot=0
    
    # Temp file to hold existing loot for fast deduplication
    local temp_loot="/tmp/hyzer_loot_existing.tmp"
    touch "$HYZER_LOOT_FILE"
    # Extract just the hash:plaintext part for comparison
    awk -F'] ' '{print $2}' "$HYZER_LOOT_FILE" > "$temp_loot"
    
    # 1. Check Hashcat
    local hc_pots=(
        "${HOME}/.local/share/hashcat/hashcat.potfile"
        "${HOME}/.hashcat/hashcat.potfile"
    )
    for pot in "${hc_pots[@]}"; do
        if [[ -f "$pot" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]] && ! grep -Fxq "$line" "$temp_loot"; then
                    echo "[hashcat] $timestamp  $line" >> "$HYZER_LOOT_FILE"
                    echo "$line" >> "$temp_loot"
                    new_loot=$((new_loot + 1))
                fi
            done < "$pot"
        fi
    done
    
    # 2. Check John
    local john_pot="${HOME}/.john/john.pot"
    if [[ -f "$john_pot" ]]; then
        while IFS= read -r line; do
            # John potfile format: hash:plaintext (often with $dynamic$ or similar prefixes)
            # Remove the $john$ or whatever prefix if we want, or just store as is
            if [[ -n "$line" && "$line" == *":"* ]] && ! grep -Fxq "$line" "$temp_loot"; then
                echo "[john]    $timestamp  $line" >> "$HYZER_LOOT_FILE"
                echo "$line" >> "$temp_loot"
                new_loot=$((new_loot + 1))
            fi
        done < "$john_pot"
    fi
    
    # Note: Hydra output is typically stdout, so it would need to be parsed from the log file
    # This is a basic implementation. A more robust one would parse $HYZER_CURRENT_LOG
    if [[ "$HYZER_CURRENT_LOG" != "/dev/null" && -f "$HYZER_CURRENT_LOG" ]]; then
         # Basic grep for hydra success lines. Adjust regex based on actual hydra output.
         grep -E "\[[0-9]+\]\[[a-zA-Z0-9_-]+\] host:.*login:.*password:" "$HYZER_CURRENT_LOG" | while IFS= read -r line; do
             # Extract host, login, pass
             if ! grep -Fq "$line" "$temp_loot"; then
                 echo "[hydra]   $timestamp  $line" >> "$HYZER_LOOT_FILE"
                 echo "$line" >> "$temp_loot"
                 new_loot=$((new_loot + 1))
             fi
         done
    fi
    
    rm -f "$temp_loot"
    
    if (( new_loot > 0 )); then
        ui_newline
        ui_success "Found $new_loot new cracked credentials! Added to Loot Vault."
    fi
}

cfg_view_loot() {
    ui_push_breadcrumb "Loot Vault"
    ui_header

    echo -e "${CLR_GREEN}${CLR_BOLD}╔═══════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_GREEN}${CLR_BOLD}║              🔓  HYZER LOOT VAULT  🔓                    ║${CLR_RESET}"
    echo -e "${CLR_GREEN}${CLR_BOLD}╚═══════════════════════════════════════════════════════════╝${CLR_RESET}"
    ui_newline

    if [[ ! -s "$HYZER_LOOT_FILE" ]]; then
        ui_info "Loot vault is currently empty."
        ui_newline
        ui_print "Cracked credentials from Hashcat, John, and Hydra will"
        ui_print "automatically appear here after successful attacks."
        ui_newline
        ui_tip "Run a dictionary or brute-force attack to get started!"
    else
        local count=$(wc -l < "$HYZER_LOOT_FILE")
        ui_info "Total cracked credentials: ${CLR_GREEN}${CLR_BOLD}${count}${CLR_RESET}"
        ui_newline

        local entry_num=1
        while IFS= read -r line; do
            # Parse format: [source] timestamp  hash:plaintext
            local source=""
            if [[ "$line" == "[hashcat]"* ]]; then
                source="${CLR_ORANGE}hashcat${CLR_RESET}"
            elif [[ "$line" == "[john]"* ]]; then
                source="${CLR_CYAN}john${CLR_RESET}"
            elif [[ "$line" == "[hydra]"* ]]; then
                source="${CLR_MAGENTA}hydra${CLR_RESET}"
            else
                source="${CLR_GRAY}unknown${CLR_RESET}"
            fi

            # Extract the hash:plaintext part (after the ] timestamp)
            local payload="${line#*]}"
            # Remove leading timestamp (YYYY-MM-DD HH:MM:SS)
            payload=$(echo "$payload" | sed 's/^[[:space:]]*[0-9-]* [0-9:]*//' | xargs)

            if [[ "$payload" == *":"* ]]; then
                local hash_part="${payload%:*}"
                local pass_part="${payload##*:}"
                echo -e "  ${CLR_DIM}#${entry_num}${CLR_RESET}  [${source}]"
                echo -e "      ${CLR_GRAY}Hash: ${hash_part:0:60}${CLR_RESET}"
                echo -e "      ${CLR_GREEN}${CLR_BOLD}Pass: ${pass_part}${CLR_RESET}"
                echo ""
            else
                echo -e "  ${CLR_DIM}#${entry_num}${CLR_RESET}  [${source}]  ${payload}"
                echo ""
            fi
            ((entry_num++))
        done < "$HYZER_LOOT_FILE"

        ui_line
    fi
    ui_newline
    ui_pause
    ui_pop_breadcrumb
}

cfg_clear_loot() {
    ui_header
    ui_section "Clear Loot Vault"
    ui_warn "This will permanently delete all entries in ~/.hyzer/loot.txt"
    if ui_prompt_yesno "Are you sure you want to clear the Loot Vault?" "n"; then
        > "$HYZER_LOOT_FILE"
        ui_success "Loot Vault cleared."
    else
        ui_info "Operation cancelled."
    fi
    ui_pause
}

# CONFIG SUBMENU

cfg_set_default_wordlist() {
    ui_header
    ui_section "Set Default Wordlist"
    local current=$(cfg_get "default_wordlist")
    if [[ -n "$current" ]]; then
        ui_info "Current: $current"
    else
        ui_info "Current: Not set"
    fi
    ui_newline
    ui_prompt_file "Enter path to new default wordlist (or Ctrl+C to cancel)"
    if [[ -n "$REPLY" ]]; then
        cfg_save "default_wordlist" "$REPLY"
        cfg_load # Reload config
        ui_success "Default wordlist updated."
        ui_pause
    fi
}

cfg_set_default_userlist() {
    ui_header
    ui_section "Set Default Userlist"
    local current=$(cfg_get "default_userlist")
    if [[ -n "$current" ]]; then
        ui_info "Current: $current"
    else
        ui_info "Current: Not set"
    fi
    ui_newline
    ui_prompt_file "Enter path to new default userlist (or Ctrl+C to cancel)"
    if [[ -n "$REPLY" ]]; then
        cfg_save "default_userlist" "$REPLY"
        cfg_load
        ui_success "Default userlist updated."
        ui_pause
    fi
}

cfg_toggle_theme() {
    ui_header
    ui_section "Toggle UI Theme"
    local current=$(cfg_get "theme")
    local new_theme="light"
    if [[ "$current" == "light" ]]; then
        new_theme="dark"
    fi
    
    cfg_save "theme" "$new_theme"
    cfg_load
    ui_apply_theme
    
    ui_success "Theme switched to: $new_theme"
    ui_pause
}

cfg_menu() {
    ui_push_breadcrumb "Loot & Config"
    while true; do
        ui_header
        ui_menu_item 1 "View Cracked Credentials" "Loot Vault"
        ui_menu_item 2 "Set Default Wordlist Path"
        ui_menu_item 3 "Set Default Userlist Path"
        ui_menu_item 4 "Toggle UI Theme" "Current: ${HYZER_CFG_THEME}"
        ui_menu_item 5 "View Command History"
        ui_menu_item 6 "Clear Loot Vault"
        ui_menu_back
        
        ui_newline
        ui_prompt_choice "Select an option" 6
        case "$REPLY" in
            1) cfg_view_loot ;;
            2) cfg_set_default_wordlist ;;
            3) cfg_set_default_userlist ;;
            4) cfg_toggle_theme ;;
            5) cfg_view_history ;;
            6) cfg_clear_loot ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}

cfg_credits() {
    ui_push_breadcrumb "Credits"
    ui_header
    
    echo -e "${CLR_CYAN}${CLR_BOLD}"
    echo ' ██╗  ██╗██╗   ██╗███████╗███████╗██████╗ '
    echo ' ██║  ██║╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗'
    echo ' ███████║ ╚████╔╝   ███╔╝ █████╗  ██████╔╝'
    echo ' ██╔══██║  ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗'
    echo ' ██║  ██║   ██║   ███████╗███████╗██║  ██║'
    echo ' ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝'
    echo -e "${CLR_RESET}"
    
    ui_info "Version: $HYZER_VERSION"
    ui_info "Created by dhype7"
    ui_newline
    ui_warn "LEGAL DISCLAIMER"
    ui_print "Hyzer is provided for CTF practice and authorized security testing only."
    ui_print "Do not use this tool against systems you do not own or have explicit"
    ui_print "permission to test."
    ui_newline
    ui_tip "Built with ❤ for the cybersecurity community."
    ui_print "Leveraging:"
    ui_print "  - Hashcat"
    ui_print "  - John the Ripper"
    ui_print "  - Hydra"
    ui_newline
    ui_pause
    
    ui_pop_breadcrumb
}
