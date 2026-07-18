# =============================================================================
# john.sh — John the Ripper Module for Hyzer
# Sourced by hyzer.sh. Uses ui_*, cfg_*, wl_* functions.
# =============================================================================

# -----------------------------------------------------------------------------
# REFERENCE DATA
# -----------------------------------------------------------------------------

JOHN_COMMON_FORMATS=(
    "Raw-MD5:MD5 hashes"
    "Raw-SHA1:SHA1 hashes"
    "Raw-SHA256:SHA256 hashes"
    "Raw-SHA512:SHA512 hashes"
    "NT:NTLM / Windows NT hashes"
    "LM:LAN Manager hashes"
    "bcrypt:bcrypt / Blowfish"
    "sha512crypt:Linux SHA512 crypt (\$6\$)"
    "sha256crypt:Linux SHA256 crypt (\$5\$)"
    "md5crypt:Linux/Cisco MD5 crypt (\$1\$)"
    "descrypt:Traditional DES crypt"
    "phpass:WordPress/phpBB (\$P\$/\$H\$)"
    "krb5tgs:Kerberoast TGS-REP"
    "krb5asrep:Kerberos AS-REP"
    "mssql:MS SQL Server"
    "mysql-sha1:MySQL 4.1+"
    "zip:ZIP archives (via zip2john)"
    "rar:RAR archives (via rar2john)"
    "SSH:SSH private keys (via ssh2john)"
    "PDF:PDF files (via pdf2john)"
    "KeePass:KeePass databases"
)

JOHN_HELPERS=(
    "zip2john:ZIP archives"
    "rar2john:RAR archives"
    "ssh2john:SSH private keys"
    "pdf2john:PDF documents"
    "unshadow:Linux shadow files"
    "7z2john:7-Zip archives"
    "office2john:MS Office docs"
    "keepass2john:KeePass databases"
    "bitcoin2john:Bitcoin wallets"
    "dmg2john:macOS DMG images"
)

JOHN_CHAIN_HASHFILE=""

# -----------------------------------------------------------------------------
# FORMAT SELECTOR — interactive menu
# Sets REPLY to the selected format string (e.g. "Raw-MD5"), or empty for auto.
# -----------------------------------------------------------------------------
john_select_format() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select Hash Format${CLR_RESET}"
    ui_line

    echo -e "  ${CLR_GREEN}[A]${CLR_RESET}  ${CLR_GREEN}Auto-detect (let John decide)${CLR_RESET}"
    ui_newline

    local i=1
    for fmt_entry in "${JOHN_COMMON_FORMATS[@]}"; do
        local name="${fmt_entry%%:*}"
        local desc="${fmt_entry#*:}"
        printf "  ${CLR_CYAN}[%2d]${CLR_RESET} %-15s ${CLR_GRAY}%s${CLR_RESET}\n" "$i" "$name" "$desc"
        ((i++))
    done
    echo -e "  ${CLR_YELLOW}[C]${CLR_RESET}  Enter a custom format name"
    ui_newline

    while true; do
        ui_prompt "Select format"
        local input="${REPLY,,}"

        if [[ "$input" == "a" || -z "$input" ]]; then
            REPLY=""
            ui_success "Auto-detect enabled (John will determine the format)"
            return 0
        elif [[ "$input" == "c" ]]; then
            ui_prompt_text "Enter John format name"
            return 0
        elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#JOHN_COMMON_FORMATS[@]} )); then
            local selected="${JOHN_COMMON_FORMATS[$((input-1))]}"
            REPLY="${selected%%:*}"
            ui_success "Selected: ${REPLY}"
            return 0
        else
            ui_error "Invalid selection. Enter A, a number 1-${#JOHN_COMMON_FORMATS[@]}, or C."
        fi
    done
}

