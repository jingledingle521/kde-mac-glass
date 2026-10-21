import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

// macOS Battery menu: charge and power source, time remaining, Energy Mode
// (power profiles) and other devices' batteries, with the classic battery
// glyph and percentage in the bar.
PlasmoidItem {
    id: root

    readonly property int percent: batteries.percent
    readonly property bool pluggedIn: batteries.pluggedIn
    readonly property bool charging: batteries.state === BatteryControlModel.Charging
    readonly property bool full: batteries.state === BatteryControlModel.FullyCharged || (pluggedIn && percent >= 100)

    function statusText() {
        if (!batteries.hasInternalBatteries) {
            return i18n("No battery");
        }
        if (full) {
            return i18n("Fully Charged");
        }
        if (pluggedIn && !charging) {
            return i18n("Not Charging");
        }
        const msec = batteries.smoothedRemainingMsec;
        if (msec <= 0) {
            return charging ? i18n("Calculating time until full…") : i18n("Calculating time remaining…");
        }
        const mins = Math.round(msec / 60000);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        const span = h > 0 ? i18n("%1 hr %2 min", h, m) : i18n("%1 min", m);
        return charging ? i18n("%1 until full", span) : i18n("%1 remaining", span);
    }

    function profileLabel(name) {
        switch (name) {
        case "power-saver":
            return i18n("Low Power");
        case "balanced":
            return i18n("Automatic");
        case "performance":
            return i18n("High Power");
        }
        return name;
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "battery-good"
    Plasmoid.status: batteries.hasBatteries ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: ""
    toolTipSubText: ""

    BatteryControlModel {
        id: batteries
    }

    PowerProfilesControl {
        id: profiles
        isSilent: false
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 1.5 // + the panel's ~5 px: even ~17 px gaps, as macOS
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18nc("battery percent", "%1%", root.percent)
                visible: Plasmoid.configuration.showPercentage && batteries.hasInternalBatteries
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1 // as the menu bar's other text
            }
            BatteryGlyph {
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
                percent: root.percent
                charging: root.charging
                pluggedIn: root.pluggedIn
            }
        }
    }

    fullRepresentation: ColumnLayout {
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

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Battery")
                font.weight: Font.Bold
            }
            PlasmaComponents3.Label {
                text: i18nc("battery percent", "%1%", root.percent)
                visible: batteries.hasInternalBatteries
                opacity: 0.6
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: root.pluggedIn ? i18n("Power Source: Power Adapter") : i18n("Power Source: Battery")
            opacity: 0.6
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            text: root.statusText()
            opacity: 0.6
        }

        MacMenuSeparator {
            visible: profiles.isPowerProfileDaemonInstalled
        }
        MacMenuHeader {
            text: i18n("Energy Mode")
            visible: profiles.isPowerProfileDaemonInstalled
        }
        Repeater {
            model: profiles.isPowerProfileDaemonInstalled ? profiles.profiles : []
            delegate: MacMenuItem {
                required property string modelData
                text: root.profileLabel(modelData)
                checkable: true
                checked: profiles.activeProfile === modelData
                onTriggered: profiles.setProfile(modelData)
            }
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            visible: text.length > 0 && profiles.isPowerProfileDaemonInstalled
            text: profiles.inhibitionReason || profiles.degradationReason || ""
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }

        // Batteries of mice, keyboards, headphones…
        MacMenuSeparator {
            visible: deviceList.implicitHeight > 0
        }
        MacMenuHeader {
            text: i18n("Devices")
            visible: deviceList.implicitHeight > 0
        }
        ColumnLayout {
            id: deviceList
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: batteries
                delegate: RowLayout {
                    required property var model
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.mediumSpacing
                    Layout.rightMargin: Kirigami.Units.mediumSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing / 2
                    Layout.bottomMargin: Kirigami.Units.smallSpacing / 2
                    visible: !model.IsPowerSupply
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: model.PrettyName
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.Label {
                        text: i18nc("battery percent", "%1%", model.Percent)
                        opacity: 0.6
                    }
                    BatteryGlyph {
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.preferredWidth: implicitWidth
                        percent: model.Percent
                        charging: model.ChargeState === BatteryControlModel.Charging
                    }
                }
            }
        }

        MacMenuSeparator {}

        MacMenuItem {
            text: i18n("Show Percentage")
            checkable: true
            checked: Plasmoid.configuration.showPercentage
            onTriggered: Plasmoid.configuration.showPercentage = !Plasmoid.configuration.showPercentage
        }
        MacMenuItem {
            text: i18n("Battery Settings…")
            onTriggered: {
                root.expanded = false;
                KCMUtils.KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig");
            }
        }
    }
}
