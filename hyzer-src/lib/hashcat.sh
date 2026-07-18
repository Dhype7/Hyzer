# =============================================================================
# hashcat.sh — Hashcat Module for Hyzer
# Sourced by hyzer.sh. Uses ui_*, cfg_*, wl_* functions.
# =============================================================================

# -----------------------------------------------------------------------------
# REFERENCE DATA
# -----------------------------------------------------------------------------

HC_MODES_COMMON=(
    "0:MD5"
    "100:SHA1"
    "900:MD4"
    "1000:NTLM"
    "1400:SHA2-256"
    "1700:SHA2-512"
    "1800:sha512crypt (Unix)"
    "500:md5crypt (Unix)"
    "3200:bcrypt"
    "400:phpass / WordPress"
    "3000:LM"
    "5500:NetNTLMv1"
    "5600:NetNTLMv2"
    "13100:Kerberoast TGS-REP (etype 23)"
    "18200:Kerberos AS-REP (etype 23)"
    "22000:WPA-PBKDF2-PMKID+EAPOL"
    "16800:WPA-PMKID-PBKDF2"
    "7500:Kerberos AS-REQ Pre-Auth"
    "11600:7-Zip"
    "13400:KeePass"
    "7400:sha256crypt (Unix)"
)

HC_ATTACK_MODES=(
    "0:Straight (Dictionary)"
    "1:Combination"
    "3:Brute-force (Mask)"
    "6:Hybrid Wordlist + Mask"
    "7:Hybrid Mask + Wordlist"
    "9:Association"
)

HC_CHARSETS=(
    "?l:Lowercase a-z"
    "?u:Uppercase A-Z"
    "?d:Digits 0-9"
    "?h:Hex lowercase 0-9a-f"
    "?H:Hex uppercase 0-9A-F"
    "?s:Special characters"
    "?a:All (?l?u?d?s)"
    "?b:Binary 0x00-0xff"
)

HC_WORKLOADS=(
    "1:Low (Desktop friendly)"
    "2:Default"
    "3:High (Unresponsive desktop)"
    "4:Nightmare (Headless only)"
)

# -----------------------------------------------------------------------------
# HASH MODE SELECTOR — interactive menu instead of typing raw numbers
# Sets REPLY to the selected mode number.
# -----------------------------------------------------------------------------
hc_select_mode() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select Hash Type${CLR_RESET}"
    ui_line

    local i=1
    for mode_entry in "${HC_MODES_COMMON[@]}"; do
        local num="${mode_entry%%:*}"
        local name="${mode_entry#*:}"
        printf "  ${CLR_CYAN}[%2d]${CLR_RESET} %-38s ${CLR_GRAY}(-m %s)${CLR_RESET}\n" "$i" "$name" "$num"
        ((i++))
    done
    echo -e "  ${CLR_YELLOW}[C]${CLR_RESET}  Enter a custom mode number"
    echo -e "  ${CLR_YELLOW}[S]${CLR_RESET}  Search all hashcat modes"
    ui_newline

    while true; do
        ui_prompt "Select hash type"
        local input="${REPLY,,}"

        if [[ "$input" == "c" ]]; then
            ui_prompt_text "Enter hashcat mode number"
            return 0
        elif [[ "$input" == "s" ]]; then
            ui_prompt_text "Search term (e.g. NTLM, sha256, wordpress)"
            local search="$REPLY"
            ui_newline
            echo -e "${CLR_CYAN}Search results for '${search}':${CLR_RESET}"
            ui_line
            hashcat --example-hashes 2>/dev/null | grep -i -B1 "$search" | grep -E '^Hash mode|^Name' || \
                hashcat -hh 2>/dev/null | grep -i "$search" | head -20 || \
                ui_error "No matches found."
            ui_line
            ui_newline
            # Loop back to let them pick
        elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#HC_MODES_COMMON[@]} )); then
            local selected="${HC_MODES_COMMON[$((input-1))]}"
            REPLY="${selected%%:*}"
            local selected_name="${selected#*:}"
            ui_success "Selected: ${selected_name} (-m ${REPLY})"
            return 0
        else
            ui_error "Invalid selection. Enter a number 1-${#HC_MODES_COMMON[@]}, C, or S."
        fi
    done
}

