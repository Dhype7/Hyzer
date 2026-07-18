# =============================================================================
# hydra.sh — Hydra Module for Hyzer
# Sourced by hyzer.sh. Uses ui_*, cfg_*, wl_* functions.
# =============================================================================

# -----------------------------------------------------------------------------
# REFERENCE DATA
# -----------------------------------------------------------------------------

HYDRA_SERVICES=(
    "ssh:SSH - Secure Shell:22"
    "ftp:FTP - File Transfer Protocol:21"
    "http-post-form:HTTP POST Form Login:80"
    "http-get-form:HTTP GET Form Login:80"
    "rdp:RDP - Remote Desktop Protocol:3389"
    "smb:SMB - Server Message Block:445"
    "smb2:SMB2 - Server Message Block v2:445"
    "mysql:MySQL Database:3306"
    "postgres:PostgreSQL Database:5432"
    "telnet:Telnet:23"
    "vnc:VNC - Virtual Network Computing:5900"
    "snmp:SNMP:161"
    "pop3:POP3 Email:110"
    "imap:IMAP Email:143"
    "smtp:SMTP Email:25"
)

# -----------------------------------------------------------------------------
# SERVICE SELECTOR — interactive menu
# Sets REPLY to the service name (e.g. "ssh")
# -----------------------------------------------------------------------------
hydra_select_service() {
    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}Select Target Service${CLR_RESET}"
    ui_line

    local i=1
    for svc in "${HYDRA_SERVICES[@]}"; do
        IFS=':' read -r name desc port <<< "$svc"
        printf "  ${CLR_CYAN}[%2d]${CLR_RESET} %-15s ${CLR_GRAY}%s (port %s)${CLR_RESET}\n" "$i" "$name" "$desc" "$port"
        ((i++))
    done
    echo -e "  ${CLR_YELLOW}[C]${CLR_RESET}  Enter a custom service name"
    ui_newline

    while true; do
        ui_prompt "Select service"
        local input="${REPLY,,}"

        if [[ "$input" == "c" ]]; then
            ui_prompt_text "Enter service name (e.g. ssh, ftp, http-get)"
            return 0
        elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#HYDRA_SERVICES[@]} )); then
            local selected="${HYDRA_SERVICES[$((input-1))]}"
            REPLY="${selected%%:*}"
            IFS=':' read -r _ desc port <<< "$selected"
            ui_success "Selected: ${REPLY} (${desc})"
            HYDRA_DEFAULT_PORT="$port"
            return 0
        else
            ui_error "Invalid selection."
        fi
    done
}

