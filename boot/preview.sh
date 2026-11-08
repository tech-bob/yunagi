#!/usr/bin/env bash
# Shows the yunagi-ion Plymouth splash on tty5 for a few seconds, then returns.
# The boot setup is left as it was. Usage: sudo boot/preview.sh [seconds] [boot|shutdown|password]
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo." >&2; exit 1; }

here=$(dirname "$(readlink -f "$0")")
back=$(fgconsole)
old=$(plymouth-set-default-theme)

install -Dm644 -t /usr/share/plymouth/themes/yunagi-ion "$here"/ion/plymouth/*.{png,script,plymouth}
plymouth-set-default-theme yunagi-ion
restore() {
    plymouth quit 2>/dev/null || true
    plymouth-set-default-theme "$old"
    chmod 644 /tmp/plymouth-preview.log 2>/dev/null || true
    chvt "$back"
}
trap restore EXIT

mode=${2:-boot}; [ "$mode" = password ] && mode=boot
# With DISPLAY set plymouthd skips udev and looks only for /dev/dri/card0
unset DISPLAY WAYLAND_DISPLAY
chvt 5
# Without "splash" on the kernel command line plymouthd shows no theme
plymouthd --tty=/dev/tty5 --mode="$mode" --kernel-command-line="quiet splash" --debug --debug-file=/tmp/plymouth-preview.log
plymouth --show-splash
# password: ask like the disk unlock does, then show the start-up bar
[ "${2:-}" = password ] && plymouth ask-for-password --prompt="Password" >/dev/null
sleep "${1:-8}"
