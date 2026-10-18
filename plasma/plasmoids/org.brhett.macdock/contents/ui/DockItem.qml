import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
        x: Math.round((parent.width - width) / 2)
        // Leave room under the icon for the running dot.
        y: Math.round((parent.height - height - item.dock.dotSize * 1.6) / 2) - item.bounceY
        source: item.model.decoration
        roundToIconSize: false
        opacity: mouse.pressed ? 0.65 : 1
    }

    Rectangle {
        width: item.dock.dotSize
        height: width
        radius: width / 2
        x: Math.round((parent.width - width) / 2)
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

    // macOS dock label: the app's name in a glass bubble above the icon,
    // shown at once on hover (no tooltip delay), hidden while dragging,
    // pressing or with the menu open.
    readonly property string appName: model.AppName || model.display || ""
    readonly property bool bubbleWanted: mouse.containsMouse && !mouse.pressed && !mouse.dragging && !dock.menu.opened && appName !== ""

    // Have the app's actions ready for a right-click.
    onBubbleWantedChanged: if (bubbleWanted) dock.loadAppActions(launcherUrl)

    DockBubble {
        dock: item.dock
        anchor: item
        text: item.appName
        shown: item.bubbleWanted
    }

    // ---- right-click menu ---------------------------------------------------
    // macOS order: the app's open windows (✓ on the front one), then its own
    // actions, Keep in Dock, and Show All Windows / Hide / Quit.
    function windowIndexes() {
        if (!running) {
            return [];
        }
        const parent = modelIndex();
        if (!model.IsGroupParent) {
            return [parent];
        }
        const list = [];
        for (let i = 0; i < tasks.rowCount(parent); ++i) {
            list.push(tasks.makeModelIndex(index, i));
        }
        return list;
    }

    function menuEntries(appActions) {
        const entries = [];
        const windows = windowIndexes();
        for (const w of windows) {
            const title = tasks.data(w, Qt.DisplayRole) || appName;
            const minimized = tasks.data(w, TaskManager.AbstractTasksModel.IsMinimized) === true;
            entries.push({
                label: minimized ? "◆ " + title : title,
                check: tasks.data(w, TaskManager.AbstractTasksModel.IsActive) === true ? 1 : 0,
                trigger: () => tasks.requestActivate(w)
            });
        }
        if (windows.length > 0) {
            entries.push({separator: true});
        }

        // The app's own actions ("New Private Window"); the dock's generic
        // New Window only if the app has none of its own.
        const ownNewWindow = appActions.some(a => /new window/i.test(a.name));
        if (running && !ownNewWindow) {
            entries.push({label: i18n("New Window"), trigger: () => tasks.requestNewInstance(modelIndex())});
        }
        for (const action of appActions) {
            entries.push({label: action.name, trigger: () => dock.runAppAction(launcherUrl, action.id)});
        }
        if (!running) {
            entries.unshift({label: i18n("Open"), trigger: () => tasks.requestActivate(modelIndex())});
        }
        if (entries.length > 0 && !entries[entries.length - 1].separator) {
            entries.push({separator: true});
        }

        if (launcherUrl.toString() !== "") {
            entries.push({
                label: i18n("Keep in Dock"),
                check: pinned ? 1 : 0,
                trigger: () => pinned ? tasks.requestRemoveLauncher(launcherUrl) : tasks.requestAddLauncher(launcherUrl)
            });
        }

        if (running) {
            entries.push({separator: true});
            const ids = model.WinIdList || [];
            if (windows.length > 1 && ids.length > 0) {
                entries.push({label: i18n("Show All Windows"), trigger: () => dock.showWindows(ids)});
            }
            entries.push({
                label: i18n("Hide"),
                trigger: () => {
                    for (const w of windowIndexes()) {
                        if (tasks.data(w, TaskManager.AbstractTasksModel.IsMinimized) !== true) {
                            tasks.requestToggleMinimized(w);
                        }
                    }
                }
            });
            entries.push({label: i18n("Quit"), trigger: () => tasks.requestClose(modelIndex())});
        }
        // Entries with a check column get it for all rows; only windows and
        // Keep in Dock carry one, as in macOS.
        return entries;
    }

    function openMenu() {
        refreshPinned();
        dock.loadAppActions(launcherUrl, actions => dock.menu.popup(item, menuEntries(actions)));
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
                item.openMenu();
            } else if (mouseEvent.button === Qt.MiddleButton) {
                item.tasks.requestNewInstance(item.modelIndex());
            } else {
                item.tasks.requestActivate(item.modelIndex());
            }
        }
    }
}
