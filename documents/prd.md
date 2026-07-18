# Enhanced PRD — Hyzer

### A comprehensive terminal-based menu toolkit for CTF players, cybersecurity students, & ethical hackers

**Author of tool:** dhype7

## 1. Overview

Build a single, polished, Linux-terminal application called **Hyzer** that acts as a guided command center for three password-attack tools commonly used in CTFs and authorized penetration testing:

1. **Hashcat** — GPU-accelerated offline hash cracking.
2. **John the Ripper** — CPU-based offline hash cracking / format detection.
3. **Hydra** — online, network-service login brute-forcing.

**Enhancement:** Hyzer will now also feature global system accessibility via an automated `install.sh` deployment script, advanced configuration files, and a local "Loot" manager to track successfully cracked credentials.

The tool must feel like a professional CLI product (think: `nmap` NSE menu wrappers, `msfconsole`-style banners), not a rough script.

## 2. Goals

- **Global Execution:** One executable entrypoint deployed globally so the user can type `hyzer` from any directory in the terminal to launch the full interactive menu system.
- **Out-of-the-Box Functionality:** Works seamlessly on Kali Linux, Parrot OS, or BlackArch environments where hashcat, john, and hydra are standard.
- **Educational UX:** Teaches as it goes. Every submenu shows a short description and real example commands before asking the user to build their own.
- **Command Transparency:** Builds correct, commands from guided prompts and never guesses blindly.
- **Context-Aware Suggestions:** Suggests wordlists intelligently based on what actually exists on disk.
- **Aesthetics:** Looks and feels good with consistent colors, ASCII banners, clear navigation, and no dead ends.
- **Professional Polish:** Ships with a clean install script, a Credits screen, and a clean Exit.

## 3. Non-Goals

- Do NOT auto-download wordlists or word-list generators from the internet without explicit user consent and a visible confirmation step.
- Do NOT silently install missing packages — detect and inform only.

## 4. Target User

CTF competitors, academic cybersecurity engineering students, and authorized security testers working in a terminal. This is for users who want to move faster between "I have a hash / a login form" and "I have the right command running" without re-Googling syntax every time.

## 5. MANDATORY Pre-Build Research Step

Before writing a single line of code, the building agent must establish a solid internal knowledge base by reading documentation/help output, not guessing from memory:

- Run and read: `hashcat --help`, `hashcat --example-hashes | head -100`, `man hashcat`.
- Run and read: `john --help`, `man john`, `--list=formats`, `--list=subformats`.
- Run and read: `hydra -h`, `man hydra`, and module-specific help (`hydra http-post-form -U`).
- Structure the code so mode numbers and flags live in one clearly-commented configuration section, making them trivial to update later.
- Cross-check the reference tables against current local `--help` output and correct any discrepancies before shipping.

## 6. Tool Selection & Extensions

### 6.1 Hashcat

GPU-accelerated offline hash cracking. Essential for cracking hashes fast in CTFs (NTLM dumps, WPA handshakes, etc.).

### 6.2 John the Ripper

CPU-based offline cracking with excellent auto-detection (`--format`), and a huge ecosystem of `*2john` helper scripts that convert real-world artifacts into crackable hash files.

### 6.3 Hydra

Chosen because CTFs and real engagements often present a _live_ login surface (SSH, FTP, web login forms) where online credential brute-forcing is required. Hydra shares Hyzer's "wordlist-driven" UX pattern perfectly.

### 6.4 Enhanced Module: Hyzer Loot & Config

A built-in lightweight tracking mechanism that parses successful cracks (from `.potfile` or Hydra stdout) and stores them in a readable local vault, alongside a configuration manager for setting default wordlist paths.

## 7. Information Architecture

