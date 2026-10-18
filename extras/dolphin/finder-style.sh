#!/usr/bin/env bash
# Finder-style Dolphin: back/forward, breadcrumb location, view buttons and
# search in the toolbar; smaller sidebar icons. Close Dolphin first (it saves
# its settings on exit). Its menus go to the top bar via the global menu.
set -euo pipefail
if pgrep -x dolphin >/dev/null; then
    echo "Close Dolphin first." >&2
    exit 1
fi
rc=${XDG_DATA_HOME:-$HOME/.local/share}/kxmlgui5/dolphin/dolphinui.rc
if [ -f "$rc" ]; then
    cp "$rc" "$rc.before-finder-style"
    python3 -I - "$rc" <<'PY'
import re, sys
path = sys.argv[1]
s = open(path).read()
actions = ''.join(f'  <Action name="{a}"/>\n' for a in
                  ('go_back', 'go_forward', 'url_navigators', 'icons', 'compact', 'details', 'toggle_search'))
s = re.sub(r'(<ToolBar[^>]*name="mainToolBar"[^>]*>\s*<text[^<]*</text>\n)(.*?)( </ToolBar>)',
           lambda m: m.group(1) + actions + m.group(3), s, count=1, flags=re.S)
open(path, 'w').write(s)
PY
else
    echo "No customised toolbar yet: open Dolphin once, close it, and run this again." >&2
fi
kwriteconfig6 --file dolphinrc --group General --key EditableUrl false
kwriteconfig6 --file dolphinrc --group PlacesPanel --key IconSize 16
echo "Done. Open Dolphin to see it."