# -----------------------------------------------------------------------------
# RESULT PARSER — analyzes John output and shows colored summary
# -----------------------------------------------------------------------------
john_parse_results() {
    local logfile="$1"
    local exit_code="$2"

    if [[ ! -f "$logfile" || "$logfile" == "/dev/null" ]]; then
        return
    fi

    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}╔═══════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}║     JOHN THE RIPPER RESULTS          ║${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}╚═══════════════════════════════════════╝${CLR_RESET}"
    ui_newline

    # Check for cracked passwords (john outputs: username:password or hash:password)
    local found_cracks=false
    while IFS= read -r line; do
        # John shows cracked passwords as lines with (format)
        # Or as user:password format
        if [[ "$line" =~ ^.*:.*$ ]] && ! [[ "$line" == *"Warning"* || "$line" == *"Loaded"* || "$line" == *"Press"* || "$line" == *"guesses"* || "$line" == *"Note"* || "$line" == *"Cost"* || "$line" == *"Proceeding"* || "$line" == *"Using"* || "$line" == *"Will"* ]]; then
            if ! $found_cracks; then
                echo -e "  ${CLR_GREEN}${CLR_BOLD}🔓 Cracked Passwords:${CLR_RESET}"
                found_cracks=true
            fi
            # Try to extract user:password
            local user_part="${line%%:*}"
            local pass_part="${line#*:}"
            # Remove trailing format hint like (Raw-MD5)
            pass_part="${pass_part%%(*}"
            pass_part=$(echo "$pass_part" | xargs)
            if [[ -n "$pass_part" && ${#pass_part} -lt 100 ]]; then
                echo -e "    ${CLR_WHITE}User/Hash:${CLR_RESET} ${CLR_GRAY}${user_part}${CLR_RESET}"
                echo -e "    ${CLR_GREEN}${CLR_BOLD}→ Password: ${pass_part}${CLR_RESET}"
                echo ""
            fi
        fi
    done < <(grep -v '^$' "$logfile" 2>/dev/null | grep -E '^[^[:space:]].*:' 2>/dev/null | grep -v '^==' 2>/dev/null)

    # Check for loaded hashes info
    local loaded
    loaded=$(grep -oP 'Loaded \K\d+ password' "$logfile" 2>/dev/null | head -1)
    if [[ -n "$loaded" ]]; then
        ui_info "Loaded: $loaded hash(es)"
    fi

    # Already cracked
    if grep -q "No password hashes left to crack" "$logfile" 2>/dev/null; then
        ui_success "All hashes have been cracked!"
        ui_tip "Use 'john --show <hashfile>' or check the Loot Vault."
    fi

    # No hashes loaded
    if grep -q "No password hashes loaded" "$logfile" 2>/dev/null; then
        ui_error "No password hashes were loaded from the file."
        ui_tip "Check that the file contains valid hashes."
        ui_tip "Try specifying the format with --format=<type>."
    fi

    if ! $found_cracks && ! grep -q "No password hashes left" "$logfile" 2>/dev/null; then
        if (( exit_code == 0 )); then
            ui_warn "No new passwords were cracked in this session."
            ui_tip "Try a larger wordlist, enable rules (--rules), or use incremental mode."
        fi
    fi

    ui_newline
    ui_info "Full log saved to: ${CLR_DIM}${logfile}${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# CHEAT SHEET
# -----------------------------------------------------------------------------
john_about() {
    ui_push_breadcrumb "Cheat Sheet"
    ui_header
    ui_section "John the Ripper Cheat Sheet"
    ui_info "CPU-based offline cracker with excellent auto-detection and format helpers."

    ui_subsection "Attack Modes"
    ui_print "  ${CLR_CYAN}Wordlist${CLR_RESET}    : --wordlist=FILE"
    ui_print "  ${CLR_CYAN}Incremental${CLR_RESET} : --incremental (Brute-force)"
    ui_print "  ${CLR_CYAN}Single${CLR_RESET}      : --single (Uses username/gecos info)"
    ui_print "  ${CLR_CYAN}Mask${CLR_RESET}        : --mask=MASK"

    ui_subsection "Common Formats (--format=NAME)"
    for fmt in "${JOHN_COMMON_FORMATS[@]}"; do
        printf "  ${CLR_CYAN}%-15s${CLR_RESET} : %s\n" "${fmt%%:*}" "${fmt#*:}"
    done

    ui_subsection "Available Format Helpers (*2john)"
    for helper in "${JOHN_HELPERS[@]}"; do
        IFS=':' read -r name desc <<< "$helper"
        if command -v "$name" >/dev/null 2>&1; then
            printf "  ${CLR_GREEN}[✓]${CLR_RESET} ${CLR_CYAN}%-15s${CLR_RESET} : %s\n" "$name" "$desc"
        else
            printf "  ${CLR_RED}[✗]${CLR_RESET} ${CLR_GRAY}%-15s : %s${CLR_RESET}\n" "$name" "$desc"
        fi
    done

    ui_subsection "Example Commands"
    ui_print "  ${CLR_WHITE}Wordlist:${CLR_RESET}    john --wordlist=rockyou.txt hashes.txt"
    ui_print "  ${CLR_WHITE}With Rules:${CLR_RESET}  john --wordlist=words.txt --rules hashes.txt"
    ui_print "  ${CLR_WHITE}Incremental:${CLR_RESET} john --incremental hashes.txt"
    ui_print "  ${CLR_WHITE}With Format:${CLR_RESET} john --format=Raw-MD5 --wordlist=words.txt hashes.txt"
    ui_print "  ${CLR_WHITE}Show Cracked:${CLR_RESET} john --show hashes.txt"
    ui_print "  ${CLR_WHITE}Unshadow:${CLR_RESET}    unshadow /etc/passwd /etc/shadow > unshadowed.txt"

    ui_newline
    ui_pause
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# QUICK ATTACKS
# -----------------------------------------------------------------------------

john_quick_wordlist() {
    ui_push_breadcrumb "Wordlist Attack"
    ui_header
    ui_section "John the Ripper: Wordlist Attack"

    local hashfile=""
    if [[ -n "$JOHN_CHAIN_HASHFILE" && -f "$JOHN_CHAIN_HASHFILE" ]]; then
        ui_success "Using chained hash file: $JOHN_CHAIN_HASHFILE"
        hashfile="$JOHN_CHAIN_HASHFILE"
        JOHN_CHAIN_HASHFILE=""
    else
        ui_prompt_file "Enter path to hash file"
        hashfile="$REPLY"
    fi

    local format_flag=""
    if [[ -n "${HASHID_CHAIN_JOHN_FMT:-}" ]]; then
        ui_success "Using auto-detected John format: $HASHID_CHAIN_JOHN_FMT"
        format_flag="--format=$HASHID_CHAIN_JOHN_FMT"
        HASHID_CHAIN_JOHN_FMT=""
    else
        john_select_format
        if [[ -n "$REPLY" ]]; then
            format_flag="--format=$REPLY"
        fi
    fi

    if ! wl_select_wordlist; then
        ui_pop_breadcrumb; return 1
    fi
    local wordlist="$REPLY"

    local rules_flag=""
    if ui_prompt_yesno "Use word mangling rules (--rules)?" "N"; then
        rules_flag="--rules"
    fi

    ui_prompt_optional "Session Name (--session)"
    local session_flag=""
    if [[ -n "$REPLY" ]]; then session_flag="--session=$REPLY"; fi

    local cmd="john $format_flag --wordlist=\"$wordlist\" $rules_flag $session_flag \"$hashfile\""
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "john_parse_results"
    ui_pop_breadcrumb
}

john_quick_incremental() {
    ui_push_breadcrumb "Incremental Attack"
    ui_header
    ui_section "John the Ripper: Incremental (Brute-force) Mode"

    ui_prompt_file "Enter path to hash file"
    local hashfile="$REPLY"

    john_select_format
    local format_flag=""
    if [[ -n "$REPLY" ]]; then format_flag="--format=$REPLY"; fi

    ui_prompt_optional "Incremental Mode (e.g. Alnum, Digits, ASCII) [leave blank for default]"
    local inc_flag="--incremental"
    if [[ -n "$REPLY" ]]; then inc_flag="--incremental=$REPLY"; fi

    ui_prompt_optional "Session Name (--session)"
    local session_flag=""
    if [[ -n "$REPLY" ]]; then session_flag="--session=$REPLY"; fi

    local cmd="john $format_flag $inc_flag $session_flag \"$hashfile\""
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "john_parse_results"
    ui_pop_breadcrumb
}

john_quick_single() {
    ui_push_breadcrumb "Single-Crack Mode"
    ui_header
    ui_section "John the Ripper: Single-Crack Mode"

    ui_prompt_file "Enter path to hash file"
    local hashfile="$REPLY"

    john_select_format
    local format_flag=""
    if [[ -n "$REPLY" ]]; then format_flag="--format=$REPLY"; fi

    local cmd="john $format_flag --single \"$hashfile\""
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "john_parse_results"
    ui_pop_breadcrumb
}

john_quick_show() {
    ui_push_breadcrumb "Show Cracked"
    ui_header
    ui_section "View Cracked Credentials"

    echo -e "${CLR_CYAN}${CLR_BOLD}Where to look?${CLR_RESET}"
    ui_menu_item 1 "Hyzer Loot Vault" "All cracked creds from every session"
    ui_menu_item 2 "John Potfile" "Raw john.pot contents"
    ui_menu_item 3 "Show results for a specific hash file" "john --show"
    ui_menu_back
    ui_newline

    ui_prompt_choice "Select option" 3
    case "$REPLY" in
        1)
            cfg_view_loot
            ;;
        2)
            ui_header
            ui_section "John Potfile"
            local john_pot="${HOME}/.john/john.pot"
            if [[ -f "$john_pot" ]]; then
                ui_info "Potfile: $john_pot"
                ui_info "Entries: $(wc -l < "$john_pot")"
                ui_line
                while IFS=: read -r hash pass; do
                    echo -e "  ${CLR_GRAY}${hash}${CLR_RESET}"
                    echo -e "  ${CLR_GREEN}${CLR_BOLD}→ ${pass}${CLR_RESET}"
                    echo ""
                done < "$john_pot"
                ui_line
            else
                ui_warn "No John potfile found at $john_pot"
            fi
            ui_pause
            ;;
        3)
            ui_prompt_file "Enter path to hash file"
            local hashfile="$REPLY"
            john_select_format
            local format_flag=""
            if [[ -n "$REPLY" ]]; then format_flag="--format=$REPLY"; fi
            local cmd="john --show $format_flag \"$hashfile\""
            cmd=$(echo "$cmd" | tr -s ' ')
            confirm_and_run "$cmd" "john_parse_results"
            ;;
        0) ;;
    esac
    ui_pop_breadcrumb
}

