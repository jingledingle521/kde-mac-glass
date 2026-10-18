# Mac Glass for KDE Plasma 6

A macOS-style desktop for Plasma 6: a liquid-glass menu bar and floating dock,
and Mac-style widgets for the menu bar.

## What's inside

| Path | What it is |
|---|---|
| `plasma/desktoptheme/MacGlass` | **Plasma style "Mac Glass"**: clear, blurred glass panels with a light rim, based on WhiteSur-dark |
| `plasma/look-and-feel/org.brhett.macglass` | **Global Theme "Mac Glass"**: sets the style, icons, cursors and window decoration, and builds the menu bar + dock layout |
| `plasma/plasmoids/org.brhett.*` | Widgets: Apple menu, active app name, dock, Clipboard, Now Playing, Battery, Wi-Fi, Sound (with mixer), Control Center, Notifications |
| `aurorae/MacSequoia-Dark` | Window decoration (stoplight buttons on the left, 28px title bar) |
| `wallpapers/GoldenGate` | Golden Gate wallpaper |
| `fonts/` | Inter (UI font) |
| `extras/lockscreen` | Optional Golden Gate lock screen |
| `extras/tray-patch` | Optional patched system tray: 16px icons, icon-grid overflow popup |
| `extras/vivaldi-menu` | Optional File/Edit/View/History/Bookmarks/Window/Help for Vivaldi in KDE's global menu (`install.sh`, load the extension once; Vivaldi runs natively on Wayland, `install.sh --x11` for the stock Global Menu widget) |
| `extras/kvantum` | Optional Mac-style menus for Plasma's own menus (global, right-click, tray): rounded glass with a blue hover. Needs `kvantum` |
| `extras/finder` | Finder: Dolphin rebuilt as a Golden Gate Finder (frameless glass window, sidebar, toolbar capsules, Finder selection and footer). Separate app; stock Dolphin is untouched. `./install.sh --finder` or `extras/finder/build-finder [--deps]`. Also: column view, Finder-style Open/Save windows for other apps (through xdg-desktop-portal; set up by the installer, asks for your password once), and AirDrop with iPhones and Macs (sidebar, Ctrl+Shift+R, right-click › Share › AirDrop, progress cards) once `./install.sh --airdrop` (or `extras/finder/install-airdrop`) has set up [omdrop-owl](https://github.com/t4t5/omdrop-owl) and [omdrop](https://github.com/netmojo-systems/omdrop-plugin). On Intel Wi-Fi, Wi-Fi disconnects while AirDrop is on. |
| `extras/dolphin` | Optional Finder-style Dolphin toolbar and sidebar (`finder-style.sh`, with Dolphin closed) |
| `extras/sddm` | Optional Golden Gate login screen for SDDM (`install-sddm.sh`; Fedora, needs sudo) |

## Install

```sh
./install.sh            # install only; nothing on screen changes
./install.sh --apply    # install and switch to it (replaces your panels; old layout is backed up)
```

Add any of these:

- `--icons` downloads the WhiteSur icon theme and cursors from GitHub if they're missing.
- `--lockscreen` uses the Golden Gate lock screen. It takes effect after you log out and back in.
- `--tray-patch` builds the patched system tray. It expects Qt plugins in `/usr/lib64`, as on Fedora or openSUSE.

Without `--apply`, pick it later in **System Settings → Colors & Themes → Global
Theme → Mac Glass**, and tick **Desktop and window layout** to get the menu bar and dock.

**Meta+V** opens the Clipboard widget.

### Glass level

**Control Center → Glass** slides from **Clear** to **Frosted**, like macOS's
Liquid Glass setting. While you drag, the blur strength changes. When you let go,
the panel tint updates and the style reloads, with a quick flicker. You can
also set it from a terminal:

```sh
~/.local/share/plasma/desktoptheme/MacGlass/glass/glass.py apply 60   # 0–100
```

## Requirements

- KDE Plasma 6 on Wayland (tested on 6.7, Fedora).
- Blur and Background Contrast desktop effects enabled. They're on by default.
- Optional: an app-menu provider such as `appmenu-gtk-module`, so GTK apps show their menus in the menu bar.

## Remove

Switch to another Global Theme first, then run `./uninstall.sh`.

## Credits

- WhiteSur and MacSequoia: Vince Liuice (GPL-3.0).
- Inter: Rasmus Andersson (SIL OFL 1.1).
- Golden Gate photo: Frank Schulenburg (CC BY-SA 4.0). See `wallpapers/GoldenGate/README.txt`.
- Kvantum menus: built from KvMojave by Vince Liuice (GPL-3.0).

Finder and the Menu Bar also live in their own repos:
[finder-kde](https://github.com/jingledingle521/finder-kde) (a fork of KDE's
Dolphin, GPL-2.0-or-later) and
[kde-mac-menubar](https://github.com/jingledingle521/kde-mac-menubar).

## License

GPL-3.0 (see [LICENSE](LICENSE)), as the Plasma style and window decoration
build on GPL-3.0 themes. The Inter font is under the SIL Open Font License
(`fonts/OFL-Inter.txt`) and the wallpaper under CC BY-SA 4.0.