# -----------------------------------------------------------------------------
# RESULT PARSER — analyzes Hydra output and shows colored summary
# -----------------------------------------------------------------------------
hydra_parse_results() {
    local logfile="$1"
    local exit_code="$2"

    if [[ ! -f "$logfile" || "$logfile" == "/dev/null" ]]; then
        return
    fi

    ui_newline
    echo -e "${CLR_CYAN}${CLR_BOLD}╔═══════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}║         HYDRA RESULTS SUMMARY        ║${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}╚═══════════════════════════════════════╝${CLR_RESET}"
    ui_newline

    # Extract successful logins
    local found_creds=false
    while IFS= read -r line; do
        if ! $found_creds; then
            echo -e "  ${CLR_GREEN}${CLR_BOLD}🔓 Valid Credentials Found:${CLR_RESET}"
            found_creds=true
        fi
        # Parse hydra success line: [PORT][SERVICE] host: HOST   login: USER   password: PASS
        local host login pass
        host=$(echo "$line" | grep -oP 'host:\s*\K\S+' 2>/dev/null)
        login=$(echo "$line" | grep -oP 'login:\s*\K\S+' 2>/dev/null)
        pass=$(echo "$line" | grep -oP 'password:\s*\K.*' 2>/dev/null)

        if [[ -n "$login" && -n "$pass" ]]; then
            echo -e "    ${CLR_WHITE}Host:${CLR_RESET}     ${CLR_GRAY}${host:-unknown}${CLR_RESET}"
            echo -e "    ${CLR_WHITE}Login:${CLR_RESET}    ${CLR_CYAN}${login}${CLR_RESET}"
            echo -e "    ${CLR_GREEN}${CLR_BOLD}Password: ${pass}${CLR_RESET}"
            echo ""
        fi
    done < <(grep -E '\[[0-9]+\]\[' "$logfile" 2>/dev/null | grep -i "host:")

    if ! $found_creds; then
        # Check for specific failure reasons
        if grep -q "valid password found" "$logfile" 2>/dev/null; then
            ui_warn "Attack completed. No valid passwords were found."
            ui_tip "Try a larger wordlist or different credentials."
        elif grep -qi "connection refused" "$logfile" 2>/dev/null; then
            ui_error "Connection refused by the target."
            ui_tip "Check that the service is running and the port is correct."
        elif grep -qi "could not connect" "$logfile" 2>/dev/null; then
            ui_error "Could not connect to the target."
            ui_tip "Verify the target IP/hostname and network connectivity."
        elif grep -qi "max.*retries" "$logfile" 2>/dev/null; then
            ui_warn "Maximum retries reached — target may be rate-limiting."
            ui_tip "Lower the thread count (-t) and try again."
        elif grep -qi "Medusa\|target was refused\|too many" "$logfile" 2>/dev/null; then
            ui_warn "Connection dropped — target is likely blocking rapid attempts."
            ui_tip "Try -t 1 and -W 3 for slower, safer brute-forcing."
        else
            ui_info "No credentials found yet. The attack may have been incomplete."
        fi
    fi

    # Count attempts
    local attempts
    attempts=$(grep -c '^\[ATTEMPT\]' "$logfile" 2>/dev/null)
    if [[ -n "$attempts" && "$attempts" -gt 0 ]]; then
        ui_info "Total attempts logged: $attempts"
    fi

    ui_newline
    ui_info "Full log saved to: ${CLR_DIM}${logfile}${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# CHEAT SHEET
# -----------------------------------------------------------------------------
hydra_about() {
    ui_push_breadcrumb "Cheat Sheet"
    ui_header
    ui_section "Hydra Cheat Sheet"
    ui_info "Fast and flexible network login cracker."

    ui_subsection "Syntax"
    ui_print "  hydra [options] <target> <service>"

    ui_subsection "Common Flags"
    ui_print "  ${CLR_CYAN}-l LOGIN${CLR_RESET} / ${CLR_CYAN}-L FILE${CLR_RESET} : Single login / Login list"
    ui_print "  ${CLR_CYAN}-p PASS${CLR_RESET}  / ${CLR_CYAN}-P FILE${CLR_RESET} : Single password / Password list"
    ui_print "  ${CLR_CYAN}-C FILE${CLR_RESET}             : Colon-separated login:pass file"
    ui_print "  ${CLR_CYAN}-t TASKS${CLR_RESET}            : Parallel connections (default 16)"
    ui_print "  ${CLR_CYAN}-f${CLR_RESET}                  : Stop on first valid password"
    ui_print "  ${CLR_CYAN}-s PORT${CLR_RESET}             : Custom port"
    ui_print "  ${CLR_CYAN}-e nsr${CLR_RESET}              : Try null(n), same-as-login(s), reversed(r)"
    ui_print "  ${CLR_CYAN}-V${CLR_RESET}                  : Verbose (show each attempt)"

    ui_subsection "Supported Services"
    for svc in "${HYDRA_SERVICES[@]}"; do
        IFS=':' read -r name desc port <<< "$svc"
        printf "  ${CLR_CYAN}%-15s${CLR_RESET} : %s ${CLR_GRAY}(port %s)${CLR_RESET}\n" "$name" "$desc" "$port"
    done

    ui_subsection "Rate Limiting Warnings"
    ui_warn "SSH: Use -t 4 max to avoid lockouts/dropped connections."
    ui_warn "RDP: Use -t 1, very slow and unstable under load."
    ui_warn "HTTP: Watch for CSRF tokens and WAF rate limiting."

    ui_subsection "Examples"
    ui_print "  ${CLR_WHITE}SSH:${CLR_RESET}       hydra -l admin -P wordlist.txt ssh://192.168.1.1"
    ui_print "  ${CLR_WHITE}HTTP POST:${CLR_RESET} hydra -l admin -P wordlist.txt 192.168.1.1 http-post-form \"/login:user=^USER^&pass=^PASS^:F=Invalid\""

    ui_newline
    ui_pause
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# COMMON PROMPTS — shared by all service presets
# Sets HYDRA_* variables for building the command.
# -----------------------------------------------------------------------------
hydra_common_prompts() {
    local service_name="$1"
    local default_port="$2"
    local thread_warning="${3:-}"

    ui_prompt_text "Target Host/IP"
    HYDRA_TARGET="$REPLY"

    ui_prompt_text "Port" "$default_port"
    HYDRA_PORT="$REPLY"

    if ! wl_select_wordlist_or_single "Username"; then return 1; fi
    HYDRA_USER_FLAG="$WL_FLAG"
    HYDRA_USER_VAL="$WL_VALUE"

    if ! wl_select_wordlist_or_single "Password"; then return 1; fi
    HYDRA_PASS_FLAG="$WL_FLAG"
    HYDRA_PASS_VAL="$WL_VALUE"

    if [[ -n "$thread_warning" ]]; then
        ui_warn "$thread_warning"
    fi
    local default_threads="16"
    if [[ "$service_name" == "SSH" ]]; then default_threads="4"; fi
    if [[ "$service_name" == "RDP" ]]; then default_threads="1"; fi

    ui_prompt_text "Threads (-t)" "$default_threads"
    HYDRA_THREADS="$REPLY"

    HYDRA_EXTRA_FLAGS=""
    if ui_prompt_yesno "Stop on first success (-f)?" "Y"; then
        HYDRA_EXTRA_FLAGS+="-f "
    fi
    if ui_prompt_yesno "Try null/same-as-login/reversed (-e nsr)?" "N"; then
        HYDRA_EXTRA_FLAGS+="-e nsr "
    fi
    if ui_prompt_yesno "Verbose mode (-V)?" "N"; then
        HYDRA_EXTRA_FLAGS+="-V "
    fi
    ui_prompt_optional "Output file (-o)"
    if [[ -n "$REPLY" ]]; then
        HYDRA_EXTRA_FLAGS+="-o \"$REPLY\" "
    fi
    return 0
}

# Build final hydra command from HYDRA_* variables
_hydra_build_cmd() {
    local service="$1"
    local cmd="hydra $HYDRA_USER_FLAG \"$HYDRA_USER_VAL\" $HYDRA_PASS_FLAG \"$HYDRA_PASS_VAL\" -t $HYDRA_THREADS -s $HYDRA_PORT $HYDRA_EXTRA_FLAGS ${service}://$HYDRA_TARGET"
    echo "$cmd" | tr -s ' '
}

# -----------------------------------------------------------------------------
# QUICK ATTACKS — SERVICE PRESETS
# -----------------------------------------------------------------------------

hydra_preset_ssh() {
    ui_push_breadcrumb "SSH"
    ui_header
    ui_section "Hydra: SSH Brute-force"
    if hydra_common_prompts "SSH" "22" "SSH servers often limit connections. Use -t 4 max."; then
        confirm_and_run "$(_hydra_build_cmd ssh)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_preset_ftp() {
    ui_push_breadcrumb "FTP"
    ui_header
    ui_section "Hydra: FTP Brute-force"
    if hydra_common_prompts "FTP" "21" ""; then
        confirm_and_run "$(_hydra_build_cmd ftp)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_preset_http_post() {
    ui_push_breadcrumb "HTTP POST Form"
    ui_header
    ui_section "Hydra: HTTP POST Form"

    ui_prompt_text "Target Host/IP"
    local target="$REPLY"

    ui_prompt_text "Port" "80"
    local port="$REPLY"

    ui_prompt_text "Login page path (e.g. /login.php)"
    local path="$REPLY"

    ui_prompt_text "Username field name (e.g. user, username)"
    local user_field="$REPLY"

    ui_prompt_text "Password field name (e.g. pass, password)"
    local pass_field="$REPLY"

    ui_prompt_text "Failure string (text shown when login fails)"
    local fail_string="$REPLY"

    local is_https="N"
    if [[ "$port" == "443" ]]; then is_https="Y"; fi
    local svc_name="http-post-form"
    if ui_prompt_yesno "Is this HTTPS?" "$is_https"; then
        svc_name="https-post-form"
    fi

    if ! wl_select_wordlist_or_single "Username"; then ui_pop_breadcrumb; return 1; fi
    local u_flag="$WL_FLAG"
    local u_val="$WL_VALUE"

    if ! wl_select_wordlist_or_single "Password"; then ui_pop_breadcrumb; return 1; fi
    local p_flag="$WL_FLAG"
    local p_val="$WL_VALUE"

    ui_prompt_text "Threads (-t)" "16"
    local threads="$REPLY"

    local extra=""
    if ui_prompt_yesno "Stop on first success (-f)?" "Y"; then extra+="-f "; fi
    if ui_prompt_yesno "Verbose mode (-V)?" "N"; then extra+="-V "; fi

    ui_tip "Hydra uses ^USER^ and ^PASS^ as placeholders in the form data."

    local cmd="hydra $u_flag \"$u_val\" $p_flag \"$p_val\" -t $threads -s $port $extra \"$target\" $svc_name \"$path:${user_field}=^USER^&${pass_field}=^PASS^:F=$fail_string\""
    cmd=$(echo "$cmd" | tr -s ' ')
    confirm_and_run "$cmd" "hydra_parse_results"
    ui_pop_breadcrumb
}

hydra_preset_rdp() {
    ui_push_breadcrumb "RDP"
    ui_header
    ui_section "Hydra: RDP Brute-force"
    if hydra_common_prompts "RDP" "3389" "RDP brute-forcing is very slow. Use -t 1."; then
        confirm_and_run "$(_hydra_build_cmd rdp)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_preset_smb() {
    ui_push_breadcrumb "SMB"
    ui_header
    ui_section "Hydra: SMB Brute-force"
    if hydra_common_prompts "SMB" "445" ""; then
        confirm_and_run "$(_hydra_build_cmd smb)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_preset_mysql() {
    ui_push_breadcrumb "MySQL"
    ui_header
    ui_section "Hydra: MySQL Brute-force"
    if hydra_common_prompts "MySQL" "3306" ""; then
        confirm_and_run "$(_hydra_build_cmd mysql)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_preset_postgres() {
    ui_push_breadcrumb "PostgreSQL"
    ui_header
    ui_section "Hydra: PostgreSQL Brute-force"
    if hydra_common_prompts "PostgreSQL" "5432" ""; then
        confirm_and_run "$(_hydra_build_cmd postgres)" "hydra_parse_results"
    fi
    ui_pop_breadcrumb
}

hydra_quick_menu() {
    ui_push_breadcrumb "Quick Attacks"
    while true; do
        ui_header
        ui_menu_item 1 "SSH"
        ui_menu_item 2 "FTP"
        ui_menu_item 3 "HTTP POST Form"
        ui_menu_item 4 "RDP"
        ui_menu_item 5 "SMB"
        ui_menu_item 6 "MySQL"
        ui_menu_item 7 "PostgreSQL"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 7
        case "$REPLY" in
            1) hydra_preset_ssh ;;
            2) hydra_preset_ftp ;;
            3) hydra_preset_http_post ;;
            4) hydra_preset_rdp ;;
            5) hydra_preset_smb ;;
            6) hydra_preset_mysql ;;
            7) hydra_preset_postgres ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# CUSTOM COMMAND BUILDER
