#!/usr/bin/env bash
# Install the Mac Glass pack for KDE Plasma 6 into the current user's home.
#
#   ./install.sh               install everything (changes nothing on screen)
#   ./install.sh --apply       ...and switch to it, replacing your panels
#   ./install.sh --icons       ...and download WhiteSur icons + cursors if missing
#   ./install.sh --lockscreen  ...and use the Golden Gate lock screen (re-login)
#   ./install.sh --tray-patch  ...and build the patched system tray (16px icons)
#   ./install.sh --menus       ...and draw every app's menus like macOS (builds the
#                              MacGlass widget style: Breeze with Mac menus)
#   ./install.sh --finder      ...and build Finder, a Golden Gate Finder made
#                              from Dolphin (needs build tools; ~10 minutes)
#   ./install.sh --airdrop     ...and set up AirDrop for Finder (omdrop-owl +
#                              omdrop; Fedora; Wi-Fi drops while it's on)
#
# Options can be combined. Run ./uninstall.sh to remove.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
config=${XDG_CONFIG_HOME:-$HOME/.config}

apply=0 icons=0 lockscreen=0 traypatch=0 menus=0 finder=0 airdrop=0
for arg in "$@"; do
    case $arg in
        --apply) apply=1 ;;
        --icons) icons=1 ;;
        --lockscreen) lockscreen=1 ;;
        --tray-patch) traypatch=1 ;;
        --menus) menus=1 ;;
        --finder) finder=1 ;;
        --airdrop) airdrop=1 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# Copy a directory into place, replacing an older copy of the same thing.
put() {
    mkdir -p "$2"
    rm -rf "$2/$(basename "$1")"
    cp -a "$1" "$2/"
}

echo "Installing Plasma style, widgets and global theme…"
put "$here/plasma/desktoptheme/MacGlass" "$data/plasma/desktoptheme"
for widget in "$here"/plasma/plasmoids/*; do
    put "$widget" "$data/plasma/plasmoids"
done
put "$here/plasma/look-and-feel/org.brhett.macglass" "$data/plasma/look-and-feel"
put "$here/aurorae/MacSequoia-Dark" "$data/aurorae/themes"
put "$here/wallpapers/GoldenGate" "$data/wallpapers"
mkdir -p "$data/fonts/MacGlass"
cp "$here"/fonts/* "$data/fonts/MacGlass/"
fc-cache -f "$data/fonts" >/dev/null 2>&1 || true
# Drop stale cached copies of the style.
rm -rf "$HOME"/.cache/plasma_theme_MacGlass*.kcache "$HOME/.cache/ksvg-elements"

# The dock is its own window; this helper gives it KWin blur behind the glass
# and lets clicks through the rest. Needs build tools (see its install.sh).
echo "Building the dock's window helper…"
"$here/extras/dock-helper/install.sh" || echo "  Dock helper build failed: install the build tools listed in extras/dock-helper/install.sh and run it again."

# Snappier popup fades (stock KWin: 150 ms in, 600 ms out).
mkdir -p "$data/kwin-wayland/effects"
put "$here/extras/kwin-effects/fadingpopups" "$data/kwin-wayland/effects"

# The Menu Bar widget reads apps' menus through this helper service.
mkdir -p "$HOME/.local/bin" "$config/systemd/user"
install -m 755 "$here/extras/vivaldi-menu/vivaldi-menu-bridge" "$HOME/.local/bin/vivaldi-menu-bridge"
cp "$here/extras/vivaldi-menu/vivaldi-menu-bridge.service" "$config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now vivaldi-menu-bridge.service >/dev/null 2>&1 || true

if [ $icons = 1 ]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    if [ ! -d "$data/icons/WhiteSur-dark" ]; then
        echo "Downloading WhiteSur icons…"
        git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$tmp/icons"
        (cd "$tmp/icons" && ./install.sh -d "$data/icons")
    fi
    if [ ! -d "$data/icons/WhiteSur-cursors" ] && [ ! -d "$HOME/.icons/WhiteSur-cursors" ]; then
        echo "Downloading WhiteSur cursors…"
        git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git "$tmp/cursors"
        mkdir -p "$data/icons"
        cp -a "$tmp/cursors/dist" "$data/icons/WhiteSur-cursors"
    fi
fi

if [ $lockscreen = 1 ]; then
    echo "Installing Golden Gate lock screen…"
    put "$here/extras/lockscreen/org.brhett.goldengate" "$data/plasma/shells"
    mkdir -p "$config/systemd/user/plasma-kwin_wayland.service.d"
    cp "$here/extras/lockscreen/goldengate-lockscreen.conf" "$config/systemd/user/plasma-kwin_wayland.service.d/"
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
        --key Image "file://$data/wallpapers/GoldenGate/golden-hour.jpg"
    systemctl --user daemon-reload
    echo "  The lock screen takes effect after you log out and back in."
fi

if [ $traypatch = 1 ]; then
    if [ -f /usr/lib64/qt6/plugins/plasma/applets/org.kde.plasma.systemtray.so ]; then
        echo "Building patched system tray…"
        mkdir -p "$HOME/.local/bin" "$config/systemd/user/plasma-plasmashell.service.d"
        cp "$here/extras/tray-patch/patch-tray-icons" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/patch-tray-icons"
        cp "$here/extras/tray-patch/small-tray-icons.conf" "$config/systemd/user/plasma-plasmashell.service.d/"
        "$HOME/.local/bin/patch-tray-icons"
        systemctl --user daemon-reload
    else
        echo "  Skipping tray patch: it expects Qt plugins in /usr/lib64 (Fedora/openSUSE layout)."
    fi
fi

if [ $menus = 1 ]; then
    echo "Building the MacGlass menu style…"
    "$here/extras/menu-style/install.sh" || echo "  Menu style build failed; run extras/menu-style/install.sh again to see why."
fi

if [ $finder = 1 ]; then
    echo "Building Finder (this takes a while)…"
    "$here/extras/finder/build-finder" || echo "  Finder build failed; run extras/finder/build-finder --deps to install build tools."
fi

if [ $airdrop = 1 ]; then
    echo "Setting up AirDrop…"
    "$here/extras/finder/install-airdrop" || echo "  AirDrop setup failed; run extras/finder/install-airdrop again to see why."
fi

if [ $apply = 1 ]; then
    backup="$config/plasma-org.kde.plasma.desktop-appletsrc.before-macglass"
    cp "$config/plasma-org.kde.plasma.desktop-appletsrc" "$backup" 2>/dev/null || true
    echo "Applying Mac Glass (your old panel layout is saved as $backup)…"
    plasma-apply-lookandfeel --apply org.brhett.macglass --resetLayout
    # Match KWin's blur strength to the saved glass level.
    python3 -I "$data/plasma/desktoptheme/MacGlass/glass/glass.py" blur "$(cat "$data/plasma/desktoptheme/MacGlass/glass/level" 2>/dev/null || echo 40)"
    kwriteconfig6 --file kdeglobals --group General --key font "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kwriteconfig6 --file kdeglobals --group WM --key activeFont "Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure || true
    if [ $traypatch = 1 ] || [ $lockscreen = 1 ]; then
        systemctl --user restart plasma-plasmashell.service
    fi
else
    echo
    echo "Installed. To switch to it, either run ./install.sh --apply or open"
    echo "System Settings → Colors & Themes → Global Theme → Mac Glass and tick"
    echo "\"Desktop and window layout\" to get the menu bar and dock."
fi