john_quick_menu() {
    ui_push_breadcrumb "Quick Attacks"
    while true; do
        ui_header
        ui_menu_item 1 "Wordlist Attack"
        ui_menu_item 2 "Incremental (Brute-force) Mode"
        ui_menu_item 3 "Single-Crack Mode"
        ui_menu_item 4 "Show Cracked Results" "View cracked passwords"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 4
        case "$REPLY" in
            1) john_quick_wordlist ;;
            2) john_quick_incremental ;;
            3) john_quick_single ;;
            4) john_quick_show ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# FORMAT HELPERS (*2john)
# -----------------------------------------------------------------------------

_john_helper_generic() {
    local helper_name="$1"
    local input_prompt="$2"
    local output_default="$3"

    if ! command -v "$helper_name" >/dev/null 2>&1; then
        ui_error "$helper_name is not installed or not in PATH."
        ui_pause
        return 1
    fi

    ui_prompt_file "$input_prompt"
    local input_file="$REPLY"

    ui_prompt_text "Output hash file name" "$output_default"
    local output_file="$REPLY"

    local cmd="$helper_name \"$input_file\" > \"$output_file\""

    if confirm_and_run "$cmd"; then
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            ui_newline
            ui_success "Hash extracted successfully to: $output_file"
            ui_info "Preview:"
            head -3 "$output_file" | while IFS= read -r line; do
                echo -e "  ${CLR_GRAY}${line:0:80}${CLR_RESET}"
            done
            ui_newline
            if ui_prompt_yesno "Chain directly into a Wordlist attack with this file?" "Y"; then
                JOHN_CHAIN_HASHFILE="$output_file"
                john_quick_wordlist
            fi
        fi
    fi
}

