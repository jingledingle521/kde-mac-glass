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
| `extras/dock-helper` | Window helper for the dock and notifications (QML module `org.brhett.macdock`): KWin blur behind the glass, clicks pass through the rest. Built by `install.sh` (needs build tools, listed in its `install.sh`) |
| `extras/menu-style` | Optional **MacGlass widget style**: Breeze with every app's menus drawn like macOS (frosted rounded panel, hover in the accent colour, ⌃⇧⌘ shortcuts), and macOS-style buttons, checkboxes, pop-up buttons, sliders, segmented tabs and grouped panels (group boxes). `./install.sh --menus`; `extras/menu-style/install.sh --off` goes back to Breeze |
| `extras/accent` | Accent colour watcher: Plasma ignores Appearance's accent for a style with its own colours, so `macglass-accent` (run by a systemd path unit whenever `kdeglobals` changes) copies it into Mac Glass's selection and focus colours. Installed by `install.sh`; `--apply` sets the Apple menu's blue as the accent |
| `extras/lockscreen` | Optional Golden Gate lock screen |
| `extras/tray-patch` | Optional patched system tray: 16px icons, icon-grid overflow popup |
| `extras/vivaldi-menu` | Optional File/Edit/View/History/Bookmarks/Window/Help for Vivaldi in KDE's global menu (`install.sh`, load the extension once; Vivaldi runs natively on Wayland, `install.sh --x11` for the stock Global Menu widget) |
| `extras/kvantum` | Older alternative to `extras/menu-style` for Plasma's own menus only (needs `kvantum`) |
| `extras/finder` | Finder: Dolphin rebuilt as a Golden Gate Finder (frameless glass window, sidebar, toolbar capsules, Finder selection and footer). Separate app; stock Dolphin is untouched. `./install.sh --finder` or `extras/finder/build-finder [--deps]`. Also: column view, Finder-style Open/Save windows for other apps (through xdg-desktop-portal; set up by the installer, asks for your password once), and AirDrop with iPhones and Macs (sidebar, Ctrl+Shift+R, right-click › Share › AirDrop, progress cards) once `./install.sh --airdrop` (or `extras/finder/install-airdrop`) has set up [omdrop-owl](https://github.com/t4t5/omdrop-owl) and [omdrop](https://github.com/netmojo-systems/omdrop-plugin). On Intel Wi-Fi, Wi-Fi disconnects while AirDrop is on. |
| `extras/settings` | Mac Settings: KDE's System Settings laid out as macOS's (frameless glass window with stoplights, the account card and macOS's sidebar groups with coloured tiles, grouped-panel forms, back-navigable lists of pages). Patches against System Settings 6.7.5 (the full fork: [mac-settings-kde](https://github.com/jingledingle521/mac-settings-kde)); stock System Settings stays installed. `./install.sh --settings` or `extras/settings/build-settings [--deps]`. |
| `extras/appstore` | App Store: KDE's Discover laid out as macOS's App Store (frameless glass window with stoplights; a sidebar of Discover, Create, Work, Play, Develop, Categories and Updates with the account card; a Discover page of feature cards and shelves; Get/Open buttons with an install progress ring; app pages with a facts strip; grouped Settings). Patches against Discover 6.7.5 (the full fork: [mac-app-store-kde](https://github.com/jingledingle521/mac-app-store-kde)); stock Discover stays installed. `./install.sh --appstore` or `extras/appstore/build-appstore [--deps]`. |
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
- `--menus` draws every app's right-click and app menus like macOS (the MacGlass widget style).
- `--smooth` runs Plasma's animations at the screen's refresh rate. Qt falls back
  to 60 fps on some GPUs (seen with NVIDIA), which looks choppy on a 120/240 Hz
  screen. Delete `~/.config/systemd/user/plasma-plasmashell.service.d/threaded-render.conf`
  to go back.

The installer always builds the dock's small window helper, so it needs a C++
toolchain with Qt and KDE Frameworks headers (on Fedora:
`sudo dnf install cmake ninja-build gcc-c++ extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel`).

Without `--apply`, pick it later in **System Settings → Colors & Themes → Global
Theme → Mac Glass**, and tick **Desktop and window layout** to get the menu bar and dock.

**Meta+V** opens the Clipboard widget.

### Dock

The dock isn't a Plasma panel: its widget sits invisibly in the menu bar and
draws the dock in its own window along the bottom of the screen. (Plasma moves
and resizes a panel's window in two separate steps, a frame apart, so a panel
dock shook while it was resized.) Hover an icon for its name, right-click for
its windows and actions, drag icons to reorder, and drag the divider before
Downloads and Trash up or down to resize the dock, as on macOS; right-click
it to turn hiding on or off (the dock slides away and comes back when you
point at the bottom edge). Icons grow in
when an app opens and shrink away when it quits. Maximized windows stop above it.

### Notification Center

The menu bar's date and time is the Notifications widget: click it (or press
**Meta+N**) and Notification Center slides in from the right, with each app's
notifications stacked on glass cards, then a Calendar widget showing today's
events from your calendars (KOrganizer's, through Plasma's calendar plugin,
which needs kdepim-addons; all calendars are shown unless you pick some in the
Digital Clock's Calendar settings). Click a stack to spread it out; ✕ dismisses
a card or clears an app. Clicking the Calendar widget opens your default
calendar app (System Settings → Default Applications).
New notifications slide in as glass banners at the top right. Middle-click the
clock to toggle Do Not Disturb.

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
- Build tools: the dock and notifications need a small native helper that
  the installer compiles (`extras/dock-helper/install.sh` lists the Fedora
  packages). The Mac menus and controls (`--menus`), Finder, Mac Settings
  and App Store are compiled too.

### Known limits

- Written and used on Fedora 44 with Plasma 6.7.5. Other distributions
  should work for the theme and widgets; the build scripts use `dnf`, and
  the tray patch expects Fedora's `/usr/lib64` layout.
- Finder's patches are for Dolphin 26.08.1, Mac Settings' for System
  Settings 6.7.5 and App Store's for Discover 6.7.5; other versions may not
  apply cleanly.
- `--lockscreen` installs a custom lock screen that its author has since
  turned off after two lockouts (probably a graphics-driver freeze rather
  than the lock screen, but unconfirmed). The stock lock screen with the
  Golden Gate wallpaper, which `--apply` sets, is the safe choice.
- `extras/sddm` (a matching login screen) is staged but not part of the
  installer.

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
