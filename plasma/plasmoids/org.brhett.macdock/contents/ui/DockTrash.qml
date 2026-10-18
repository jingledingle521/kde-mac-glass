import QtCore
import QtQuick
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// Trash at the end of the dock: empty/full icon, click to open, drop files
// to trash them, right-click to empty.
Item {
    id: trash

    required property Item dock
    readonly property bool full: trashFiles.count > 0

    signal run(string command, var callback)

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    width: dock.vertical ? dock.thickness : dock.cellSize
    height: dock.vertical ? dock.cellSize : dock.thickness

    FolderListModel {
        id: trashFiles
        folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/Trash/files"
        showHidden: true
        showDirs: true
    }

    Kirigami.Icon {
        width: trash.dock.iconSize
        height: width
        x: (parent.width - width) / 2
        y: (parent.height - height - trash.dock.dotSize * 1.6) / 2
        source: trash.full ? "user-trash-full" : "user-trash"
        roundToIconSize: false
        opacity: mouse.pressed ? 0.65 : 1
        scale: drop.containsDrag ? 1.12 : 1
        Behavior on scale {
            NumberAnimation { duration: 120 }
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: i18n("Trash")
        location: Plasmoid.location
        active: !menu.opened
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) {
                menu.openRelative();
            } else {
                trash.run("setsid -f xdg-open trash:/ >/dev/null 2>&1", null);
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: dropEvent => {
            const urls = dropEvent.urls.map(u => trash.shellQuote(u.toString())).join(" ");
            if (urls) {
                trash.run("kioclient move " + urls + " trash:/", null);
                dropEvent.accept(Qt.MoveAction);
            }
        }
    }

    PlasmaExtras.Menu {
        id: menu

        property bool opened: status === PlasmaExtras.Menu.Open

        visualParent: trash
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Open")
            icon: "document-open-folder"
            onClicked: trash.run("setsid -f xdg-open trash:/ >/dev/null 2>&1", null)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Empty Trash")
            icon: "trash-empty"
            enabled: trash.full
            onClicked: trash.run("ktrash6 --empty", null)
        }
    }
}
