# Branding

Identity assets used by Yunagi. See `BRAND.md` for colours, type and the mark.

## The mark

`neon/diamant.svg` (the angular diamond spiral) is **the** Yunagi mark. Its
geometry is locked; colour is free. Boot art, SDDM and the lock screen all use it.

## Alternative marks

The other marks are not old concepts: they are optional extras. Users can pick
one for the bar in Settings → Look, and the screensaver draws them.

| Setting name | File |
|---|---|
| Diamond (default) | `neon/diamant.svg` |
| Labyrinth | `neon/labyrint.svg` |
| Crystal | `mark/kristall/` |
| Prism | `prisma-mark/mockup.svg` |
| Spiral | `spiral-mark/` |
| Octahedron, Brilliant | `wire/` |

Don't delete or rename these without updating `home/.local/bin/yunagi-screensaver`
and `home/.config/quickshell/Bar.qml` / `Settings.qml`.

## Other assets

- `fonts/Inter-Variable.ttf`: wordmark outlines for Limine and Plymouth (`boot/render.py`).

## Runtime themes

Limine and Plymouth in `../boot`, SDDM in `../sddm/yunagi`, the lock screen in
`../home/.config/hypr/hyprlock.conf`. Earlier concepts and previews are in the
git history.
