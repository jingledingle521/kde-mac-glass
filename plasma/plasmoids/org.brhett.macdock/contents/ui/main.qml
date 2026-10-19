import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support
import org.kde.layershell as LayerShell
import org.brhett.macdock

// macOS-style dock: pinned apps first, running apps after them, a dot under
// every running app, a bounce while an app is starting or wants attention.
//
// The dock is its own window, not a Plasma panel. Plasma moves and resizes a
// panel window in two steps a frame apart (position first, then size), so a
// panel-based dock shook on every step of a resize. This window spans the
// bottom of the screen at a fixed size and never moves or resizes: the glass
// bar is drawn inside it (from the Plasma theme's dock artwork), so resizing
// the dock only redraws. KWin blurs behind the bar only, the rest of the
// window lets clicks through, and the space above the bar is reserved for
// windows like a panel's.
//
// The applet itself is an invisible host: add it to any panel.
PlasmoidItem {
    id: root

    // Always a bottom dock.
    readonly property bool vertical: false
    // The whole dock's height: the glass bar. Follows the divider while it's
    // dragged and is saved when it's let go.
    property int dockSize: Plasmoid.configuration.dockSize
    readonly property int thickness: dockSize
    readonly property int minDockSize: 36
    readonly property int maxDockSize: 128
    // Gap between the bar and the screen edge (the floating dock look).
    readonly property int gap: 8

    // Icons are a fixed share of the dock's height (44px in a 62px dock).
    function iconSizeFor(size) {
        return Math.round(size * 0.71 * Plasmoid.configuration.iconScale / 1.45);
    }
    readonly property int iconSize: iconSizeFor(dockSize)
    readonly property int cellSize: Math.round(iconSize * 1.08)
    readonly property int dotSize: Math.max(3, Math.round(iconSize * 0.09))
    readonly property int separatorSpace: Plasmoid.configuration.showSeparator ? Math.round(iconSize * 0.4) : 0
    // Glass between the bar's ends and the first and last icons.
    readonly property int endPadding: Math.round((dockSize - iconSize) / 2)
    // Icons arriving and leaving animate, and the bar's width follows. Off
    // while the divider is dragged (the bar tracks the pointer) and while the
    // dock first fills up.
    property bool animateLayout: false

    // Hiding (the divider's menu turns it on, as on macOS): the dock slides
    // off the bottom of the screen and comes back while the pointer is at
    // the bottom edge where it sits, or on it, or one of its menus is open.
    readonly property bool autoHide: Plasmoid.configuration.autoHide
    readonly property bool dockWanted: barHover.hovered || edgeHover.hovered || dockMenu.opened || resizing
    property bool resizing: false
    property bool dockHidden: false
    onDockWantedChanged: {
        if (dockWanted) {
            hideTimer.stop();
            dockHidden = false;
        } else if (autoHide) {
            hideTimer.restart();
        }
    }
    onAutoHideChanged: {
        if (autoHide) {
            hideTimer.restart();
        } else {
            hideTimer.stop();
            dockHidden = false;
        }
    }
    Timer {
        id: hideTimer
        interval: 700
        onTriggered: if (root.autoHide && !root.dockWanted) root.dockHidden = true
    }
    readonly property int layoutDuration: 280

    Timer {
        running: true
        interval: 1500
        onTriggered: root.animateLayout = true
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Layout.minimumWidth: 0
    Layout.preferredWidth: 0
    Layout.maximumWidth: 0
    Layout.minimumHeight: 0
    Layout.preferredHeight: 0
    Layout.maximumHeight: 0

    // The right-click menu every dock icon shares, and the helper that lists
    // and runs apps' extra actions ("New Private Window"…).
    readonly property alias menu: dockMenu
    readonly property string actionsHelper: Qt.resolvedUrl("../code/actions.py").toString().replace("file://", "")
    property var appActions: ({}) // launcher URL -> [{id, name, icon}]

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function run(command, callback) {
        executable.exec(command, callback);
    }

    // Loads (once) the extra actions of the app behind `launcherUrl`.
    function loadAppActions(launcherUrl, callback) {
        const key = String(launcherUrl);
        if (key === "" || appActions[key] !== undefined) {
            if (callback) {
                callback(appActions[key] || []);
            }
            return;
        }
        run("python3 -I " + shellQuote(actionsHelper) + " list " + shellQuote(key), out => {
            let list = [];
            try {
                list = JSON.parse(out) || [];
            } catch (e) {
                list = [];
            }
            const cache = appActions;
            cache[key] = list;
            appActions = cache;
            if (callback) {
                callback(list);
            }
        });
    }

    function runAppAction(launcherUrl, id) {
        run("python3 -I " + shellQuote(actionsHelper) + " run " + shellQuote(String(launcherUrl)) + " " + shellQuote(id));
    }

    // Shows only `winIds` in KWin's window overview ("Show All Windows").
    function showWindows(winIds) {
        const ids = winIds.map(id => "'" + String(id).replace(/'/g, "") + "'").join(",");
        run("gdbus call --session --dest org.kde.KWin --object-path /org/kde/KWin/Effect/WindowView1 --method org.kde.KWin.Effect.WindowView1.activate " + shellQuote("[" + ids + "]"));
    }

    DockMenu {
        id: dockMenu
        dock: root
    }

    // Places a popup (bubble, menu or stack) centred above the dock item
    // `anchor`, `gap` pixels clear of it, before it is shown (Wayland won't
    // move a window once it is showing).
    function placePopup(dialog, anchor, gap) {
        const win = anchor && anchor.Window ? anchor.Window.window : null;
        if (!win) {
            return false;
        }
        const pos = anchor.mapToItem(null, 0, 0);
        // A layer-shell window doesn't know where it is; the dock's is pinned
        // to the bottom of the screen.
        const left = (win === dockWindow ? dockWindow.screenX : win.x) + pos.x;
        const top = (win === dockWindow ? dockWindow.screenY : win.y) + pos.y;
        const screen = dockWindow.screenGeometry;
        // The size the window will have: its own can lag a frame behind its
        // content, and placing by that put popups over the icon.
        const item = dialog.mainItem;
        const m = dialog.margins;
        const w = item ? item.width + (m ? m.left + m.right : 0) : dialog.width;
        const h = item ? item.height + (m ? m.top + m.bottom : 0) : dialog.height;
        const x = left + (anchor.width - w) / 2;
        const y = top - h - gap;
        dialog.x = Math.round(Math.max(screen.x, Math.min(x, screen.x + screen.width - w)));
        dialog.y = Math.round(Math.max(screen.y, Math.min(y, screen.y + screen.height - h)));
        return true;
    }

    function saveLaunchers() {
        if (String(Plasmoid.configuration.launchers) !== String(tasksModel.launcherList)) {
            Plasmoid.configuration.launchers = tasksModel.launcherList;
        }
    }

    P5Support.DataSource {
        id: executable

        property var callbacks: ({})

        function exec(cmd, callback) {
            if (callback) {
                callbacks[cmd] = callback;
            }
            connectSource(cmd);
        }

        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const callback = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (callback) {
                callback(data["stdout"]);
            }
        }
    }

    TaskManager.TasksModel {
        id: tasksModel

        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterNotMinimized: false

        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
        onLauncherListChanged: root.saveLaunchers()
    }

    Window {
        id: dockWindow

        readonly property rect screenGeometry: Plasmoid.containment.screenGeometry
        // Where the window is on screen (pinned to the bottom edge).
        readonly property real screenX: screenGeometry.x
        readonly property real screenY: screenGeometry.y + screenGeometry.height - height

        width: screenGeometry.width
        // Room for the biggest dock, its shadow and an icon bouncing above it.
        height: root.maxDockSize + root.gap + Math.round(root.iconSizeFor(root.maxDockSize) * 0.5) + 24
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        visible: true

        LayerShell.Window.scope: "macdock"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorBottom
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        // Maximized windows stop above the dock (or use the whole screen when
        // it hides). Only the saved size: windows don't resize along with
        // every step of a drag.
        LayerShell.Window.exclusionZone: root.autoHide ? 0 : Plasmoid.configuration.dockSize + 2 * root.gap

        DockSurface {
            glass: bar
            inputItem: hitArea
            radius: 16
        }

        // What takes the pointer: the bar and the gap under it, or, while the
        // dock is hidden, a strip along the bottom edge where it sits
        // (pointing at it brings the dock back).
        Item {
            id: hitArea
            x: bar.x
            width: bar.width
            y: root.dockHidden ? dockWindow.height - 3 : bar.y
            height: dockWindow.height - y
            HoverHandler {
                id: edgeHover
            }
        }

        KSvg.FrameSvgItem {
            id: shadow
            imagePath: "widgets/panel-background"
            prefix: "shadow"
            x: bar.x - margins.left
            y: bar.y - margins.top
            width: bar.width + margins.left + margins.right
            height: bar.height + margins.top + margins.bottom
        }

        KSvg.FrameSvgItem {
            id: bar
            imagePath: "widgets/panel-background"
            prefix: "south"
            width: row.width + 2 * root.endPadding
            height: root.dockSize
            x: Math.round((dockWindow.width - width) / 2)
            y: dockWindow.height - root.gap - height + (root.dockHidden ? height + root.gap + 12 : 0)

            Behavior on y {
                // Not while the divider resizes it (the bar follows the pointer).
                enabled: root.animateLayout
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            HoverHandler {
                id: barHover
            }

            Row {
                id: row
                x: root.endPadding
                height: parent.height

                // The apps. A ListView, not a Repeater, so icons can grow in
                // when an app opens and shrink away when it quits, with their
                // neighbours sliding over, as on macOS.
                ListView {
                    id: taskList
                    width: contentWidth
                    height: parent.height
                    orientation: ListView.Horizontal
                    interactive: false
                    model: tasksModel

                    Behavior on width {
                        enabled: root.animateLayout
                        NumberAnimation { duration: root.layoutDuration; easing.type: Easing.OutCubic }
                    }

                    delegate: DockItem {
                        dock: root
                        tasks: tasksModel
                        repeaterCount: taskList.count
                    }

                    add: Transition {
                        enabled: root.animateLayout
                        NumberAnimation { property: "scale"; from: 0.3; to: 1; duration: root.layoutDuration; easing.type: Easing.OutBack }
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.layoutDuration * 0.6 }
                    }
                    remove: Transition {
                        enabled: root.animateLayout
                        NumberAnimation { property: "scale"; to: 0.3; duration: root.layoutDuration; easing.type: Easing.InCubic }
                        NumberAnimation { property: "opacity"; to: 0; duration: root.layoutDuration }
                    }
                    // Neighbours slide into place; the icon being dragged
                    // itself follows the pointer without animating.
                    addDisplaced: Transition {
                        enabled: root.animateLayout
                        NumberAnimation { property: "x"; duration: root.layoutDuration; easing.type: Easing.OutCubic }
                    }
                    removeDisplaced: Transition {
                        enabled: root.animateLayout
                        NumberAnimation { property: "x"; duration: root.layoutDuration; easing.type: Easing.OutCubic }
                    }
                    moveDisplaced: Transition {
                        enabled: root.animateLayout
                        NumberAnimation { property: "x"; duration: root.layoutDuration * 0.7; easing.type: Easing.OutCubic }
                    }
                }

                // Thin divider between the apps and the stacks/trash, as on
                // macOS. Dragging it resizes the dock, as on macOS.
                Item {
                    visible: Plasmoid.configuration.showSeparator
                    width: root.separatorSpace
                    height: root.thickness

                    MouseArea {
                        id: divider
                        property real startY
                        property int startSize

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.SizeVerCursor
                        // Right-click: the dock's own menu, as on macOS.
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                root.menu.popup(divider, [
                                    {
                                        label: root.autoHide ? i18n("Turn Hiding Off") : i18n("Turn Hiding On"),
                                        trigger: () => Plasmoid.configuration.autoHide = !root.autoHide
                                    }
                                ]);
                            }
                        }
                        // The window never moves, so its coordinates are the
                        // screen's: the pointer's height in it is all it takes.
                        onPressed: mouse => {
                            if (mouse.button !== Qt.LeftButton) {
                                return;
                            }
                            startY = mapToItem(null, mouse.x, mouse.y).y;
                            startSize = root.dockSize;
                            root.animateLayout = false;
                            root.resizing = true;
                        }
                        onPositionChanged: mouse => {
                            if (pressed && (pressedButtons & Qt.LeftButton)) {
                                const size = startSize + Math.round(startY - mapToItem(null, mouse.x, mouse.y).y);
                                root.dockSize = Math.max(root.minDockSize, Math.min(root.maxDockSize, size));
                            }
                        }
                        onReleased: mouse => {
                            if (mouse.button !== Qt.LeftButton) {
                                return;
                            }
                            Plasmoid.configuration.dockSize = root.dockSize;
                            root.animateLayout = true;
                            root.resizing = false;
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: root.iconSize * 0.9
                        color: Kirigami.Theme.textColor
                        opacity: 0.28
                    }
                }

                DownloadsStack {
                    dock: root
                    onRun: (command, callback) => executable.exec(command, callback)
                }

                DockTrash {
                    dock: root
                    onRun: (command, callback) => executable.exec(command, callback)
                }
            }
        }
    }
}
