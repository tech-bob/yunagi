#!/usr/bin/env bash
# yunagi — installs packages and puts the config in the user's home
#
#   ./install.sh                        as the user, asks for sudo
#   install.sh --user NAME [--desktop yunagi|gnome|minimal] [--apps] [--keyboard LAYOUT]
#                                       as root, e.g. in arch-chroot from the ISO
#   install.sh --config-only [--user NAME]
#                                       only the config in the home, no packages or sudo
#                                       (as root for another account, e.g. the AI account)
#
# yunagi: Hyprland with the Yunagi shell and SDDM. gnome: GNOME with GDM.
# minimal: no desktop, only the network. yunagi and gnome share packages-common.txt.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
repo=$PWD

user=$USER
apps=ask
keyboard=
desktop=
config_only=no
while [ $# -gt 0 ]; do
    case $1 in
        --user) user=$2; shift ;;
        --apps) apps=yes ;;
        --no-apps) apps=no ;;
        --keyboard) keyboard=$2; shift ;;
        --desktop) desktop=$2; shift ;;
        --config-only) config_only=yes ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
home=$(getent passwd "$user" | cut -d: -f6)

if [ "$EUID" -eq 0 ]; then
    chroot=yes
    as_root() { "$@"; }
    as_user() { runuser -u "$user" -- env HOME="$home" "$@"; }
    [ "$apps" = ask ] && apps=no
else
    chroot=no
    as_root() { sudo "$@"; }
    as_user() { "$@"; }
fi

if [ -z "$desktop" ]; then
    if [ "$chroot" = yes ] || [ "$config_only" = yes ]; then
        desktop=yunagi
    else
        read -rp "Desktop: yunagi, gnome or minimal? [yunagi] " desktop
        desktop=${desktop:-yunagi}
    fi
fi
case $desktop in yunagi|gnome|minimal) ;; *) echo "unknown desktop: $desktop" >&2; exit 1 ;; esac

pkgs() { grep -hv -e '^#' -e '^$' "$@" | as_root pacman -S --needed --noconfirm -; }
svc_enable() { if [ "$chroot" = yes ]; then systemctl enable "$@"; else sudo systemctl enable --now "$@"; fi; }

# Every desktop gets the firewall: nftables, incoming dropped except replies,
# loopback and ping; outgoing open. An existing ruleset of your own is kept.
firewall() {
    # Replaces Arch's file or ours; a file edited by hand (pacman -Qkk flags it) stays
    local f=/etc/nftables.conf
    if [ ! -f $f ] || grep -q 'Yunagi firewall' $f || ! pacman -Qkk nftables 2>&1 | grep -q " $f "; then
        as_root install -Dm644 default/nftables.conf $f
    fi
}

if [ "$config_only" = no ]; then

# --- Minimal: only the network and the firewall ---------------------------------

if [ "$desktop" = minimal ]; then
    as_root pacman -S --needed --noconfirm networkmanager nftables
    firewall
    svc_enable NetworkManager nftables
    echo "Done. Minimal install: no desktop, NetworkManager and the firewall are on."
    exit 0
fi

# --- System -----------------------------------------------------------------

if [ "$apps" = ask ]; then
    read -rp "Also install the programs in apps.txt? [y/N] " answer
    [[ $answer == [yY]* ]] && apps=yes || apps=no
fi
# One pacman run, so its hooks (font and icon caches) run once
lists=(packages-common.txt)
if [ "$desktop" = yunagi ]; then lists+=(packages.txt); else lists+=(packages-gnome.txt); fi
[ "$apps" = yes ] && lists+=(apps.txt)
pkgs "${lists[@]}"

# Boot: Ion for existing Limine installs (Limine menu and Plymouth splash).
as_root python3 boot/configure.py

firewall
svc_enable NetworkManager bluetooth power-profiles-daemon nftables

# The SSH agent (gcr-ssh-agent) is off until you turn it on: System → SSH in the menu
# Packages tool (yunagi-pkg): prebuilt on the ISO, otherwise built from source;
# Rust stays only if it was already installed
if [ -x yunagi-pkg/yunagi-pkg ]; then
    as_root install -Dm755 yunagi-pkg/yunagi-pkg /usr/local/bin/yunagi-pkg
else
    had_rust=$(pacman -Q rust 2>/dev/null || true)
    as_root pacman -S --needed --noconfirm rust
    build=$(mktemp -d)
    as_root env CARGO_HOME="$build/cargo" cargo build --release --manifest-path yunagi-pkg/Cargo.toml --target-dir "$build/target"
    as_root install -Dm755 "$build/target/release/yunagi-pkg" /usr/local/bin/yunagi-pkg
    as_root rm -rf "$build"
    [ -n "$had_rust" ] || as_root pacman -Rns --noconfirm rust
fi
as_root install -Dm644 yunagi-pkg/yunagi-pkg.desktop /usr/share/applications/yunagi-pkg.desktop
# AI page and usage (root runs yunagi-ai through pkexec, so it lives where only root writes)
as_root install -Dm755 -t /usr/local/bin bin/yunagi-ai bin/yunagi-ai-usage

if [ "$desktop" = yunagi ]; then
    # Login: SDDM with the Yunagi theme, active from the next boot
    as_root rm -rf /usr/share/sddm/themes/yunagi
    as_root cp -r sddm/yunagi /usr/share/sddm/themes/yunagi
    as_root install -Dm644 sddm/sddm.conf.d/yunagi.conf /etc/sddm.conf.d/yunagi.conf
    as_root systemctl enable sddm
