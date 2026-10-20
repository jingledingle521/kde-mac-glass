import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

// macOS Wi-Fi menu: Wi-Fi switch, Known Networks, Other Networks, settings.
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    PlasmaNM.Handler {
        id: handler
    }

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    PlasmaNM.ConnectionIcon {
        id: connectionIcon
    }

    PlasmaNM.NetworkModel {
        id: networkModel
    }

    PlasmaNM.AppletProxyModel {
        id: networks
        sourceModel: networkModel
    }

    onExpandedChanged: if (expanded) handler.requestScan()

    function signalIcon(signal) {
        if (signal >= 80) return "network-wireless-signal-excellent-symbolic";
        if (signal >= 55) return "network-wireless-signal-good-symbolic";
        if (signal >= 30) return "network-wireless-signal-ok-symbolic";
        if (signal > 5) return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        // NetworkManager's icon name says the state: network-wireless-<0-100>
        // (-connected-<n> while connecting, -locked, -limited), -disconnected,
        // network-wired-*, network-unavailable, network-flightmode-on.
        readonly property string iconName: connectionIcon.connectionIcon
        readonly property bool wired: iconName.startsWith("network-wired") && iconName !== "network-wired-disconnected"
        readonly property bool drawn: !wired && /^network-(wireless|unavailable|flightmode|wired-disconnected)/.test(iconName)
        readonly property int strength: {
            const m = iconName.match(/^network-wireless-(?:connected-)?(\d+)/);
            return m ? Number(m[1]) : 0;
        }

        Layout.minimumWidth: (drawn ? glyph.implicitWidth : Kirigami.Units.iconSizes.small) + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        WifiGlyph {
            id: glyph
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            visible: parent.drawn
            off: !enabledConnections.wirelessEnabled || /unavailable|flightmode/.test(parent.iconName)
            connecting: connectionIcon.connecting
            bars: parent.strength >= 70 ? 3 : parent.strength >= 35 ? 2 : parent.strength > 0 ? 1 : 0
        }

        // Wired, mobile and VPN keep the icon theme's glyph.
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            visible: !parent.drawn
            source: visible ? parent.iconName : ""
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        id: menu

        spacing: 0
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Wi-Fi")
                font.weight: Font.Bold
            }
            PlasmaComponents3.Switch {
                checked: enabledConnections.wirelessEnabled
                enabled: enabledConnections.wirelessHwEnabled && !PlasmaNM.Configuration.airplaneModeEnabled
                onToggled: handler.enableWireless(checked)
            }
        }

        MacMenuSeparator {
            visible: enabledConnections.wirelessEnabled
        }

        MacMenuHeader {
            text: i18n("Known Networks")
            visible: enabledConnections.wirelessEnabled && knownRepeater.visibleCount > 0
        }

        Repeater {
            id: knownRepeater
            property int visibleCount: 0
            model: enabledConnections.wirelessEnabled ? networks : null
            delegate: NetworkRow {
                known: true
                onVisibleChanged: knownRepeater.visibleCount += visible ? 1 : -1
                Component.onCompleted: if (visible) knownRepeater.visibleCount += 1
                Component.onDestruction: if (visible) knownRepeater.visibleCount -= 1
            }
        }

        MacMenuHeader {
            text: i18n("Other Networks")
            visible: enabledConnections.wirelessEnabled && otherRepeater.visibleCount > 0
        }

        Repeater {
            id: otherRepeater
            property int visibleCount: 0
            model: enabledConnections.wirelessEnabled ? networks : null
            delegate: NetworkRow {
                known: false
                onVisibleChanged: otherRepeater.visibleCount += visible ? 1 : -1
                Component.onCompleted: if (visible) otherRepeater.visibleCount += 1
                Component.onDestruction: if (visible) otherRepeater.visibleCount -= 1
            }
        }

        MacMenuSeparator {}

        MacMenuItem {
            text: i18n("Wi-Fi Settings…")
            onTriggered: {
                root.expanded = false;
                KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement");
            }
        }
    }

    component NetworkRow: MouseArea {
        id: row

        required property var model
        property bool known: false
        readonly property bool isWifi: model.Type === PlasmaNM.Enums.Wireless
        readonly property bool connected: model.ConnectionState === PlasmaNM.Enums.Activated
        readonly property bool busy: model.ConnectionState === PlasmaNM.Enums.Activating || model.ConnectionState === PlasmaNM.Enums.Deactivating
        readonly property bool secured: model.SecurityType !== undefined && model.SecurityType > 0

        visible: isWifi && ((model.Uuid !== "") === known)
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing : 0
        hoverEnabled: true

        onClicked: {
            if (connected) {
                handler.deactivateConnection(model.ConnectionPath, model.DevicePath);
            } else if (model.Uuid) {
                handler.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath);
            } else {
                // New network: NetworkManager's agent asks for the password.
                handler.addAndActivateConnection(model.DevicePath, model.SpecificPath);
            }
            root.expanded = false;
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
            visible: row.containsMouse
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.mediumSpacing
            anchors.rightMargin: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.mediumSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium - Kirigami.Units.smallSpacing
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: row.connected ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: root.signalIcon(row.model.Signal || 0)
                    isMask: true
                    color: row.connected ? "white" : Kirigami.Theme.textColor
                }
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.model.ItemUniqueName
                elide: Text.ElideRight
            }
            PlasmaComponents3.BusyIndicator {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                visible: row.busy
                running: visible
            }
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "object-locked-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: 0.6
                visible: row.secured && !row.busy
            }
        }
    }
}
