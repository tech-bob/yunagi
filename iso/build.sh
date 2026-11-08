#!/usr/bin/env bash
# Builds the Yunagi install ISO: Arch's releng profile plus the files in iso/
#
#   iso/build.sh            output in iso/out/, needs root (runs sudo itself)
#   iso/build.sh --offline  the same with every package on the ISO, for installing
#                           without a network (several GB; too big for GitHub)
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
here=$PWD
repo=$(dirname "$here")

[ "$EUID" -eq 0 ] || exec sudo "$0" "$@"

offline=no
[ "${1:-}" = --offline ] && offline=yes
name=yunagi
[ "$offline" = yes ] && name=yunagi-offline

work=$here/work
out=$here/out
prof=$work/profile

# Always start clean: mkarchiso skips steps it finds already done in an old work dir
rm -rf "$work"
mkdir -p "$work" "$out"
rm -f "$out/$name"-2*.iso
# No inherited ACLs from the checkout (squashfs cannot store them)
setfacl -R -b -k "$work"
cp -r /usr/share/archiso/configs/releng "$prof"

# Yunagi files and the Yunagi repo itself
cp -r airootfs/. "$prof/airootfs/"
mkdir -p "$prof/airootfs/usr/share/yunagi"
git -c safe.directory='*' -C "$repo" archive HEAD | tar -x -C "$prof/airootfs/usr/share/yunagi"

# Packages tool, built here so installing needs neither Rust nor the network
cargo_user=${SUDO_USER:-root}
sudo -u "$cargo_user" -H cargo build --release --manifest-path "$repo/yunagi-pkg/Cargo.toml" --target-dir "$repo/yunagi-pkg/target"
install -Dm755 "$repo/yunagi-pkg/target/release/yunagi-pkg" "$prof/airootfs/usr/share/yunagi/yunagi-pkg/yunagi-pkg"

# Offline: a local repository with everything archinstall and install.sh install,
# dependencies included (an empty package database makes pacman fetch them all)
if [ "$offline" = yes ]; then
    pkgrepo=$prof/airootfs/opt/yunagi/repo
    mkdir -p "$pkgrepo" "$work/pkgdb"
    mapfile -t pkgs < <(grep -hv -e '^#' -e '^$' "$repo"/packages*.txt "$repo"/apps.txt)
    pkgs+=(base sudo linux linux-firmware mkinitcpio intel-ucode amd-ucode zram-generator
           networkmanager network-manager-applet limine efibootmgr cryptsetup btrfs-progs
           e2fsprogs dosfstools pipewire pipewire-alsa pipewire-jack pipewire-pulse
           gst-plugin-pipewire libpulse wireplumber sof-firmware alsa-firmware)
    pacman -Sy --dbpath "$work/pkgdb" --noconfirm
    pacman -Sw --dbpath "$work/pkgdb" --cachedir "$pkgrepo" --noconfirm "${pkgs[@]}"
    repo-add -q "$pkgrepo/yunagi.db.tar.zst" "$pkgrepo"/*.pkg.tar.zst
    # The installer points core and extra at this one repository
    for r in core extra; do ln -sf yunagi.db.tar.zst "$pkgrepo/$r.db"; done
fi

# Installer: gum for the dialogs, started by itself on tty1
echo gum >>"$prof/packages.x86_64"
printf '\n[ "$(tty)" = /dev/tty1 ] && yunagi-install\n' >>"$prof/airootfs/root/.zlogin"


# Name and boot menu
sed -i \
    -e "s|^iso_name=.*|iso_name=\"$name\"|" \
    -e 's|^iso_label=.*|iso_label="YUNAGI_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"|' \
    -e 's|^iso_publisher=.*|iso_publisher="techbob <https://github.com/tech-bob/yunagi>"|' \
    -e 's|^iso_application=.*|iso_application="Yunagi install medium"|' \
    -e 's|^file_permissions=(|file_permissions=(\n  ["/usr/local/bin/yunagi-install"]="0:0:755"\n  ["/usr/share/yunagi/home/.local/bin/"]="0:0:755"\n  ["/usr/share/yunagi/install.sh"]="0:0:755"\n  ["/usr/share/yunagi/yunagi-pkg/yunagi-pkg"]="0:0:755"|' \
    "$prof/profiledef.sh"
# No kernel or systemd text between the boot menu and the installer
# copytoram=n: run from the stick instead of copying the whole image to RAM first
echo 'kernel_params_x86_64="copytoram=n quiet loglevel=0 rd.udev.log_level=0 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0"' >>"$prof/profiledef.sh"
# Boot menus: archiso's own, with the name changed
grep -rl "Arch Linux" "$prof/efiboot" "$prof/syslinux" "$prof/grub" | xargs sed -i 's/Arch Linux/Yunagi/g'

mkarchiso -v -r -w "$work/build" -o "$out" "$prof"

[ -n "${SUDO_USER:-}" ] && chown -R "$SUDO_USER:" "$out"
ls -lh "$out"
