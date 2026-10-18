import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: item

    required property int index
    required property var model
    required property Item dock
    required property TaskManager.TasksModel tasks
    required property int repeaterCount

    readonly property bool running: !model.IsLauncher
    readonly property bool bouncing: model.IsStartup === true || model.IsDemandingAttention === true
    readonly property url launcherUrl: model.LauncherUrlWithoutIcon
    property bool pinned: false
    property real bounceY: 0

    function modelIndex() {
        return tasks.makeModelIndex(index);
    }

    function refreshPinned() {
        pinned = launcherUrl.toString() !== "" && tasks.launcherPosition(launcherUrl) >= 0;
    }

    width: dock.vertical ? dock.thickness : dock.cellSize
    height: dock.vertical ? dock.cellSize : dock.thickness

    Kirigami.Icon {
        id: icon
        width: item.dock.iconSize
        height: width
        x: (parent.width - width) / 2
        // Leave room under the icon for the running dot.
        y: (parent.height - height - item.dock.dotSize * 1.6) / 2 - item.bounceY
        source: item.model.decoration
        roundToIconSize: false
        opacity: mouse.pressed ? 0.65 : 1
    }

    Rectangle {
        width: item.dock.dotSize
        height: width
        radius: width / 2
        x: (parent.width - width) / 2
        y: icon.y + icon.height + item.dock.dotSize * 0.6 + item.bounceY
        color: Kirigami.Theme.textColor
        opacity: 0.8
        visible: item.running
    }

    // Bounce while launching or demanding attention.
    SequentialAnimation {
        running: item.bouncing
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { target: item; property: "bounceY"; to: item.dock.iconSize * 0.45; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: item; property: "bounceY"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 120 }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: item.model.AppName || item.model.display || ""
        location: Plasmoid.location
        active: !contextMenu.opened && !mouse.dragging
    }

    MouseArea {
        id: mouse

        property bool dragging: false
        property real pressX: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onPressed: mouseEvent => {
            pressX = item.dock.vertical ? mouseEvent.y : mouseEvent.x;
            dragging = false;
        }
        onPositionChanged: mouseEvent => {
            if (!(pressedButtons & Qt.LeftButton)) {
                return;
            }
            const pos = item.dock.vertical ? mouseEvent.y : mouseEvent.x;
            if (!dragging && Math.abs(pos - pressX) > Kirigami.Units.gridUnit) {
                dragging = true;
            }
            if (dragging) {
                // Reorder live: move this item to the slot under the cursor.
                const offset = Math.round((pos - pressX) / item.dock.cellSize);
                const target = Math.max(0, Math.min(item.repeaterCount - 1, item.index + offset));
                if (target !== item.index) {
                    item.tasks.move(item.index, target);
                    pressX += (target - item.index) * item.dock.cellSize;
                }
            }
        }
        onReleased: {
            if (dragging) {
                dragging = false;
                item.tasks.syncLaunchers();
            }
        }
        onClicked: mouseEvent => {
            if (dragging) {
                return;
            }
            if (mouseEvent.button === Qt.RightButton) {
                item.refreshPinned();
                contextMenu.openRelative();
            } else if (mouseEvent.button === Qt.MiddleButton) {
                item.tasks.requestNewInstance(item.modelIndex());
            } else {
                item.tasks.requestActivate(item.modelIndex());
            }
        }
    }

    PlasmaExtras.Menu {
        id: contextMenu

        property bool opened: status === PlasmaExtras.Menu.Open

        visualParent: item
        placement: item.dock.vertical ? PlasmaExtras.Menu.RightPosedTopAlignedPopup : PlasmaExtras.Menu.TopPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: item.running ? i18n("New Window") : i18n("Open")
            icon: item.running ? "window-new" : "media-playback-start"
            onClicked: item.running ? item.tasks.requestNewInstance(item.modelIndex()) : item.tasks.requestActivate(item.modelIndex())
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Keep in Dock")
            checkable: true
            checked: item.pinned
            visible: item.launcherUrl.toString() !== ""
            onClicked: {
                if (item.pinned) {
                    item.tasks.requestRemoveLauncher(item.launcherUrl);
                } else {
                    item.tasks.requestAddLauncher(item.launcherUrl);
                }
            }
        }
        PlasmaExtras.MenuItem {
            separator: true
            visible: item.running
        }
        PlasmaExtras.MenuItem {
            text: i18n("Quit")
            icon: "application-exit"
            visible: item.running
            onClicked: item.tasks.requestClose(item.modelIndex())
        }
    }
}
