#!/usr/bin/env bash
# Shared media in /home/delat, run as root by install.sh and yunagi-update:
#   shared-media.sh USER...
# The group delat, /home/delat/yunagi/media/{backgrounds,pictures,videos} and
# /home/delat/screenshots, Yunagi's backgrounds in backgrounds, and for each USER:
# membership in delat and ~/Pictures/wallpapers as a link to backgrounds. Pictures
# already in ~/Pictures/wallpapers are moved there; a name that clashes with a
# different picture keeps the old folder as ~/Pictures/wallpapers.old-DATE.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

media=/home/delat/yunagi/media
groupadd -f delat
for d in /home/delat /home/delat/yunagi "$media" "$media/backgrounds" "$media/pictures" \
         "$media/videos" /home/delat/screenshots; do
    [ -d "$d" ] || install -d -m 2775 -o root -g delat "$d"
done
for f in home/Pictures/wallpapers/*; do
    [ -e "$media/backgrounds/${f##*/}" ] || install -m 664 -g delat "$f" "$media/backgrounds/"
done

for u in "$@"; do
    id "$u" &>/dev/null || continue
    id -nG "$u" | grep -qw delat || usermod -aG delat "$u"
    home=$(getent passwd "$u" | cut -d: -f6)
    w=$home/Pictures/wallpapers
    [ -L "$w" ] && continue
    if [ -d "$w" ]; then
        keep=no
        for f in "$w"/*; do
            [ -f "$f" ] || { [ -e "$f" ] && keep=yes; continue; }
            dst=$media/backgrounds/${f##*/}
            if [ ! -e "$dst" ]; then install -m 664 -g delat "$f" "$dst"
            elif ! cmp -s "$f" "$dst"; then keep=yes; fi
        done
        if [ "$keep" = yes ]; then mv "$w" "$w.old-$(date +%F-%H%M%S)"; else rm -rf "$w"; fi
    fi
    runuser -u "$u" -- mkdir -p "$home/Pictures"
    runuser -u "$u" -- ln -s "$media/backgrounds" "$w"
done
