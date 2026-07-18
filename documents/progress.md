# Hyzer — Build Progress Tracker

**Project:** Hyzer — Terminal-Based Password Attack Toolkit  
**Author:** dhype7  
**Started:** 2026-07-17

## Pre-Build Research

- [x] Run `hashcat --help` / `hashcat -hh` — captured attack modes, hash modes, charsets, workload profiles
- [x] Run `john --help` / `--list=formats` — captured modes, format list, helper locations
- [x] Run `hydra -h` — captured syntax, flags, supported services list
- [x] Locate wordlists — found rockyou.txt, SecLists, fasttrack.txt at standard Kali paths
- [x] Locate *2john helpers — found 30+ at /usr/bin/ and /usr/sbin/
- [x] PRD saved to `documents/prd.md`
- [x] Implementation plan created and awaiting approval

## Implementation Status

- [ ] `lib/ui.sh` — Color system, banners, prompts, breadcrumbs, confirm_and_run
- [ ] `lib/config.sh` — ~/.hyzer init, logging, history, loot, config read/write
- [ ] `lib/wordlists.sh` — Shared wordlist detection and picker
- [ ] `lib/hashcat.sh` — Hashcat submenu, cheat-sheet, quick attacks, custom builder, search
- [ ] `lib/john.sh` — John submenu, cheat-sheet, quick attacks, *2john helpers, custom builder
- [ ] `lib/hydra.sh` — Hydra submenu, cheat-sheet, service presets, custom builder
- [ ] `hyzer.sh` — Main entrypoint, banner, disclaimer, dep check, main menu loop
- [ ] `install.sh` — Global/local installer with symlinks and dep summary
- [ ] `README.md` — Documentation

## Verification

- [ ] `bash -n` syntax check on all scripts
- [ ] `shellcheck` passes
- [ ] Full menu navigation test — no dead ends
- [ ] Wordlist detection works
- [ ] File path validation works
- [ ] Ctrl+C returns to menu cleanly
- [ ] Logs and history populated
- [ ] No placeholder/stub text
