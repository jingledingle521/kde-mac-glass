#!/usr/bin/env bash
# Remove everything install.sh put in place. Switch to another Global Theme
# (System Settings → Colors & Themes) first so you aren't left without panels.
set -euo pipefail

data=${XDG_DATA_HOME:-$HOME/.local/share}
config=${XDG_CONFIG_HOME:-$HOME/.config}

rm -rf "$data/plasma/desktoptheme/MacGlass" \
       "$data/plasma/look-and-feel/org.brhett.macglass" \
       "$data/aurorae/themes/MacSequoia-Dark" \
       "$data/wallpapers/GoldenGate" \
       "$data/fonts/MacGlass" \
       "$data/plasma/shells/org.brhett.goldengate" \
       "$HOME/.local/opt/finder" \
       "${XDG_CACHE_HOME:-$HOME/.cache}/mac-glass-kde/finder-src" \
       "$data"/plasma/plasmoids/org.brhett.{activeapp,applemenu,menubar,controlcenter,macbattery,macclipboard,macdock,macnotifications,macnowplaying,macsound,macwifi}
rm -f "$config/systemd/user/plasma-kwin_wayland.service.d/goldengate-lockscreen.conf" \
      "$config/systemd/user/plasma-plasmashell.service.d/small-tray-icons.conf" \
      "$HOME/.local/bin/patch-tray-icons" \
      "$data/applications/org.brhett.finder.desktop" \
      "$HOME/.local/bin/vivaldi-menu-bridge" \
      "$config/systemd/user/vivaldi-menu-bridge.service" \
      "$HOME/.local/lib64/qt6/plugins/plasma/applets/org.kde.plasma.systemtray.so" \
      "$HOME/.local/lib64/qt6/plugins/plasma/applets/org.kde.plasma.systemtray.so.source-sha256" \
      "$config/systemd/user/plasma-plasmashell.service.d/macdock-qml.conf" \
      "$config/environment.d/61-macdock-qml.conf" \
      "$HOME/.local/lib64/qt6/plugins/styles/libmacglass.so"
rm -rf "$HOME/.local/lib64/qt6/qml/org/brhett/macdock"
# MacGlass menu style: back to Breeze.
if [ "$(kreadconfig6 --group KDE --key widgetStyle 2>/dev/null)" = MacGlass ]; then
    kwriteconfig6 --group KDE --key widgetStyle Breeze
fi
# Finder's file chooser: hand Open/Save dialogs back to KDE.
rm -f "$data/dbus-1/services/org.freedesktop.impl.portal.desktop.finder.service"
sed -i '/^org.freedesktop.impl.portal.FileChooser=finder/d' "$config/xdg-desktop-portal/kde-portals.conf" 2>/dev/null || true
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
systemctl --user daemon-reload || true
fc-cache -f >/dev/null 2>&1 || true
echo "Mac Glass removed. Log out and back in to finish."