john_helper_zip() {
    ui_push_breadcrumb "ZIP Helper"
    ui_header
    ui_section "zip2john: ZIP Archive Hash Extraction"
    _john_helper_generic "zip2john" "Path to ZIP file" "zip_hash.txt"
    ui_pop_breadcrumb
}

john_helper_rar() {
    ui_push_breadcrumb "RAR Helper"
    ui_header
    ui_section "rar2john: RAR Archive Hash Extraction"
    _john_helper_generic "rar2john" "Path to RAR file" "rar_hash.txt"
    ui_pop_breadcrumb
}

john_helper_ssh() {
    ui_push_breadcrumb "SSH Helper"
    ui_header
    ui_section "ssh2john: SSH Private Key Hash Extraction"
    _john_helper_generic "ssh2john" "Path to SSH private key (e.g. id_rsa)" "ssh_hash.txt"
    ui_pop_breadcrumb
}

john_helper_pdf() {
    ui_push_breadcrumb "PDF Helper"
    ui_header
    ui_section "pdf2john: PDF Document Hash Extraction"
    _john_helper_generic "pdf2john" "Path to PDF file" "pdf_hash.txt"
    ui_pop_breadcrumb
}

john_helper_unshadow() {
    ui_push_breadcrumb "Unshadow Helper"
    ui_header
    ui_section "unshadow: Combine passwd and shadow files"

    if ! command -v unshadow >/dev/null 2>&1; then
        ui_error "unshadow is not installed or not in PATH."
        ui_pause
        ui_pop_breadcrumb
        return 1
    fi

    ui_prompt_file "Path to passwd file"
    local passwd_file="$REPLY"
    ui_prompt_file "Path to shadow file"
    local shadow_file="$REPLY"
    ui_prompt_text "Output hash file name" "unshadowed.txt"
    local output_file="$REPLY"

    local cmd="unshadow \"$passwd_file\" \"$shadow_file\" > \"$output_file\""
    if confirm_and_run "$cmd"; then
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            ui_newline
            if ui_prompt_yesno "Chain directly into a Wordlist attack with $output_file?" "Y"; then
                JOHN_CHAIN_HASHFILE="$output_file"
                john_quick_wordlist
            fi
        fi
    fi
    ui_pop_breadcrumb
}