else
    # Login: GDM; GNOME defaults (look, keys) for every user through dconf
    as_root systemctl enable gdm
    as_root install -Dm644 -t /usr/share/backgrounds/yunagi home/Pictures/wallpapers/*.jpg
    printf 'user-db:user\nsystem-db:local\n' | as_root install -Dm644 /dev/stdin /etc/dconf/profile/user
    as_root install -Dm644 default/gnome/00-yunagi /etc/dconf/db/local.d/00-yunagi
    if [ -n "$keyboard" ]; then
        printf "[org/gnome/desktop/input-sources]\nsources=[('xkb', '%s')]\n" "$keyboard" |
            as_root install -Dm644 /dev/stdin /etc/dconf/db/local.d/01-keyboard
    fi
    as_root dconf update
fi

# Encrypted root: the disk password already proved who you are, so log in automatically
root_src=$(findmnt -no SOURCE / | sed 's/\[.*//')
if [ "$(lsblk -no TYPE "$root_src" 2>/dev/null)" = crypt ]; then
    if [ "$desktop" = yunagi ]; then
        printf '[Autologin]\nUser=%s\nSession=hyprland.desktop\n' "$user" |
            as_root install -Dm644 /dev/stdin /etc/sddm.conf.d/autologin.conf
    else
        printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=%s\n' "$user" |
            as_root install -Dm644 /dev/stdin /etc/gdm/custom.conf
    fi
fi

# Keyboard layout for the login screen (X11 config, read by SDDM and GDM)
if [ -n "$keyboard" ]; then
    printf 'Section "InputClass"\n    Identifier "keyboard"\n    MatchIsKeyboard "on"\n    Option "XkbLayout" "%s"\nEndSection\n' "$keyboard" |
        as_root install -Dm644 /dev/stdin /etc/X11/xorg.conf.d/00-keyboard.conf
fi

fi # config_only

# fish as the shell; config-only too when run as root (the AI account)
if [ "$config_only" = no ] || [ "$EUID" -eq 0 ]; then
    [ "$(getent passwd "$user" | cut -d: -f7)" = /usr/bin/fish ] || as_root chsh -s /usr/bin/fish "$user"
fi

# --- User -------------------------------------------------------------------

# Yunagi lives in ~/.local/share/yunagi; the files in ~/.config are the user's own copies
share="$home/.local/share/yunagi"
if [ "$repo" != "$share" ]; then
    as_user mkdir -p "$(dirname "$share")"
    as_user rm -rf "$share"
    if [ "$EUID" -eq 0 ]; then
        # The repo may sit in another home the user cannot read
        cp -a "$repo" "$share"
        chown -R "$user:" "$share"
    else
        cp -a "$repo" "$share"
    fi
fi

# Copy the config into the home directory; existing files that differ are backed up
backup="$home/.yunagi-backup-$(date +%F-%H%M%S)"
while IFS= read -r -d '' f; do
    rel=${f#home/}
    dst="$home/$rel"
    # Links from older installs that used stow
    p=$dst
    while [ "$p" != "$home" ]; do
        if [ -L "$p" ] && [[ $(readlink "$p") == *yunagi/home/* ]]; then as_user rm "$p"; fi
        p=$(dirname "$p")
    done
    if [ -e "$dst" ] && ! cmp -s "$f" "$dst"; then
        as_user mkdir -p "$backup/$(dirname "$rel")"
        as_user mv "$dst" "$backup/$rel"
    fi
    as_user install -D -m "$(stat -c %a "$f")" "$f" "$dst"
done < <(if [ "$desktop" = yunagi ]; then find home -type f -print0
         else find home/.vimrc home/.config/kitty home/.config/fish home/.config/nvim home/Pictures -type f -print0; fi)
[ -d "$backup" ] && echo "Old files moved to $backup"

if [ "$desktop" = gnome ]; then
    echo "Done. Reboot to log in to GNOME."
    exit 0
fi

# Quickshell (bar and menus) runs from Yunagi's copy, so updates reach it; copies in
# ~/.config/quickshell from older installs are moved to the backup
qs="$home/.config/quickshell"
if [ -d "$qs" ] && [ ! -L "$qs" ]; then
    as_user mkdir -p "$backup/.config"
    as_user mv "$qs" "$backup/.config/quickshell"
    echo "Old Quickshell files moved to $backup/.config/quickshell"
fi
as_user ln -sfn "$share/default/quickshell" "$qs"
as_user mkdir -p "$home/.local/state/yunagi"

# The scripts are links into Yunagi's copy as well (yunagi-ai and its usage timer are in
# /usr/local/bin, where the AI account reaches them); older copies go to the backup
as_user mkdir -p "$home/.local/bin"
for f in "$share"/bin/yunagi-*; do
    n=${f##*/}
    case $n in yunagi-ai|yunagi-ai-usage) continue ;; esac
    dst="$home/.local/bin/$n"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        as_user mkdir -p "$backup/.local/bin"
        as_user mv "$dst" "$backup/.local/bin/$n"
    fi
    as_user ln -sfn "$f" "$dst"
done

# Keyboard layout for Hyprland, in settings.lua where the settings menu changes it
if [ -n "$keyboard" ] && [ ! -e "$home/.config/hypr/settings.lua" ]; then
    as_user "$home/.local/bin/yunagi-settings" set kb_layout "$keyboard" >/dev/null
fi

as_user matugen image "$home/Pictures/wallpapers/jonatan-pie-h8nxGssjQXs-unsplash.jpg" \
    -m dark -t scheme-vibrant --source-color-index 0

gs="gsettings"
[ "$chroot" = yes ] && gs="dbus-run-session gsettings"
as_user $gs set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
as_user $gs set org.gnome.desktop.interface color-scheme prefer-dark
as_user $gs set org.gnome.desktop.interface icon-theme Papirus-Dark

[ "$config_only" = yes ] && echo "Done." || echo "Done. Reboot to log in to Yunagi."
