# Toward 1.0

- **Limine:** a new theme; the current Ion menu does not look right.
- **Plymouth:** a new start-up screen.
- **btrfs and snapshots:** btrfs by default with subvolumes (`@`, `@home`, `@log`,
  `@pkg`), snapper and snap-pac for a snapshot before and after every pacman run,
  and snapshots as Limine boot entries (our own, since `limine-snapper-sync` is
  only in the AUR).
- **Image install:** build a zstd-compressed btrfs image of Arch and Yunagi with
  the ISO and write it to disk, instead of installing packages one by one
  (Omarchy installs in under a minute this way). This also makes every ISO
  offline.
- **UEFI boot menu** of the ISO in Yunagi's look.
- **AI user:** `yunagi-ai`, run after install and reachable from the settings
  menu (the tools need a network, so not in the installer). Creates an account
  without sudo that shares the `delat` group and `/home/delat` with the admin,
  installs Claude Code, Codex and Grok in that account's `~/.local` only, and
  sets up the shared tmux (`tmuxdela`, `tmuxdelaw`) through which the admin lets
  the agent in. You pick which agents to install.
- **Hermes desktop:** installed for the admin only when chosen in the settings
  menu; never starts by itself.
- **Agent usage in the bar:** quota left and pace per provider, like Omarchy's
  Agents panel. A timer in the AI account writes the numbers to
  `/home/delat/ai-usage.json`; the admin's bar only reads that file, so the
  logins never leave the AI account.
- **Installer disk wipe:** erase any disk from the disk step, not only the
  install disk, without dropping to the shell.
- **Firewall tool:** open and close ports from a small TUI like the Packages
  tool, instead of editing `/etc/nftables.conf`.
- **KDE** as a third desktop; **language choice** (Swedish, English, Norwegian,
  Danish).
- **Config layering:** Quickshell and the scripts run from
  `~/.local/share/yunagi`, like the Hyprland defaults; `~/.config` holds only
  the user's overrides, so updates no longer collide with copied files.
- **Network tool:** a small TUI like the Packages tool, opened from the network
  panel, for what the panel cannot do: static IP, DNS, VLAN, bridges, saved
  connections. Replaces `nmtui`.
- **Settings menu layout:** the root menu is cluttered; consider moving Settings
  under System.
