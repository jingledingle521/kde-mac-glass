import QtCore
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Downloads folder as a macOS "stack": clicking shows the newest files in a
// grid above the dock.
Item {
    id: stack

    required property Item dock
    property var items: []
    readonly property string folder: StandardPaths.writableLocation(StandardPaths.DownloadLocation).toString().replace("file://", "")

    signal run(string command, var callback)

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        const helper = Qt.resolvedUrl("../code/downloads.py").toString().replace("file://", "");
        run("python3 -I " + shellQuote(helper) + " " + shellQuote(folder) + " 12", stdout => {
            try {
                items = JSON.parse(stdout);
            } catch (e) {
                items = [];
            }
        });
    }

    function open(path) {
        popup.visible = false;
        run("setsid -f xdg-open " + shellQuote(path) + " >/dev/null 2>&1", null);
    }

    width: dock.vertical ? dock.thickness : dock.cellSize
    height: dock.vertical ? dock.cellSize : dock.thickness

    Kirigami.Icon {
        width: stack.dock.iconSize
        height: width
        x: (parent.width - width) / 2
        y: (parent.height - height - stack.dock.dotSize * 1.6) / 2
        source: "folder-downloads"
        roundToIconSize: false
        opacity: mouse.pressed ? 0.65 : 1
    }

    DockBubble {
        dock: stack.dock
        anchor: stack
        text: i18n("Downloads")
        shown: mouse.containsMouse && !mouse.pressed && !popup.visible && !stack.dock.menu.opened
    }

    MouseArea {
        id: mouse

        // Pressing the icon closes an open stack (the popup loses focus)
        // before the click arrives, so remember whether it was open.
        property bool wasOpen: false

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: wasOpen = popup.visible
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) {
                stack.open(stack.folder);
                return;
            }
            if (wasOpen || popup.visible) {
                popup.visible = false;
            } else {
                stack.refresh();
                popup.visible = true;
            }
        }
    }

    PlasmaCore.Dialog {
        id: popup

        visualParent: stack
        location: Plasmoid.location
        type: PlasmaCore.Dialog.PopupMenu
        hideOnWindowDeactivate: true
        flags: Qt.WindowStaysOnTopHint

        mainItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            // The dialog sizes its window from these; without a height it
            // opened as a sliver on top of the dock.
            width: Kirigami.Units.gridUnit * 22
            height: implicitHeight

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Downloads")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Kirigami.Units.largeSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: stack.items
                    delegate: MouseArea {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge + label.implicitHeight + Kirigami.Units.smallSpacing * 3
                        hoverEnabled: true
                        onClicked: stack.open(modelData.path)

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Kirigami.Theme.highlightColor
                            opacity: parent.containsMouse ? 0.35 : 0
                        }
                        Kirigami.Icon {
                            id: fileIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Kirigami.Units.smallSpacing
                            width: Kirigami.Units.iconSizes.huge
                            height: width
                            source: modelData.icon
                            fallback: "text-x-generic"
                        }
                        PlasmaComponents3.Label {
                            id: label
                            anchors.top: fileIcon.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Kirigami.Units.smallSpacing
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name
                            elide: Text.ElideMiddle
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            font: Kirigami.Theme.smallFont
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: stack.items.length === 0
                text: i18n("No downloads")
                opacity: 0.6
            }

            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignRight
                text: i18n("Open Folder")
                icon.name: "system-file-manager"
                onClicked: stack.open(stack.folder)
            }
        }
    }
}
