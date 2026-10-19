#!/bin/sh
# Opens the user's calendar app: the default handler for calendar files, or,
# when that handler is a hidden helper (KOrganizer's "korganizer-view"), the
# visible app it belongs to. Exits 1 when there is no calendar app.

dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

find_entry() {
    IFS=:
    for d in $dirs; do
        [ -f "$d/applications/$1" ] && { echo "$d/applications/$1"; unset IFS; return 0; }
    done
    unset IFS
    return 1
}

entry=$(xdg-mime query default text/calendar)
[ -n "$entry" ] || entry=$(xdg-mime query default x-scheme-handler/webcal)
[ -n "$entry" ] || exit 1
path=$(find_entry "$entry") || exit 1

if grep -q '^NoDisplay=true' "$path"; then
    bin=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$path" | head -n 1)
    IFS=:
    for d in $dirs; do
        for f in "$d"/applications/*.desktop; do
            [ -f "$f" ] || continue
            if grep -q "^Exec=$bin\( \|$\)" "$f" && ! grep -q '^NoDisplay=true' "$f"; then
                entry=$(basename "$f")
                break 2
            fi
        done
    done
    unset IFS
fi

app=${entry%.desktop}
kstart --application "$app" >/dev/null 2>&1 || exec gtk-launch "$app"