```
Hyzer (banner + disclaimer on launch)
├── 1) Hashcat
│     ├── About / cheat sheet (attack modes, hash modes table)
│     ├── Quick attacks (dictionary, mask, WPA, custom rules)
│     ├── Custom command builder (fully manual, step by step)
│     ├── List installed hashcat hash-mode reference (searchable)
│     └── Back
├── 2) John the Ripper
│     ├── About / cheat sheet (modes, *2john helpers)
│     ├── Quick attacks (wordlist, incremental, single-crack)
│     ├── Format-conversion helpers (zip/ssh/rar/pdf/unshadow)
│     ├── Custom command builder
│     └── Back
├── 3) Hydra
│     ├── About / cheat sheet (supported services, syntax anatomy)
│     ├── Quick attacks (ssh/ftp/http-post-form/rdp/smb/mysql)
│     ├── Custom command builder (includes proxy support options)
│     └── Back
├── 4) Hyzer Loot & Config (ENHANCED)
│     ├── View Cracked Credentials (Loot vault)
│     ├── Set Default Wordlist Paths
│     ├── Toggle UI Themes
│     └── Back
├── 5) Credits
│     └── "Hyzer — created by dhype7" + version + disclaimer
└── 6) Exit
```

Every submenu must offer a **"0) Back"** and the top-level main menu must offer **exit** from anywhere via a consistent key (e.g., `q` or `0`), never a dead end requiring Ctrl+C.

## 8. UX / Design Requirements

- **Banner:** Large ASCII-art "HYZER" title on launch. Hand-built ASCII acceptable if `figlet`/`toilet` aren't installed.
- **Color System:** Use `tput`/ANSI codes with a defined palette (e.g., cyan for headers, green for success, yellow for prompts, red for errors). Define these once as reusable variables/functions.
- **Consistent Navigation:** Numbered choices everywhere, breadcrumb line at the top of every screen (e.g., `Hyzer > Hashcat > Quick Attacks`).
- **Legal/Ethics Banner:** One-time-per-session notice: _"For use only against systems you own or are explicitly authorized to test."_ Require keypress acknowledgment.
- **Confirmation Before Execution:** Every generated command must be printed in full, clearly highlighted, with an explicit "Run this command? [Y/n/e=edit]" step.
- **Validation:** File path prompts must check that the file exists before proceeding and re-prompt with a clear error rather than crashing.
- **Progress Feedback:** Stream stdout/stderr live to the terminal so the user sees native progress output.

## 9. Expanded Functional Requirements per Tool

### 9.1 Hashcat

**Quick Attacks (guided presets):**

1. Dictionary attack (`-a 0`).
2. Mask / brute-force attack (`-a 3`) with a short mask-syntax legend.
3. WPA/WPA2/WPA3 handshake crack (`-m 22000` / `-m 22001`).
4. Show cracked results (`--show`).

**Custom command builder:** Step-by-step prompts for `-m`, `-a`, hash file, wordlist/mask, `-r` rules, `-o` output file, `-w` workload.

### 9.2 John the Ripper

**Format-conversion helpers (`*2john`):** Includes ZIP, RAR, SSH private key, Linux shadow (`unshadow`), and a generic prompt for other helpers (e.g., `pdf2john`, `office2john`). Checks existence via `command -v` before running.

**Quick Attacks:**

1. Wordlist attack (optionally with `--rules`).
2. Incremental (brute-force) mode.
3. Single-crack mode (`--single`).

### 9.3 Hydra

**Quick Attacks (service presets):**

1. SSH.
2. FTP.
3. HTTP POST login form (guided prompts for form path, field names, and the failure string `F=...`).
4. RDP and SMB.
5. _Enhanced:_ Database logins (MySQL, PostgreSQL) preset.

Each preset prompts for target host, username(s), password(s), and thread count (with default suggestions and rate-limit warnings).

## 10. Wordlist Management (Shared Subsystem)

1. Check for common preinstalled locations and only offer existing ones:
    - `/usr/share/wordlists/rockyou.txt` (If only `.gz` exists, offer to `gunzip -k` it).
    - `/usr/share/seclists/Passwords/**` (Glob and list what is actually present).
    - `/usr/share/seclists/Usernames/**`.
2. If none exist, offer to run a bounded `locate`/`find` search with a timeout.
3. Always allow a custom path input and validate its existence.
4. Never auto-download anything. Inform the user where lists normally come from (e.g., `seclists` apt package) if none are found.

## 11. Command Execution, Logging, and Loot

