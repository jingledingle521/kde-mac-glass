#!/bin/bash
# Build and install the MacGlass widget style (Breeze with macOS menus) into
# ~/.local, make every app find it, and select it.
#   install.sh            build, install and turn it on
#   install.sh --off      go back to Breeze
set -e
here=$(cd "$(dirname "$0")" && pwd)

if [ "$1" = --off ]; then
    kwriteconfig6 --group KDE --key widgetStyle Breeze
    echo "Breeze restored; restart apps (and plasmashell) to see it."
    exit 0
fi

# Fedora: sudo dnf install cmake ninja-build gcc-c++ extra-cmake-modules qt6-qtbase-devel kf6-kwindowsystem-devel
cmake -S "$here" -B "$here/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
ninja -C "$here/build" install

mkdir -p "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/60-qt-plugins.conf" <<'CONF'
# Qt plugins installed in ~/.local (MacGlass menu style, patched tray) for every app.
QT_PLUGIN_PATH=${HOME}/.local/lib64/qt6/plugins
CONF
export QT_PLUGIN_PATH="$HOME/.local/lib64/qt6/plugins"
systemctl --user import-environment QT_PLUGIN_PATH || true
dbus-update-activation-environment --systemd QT_PLUGIN_PATH || true

kwriteconfig6 --group KDE --key widgetStyle MacGlass
# Plasma's own menus used the Kvantum MacGlass theme before; this replaces it.
dropin="$HOME/.config/systemd/user/plasma-plasmashell.service.d/kvantum-menus.conf"
[ -f "$dropin" ] && mv "$dropin" "$dropin.off" && systemctl --user daemon-reload
systemctl --user restart plasma-plasmashell || true
echo "MacGlass menus on. Restart running apps to pick them up."
