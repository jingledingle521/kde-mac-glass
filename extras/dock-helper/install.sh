#!/bin/bash
# Build and install the Mac dock's window helper (QML module org.brhett.macdock:
# KWin blur behind the dock's glass, click-through elsewhere) into ~/.local,
# and point Plasma at it. The dock widget needs it.
#
# Fedora build deps: sudo dnf install cmake ninja-build gcc-c++ extra-cmake-modules \
#     qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel
set -e
here=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
qml="$HOME/.local/lib64/qt6/qml"

cmake -S "$here" -B "$here/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" -Wno-dev >/dev/null
ninja -C "$here/build" install >/dev/null

# Plasma (and anything started in the session) finds QML modules in ~/.local.
mkdir -p "$config/systemd/user/plasma-plasmashell.service.d" "$config/environment.d"
cat > "$config/systemd/user/plasma-plasmashell.service.d/macdock-qml.conf" <<'CONF'
# QML modules installed in ~/.local (the Mac dock's window helper).
[Service]
Environment=QML_IMPORT_PATH=%h/.local/lib64/qt6/qml
CONF
cat > "$config/environment.d/61-macdock-qml.conf" <<'CONF'
QML_IMPORT_PATH=${HOME}/.local/lib64/qt6/qml
CONF
systemctl --user daemon-reload
echo "Dock helper installed in $qml/org/brhett/macdock."
