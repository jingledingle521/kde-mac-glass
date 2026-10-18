// Mac Glass layout: a menu bar along the top and a floating dock at the
// bottom, built from the org.brhett.* widgets.

function add(panel, plugin, config) {
    var widget = panel.addWidget(plugin);
    for (var group in (config || {})) {
        widget.currentConfigGroup = group.split("/");
        for (var key in config[group]) {
            widget.writeConfig(key, config[group][key]);
        }
    }
    return widget;
}

// Menu bar
var bar = new Panel;
bar.location = "top";
bar.height = 32;
bar.hiding = "dodgewindows";
bar.floating = false;
bar.lengthMode = "fill";
bar.opacity = "translucent"; // stay glass even when a window touches it

// Apple menu, app menu and the focused app's menus in one strip.
add(bar, "org.brhett.menubar", { General: { iconSize: 16, monochrome: true } });
add(bar, "org.kde.plasma.panelspacer");
add(bar, "org.kde.plasma.marginsseparator");
add(bar, "org.kde.plasma.systemtray", { General: {
    // Volume, network, battery, media, notifications and clipboard are
    // replaced by the Mac widgets below. Listing the stock applets as "known"
    // keeps the tray from adding them back on its own.
    extraItems: [],
    knownItems: ["org.kde.kdeconnect", "org.kde.plasma.vault", "org.kde.plasma.cameraindicator",
                 "org.kde.plasma.clipboard", "org.kde.plasma.devicenotifier", "org.kde.plasma.manage-inputmethod",
                 "org.kde.plasma.mediacontroller", "org.kde.plasma.notifications", "org.kde.plasma.battery",
                 "org.kde.plasma.brightness", "org.kde.plasma.networkmanagement", "org.kde.plasma.keyboardlayout",
                 "org.kde.plasma.printmanager", "org.kde.plasma.keyboardindicator", "org.kde.plasma.weather",
                 "org.kde.kscreen", "org.kde.plasma.volume", "org.kde.plasma.bluetooth"],
    iconSpacing: 4
} });
add(bar, "org.brhett.macclipboard").globalShortcut = "Meta+V";
add(bar, "org.brhett.macnowplaying");
add(bar, "org.brhett.macbattery");
add(bar, "org.brhett.macwifi");
add(bar, "org.brhett.macsound");
add(bar, "org.brhett.controlcenter");
add(bar, "org.kde.plasma.panelspacer", { General: { expanding: false, length: 10 } });
add(bar, "org.kde.plasma.digitalclock", { Appearance: {
    autoFontAndSize: false,
    fontFamily: "Inter",
    fontSize: 10,
    fontWeight: 400,
    dateDisplayFormat: "BesideTime",
    dateFormat: "custom",
    customDateFormat: "ddd MMM d"
} });
add(bar, "org.brhett.macnotifications");

// Dock
var dock = new Panel;
dock.location = "bottom";
dock.height = 62;
dock.hiding = "dodgewindows";
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.opacity = "translucent";
add(dock, "org.brhett.macdock", { General: { launchers: [
    "applications:org.kde.dolphin.desktop",
    "preferred://browser",
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.discover.desktop",
    "applications:systemsettings.desktop"
] } });

// Wallpaper
var wallpaper = "file://" + userDataPath("wallpapers/GoldenGate/golden-hour.jpg");
desktops().forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", wallpaper);
});
