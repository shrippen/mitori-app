#!/usr/bin/env bash
# Copies the Breeze icons the app uses into app/icons/breeze-mitori, a small icon theme in the
# resources (:/icons). Android, the AppImage and tests have no system icon theme; Plasma keeps its own.
# Kante draws icons as masks in its ink, so one set serves light and dark.
# Add a name to ICONS when a page uses a new icon, then run this script (needs breeze-icons).
set -euo pipefail
cd "$(dirname "$0")/.."

# The app's icon.name values, the pause state of the player, and what Kirigami itself shows
# (back, menus, dialog close, search, overflow).
ICONS="configure data-error documentinfo go-next go-previous go-previous-view media-playback-pause
media-playback-start media-playlist-repeat media-skip-backward media-skip-forward media-seek-backward media-seek-forward view-list-details
application-menu dialog-close edit-clear go-up go-down open-menu-symbolic overflow-menu list-add edit-delete document-save view-pim-notes
overflow-menu-left overflow-menu-right search arrow-left arrow-right window-close window-close-symbolic dialog-cancel
view-calendar internet-services view-refresh camera-photo audio-input-microphone insert-image media-record
media-playback-stop document-export document-share document-open dialog-warning document-edit view-fullscreen view-restore
audio-volume-high audio-volume-muted brightness-high view-barcode-qr media-view-subtitles-symbolic"

SRC="${BREEZE:-/usr/share/icons/breeze}"
OUT=app/icons/breeze-mitori
rm -rf "$OUT"
dirs=()
for name in $ICONS; do
    file=""
    for size in 22 24 16 32; do
        file=$(find -L "$SRC" -path "*/$size/$name.svg" | sort | head -1)
        [ -z "$file" ] || break
    done
    [ -n "$file" ] || { echo "sync-icons: $name not in $SRC" >&2; exit 1; }
    rel="${file#"$SRC"/}"
    mkdir -p "$OUT/$(dirname "$rel")"
    cp -L "$file" "$OUT/$rel"
    dirs+=("$(dirname "$rel")")
done
mapfile -t dirs < <(printf '%s\n' "${dirs[@]}" | sort -u)
{
    echo "[Icon Theme]"
    echo "Name=Breeze (Mitori subset)"
    echo "Comment=The Breeze icons Mitori uses (scripts/sync-icons.sh), LGPL-3.0, from KDE's breeze-icons"
    echo "Directories=$(IFS=,; echo "${dirs[*]}")"
    for d in "${dirs[@]}"; do
        printf '\n[%s]\nSize=%s\nType=Scalable\nMinSize=8\nMaxSize=512\n' "$d" "${d##*/}"
    done
} > "$OUT/index.theme"
echo "sync-icons: $(find "$OUT" -name '*.svg' | wc -l) icons -> $OUT"