# -----------------------------------------------------------------------------
# WORKLOAD SELECTOR — pick from a menu
# -----------------------------------------------------------------------------
hc_select_workload() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Workload Profile${CLR_RESET}"
    for wl in "${HC_WORKLOADS[@]}"; do
        local num="${wl%%:*}"
        local desc="${wl#*:}"
        printf "  ${CLR_CYAN}[%s]${CLR_RESET} %s\n" "$num" "$desc"
    done
    ui_newline
    ui_prompt_text "Select workload profile" "2"
}

# -----------------------------------------------------------------------------
# RESULT PARSER — called by confirm_and_run after execution
# Analyzes the log file and prints a colored summary of what happened.
# -----------------------------------------------------------------------------
hc_parse_results() {
    local logfile="$1"
    local exit_code="$2"
    local original_command="${3:-}"

    if [[ ! -f "$logfile" || "$logfile" == "/dev/null" ]]; then
        return
    fi

    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}╔═══════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}║       HASHCAT RESULTS SUMMARY        ║${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}╚═══════════════════════════════════════╝${CLR_RESET}"
    ui_newline

    # 1. Already in potfile
    if grep -q "All hashes found as potfile" "$logfile" 2>/dev/null; then
        ui_success "All hashes were already cracked previously!"
        if [[ -n "$original_command" ]]; then
            ui_newline
            echo -e "  ${CLR_GREEN}${CLR_BOLD}Cracked Passwords:${CLR_RESET}"
            local show_out
            # Run the same command but with --show added, which ignores -a and wordlists
            show_out=$(eval "$original_command --show" 2>/dev/null)
            if [[ -n "$show_out" ]]; then
                while IFS= read -r line; do
                    local hash_part="${line%:*}"
                    local pass_part="${line##*:}"
                    if [[ -n "$pass_part" ]]; then
                        echo -e "    ${CLR_GRAY}${hash_part}${CLR_RESET}"
                        echo -e "    ${CLR_GREEN}${CLR_BOLD}→ Password: ${pass_part}${CLR_RESET}"
                        echo ""
                    fi
                done <<< "$show_out"
            fi
        else
            ui_tip "They exist in hashcat's potfile from an earlier session."
            ui_tip "Use the ${CLR_BOLD}Loot Vault${CLR_RESET} from the main menu to see them,"
        fi
        return
    fi

    # 2. Check for recovered stats line
    local recovered
    recovered=$(grep -oP 'Recovered\.*:\s*\K\d+/\d+' "$logfile" 2>/dev/null | tail -1)
    if [[ -n "$recovered" ]]; then
        local cracked_n="${recovered%%/*}"
        local total_n="${recovered##*/}"
        if (( cracked_n > 0 )); then
            echo -e "  ${CLR_GREEN}${CLR_BOLD}🔓 Cracked: ${cracked_n} / ${total_n} hashes${CLR_RESET}"
        else
            echo -e "  ${CLR_YELLOW}🔒 Cracked: 0 / ${total_n} hashes${CLR_RESET}"
        fi
        ui_newline
    fi

    # 3. Show cracked passwords (hash:password format in output)
    local found_cracks=false
    while IFS= read -r line; do
        if [[ "$line" == *":"* ]] && ! [[ "$line" == *"="* || "$line" == *"["* || "$line" == "Hash"* || "$line" == "Recovered"* || "$line" == *"Platform"* || "$line" == *"Device"* || "$line" == *"http"* ]]; then
            if ! $found_cracks; then
                echo -e "  ${CLR_GREEN}${CLR_BOLD}Cracked Passwords:${CLR_RESET}"
                found_cracks=true
            fi
            # Split on last : to get hash:plaintext
            local hash_part="${line%:*}"
            local pass_part="${line##*:}"
            if [[ -n "$pass_part" && ${#pass_part} -lt 100 && ${#hash_part} -gt 10 ]]; then
                echo -e "    ${CLR_GRAY}${hash_part}${CLR_RESET}"
                echo -e "    ${CLR_GREEN}${CLR_BOLD}→ Password: ${pass_part}${CLR_RESET}"
                echo ""
            fi
        fi
    done < <(grep -E '^[a-fA-F0-9\$]{10,}:' "$logfile" 2>/dev/null)

    # 4. Wordlist exhausted
    if grep -q "Status.*Exhausted" "$logfile" 2>/dev/null; then
        ui_warn "Wordlist exhausted — no more candidates to try."
        ui_tip "Try a bigger wordlist, add rules (-r best64.rule), or use a mask attack."
    fi

    # 5. Session aborted / quit
    if grep -q "Status.*Quit" "$logfile" 2>/dev/null; then
        ui_info "Session was stopped before completion."
        ui_tip "You can resume with: hashcat --session=<name> --restore"
    fi

    # 6. Hardware warnings
    if grep -qi "hardware monitor" "$logfile" 2>/dev/null; then
        ui_warn "Hardware temperature warnings detected. Consider lowering workload."
    fi

    ui_newline
    ui_info "Full log saved to: ${CLR_DIM}${logfile}${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# CHEAT SHEET
# -----------------------------------------------------------------------------
hashcat_about() {
    ui_push_breadcrumb "Cheat Sheet"
    ui_header
    ui_section "Hashcat Cheat Sheet"
    ui_info "GPU-accelerated offline hash cracker."

    ui_subsection "Attack Modes (-a)"
    for am in "${HC_ATTACK_MODES[@]}"; do
        printf "  ${CLR_CYAN}%-2s${CLR_RESET} : %s\n" "${am%%:*}" "${am#*:}"
    done

    ui_subsection "Top Hash Modes (-m)"
    for hm in "${HC_MODES_COMMON[@]}"; do
        printf "  ${CLR_CYAN}%-6s${CLR_RESET} : %s\n" "${hm%%:*}" "${hm#*:}"
    done

    ui_subsection "Mask Charsets"
    for cs in "${HC_CHARSETS[@]}"; do
        printf "  ${CLR_CYAN}%-2s${CLR_RESET} : %s\n" "${cs%%:*}" "${cs#*:}"
    done

    ui_subsection "Workload Profiles (-w)"
    for wl in "${HC_WORKLOADS[@]}"; do
        printf "  ${CLR_CYAN}%-2s${CLR_RESET} : %s\n" "${wl%%:*}" "${wl#*:}"
    done

    ui_subsection "Example Commands"
    ui_print "  ${CLR_WHITE}Dictionary:${CLR_RESET}    hashcat -a 0 -m 0 hashes.txt wordlist.txt"
    ui_print "  ${CLR_WHITE}With Rules:${CLR_RESET}    hashcat -a 0 -m 0 hashes.txt wordlist.txt -r best64.rule"
    ui_print "  ${CLR_WHITE}Brute-Force:${CLR_RESET}   hashcat -a 3 -m 0 hashes.txt ?a?a?a?a?a?a"
    ui_print "  ${CLR_WHITE}WPA Crack:${CLR_RESET}     hashcat -m 22000 capture.hc22000 wordlist.txt"
    ui_print "  ${CLR_WHITE}Show Cracked:${CLR_RESET}  hashcat --show -m 0 hashes.txt"

    ui_newline
    ui_pause
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# QUICK ATTACKS
# -----------------------------------------------------------------------------

hashcat_quick_dictionary() {
    ui_push_breadcrumb "Dictionary Attack"
    ui_header
    ui_section "Hashcat: Dictionary Attack (-a 0)"

    local hashfile=""
    if [[ -n "${HASHID_CHAIN_FILE:-}" && -f "$HASHID_CHAIN_FILE" ]]; then
        ui_success "Using chained hash file: $HASHID_CHAIN_FILE"
        hashfile="$HASHID_CHAIN_FILE"
        HASHID_CHAIN_FILE=""
    else
        ui_prompt_file "Enter path to hash file"
        hashfile="$REPLY"
    fi

    local hashmode=""
    if [[ -n "${HASHID_CHAIN_HC_MODE:-}" ]]; then
        ui_success "Using auto-detected Hashcat mode: $HASHID_CHAIN_HC_MODE"
        hashmode="$HASHID_CHAIN_HC_MODE"
        HASHID_CHAIN_HC_MODE=""
    else
        hc_select_mode
        hashmode="$REPLY"
    fi

    if ! wl_select_wordlist; then
        ui_pop_breadcrumb
        return 1
    fi
    local wordlist="$REPLY"

    local rules_flag=""
    if ui_prompt_yesno "Use a rules file (-r)? (e.g. best64.rule)" "N"; then
        # Offer common rules first
        ui_newline
        echo -e "${CLR_CYAN}${CLR_BOLD}Common Rules Files:${CLR_RESET}"
        local rule_paths=(
            "/usr/share/hashcat/rules/best64.rule"
            "/usr/share/hashcat/rules/rockyou-30000.rule"
            "/usr/share/hashcat/rules/d3ad0ne.rule"
            "/usr/share/hashcat/rules/dive.rule"
            "/usr/share/hashcat/rules/toggles1.rule"
        )
        local found_rules=()
        local ri=1
        for rp in "${rule_paths[@]}"; do
            if [[ -f "$rp" ]]; then
                found_rules+=("$rp")
                ui_menu_item "$ri" "$(basename "$rp")" "$rp"
                ((ri++))
            fi
        done
        ui_menu_item "$ri" "Enter custom path"
        ui_newline

        ui_prompt_choice "Select rules file" "$ri"
        if (( REPLY == ri )); then
            ui_prompt_file "Enter path to rules file"
            rules_flag="-r \"$REPLY\""
        elif (( REPLY > 0 && REPLY <= ${#found_rules[@]} )); then
            rules_flag="-r \"${found_rules[$((REPLY-1))]}\""
        fi
    fi

    ui_prompt_optional "Output file (-o)"
    local outfile_flag=""
    if [[ -n "$REPLY" ]]; then
        outfile_flag="-o \"$REPLY\""
    fi

    hc_select_workload
    local workload="$REPLY"

    local cmd="hashcat -a 0 -m $hashmode \"$hashfile\" \"$wordlist\" $rules_flag $outfile_flag -w $workload"
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "hc_parse_results"
    ui_pop_breadcrumb
}

hashcat_quick_mask() {
    ui_push_breadcrumb "Mask Attack"
    ui_header
    ui_section "Hashcat: Mask / Brute-force Attack (-a 3)"

    ui_prompt_file "Enter path to hash file"
    local hashfile="$REPLY"

    hc_select_mode
    local hashmode="$REPLY"

    ui_subsection "Mask Charsets Reference"
    for cs in "${HC_CHARSETS[@]}"; do
        printf "  ${CLR_CYAN}%-2s${CLR_RESET} : %s\n" "${cs%%:*}" "${cs#*:}"
    done
    ui_newline
    ui_tip "Example: ?u?l?l?l?d?d?d?d = Password like 'Pass1234'"
    ui_prompt_text "Enter Mask Pattern"
    local mask="$REPLY"

    local inc_flag=""
    if ui_prompt_yesno "Enable mask increment mode (-i)?" "N"; then
        inc_flag="-i"
        ui_prompt_optional "Increment Min (--increment-min)"
        if [[ -n "$REPLY" ]]; then inc_flag+=" --increment-min=$REPLY"; fi
        ui_prompt_optional "Increment Max (--increment-max)"
        if [[ -n "$REPLY" ]]; then inc_flag+=" --increment-max=$REPLY"; fi
    fi

    hc_select_workload
    local workload="$REPLY"

    local cmd="hashcat -a 3 -m $hashmode \"$hashfile\" $mask $inc_flag -w $workload"
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "hc_parse_results"
    ui_pop_breadcrumb
}

hashcat_quick_wpa() {
    ui_push_breadcrumb "WPA Crack"
    ui_header
    ui_section "Hashcat: WPA/WPA2 Handshake Crack (-m 22000)"
    ui_info "You need a .hc22000 capture file (created with hcxpcapngtool)."
    ui_newline

    ui_prompt_file "Enter path to .hc22000 capture file"
    local hashfile="$REPLY"

    if ! wl_select_wordlist; then
        ui_pop_breadcrumb
        return 1
    fi
    local wordlist="$REPLY"

    hc_select_workload
    local workload="$REPLY"

    local cmd="hashcat -m 22000 \"$hashfile\" \"$wordlist\" -w $workload"
    confirm_and_run "$cmd" "hc_parse_results"
    ui_pop_breadcrumb
}

hashcat_quick_show() {
    ui_push_breadcrumb "Show Cracked"
    ui_header
    ui_section "View Cracked Credentials"

    echo -e "${CLR_CYAN}${CLR_BOLD}Where to look?${CLR_RESET}"
    ui_menu_item 1 "Hyzer Loot Vault" "All cracked creds from every session"
    ui_menu_item 2 "Hashcat Potfile" "Raw hashcat potfile contents"
    ui_menu_item 3 "Show results for a specific hash file" "hashcat --show"
    ui_menu_back
    ui_newline

    ui_prompt_choice "Select option" 3
    case "$REPLY" in
        1)
            cfg_view_loot
            ;;
        2)
            ui_header
            ui_section "Hashcat Potfile"
            local pots=(
                "${HOME}/.local/share/hashcat/hashcat.potfile"
                "${HOME}/.hashcat/hashcat.potfile"
            )
            local found_pot=""
            for p in "${pots[@]}"; do
                if [[ -f "$p" ]]; then
                    found_pot="$p"
                    break
                fi
            done
            if [[ -n "$found_pot" ]]; then
                ui_info "Potfile: $found_pot"
                ui_info "Entries: $(wc -l < "$found_pot")"
                ui_line
                while IFS=: read -r hash pass; do
                    echo -e "  ${CLR_GRAY}${hash}${CLR_RESET}"
                    echo -e "  ${CLR_GREEN}${CLR_BOLD}→ ${pass}${CLR_RESET}"
                    echo ""
                done < "$found_pot"
                ui_line
            else
                ui_warn "No hashcat potfile found."
            fi
            ui_pause
            ;;
        3)
            ui_prompt_file "Enter path to hash file"
            local hashfile="$REPLY"
            hc_select_mode
            local hashmode="$REPLY"
            local cmd="hashcat --show -m $hashmode \"$hashfile\""
            confirm_and_run "$cmd" "hc_parse_results"
            ;;
        0) ;;
    esac
    ui_pop_breadcrumb
}

hashcat_quick_menu() {
    ui_push_breadcrumb "Quick Attacks"
    while true; do
        ui_header
        ui_menu_item 1 "Dictionary Attack" "Standard wordlist attack (-a 0)"
        ui_menu_item 2 "Mask / Brute-force Attack" "Pattern-based guessing (-a 3)"
        ui_menu_item 3 "WPA/WPA2 Handshake Crack" "Cracks .hc22000 captures (-m 22000)"
        ui_menu_item 4 "Show Cracked Results" "View cracked passwords"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 4
        case "$REPLY" in
            1) hashcat_quick_dictionary ;;
            2) hashcat_quick_mask ;;
            3) hashcat_quick_wpa ;;
            4) hashcat_quick_show ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# CUSTOM COMMAND BUILDER
