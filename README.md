# Hyzer — Terminal-Based Password Attack Toolkit

Hyzer is a comprehensive terminal-based menu toolkit designed for CTF players, cybersecurity students, and authorized ethical hackers. It acts as a guided command center for three essential password-attack tools:

1. **Hash Identification** — Identify unknown hashes using `hashid`
2. **Hashcat** — GPU-accelerated offline hash cracking
3. **John the Ripper** — CPU-based offline hash cracking and format conversion (`*2john` helpers)
4. **Hydra** — Online network-service login brute-forcing
5. **Wordlist Generation** — Generate targeted wordlists on the fly using `crunch` and `cewl`

## Why Hyzer?

Instead of Googling syntax or struggling with man pages in the middle of a CTF, Hyzer provides a clean, fast, and educational TUI (Terminal User Interface). 

- **Educational UX**: It teaches you as it goes, showing cheat sheets and explaining modes before prompting.
- **Smart Wordlists**: It automatically detects common wordlists (like `rockyou.txt` and `SecLists`) on your system and presents them as a numbered menu.
- **Loot Vault**: It automatically extracts your successful cracks from Hashcat and John potfiles and stores them in a centralized `~/.hyzer/loot.txt` vault.
- **No Blind Guesses**: Hyzer never executes a command without showing it to you first. You always get a chance to review, edit, or cancel.

## Prerequisites

Hyzer is a wrapper, so it requires the underlying tools to be installed on your system. It works best on security distributions like Kali Linux or Parrot OS.

```bash
# Recommended on Debian/Ubuntu/Kali
sudo apt update
sudo apt install hashcat john hydra seclists wordlists
```

## Installation

You can install Hyzer globally (so it's available for all users) or locally (just for you).

1. Clone or download this repository.
2. Navigate to the `hyzer-src` directory.
3. Make the install script executable and run it:

```bash
chmod +x install.sh

# For a global installation (recommended):
sudo ./install.sh

# For a local installation (only your user):
./install.sh
```

Once installed, simply type `hyzer` from any directory in your terminal to launch the toolkit.

## File Structure

```
hyzer-src/
├── install.sh           # Global/local installation and setup script
├── hyzer.sh             # Main entrypoint — banner, disclaimer, main menu loop
├── lib/                 # Core modules
│   ├── ui.sh            # Colors, banners, prompts, breadcrumbs, confirmation dialogs
│   ├── hashcat.sh       # Hashcat module (quick attacks, custom builder)
│   ├── john.sh          # John module (quick attacks, format-conversion helpers)
│   ├── hydra.sh         # Hydra module (service presets, custom builder)
│   ├── wordlists.sh     # Shared wordlist detection and selection logic
│   └── config.sh        # Config management, history, and loot vault
└── README.md            # This file
```

## The Loot Vault & Configuration

Hyzer creates a `~/.hyzer/` directory in your home folder. This contains:
- `logs/`: Timestamped logs of every command run and its output.
- `history`: A history file of all executed commands.
- `loot.txt`: Your centralized vault of cracked credentials.
- `config`: Your settings (like UI theme and default wordlists).

You can manage all of this from the **Loot & Config** menu within the application.

## Legal Disclaimer

Hyzer is provided for **CTF practice, academic study, and authorized penetration testing only.** By using this tool, you agree that you will only use it against systems you explicitly own or have documented, authorized permission to test. The author assumes no liability for illegal, malicious, or unauthorized use.

## Credits

Author: dhype7
Built with ❤️ for the cybersecurity community.