# -----------------------------------------------------------------------------
hydra_custom_builder() {
    ui_push_breadcrumb "Custom Builder"
    ui_header
    ui_section "Hydra: Custom Command Builder"

    ui_prompt_text "Target Host/IP"
    local target="$REPLY"

    HYDRA_DEFAULT_PORT=""
    hydra_select_service
    local service="$REPLY"

    local port_flag=""
    if [[ -n "$HYDRA_DEFAULT_PORT" ]]; then
        ui_prompt_text "Port (-s)" "$HYDRA_DEFAULT_PORT"
    else
        ui_prompt_text "Port (-s)"
    fi
    port_flag="-s $REPLY"

    # Username Mode
    ui_subsection "Username Input"
    ui_menu_item 1 "Single username (-l)"
    ui_menu_item 2 "Username list (-L)"
    ui_menu_item 3 "Colon-separated file (-C)"
    ui_newline
    ui_prompt_choice "Select mode" 3
    local u_mode="$REPLY"

    local u_flag="" u_val="" c_flag=""
    if [[ "$u_mode" == "1" ]]; then
        ui_prompt_text "Enter username"
        u_flag="-l"; u_val="$REPLY"
    elif [[ "$u_mode" == "2" ]]; then
        if wl_select_userlist; then
            u_flag="-L"; u_val="$REPLY"
        else
            ui_pop_breadcrumb; return 1
        fi
    elif [[ "$u_mode" == "3" ]]; then
        ui_prompt_file "Enter path to colon-separated file (login:pass)"
        c_flag="-C \"$REPLY\""
    fi

    local p_flag="" p_val=""
    if [[ -z "$c_flag" ]]; then
        ui_subsection "Password Input"
        ui_menu_item 1 "Single password (-p)"
        ui_menu_item 2 "Password list (-P)"
        ui_newline
        ui_prompt_choice "Select mode" 2
        if [[ "$REPLY" == "1" ]]; then
            ui_prompt_text "Enter password"
            p_flag="-p"; p_val="$REPLY"
        else
            if wl_select_wordlist; then
                p_flag="-P"; p_val="$REPLY"
            else
                ui_pop_breadcrumb; return 1
            fi
        fi
    fi

    ui_prompt_text "Threads (-t)" "16"
    local threads="$REPLY"

    ui_prompt_optional "Extra Flags (e.g. -f, -V, -e nsr)"
    local extra="$REPLY"

    local cmd
    if [[ -n "$c_flag" ]]; then
        cmd="hydra $c_flag -t $threads $port_flag $extra ${service}://$target"
    else
        cmd="hydra $u_flag \"$u_val\" $p_flag \"$p_val\" -t $threads $port_flag $extra ${service}://$target"
    fi
    cmd=$(echo "$cmd" | sed 's/""//g' | tr -s ' ' | sed 's/ $//')

    confirm_and_run "$cmd" "hydra_parse_results"
    ui_pop_breadcrumb
}

# -----------------------------------------------------------------------------
# MAIN HYDRA MENU
# -----------------------------------------------------------------------------
hydra_menu() {
    ui_push_breadcrumb "Hydra"
    while true; do
        ui_header
        ui_menu_item 1 "About / Cheat Sheet"
        ui_menu_item 2 "Quick Attacks (Service Presets)" "SSH, FTP, HTTP, RDP, etc."
        ui_menu_item 3 "Custom Command Builder" "Step-by-step full control"
        ui_menu_back

        ui_newline
        ui_prompt_choice "Select an option" 3
        case "$REPLY" in
            1) hydra_about ;;
            2) hydra_quick_menu ;;
            3) hydra_custom_builder ;;
            0) break ;;
        esac
    done
    ui_pop_breadcrumb
}
