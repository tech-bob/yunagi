# Packages (`yunagi-pkg`)

Terminal UI for searching, installing and removing software on Yunagi.
Official Arch repos only by default; the AUR is opt-in.

Source: [`yunagi-pkg/`](yunagi-pkg/) (Rust, [ratatui](https://crates.io/crates/ratatui)).
Desktop entry name: **Packages** (`yunagi-pkg/yunagi-pkg.desktop`).

## Launch

```
yunagi-pkg
```

Or: Settings menu → **Packages** (`Super+Ctrl+Space`), or the **Packages** app
entry (opens in kitty). There are **no CLI flags or subcommands**; the binary is
a full-screen TUI.

Install path after `install.sh` / ISO install: `/usr/local/bin/yunagi-pkg`,
desktop file at `/usr/share/applications/yunagi-pkg.desktop`.

## Tabs

| Tab | How to open | Contents |
|---|---|---|
| **Installed** | `1`, or `Tab` | Explicitly installed packages (`pacman -Qe`) |
| **Search** | `2`, `Tab`, or `/` | Search results from `pacman -Ss` (and `paru -Ss --aur` when AUR is on) |

The header shows **AUR on** (magenta) or **AUR off**. Package details for the
selected row appear in the right panel (`pacman -Qi` / `pacman -Si` /
`paru -Si --aur`), fetched after the cursor rests briefly.

## Keys

| Key | Action |
|---|---|
| `/` | Switch to Search and start typing a query |
| `Enter` | Run the search (while typing) |
| `Esc` | Cancel typing, or quit when not typing |
| `i` | Install the selected package if it is not installed |
| `r` | Remove the selected installed package (`pacman -Rns`) |
| `u` | Update all packages with pacman |
| `p` | Update all packages with paru, AUR included (only when paru is installed) |
| `Tab` | Toggle Installed ↔ Search |
| `1` | Installed tab |
| `2` | Search tab |
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `a` | Enable AUR (only shown / active when AUR is off) |
| `q` | Quit |
| `Ctrl+C` | Quit |

Footer hints mirror these: `/` search, `i` install, `r` remove, `u` update,
`p` update with paru when available, `tab` switch, `q` quit, and `a` enable AUR
when needed.

## Install, remove and update behaviour

When you press `i`, `r`, `u` or `p`, the TUI exits to the plain terminal so sudo / pacman /
paru can prompt normally, then waits for Enter before restoring the UI.

- **Official package:** `sudo pacman -S <name>`
- **AUR package:** `paru -S <name>` (Search tab only, when AUR is on)
- **Remove:** `sudo pacman -Rns <name>`
- **Update all, official repos:** `sudo pacman -Syu`
- **Update all, official repos and AUR:** `paru -Syu`

After success or failure the installed list (and the current search, if any) is
refreshed.

## Enabling the AUR

Press `a` when AUR is off. That runs (as a shell one-liner):

```
sudo pacman -S --needed base-devel git &&
  d=$(mktemp -d) &&
  git clone https://aur.archlinux.org/paru-bin.git "$d" &&
  cd "$d" && makepkg -si
```

If `paru` is then on `PATH`, the header shows **AUR on** and later searches
include AUR results. Status text: `AUR enabled` or `AUR not enabled`.

## Search ranking

Results are sorted so exact name matches come first, then prefix matches, then
substring matches on the name, then description-only hits. Official-repo hits
are preferred over AUR at the same rank.

## Building from source

Needs Rust (`rust` package on Arch). From the repo root:

```
cargo build --release --manifest-path yunagi-pkg/Cargo.toml
```

Binary: `yunagi-pkg/target/release/yunagi-pkg`.

`install.sh` builds this automatically when no prebuilt
`yunagi-pkg/yunagi-pkg` binary is present (as on the ISO tree). `iso/build.sh`
always builds a release binary into the ISO under
`/usr/share/yunagi/yunagi-pkg/yunagi-pkg` so the installed system does not need
Rust.

## Examples

1. **Find and install `ripgrep` (official):**
   - Open Packages → press `/` → type `ripgrep` → Enter → select the row → `i`.
2. **Remove an explicitly installed package:**
   - On the Installed tab, select it → `r` → confirm in pacman → Enter to return.
3. **Enable AUR, then install an AUR package:**
   - Press `a`, finish the paru build → `/` search → select an `aur/...` row → `i`.

## What it does not do

- No CLI for scripting (`yunagi-pkg install foo` does not exist).
- No orphan cleanup or mirror management.
- Does not list every installed package dependency — only explicitly installed
  ones (`pacman -Qe`).
