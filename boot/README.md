# Ion boot theme

Ion (C3.1) is selected for Limine. Plymouth shows the rainbow yunagi wordmark in
the middle of a plain dark screen, with a light orbiting it on a tilted ellipse
at start-up; shutdown and reboot show the wordmark alone.
The original diamond geometry is unchanged in Limine.

Preview Plymouth without rebooting: `sudo boot/preview.sh [seconds] [boot|shutdown]`. It shows
the splash on tty5 and restores the previous theme; the boot setup is untouched.

`install.sh` installs it for Yunagi and GNOME when an existing Limine configuration
is found. Minimal and other bootloaders are left unchanged. The ISO installer's
branding is unchanged; the theme appears when booting the installed system.

- `ion/limine.conf` supplies supported menu colours and a static background;
  Limine controls the menu layout, so it differs from the concept image.
- `configure.py` preserves boot entries and root arguments, adds `quiet splash`
  to Linux entries except fallback entries, and keeps the original config as
  `limine.conf.yunagi-backup`. It selects `yunagi-ion` and rebuilds initramfs.
- `plymouth.conf` inserts the Plymouth hook before root unlocking/mounting while
  preserving keyboard, graphics and encryption hooks.
- Escape switches Plymouth to boot details. To skip it for one boot, press `e`
  in Limine and remove `splash` from the kernel command line.

Art sources and rendered PNGs are both included. Regenerate with
`python boot/render.py` (requires `python-fonttools` and `librsvg`). Inter is
converted to outlines, so the rainbow wordmark needs no font at boot.

Checks: `python -m unittest discover -s boot -v`.

References: [Limine configuration](https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md),
the packaged Plymouth `script` theme and mkinitcpio hook.