john_helper_custom() {
    ui_push_breadcrumb "Custom Helper"
    ui_header
    ui_section "Custom *2john Helper"
    ui_prompt_text "Enter helper name (e.g. office2john, keepass2john)"
    local helper_name="$REPLY"
    _john_helper_generic "$helper_name" "Path to input file" "${helper_name%%2john}_hash.txt"
    ui_pop_breadcrumb
}

john_helpers_menu() {
    ui_push_breadcrumb "Format Helpers"
    while true; do
        ui_header
        ui_menu_item 1 "ZIP Archive (zip2john)"
        ui_menu_item 2 "RAR Archive (rar2john)"
        ui_menu_item 3 "SSH Private Key (ssh2john)"
        ui_menu_item 4 "PDF Document (pdf2john)"
        ui_menu_item 5 "Linux Shadow (unshadow)"
        ui_menu_item 6 "Other Helper (custom)"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 6
        case "$REPLY" in
            1) john_helper_zip ;;
            2) john_helper_rar ;;
            3) john_helper_ssh ;;
            4) john_helper_pdf ;;
            5) john_helper_unshadow ;;
            6) john_helper_custom ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# CUSTOM COMMAND BUILDER
# -----------------------------------------------------------------------------
john_custom_builder() {
    ui_push_breadcrumb "Custom Builder"
    ui_header
    ui_section "John the Ripper: Custom Command Builder"

    ui_prompt_file "Enter path to hash file"
    local hashfile="$REPLY"

    john_select_format
    local format_flag=""
    if [[ -n "$REPLY" ]]; then format_flag="--format=$REPLY"; fi

    ui_subsection "Attack Mode"
    ui_menu_item 1 "Wordlist"
    ui_menu_item 2 "Incremental"
    ui_menu_item 3 "Single"
    ui_menu_item 4 "Mask"
    ui_newline
    ui_prompt_choice "Select Attack Mode" 4
    local mode_choice="$REPLY"

    local mode_flag=""
    case "$mode_choice" in
        1)
            if ! wl_select_wordlist; then ui_pop_breadcrumb; return 1; fi
            mode_flag="--wordlist=\"$REPLY\""
            ;;
        2)
            ui_prompt_optional "Incremental mode name (leave blank for default)"
            if [[ -n "$REPLY" ]]; then mode_flag="--incremental=$REPLY"; else mode_flag="--incremental"; fi
            ;;
        3) mode_flag="--single" ;;
        4) ui_prompt_text "Enter mask"; mode_flag="--mask=$REPLY" ;;
    esac

    local rules_flag=""
    if [[ "$mode_choice" == "1" ]]; then
        if ui_prompt_yesno "Use word mangling rules (--rules)?" "N"; then
            rules_flag="--rules"
        fi
    fi

    ui_prompt_optional "Session Name (--session)"
    local session_flag=""
    if [[ -n "$REPLY" ]]; then session_flag="--session=$REPLY"; fi

    ui_prompt_optional "Additional Flags (e.g. --fork=4)"
    local extra_flags="$REPLY"

    local cmd="john $format_flag $mode_flag $rules_flag $session_flag $extra_flags \"$hashfile\""
    cmd=$(echo "$cmd" | tr -s ' ')

    confirm_and_run "$cmd" "john_parse_results"
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# MAIN JOHN MENU
# -----------------------------------------------------------------------------
john_menu() {
    ui_push_breadcrumb "John the Ripper"
    while true; do
        ui_header
        ui_menu_item 1 "About / Cheat Sheet"
        ui_menu_item 2 "Quick Attacks" "Wordlist, Incremental, Single"
        ui_menu_item 3 "Format Conversion Helpers (*2john)" "Extract hashes from ZIP, SSH, etc."
        ui_menu_item 4 "Custom Command Builder" "Step-by-step full control"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 4
        case "$REPLY" in
            1) john_about ;;
            2) john_quick_menu ;;
            3) john_helpers_menu ;;
            4) john_custom_builder ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}
