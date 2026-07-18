#!/usr/bin/env bash
set -eou pipefail

# Hyzer Global / Local Installation Script
# This script sets up Hyzer so it can be run from anywhere by typing 'hyzer'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}        Hyzer Installation Script      ${NC}"
echo -e "${CYAN}=======================================${NC}"

# Check for required source files
if [[ ! -f "hyzer.sh" || ! -d "lib" ]]; then
    echo -e "${RED}[✗] Error: Must be run from the directory containing hyzer.sh and lib/${NC}"
    exit 1
fi

INSTALL_GLOBAL=0
if [[ $EUID -eq 0 ]]; then
    INSTALL_GLOBAL=1
    echo -e "${GREEN}[*] Running as root. Installing globally.${NC}"
else
    echo -e "${YELLOW}[!] Running as standard user. Installing locally.${NC}"
    echo -e "${YELLOW}    (Run with sudo for global installation to all users)${NC}"
fi

# Set paths based on install type
if [[ $INSTALL_GLOBAL -eq 1 ]]; then
    INSTALL_DIR="/opt/hyzer"
    BIN_DIR="/usr/local/bin"
else
    INSTALL_DIR="${HOME}/.local/share/hyzer"
    BIN_DIR="${HOME}/.local/bin"
fi

# Ensure bin dir exists for local install
if [[ $INSTALL_GLOBAL -eq 0 ]]; then
    mkdir -p "$BIN_DIR"
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}[!] Warning: $BIN_DIR is not in your PATH.${NC}"
        echo -e "${YELLOW}    You may need to add 'export PATH=\$PATH:$BIN_DIR' to your ~/.bashrc or ~/.zshrc${NC}"
    fi
fi

echo -e "\n${CYAN}[*] Copying files to $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR"
cp -r hyzer.sh lib/ "$INSTALL_DIR/"

echo -e "${CYAN}[*] Setting executable permissions...${NC}"
chmod +x "$INSTALL_DIR/hyzer.sh"

echo -e "${CYAN}[*] Creating symlink in $BIN_DIR/hyzer...${NC}"
ln -sf "$INSTALL_DIR/hyzer.sh" "$BIN_DIR/hyzer"

# Create user directories
USER_HYZER_DIR="${HOME}/.hyzer"
echo -e "${CYAN}[*] Initializing user config directory at $USER_HYZER_DIR...${NC}"
mkdir -p "$USER_HYZER_DIR/logs"
touch "$USER_HYZER_DIR/loot.txt"
touch "$USER_HYZER_DIR/history"

# Dependency Check Summary
echo -e "\n${CYAN}=== Dependency Check ===${NC}"
check_dep() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}[✓] $2 found${NC}"
    else
        echo -e "${YELLOW}[!] $2 missing ($3)${NC}"
    fi
}

check_dep hashcat "Hashcat" "sudo apt install hashcat"
check_dep john "John the Ripper" "sudo apt install john"
check_dep hydra "Hydra" "sudo apt install hydra"
check_dep gunzip "gunzip" "Standard on most Linux distros"

if [[ -d "/usr/share/seclists" ]]; then
    echo -e "${GREEN}[✓] SecLists found${NC}"
else
    echo -e "${YELLOW}[!] SecLists missing (Highly recommended: sudo apt install seclists)${NC}"
fi

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN} Installation Complete!                                                 ${NC}"
echo -e "${GREEN} You can now launch the toolkit from any terminal by typing: ${CYAN}hyzer${NC}"
echo -e "${GREEN}========================================================================${NC}"
