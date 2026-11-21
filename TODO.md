# Toward 1.0

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
- **KDE** as a third desktop; **language choice** (Swedish, English, Norwegian,
  Danish).
- **Config layering:** Quickshell and the scripts run from
  `~/.local/share/yunagi`, like the Hyprland defaults; `~/.config` holds only
  the user's overrides, so updates no longer collide with copied files.

# After 1.0, maybe

- **Network tool:** our own, in Yunagi's look, for what the network panel does not
  do (VLAN, bridges, saved connections). Until then the panel has IPv4 and DNS of
  the current connection, and More settings… opens nm-connection-editor.
