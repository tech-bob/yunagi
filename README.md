# Yunagi

A desktop for Arch Linux: Hyprland with a custom Quickshell shell. Packages come
only from Arch's official repositories; the AUR is opt-in through the Packages
tool (`yunagi-pkg`).

Version **0.6**. See [`TODO.md`](TODO.md) for the path toward 1.0.

## Installation

### From the ISO

Download the ISO from [Releases](https://github.com/tech-bob/yunagi/releases),
write it to a USB stick and boot from it; it runs just as well in a virtual
machine. To write it, copy it onto a [Ventoy](https://www.ventoy.net) stick, use
balenaEtcher, or:

```
sudo dd if=yunagi-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

The installer starts by itself. It asks for language, keyboard, time zone, user,
password, encryption, computer name, desktop and disk (erase the whole disk, use
free space or existing partitions), then installs Arch and Yunagi.

Disk encryption is chosen by default: the root is encrypted with LUKS2 using the
user's password, asked for at boot, and after that you are logged in
automatically. Without encryption the login screen asks for the password.

### Already on Arch

With a sudo user:

```
git clone https://github.com/tech-bob/yunagi
cd yunagi
./install.sh
```

It asks for a desktop: **yunagi** (Hyprland with the Yunagi shell), **gnome**
(GNOME with a lean set of apps) or **minimal** (only NetworkManager). Yunagi is
kept in `~/.local/share/yunagi`; the files in `~/.config` are ordinary copies that
you own, and conflicting files are moved to `~/.yunagi-backup-<date>`.

Optional flags (useful from the ISO chroot or scripts):

```
./install.sh --user NAME [--desktop yunagi|gnome|minimal] [--apps|--no-apps] [--keyboard LAYOUT]
```

- `--user` — install for this user (required when run as root)
- `--desktop` — skip the interactive desktop prompt
- `--apps` / `--no-apps` — install or skip the programs in `apps.txt`
- `--keyboard` — set the login-screen and desktop keyboard layout

## Keybindings

| Key | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+Space` | Launcher |
| `Super+Ctrl+Space` | Settings menu |
| `Super+E` | File manager |
| `Super+V` | Clipboard history |
| `Super+B` | System information |
| `Super+Y` | Packages |
| `Super+M` | Power menu |
| `Super+L` | Lock |
| `Super+T` | Night light |
| `Super+F` | Fullscreen |
| `Super+J` | Toggle half/full column width |
| `Super+C` | Close window |
| `Super+1–0` | Workspace (`+Shift` moves the window) |
| `Print` | Screenshot of a region |

## Settings

The settings menu (`Super+Ctrl+Space`) changes the screensaver, locking, night
light, keyboard, mouse and touchpad, and the git name and email. Config opens the
config files in nvim.

Your own Hyprland lines go in `~/.config/hypr/hyprland.lua`, below the line that
loads Yunagi's defaults; they win over the defaults.

## Packages

Settings menu → Packages, or **Packages** among the apps in GNOME. The tool is
the TUI binary `yunagi-pkg`; full usage in [`docs/packages.md`](docs/packages.md).

| Key | Action |
|---|---|
| `/` | Search |
| `i` / `r` | Install / remove |
| `Tab` | Switch between Installed and Search |
| `1` / `2` | Jump to Installed / Search |
| `j` / `k` | Move down / up |
| `a` | Enable the AUR (builds paru) |
| `q` | Quit |

On a normal `install.sh` run the binary is built from `yunagi-pkg/` (Rust is
installed only for the build if it was not already present). On the ISO the
binary is prebuilt, so neither Rust nor the network is needed at install time.

## Boot look

The ISO installs Limine with the **Ion** theme and a Plymouth splash;
`install.sh` applies the same theme where Limine is already in use. Details and a live Plymouth preview live in
[`boot/README.md`](boot/README.md). Visual identity (mark, palette, wordmark) is
documented in [`branding/BRAND.md`](branding/BRAND.md); the locked mark is
`branding/neon/diamant.svg`.

## Keyring and SSH

With automatic login, the first app that needs gnome-keyring asks for a password
for a new keyring: leave it empty and it stays unlocked from then on.

The SSH agent is gcr-ssh-agent. Add keys with `ssh-add`, or `AddKeysToAgent yes`
in `~/.ssh/config`.

## Firewall

nftables is on from the start: incoming connections are dropped except replies
and ping, SSH included; outgoing traffic is open. Settings menu →
System → Config → Firewall opens `/etc/nftables.conf` and reloads it after
saving. To open a port, add a line to the `input` chain:

```
tcp dport 53317 accept
```

## Wallpaper and profile picture

Put the image in `~/Pictures/wallpapers`, point to it in
`~/.config/hypr/hyprpaper.conf` and generate the colours:

```
matugen image <image> -m dark -t scheme-vibrant --source-color-index 0
```

The login screen shows `/usr/share/sddm/faces/<user>.face.icon`:

```
sudo cp picture.png /usr/share/sddm/faces/$USER.face.icon
```

## Building the ISO

On Arch with `archiso` installed (needs root, about 10 GB free):

```
iso/build.sh
```

The ISO ends up in `iso/out/`. `iso/build.sh --offline` builds
`yunagi-offline-*.iso` with every package on it, for machines without a network
(several GB, so it is not on Releases).

## License

MIT, see `LICENSE`.

## Credits

Wallpapers from Unsplash: Jonatan Pie, Randy Tarampi.
