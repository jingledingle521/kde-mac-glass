#!/usr/bin/env bash
# Golden Gate login screen (SDDM). Run with sudo, one stage at a time:
#
#   sudo ./install-sddm.sh            install SDDM + the theme; boot is unchanged
#   sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/goldengate
#                                     preview it in a window (as your normal user)
#   sudo ./install-sddm.sh --switch   use SDDM at the next boot
#   sudo ./install-sddm.sh --revert   go back to Plasma Login Manager
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
theme=/usr/share/sddm/themes/goldengate
conf=/etc/sddm.conf.d/10-goldengate.conf

if [ "$(id -u)" != 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi

case ${1:-} in
"")
    dnf install -y sddm sddm-wayland-plasma qt6-qt5compat
    rm -rf "$theme"
    mkdir -p "$theme"
    cp -a "$here/goldengate/." "$theme/"
    chmod -R a+rX "$theme"
    mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=goldengate\n' > "$conf"
    echo
    echo "Installed. Boot still uses Plasma Login Manager."
    echo "Preview (as your normal user, not sudo):"
    echo "  sddm-greeter-qt6 --test-mode --theme $theme"
    echo "Then switch with: sudo $0 --switch"
    ;;
--switch)
    [ -d "$theme" ] || { echo "Install first: sudo $0" >&2; exit 1; }
    systemctl disable plasmalogin.service || true
    systemctl enable --force sddm.service
    echo "SDDM will show the Golden Gate login screen at the next boot."
    echo "To undo: sudo $0 --revert"
    ;;
--revert)
    systemctl disable sddm.service || true
    systemctl enable --force plasmalogin.service
    echo "Plasma Login Manager is back from the next boot."
    ;;
*)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
