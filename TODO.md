# Next

- **Limine:** a new theme in the look of SDDM: the same blurred photo, a bit
  darker, the wordmark at the bottom centre, light menu text in the middle.
  The current Ion menu (dark ground, diamond in the corner) does not look right.
- **Softer pulse:** the wordmark pulses too much. SDDM goes from opacity 1 to
  0.35 over 2.4 s each way; check the Plymouth glow as well.
- **Themes for SDDM and the lock screen:** a theme is a background (picture or
  video) with the clock, greeting, password field and wordmark placed to fit it,
  as `greetingY` does for the cat video. One more with a video and two with a
  still picture; bob has chosen the pictures. Chosen in Settings → Lock screen,
  with the thumbnail preview.
- **Licenses:** every picture and video that ships must be free to
  redistribute, with credit in the README. The cat video and the other
  wallsflow clips are personal use only; the Death Star picture cannot ship.
  Milky way lake (Pexels, Wilson Mallmann) needs a credit if it ships.
- **Desktop background in Settings:** a list of the pictures in
  `~/Pictures/wallpapers`, like Lock screen → Background, that writes
  `hyprpaper.conf`, restarts hyprpaper and runs matugen so the colours follow.
  Today the picture is set by hand and matugen only runs at install.
- **Hidden networks:** connect to a hidden SSID from the network panel
  (name, security, password); today only nmcli or nm-connection-editor.
- **Video desktop backgrounds:** mp4 as the desktop background, for desktops
  such as burken; on laptops only if the battery cost is small.
- **btrfs and snapshots:** btrfs by default with subvolumes (`@`, `@home`, `@log`,
  `@pkg`), snapper and snap-pac for a snapshot before and after every pacman run,
  and snapshots as Limine boot entries (our own, since `limine-snapper-sync` is
  only in the AUR).
- **Image install:** build a zstd-compressed btrfs image of Arch and Yunagi with
  the ISO and write it to disk, instead of installing packages one by one
  (Omarchy installs in under a minute this way). This also makes every ISO
  offline.
- **UEFI boot menu** of the ISO in Yunagi's look.
- **Installer disk wipe:** erase any disk from the disk step, not only the
  install disk, without dropping to the shell.
- **Firewall:** nftables stays the default (Settings → Config → Firewall). Try
  firewalld in a VM from the ISO; if it fits, offer it as an option.
- **KDE** as a third desktop (`packages-kde.txt`): KDE only, Hyprland not installed
  unless chosen beside it, as with GNOME; KWallet off, gnome-keyring in every desktop;
  `~/.config/plasma-workspace/env/yunagi.sh` for Plasma after Hyprland. Config to
  copy into ~/.config is in `kde/` (window rule, shortcuts as in Hyprland, KWallet off,
  screensaver via hypridle at 5 min, lock 10 min, screens off 30 s after lock).
  AI and AI Usage (`yunagi-ai menu`, `yunagi-ai-usage show`) work but are plain;
  make them nicer, maybe a Plasma panel widget for usage like the bar's robot.
  Panel in the bar's style (top, floating, 40 px, #04090a at 65 %, square corners)
  needs Panel Colorizer (GPL-3, KDE Store/AUR): ship it in `kde/` plus a layout
  template; bob's own panel is in dotfiles `KDE_DESKTOP`. Panel Colorizer settings
  for both looks are in `kde/panel/`: `yunagi-style.json` (chosen) and
  `kde-native.json` (KDE's own background, tried on burken 2026-11-22).
  yunagi-update picks the desktop from the login manager (SDDM → Yunagi), so a
  KDE-only install would get Hyprland's packages: record the chosen desktops at
  install (e.g. /etc/yunagi/desktops) and update by that; `kde/` is not updated yet.
- **Language choice** (Swedish, English, Norwegian, Danish).

# Later, maybe

- **Network tool:** our own, in Yunagi's look, for what the network panel does not
  do (VLAN, bridges, saved connections). Until then the panel has IPv4 and DNS of
  the current connection, and More settings… opens nm-connection-editor.
