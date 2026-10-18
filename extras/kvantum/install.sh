#!/usr/bin/env bash
# Mac-style menus for Plasma itself (global menu, right-click and tray menus):
# builds the MacGlass Kvantum theme and tells plasmashell to use Kvantum.
# Needs the kvantum package (Fedora: sudo dnf install kvantum).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
python3 -I "$here/make_kvantum.py" "$config/Kvantum/MacGlass"
mkdir -p "$config/Kvantum" "$config/systemd/user/plasma-plasmashell.service.d"
kv="$config/Kvantum/kvantum.kvconfig"
if [ -f "$kv" ] && grep -q '^theme=' "$kv"; then
    sed -i 's/^theme=.*/theme=MacGlass/' "$kv"
else
    printf '[General]\ntheme=MacGlass\n' >> "$kv"
fi
cp "$here/kvantum-menus.conf" "$config/systemd/user/plasma-plasmashell.service.d/"
systemctl --user daemon-reload
systemctl --user restart plasma-plasmashell.service
echo "Plasma's menus now use MacGlass. To undo: delete $config/systemd/user/plasma-plasmashell.service.d/kvantum-menus.conf and restart plasmashell."
