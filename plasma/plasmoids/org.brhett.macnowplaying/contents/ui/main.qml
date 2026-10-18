import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

// macOS Now Playing menu: artwork, title and artist, a scrubbable progress
// bar with elapsed/remaining time, and big transport controls. The bar icon
// only appears while something is playing or paused.
PlasmoidItem {
    id: root

    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined && (player.track || player.identity || "") !== ""
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    // Live streams report junk lengths (or none); only show progress for real tracks.
    readonly property bool hasProgress: hasPlayer && player.length > 0 && player.length < 24 * 3600 * 1000000 && player.position <= player.length

    function formatTime(usec) {
        const total = Math.max(0, Math.floor(usec / 1000000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = String(total % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s;
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: playing ? "media-playback-playing" : "media-playback-paused"
    Plasmoid.status: hasPlayer ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    toolTipMainText: hasPlayer ? (player.track || player.identity) : ""
    toolTipSubText: hasPlayer ? (player.artist || "") : ""

    onHasPlayerChanged: if (!hasPlayer) expanded = false

    Mpris.Mpris2Model {
        id: mpris
    }

    // MPRIS doesn't push position updates, so poll while the menu is open.
    Timer {
        interval: 1000
        repeat: true
        running: root.expanded && root.playing
        triggeredOnStart: true
        onTriggered: root.player.updatePosition()
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        // Collapse to nothing when there's no player, like the macOS menu bar.
        Layout.minimumWidth: root.hasPlayer ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2 : 0
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        visible: root.hasPlayer
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onPressed: wasExpanded = root.expanded
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.MiddleButton) {
                root.player.PlayPause();
            } else {
                root.expanded = !wasExpanded;
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18n("Now Playing")
            font.weight: Font.Bold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.largeSpacing

            // Artwork; clicking it brings the player's window forward.
            MouseArea {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Layout.preferredWidth
                cursorShape: root.hasPlayer && root.player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.hasPlayer && root.player.canRaise) {
                        root.player.Raise();
                        root.expanded = false;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius * 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                    clip: true

                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.hasPlayer ? root.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: width * 2
                        sourceSize.height: height * 2
                        visible: status === Image.Ready
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        source: root.hasPlayer ? (root.player.iconName || "media-default-album") : "media-default-album"
                        visible: art.status !== Image.Ready
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.track || root.player.identity) : ""
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.artist || "") : ""
                    visible: text.length > 0
                    opacity: 0.6
                    elide: Text.ElideRight
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? root.player.identity : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.45
                    elide: Text.ElideRight
                }
            }
        }

        // Progress: thin capsule, scrubbable when the player allows seeking.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Math.round(Kirigami.Units.smallSpacing / 2)
            visible: root.hasProgress

            MouseArea {
                id: scrub
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 0.75
                enabled: root.hasPlayer && root.player.canSeek
                preventStealing: true

                readonly property real fraction: root.hasPlayer && root.player.length > 0 ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0

                function seekTo(mx) {
                    root.player.position = Math.max(0, Math.min(1, mx / width)) * root.player.length;
                }
                onPressed: mouseEvent => seekTo(mouseEvent.x)
                onPositionChanged: mouseEvent => {
                    if (pressed) {
                        seekTo(mouseEvent.x);
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrub.containsPress ? 6 : 4
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

                    Rectangle {
                        width: parent.width * scrub.fraction
                        height: parent.height
                        radius: height / 2
                        color: Kirigami.Theme.textColor
                        opacity: 0.75
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? root.formatTime(root.player.position) : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.55
                }
                PlasmaComponents3.Label {
                    text: root.hasPlayer ? "-" + root.formatTime(root.player.length - root.player.position) : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.55
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.gridUnit

            PlasmaComponents3.ToolButton {
                icon.name: "media-skip-backward"
                icon.width: Kirigami.Units.iconSizes.smallMedium
                icon.height: Kirigami.Units.iconSizes.smallMedium
                enabled: root.hasPlayer && root.player.canGoPrevious
                onClicked: root.player.Previous()
            }
            PlasmaComponents3.ToolButton {
                icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                icon.width: Kirigami.Units.iconSizes.medium
                icon.height: Kirigami.Units.iconSizes.medium
                enabled: root.hasPlayer && (root.playing ? root.player.canPause : root.player.canPlay)
                onClicked: root.player.PlayPause()
            }
            PlasmaComponents3.ToolButton {
                icon.name: "media-skip-forward"
                icon.width: Kirigami.Units.iconSizes.smallMedium
                icon.height: Kirigami.Units.iconSizes.smallMedium
                enabled: root.hasPlayer && root.player.canGoNext
                onClicked: root.player.Next()
            }
        }
    }
}