- **Logs:** Maintain `~/.hyzer/logs/` — each run writes a timestamped log file capturing the exact command and full output.
- **History:** Maintain `~/.hyzer/history` — append every executed command.
- **Loot (Enhanced):** Automatically extract successful crack results from standard `.potfile` locations and output them to `~/.hyzer/loot.txt`.
- **Interrupts:** Catch Ctrl+C during long-running commands and return cleanly to the calling menu without crashing the app.

## 12. Technical Requirements

- **Language:** Portable Bash (`#!/usr/bin/env bash`, `set -uo pipefail`).
- **Structure:** Modularized structure preferred (`lib/ui.sh`, `lib/hashcat.sh`, etc.) but must be clean and commented.
- **Dependencies:** No hard external dependencies beyond the three target tools. Optional visual tools (`figlet`, `dialog`) must degrade gracefully to plain Bash if absent.
- **Startup Check:** Check for `hashcat`, `john`, `hydra` with `command -v` on launch. Show a warning if missing, but do not hard-block the rest of the application.

## 13. Safety & Ethical Use

- One-time acknowledgment banner at launch.
- Credits/About screen explicitly states: "Hyzer is provided for CTF practice and authorized security testing only."

## 14. Deliverable File Structure

```
hyzer-src/
├── install.sh           # NEW: Global installation and setup script
├── hyzer.sh             # Main entrypoint logic
├── lib/                 # Sourced modules
│   ├── ui.sh
│   ├── hashcat.sh
│   ├── john.sh
│   ├── hydra.sh
│   ├── wordlists.sh
│   └── config.sh        # NEW: Handles ~/.hyzer configs and loot
└── README.md            # Instructions, install notes, credits
```

## 15. Global Installation & Setup Partition (`install.sh`) (NEW)

To ensure the user can type `hyzer` from anywhere in the terminal, the project must ship with a robust `install.sh` script.

**`install.sh` Requirements:**

1. **Permission Check:** The script must verify if it has sufficient privileges to write to `/usr/local/bin` and `/opt`. If not, it should prompt the user to run with `sudo`, or gracefully fallback to a local user install (`~/.local/bin` and `~/.local/share/hyzer`).
2. **Directory Creation:**
    - Create the core application directory (e.g., `/opt/hyzer` for global, or `~/.local/share/hyzer` for local).
    - Create user-specific operational directories (`~/.hyzer/logs`, `~/.hyzer/history`, `~/.hyzer/loot`).
3. **File Deployment:**
    - Copy `hyzer.sh` and the `lib/` directory into the core application directory.
    - Set appropriate execution permissions (`chmod +x /opt/hyzer/hyzer.sh`).
4. **Global Alias/Symlink:**
    - Create a symbolic link in a system PATH directory pointing to the main script.
    - Command: `ln -sf /opt/hyzer/hyzer.sh /usr/local/bin/hyzer`.
5. **Dependency Verification Check:**
    - The install script should perform a one-time check for `hashcat`, `john`, `hydra`, `gunzip`, and `SecLists`.
    - It will print a clean summary to the terminal (e.g., `[✓] Hashcat found`, `[!] SecLists missing - recommended to apt install seclists`).
6. **Success Message:** Conclude with a clear message: _"Installation Complete! You can now type 'hyzer' from anywhere in your terminal to launch the toolkit."_

## 16. Acceptance Criteria

The build is strictly considered "done" when:

- [ ] Running `install.sh` successfully deploys the tool globally, allowing the command `hyzer` to be executed from any terminal path.
- [ ] The application shows the banner, disclaimer, and main menu featuring Hashcat, John, Hydra, Config/Loot, Credits, and Exit.
- [ ] Every submenu provides cheat-sheets with real example commands before prompting.
- [ ] Wordlist prompts detect real files on disk and provide a working custom-path fallback.
- [ ] `*2john` helper submenu successfully runs formatting helpers and chains into an attack.
- [ ] Missing-tool detection degrades gracefully with clear messaging instead of crashing.
- [ ] Ctrl+C during a running attack safely returns to the menu.
- [ ] Logs (`~/.hyzer/logs/`) and history (`~/.hyzer/history`) track every executed command.
- [ ] No placeholder text or stubbed-out options remain in the codebase.