# -----------------------------------------------------------------------------
hashcat_custom_builder() {
    ui_push_breadcrumb "Custom Builder"
    ui_header
    ui_section "Hashcat: Custom Command Builder"

    hc_select_mode
    local hashmode="$REPLY"

    ui_subsection "Attack Modes"
    for am in "${HC_ATTACK_MODES[@]}"; do
        printf "  ${CLR_CYAN}%-2s${CLR_RESET} : %s\n" "${am%%:*}" "${am#*:}"
    done
    ui_prompt_text "Enter Attack Mode (-a)" "0"
    local attackmode="$REPLY"

    ui_prompt_file "Enter path to hash file"
    local hashfile="$REPLY"

    local target=""
    if [[ "$attackmode" == "0" || "$attackmode" == "1" || "$attackmode" == "6" || "$attackmode" == "7" || "$attackmode" == "9" ]]; then
        if wl_select_wordlist; then
            target="\"$REPLY\""
        else
            ui_pop_breadcrumb; return 1
        fi
        if [[ "$attackmode" == "1" ]]; then
            ui_info "Combination attack requires a second wordlist."
            if wl_select_wordlist; then target+=" \"$REPLY\""; else ui_pop_breadcrumb; return 1; fi
        fi
        if [[ "$attackmode" == "6" || "$attackmode" == "7" ]]; then
            ui_prompt_text "Enter Mask"
            if [[ "$attackmode" == "6" ]]; then target+=" $REPLY"; else target="$REPLY $target"; fi
        fi
    elif [[ "$attackmode" == "3" ]]; then
        ui_prompt_text "Enter Mask"
        target="$REPLY"
    fi

    local rules_flag=""
    if [[ "$attackmode" == "0" || "$attackmode" == "9" ]]; then
        ui_prompt_optional "Rules file (-r)"
        if [[ -n "$REPLY" ]]; then rules_flag="-r \"$REPLY\""; fi
    fi

    ui_prompt_optional "Output file (-o)"
    local outfile_flag=""
    if [[ -n "$REPLY" ]]; then outfile_flag="-o \"$REPLY\""; fi

    hc_select_workload
    local workload="$REPLY"

    ui_prompt_optional "Additional Flags (e.g. -O, --increment)"
    local extra_flags="$REPLY"

    local cmd="hashcat -a $attackmode -m $hashmode \"$hashfile\" $target $rules_flag $outfile_flag -w $workload $extra_flags"
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "hc_parse_results"
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# SEARCH HASH MODES
# -----------------------------------------------------------------------------
hashcat_search_modes() {
    ui_push_breadcrumb "Search Hash Modes"
    while true; do
        ui_header
        ui_section "Search Hashcat Hash Modes"
        ui_prompt_text "Enter search term (e.g. NTLM, sha256) or 0 to go back"
        if [[ "$REPLY" == "0" ]]; then break; fi
        if [[ -n "$REPLY" ]]; then
            ui_newline
            echo -e "${CLR_CYAN}Search results for '$REPLY':${CLR_RESET}"
            ui_line
            hashcat -hh 2>/dev/null | grep -i "$REPLY" | grep -E '^[[:space:]]+[0-9]+[[:space:]]+\|' || ui_error "No matches found."
            ui_line
            ui_pause
        fi
    done
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# MAIN HASHCAT MENU
# -----------------------------------------------------------------------------
hashcat_menu() {
    ui_push_breadcrumb "Hashcat"
    while true; do
        ui_header
        ui_menu_item 1 "About / Cheat Sheet"
        ui_menu_item 2 "Quick Attacks" "Guided common attack scenarios"
        ui_menu_item 3 "Custom Command Builder" "Step-by-step full control"
        ui_menu_item 4 "Search Hash Modes"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 4
        case "$REPLY" in
            1) hashcat_about ;;
            2) hashcat_quick_menu ;;
            3) hashcat_custom_builder ;;
            4) hashcat_search_modes ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}
