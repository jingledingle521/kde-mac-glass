import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.volume
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami

// macOS Control Center: connectivity tile, Do Not Disturb, Night Light,
// Keep Awake, display and sound sliders, Now Playing.
PlasmoidItem {
    id: root

    property string wifiName: ""
    property bool nightLight: false

    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    // ---- data sources -----------------------------------------------------
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.NetworkModel { id: networkModel }

    Instantiator {
        model: networkModel
        delegate: QtObject {
            required property var model
            readonly property bool activeWifi: model.Type === PlasmaNM.Enums.Wireless && model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property string name: model.ItemUniqueName || ""
            onActiveWifiChanged: sync()
            onNameChanged: sync()
            Component.onCompleted: sync()
            Component.onDestruction: if (activeWifi && root.wifiName === name) root.wifiName = ""
            function sync() {
                if (activeWifi) {
                    root.wifiName = name;
                } else if (root.wifiName === name) {
                    root.wifiName = "";
                }
            }
        }
    }

    NotificationManager.Settings { id: notificationSettings }
    readonly property bool dndOn: notificationSettings.notificationsInhibitedUntil > new Date()

    function toggleDnd() {
        if (dndOn) {
            notificationSettings.notificationsInhibitedUntil = new Date(NaN);
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = until;
        }
        notificationSettings.save();
    }

    InhibitionControl { id: inhibitionControl }

    ScreenBrightnessControl {
        id: brightness
        isSilent: false
    }
    property string displayName: ""
    property real displayBrightness: 0
    property real displayMax: 1

    Instantiator {
        model: brightness.displays
        delegate: QtObject {
            required property int index
            required property string displayName
            required property int brightness
            required property int maxBrightness
            Component.onCompleted: update()
            onBrightnessChanged: update()
            onMaxBrightnessChanged: update()
            function update() {
                if (index === 0) {
                    root.displayName = displayName;
                    root.displayBrightness = brightness;
                    root.displayMax = Math.max(1, maxBrightness);
                }
            }
        }
    }

    readonly property var sink: PreferredDevice.sink
    readonly property bool hasSink: sink && sink.name !== "auto_null"

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer

    P5Support.DataSource {
        id: executable
        property var callbacks: ({})
        function exec(cmd, callback) {
            if (callback) callbacks[cmd] = callback;
            connectSource(cmd);
        }
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const callback = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (callback) callback(data["stdout"]);
        }
    }

    function readNightLight() {
        executable.exec("kreadconfig6 --file kwinrc --group NightColor --key Active --default false", out => nightLight = out.trim() === "true");
    }

    function setNightLight(on) {
        executable.exec("kwriteconfig6 --file kwinrc --group NightColor --key Active " + (on ? "true" : "false")
                        + " && dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure", () => readNightLight());
        nightLight = on;
    }

    // Mac Glass level (0 clear .. 100 frosted), handled by the style's own
    // glass.py so the setting travels with the theme.
    readonly property string glassTool: '"${XDG_DATA_HOME:-$HOME/.local/share}/plasma/desktoptheme/MacGlass/glass/glass.py"'
    property bool glassAvailable: false
    property int glassLevel: 40
    property int glassRun: 0

    function readGlass() {
        executable.exec("if test -x " + glassTool + "; then cat \"$(dirname " + glassTool + ")/level\" 2>/dev/null || echo 40; else echo none; fi #" + (++glassRun), out => {
            const v = out.trim();
            glassAvailable = v !== "none";
            if (glassAvailable && v !== "") {
                glassLevel = parseInt(v) || 40;
            }
        });
    }

    function setGlass(level, final) {
        glassLevel = level;
        // Unique suffix: the executable engine won't rerun an identical command.
        executable.exec("python3 -I " + glassTool + (final ? " apply " : " blur ") + level + " #" + (++glassRun));
    }

    onExpandedChanged: if (root.expanded) { readNightLight(); readGlass(); }
    Component.onCompleted: readGlass()

    // ---- panel icon: two stacked toggles, like macOS ----------------------
    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        Layout.minimumWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Column {
            anchors.centerIn: parent
            spacing: Math.round(Kirigami.Units.iconSizes.small * 0.14)
            Repeater {
                model: [false, true]
                delegate: Rectangle {
                    required property bool modelData
                    width: Kirigami.Units.iconSizes.small
                    height: Math.round(width * 0.42)
                    radius: height / 2
                    color: "transparent"
                    border.color: Kirigami.Theme.textColor
                    border.width: Math.max(1, Math.round(width / 14))
                    Rectangle {
                        width: parent.height - parent.border.width * 2 - 2
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.modelData ? parent.width - width - parent.border.width - 1 : parent.border.width + 1
                        color: Kirigami.Theme.textColor
                    }
                }
            }
        }
    }

    // ---- popup --------------------------------------------------------------
    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            // Connectivity
            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: connectivity.implicitHeight + 2 * padding

                ColumnLayout {
                    id: connectivity
                    anchors.fill: parent
                    spacing: Kirigami.Units.mediumSpacing

                    ConnRow {
                        title: i18n("Wi-Fi")
                        subtitle: !enabledConnections.wirelessEnabled ? i18n("Off") : (root.wifiName || i18n("Not Connected"))
                        checked: enabledConnections.wirelessEnabled
                        iconName: "network-wireless-signal-excellent-symbolic"
                        onToggled: nmHandler.enableWireless(!enabledConnections.wirelessEnabled)
                    }
                    ConnRow {
                        title: i18n("Bluetooth")
                        subtitle: !BluezQt.Manager.bluetoothOperational ? i18n("Off") : (BluezQt.Manager.connectedDevices.length > 0 ? BluezQt.Manager.connectedDevices[0].name : i18n("On"))
                        checked: BluezQt.Manager.bluetoothOperational
                        iconName: "network-bluetooth-symbolic"
                        onToggled: BluezQt.Manager.bluetoothBlocked = BluezQt.Manager.bluetoothOperational
                    }
                    ConnRow {
                        title: i18n("Airplane Mode")
                        subtitle: PlasmaNM.Configuration.airplaneModeEnabled ? i18n("On") : i18n("Off")
                        checked: PlasmaNM.Configuration.airplaneModeEnabled
                        iconName: "network-flightmode-on-symbolic"
                        onToggled: {
                            const on = !PlasmaNM.Configuration.airplaneModeEnabled;
                            nmHandler.enableAirplaneMode(on);
                            PlasmaNM.Configuration.airplaneModeEnabled = on;
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing * 2

                Tile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.mediumSpacing
                        ToggleCircle {
                            checked: root.dndOn
                            iconName: "notifications-disabled-symbolic"
                            onClicked: root.toggleDnd()
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: i18n("Do Not Disturb")
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 2
                    SmallTile {
                        title: i18n("Night Light")
                        iconName: "redshift-status-on"
                        checked: root.nightLight
                        onToggled: root.setNightLight(!root.nightLight)
                    }
                    SmallTile {
                        title: i18n("Keep Awake")
                        iconName: "system-suspend-inhibited"
                        checked: inhibitionControl.isManuallyInhibited
                        onToggled: {
                            if (inhibitionControl.isManuallyInhibited) {
                                inhibitionControl.uninhibit();
                            } else {
                                inhibitionControl.inhibit(i18n("Keep Awake is on in Control Center"));
                            }
                        }
                    }
                }
            }
        }

        SliderTile {
            title: i18n("Display")
            visible: brightness.isBrightnessAvailable && root.displayName !== ""
            iconName: "brightness-high-symbolic"
            value: root.displayBrightness / root.displayMax
            onMoved: v => brightness.setBrightness(root.displayName, Math.round(Math.max(0.01, v) * root.displayMax))
        }

        SliderTile {
            title: i18n("Sound")
            visible: root.hasSink
            iconName: "audio-volume-high-symbolic"
            value: root.hasSink && !root.sink.muted ? root.sink.volume / PulseAudio.NormalVolume : 0
            onMoved: v => {
                root.sink.muted = false;
                root.sink.volume = Math.round(PulseAudio.NormalVolume * v);
            }
        }

        Tile {
            id: glassTile
            Layout.fillWidth: true
            Layout.preferredHeight: glassCol.implicitHeight + 2 * padding
            visible: root.glassAvailable

            // Blur follows the slider live; the panel tint is redrawn on release.
            Timer {
                id: glassBlurTimer
                interval: 150
                onTriggered: root.setGlass(glassSlider.pending, false)
            }

            ColumnLayout {
                id: glassCol
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label {
                    text: i18n("Glass")
                    font.weight: Font.DemiBold
                }
                MacSlider {
                    id: glassSlider
                    property int pending: root.glassLevel
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: pending
                    iconName: "blurfx"
                    onMoved: v => {
                        pending = Math.round(v);
                        if (!glassBlurTimer.running) {
                            glassBlurTimer.start();
                        }
                    }
                    onPressedChanged: {
                        if (!pressed) {
                            glassBlurTimer.stop();
                            root.setGlass(pending, true);
                        }
                    }
                    Connections {
                        target: root
                        function onGlassLevelChanged() {
                            if (!glassSlider.pressed) {
                                glassSlider.pending = root.glassLevel;
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: i18n("Clear")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.55
                    }
                    PlasmaComponents3.Label {
                        text: i18n("Frosted")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.55
                    }
                }
            }
        }

        // Now Playing
        Tile {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
            visible: root.player !== null && root.player !== undefined && (root.player.track || "") !== ""

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.mediumSpacing

                Rectangle {
                    Layout.preferredWidth: parent.height
                    Layout.preferredHeight: parent.height
                    radius: Kirigami.Units.smallSpacing * 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        source: root.player ? (root.player.iconName || "media-default-album") : ""
                        visible: !root.player || !root.player.artUrl
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: root.player ? root.player.track : ""
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.artist || root.player.identity) : ""
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-backward"
                    enabled: root.player && root.player.canGoPrevious
                    onClicked: root.player.Previous()
                }
                PlasmaComponents3.ToolButton {
                    icon.name: root.player && root.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "media-playback-pause" : "media-playback-start"
                    onClicked: root.player.PlayPause()
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-forward"
                    enabled: root.player && root.player.canGoNext
                    onClicked: root.player.Next()
                }
            }
        }
    }

    component ConnRow: RowLayout {
        id: connRow
        property string title
        property string subtitle
        property bool checked
        property string iconName
        signal toggled()

        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing

        ToggleCircle {
            checked: connRow.checked
            iconName: connRow.iconName
            onClicked: connRow.toggled()
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: connRow.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: connRow.subtitle
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                elide: Text.ElideRight
            }
        }
    }

    component SmallTile: Tile {
        id: small
        property string title
        property string iconName
        property bool checked
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 4.2

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            ToggleCircle {
                Layout.alignment: Qt.AlignHCenter
                checked: small.checked
                iconName: small.iconName
                onClicked: small.toggled()
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: small.title
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }
        }
    }

    component SliderTile: Tile {
        id: sliderTile
        property string title
        property string iconName
        property real value
        signal moved(real v)

        Layout.fillWidth: true
        Layout.preferredHeight: col.implicitHeight + 2 * padding

        ColumnLayout {
            id: col
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents3.Label {
                text: sliderTile.title
                font.weight: Font.DemiBold
            }
            MacSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: sliderTile.value
                iconName: sliderTile.iconName
                onMoved: v => sliderTile.moved(v)
            }
        }
    }
}
