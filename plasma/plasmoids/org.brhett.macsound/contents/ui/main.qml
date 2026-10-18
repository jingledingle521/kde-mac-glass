import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.volume
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

// macOS Sound menu: "Sound" title, volume slider, output device list with a
// blue circle on the active device, a per-app volume mixer, and Sound Settings….
PlasmoidItem {
    id: root

    readonly property var sink: PreferredDevice.sink
    readonly property bool hasSink: sink && sink.name !== "auto_null"
    readonly property int percent: hasSink ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : 0

    function setPercent(p) {
        if (!hasSink) {
            return;
        }
        sink.muted = false;
        sink.volume = Math.round(PulseAudio.NormalVolume * Math.max(0, Math.min(100, p)) / 100);
    }

    // App streams grouped by app, so an app with several streams gets one
    // slider: [{ key, name, icon, streams: [PulseObject…] }].
    property var appGroups: []

    function regroupApps() {
        const groups = [];
        const byKey = {};
        for (let i = 0; i < streamInfo.count; ++i) {
            const info = streamInfo.objectAt(i);
            if (!info || !info.stream) {
                continue;
            }
            let group = byKey[info.key];
            if (!group) {
                group = byKey[info.key] = { key: info.key, name: info.key, icon: "", streams: [] };
                groups.push(group);
            }
            if (!group.icon && info.icon) {
                group.icon = info.icon;
            }
            group.streams.push(info.stream);
        }
        appGroups = groups;
    }

    function nodeName(o) {
        return o.description || o.name || i18n("Unknown Device");
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: hasSink ? AudioIcon.forVolume(percent, sink.muted, "") : AudioIcon.forVolume(0, true, "")
    toolTipMainText: ""
    toolTipSubText: ""

    SinkModel {
        id: sinkModel
    }

    // Apps currently playing audio (virtual streams like event sounds excluded).
    PulseObjectFilterModel {
        id: appStreams
        filters: [{ role: "VirtualStream", value: false }]
        sourceModel: SinkInputModel {}
    }

    Instantiator {
        id: streamInfo
        model: appStreams
        delegate: QtObject {
            required property var model
            readonly property var stream: model.PulseObject
            readonly property string key: model.Client && model.Client.name ? model.Client.name : model.Name
            readonly property string icon: model.IconName || ""
            onKeyChanged: Qt.callLater(root.regroupApps)
            onIconChanged: Qt.callLater(root.regroupApps)
        }
        onObjectAdded: Qt.callLater(root.regroupApps)
        onObjectRemoved: Qt.callLater(root.regroupApps)
    }

    PulseObjectFilterModel {
        id: sinks
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: sinkModel
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        Layout.minimumWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onPressed: wasExpanded = root.expanded
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.MiddleButton) {
                if (root.hasSink) {
                    root.sink.muted = !root.sink.muted;
                }
            } else {
                root.expanded = !wasExpanded;
            }
        }
        onWheel: wheel => root.setPercent(root.percent + (wheel.angleDelta.y > 0 ? 5 : -5))

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: 0
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            text: i18n("Sound")
            font.weight: Font.Bold
        }

        MacSlider {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            enabled: root.hasSink
            from: 0
            to: 100
            value: root.hasSink && !root.sink.muted ? root.percent : 0
            iconName: "audio-volume-high-symbolic"
            onMoved: value => root.setPercent(Math.round(value))
        }

        MacMenuSeparator {}

        MacCollapsibleHeader {
            text: i18n("Output")
            visible: sinks.count > 0
            expanded: Plasmoid.configuration.outputExpanded
            onToggled: Plasmoid.configuration.outputExpanded = !Plasmoid.configuration.outputExpanded
        }

        Repeater {
            model: Plasmoid.configuration.outputExpanded ? sinks : []
            delegate: MouseArea {
                id: row

                required property var model
                readonly property bool active: model.PulseObject.default === true

                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing
                hoverEnabled: true
                onClicked: model.PulseObject.default = true

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
                        color: row.active ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: (row.model.PulseObject.formFactor === "headphone" || row.model.PulseObject.name.indexOf("bluez") >= 0) ? "audio-headphones-symbolic" : "audio-speakers-symbolic"
                            isMask: true
                            color: "white"
                        }
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: root.nodeName(row.model.PulseObject)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        MacMenuItem {
            text: i18n("No output devices")
            enabled: false
            visible: sinks.count === 0
        }

        MacMenuSeparator {
            visible: root.appGroups.length > 0
        }

        MacCollapsibleHeader {
            text: i18n("Mixer")
            visible: root.appGroups.length > 0
            expanded: Plasmoid.configuration.mixerExpanded
            onToggled: Plasmoid.configuration.mixerExpanded = !Plasmoid.configuration.mixerExpanded
        }

        Repeater {
            model: Plasmoid.configuration.mixerExpanded ? root.appGroups : []
            delegate: ColumnLayout {
                id: app

                required property var modelData
                readonly property var streams: modelData.streams
                // An app counts as muted only when all of its streams are.
                readonly property bool muted: streams.every(st => st.muted)
                readonly property int percent: Math.round(Math.max(...streams.map(st => st.volume)) / PulseAudio.NormalVolume * 100)

                function setPercent(p) {
                    const v = Math.round(PulseAudio.NormalVolume * Math.max(0, Math.min(100, p)) / 100);
                    for (const st of streams) {
                        st.muted = false;
                        st.volume = v;
                    }
                }

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.mediumSpacing
                Layout.rightMargin: Kirigami.Units.mediumSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // Click the app icon to mute/unmute it.
                    MouseArea {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        onClicked: {
                            const mute = !app.muted;
                            for (const st of app.streams) {
                                st.muted = mute;
                            }
                        }

                        Kirigami.Icon {
                            anchors.fill: parent
                            source: app.modelData.icon || "audio-volume-high"
                            opacity: app.muted ? 0.4 : 1
                        }
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: app.modelData.name
                        elide: Text.ElideRight
                        opacity: app.muted ? 0.5 : 1
                    }
                    PlasmaComponents3.Label {
                        text: app.muted ? i18n("Muted") : i18nc("volume percent", "%1%", app.percent)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.55
                    }
                }

                MacSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.9)
                    from: 0
                    to: 100
                    value: app.muted ? 0 : app.percent
                    onMoved: value => app.setPercent(Math.round(value))
                }
            }
        }

        MacMenuSeparator {}

        MacMenuItem {
            text: i18n("Sound Settings…")
            onTriggered: {
                root.expanded = false;
                KCMUtils.KCMLauncher.openSystemSettings("kcm_pulseaudio");
            }
        }
    }
}
