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
- **KDE** as a third desktop; **language choice** (Swedish, English, Norwegian,
  Danish).
