import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support

// macOS-style dock: pinned apps first, running apps after them, a dot under
// every running app, a bounce while an app is starting or wants attention.
PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int thickness: vertical ? width : height
    // The panel theme pads the applet area, so icons are allowed to grow past
    // it into that padding, the way macOS dock icons nearly fill the dock.
    readonly property int iconSize: Math.round(thickness * Plasmoid.configuration.iconScale)
    readonly property int cellSize: Math.round(iconSize * 1.08)
    readonly property int dotSize: Math.max(3, Math.round(iconSize * 0.09))
    readonly property int separatorSpace: Plasmoid.configuration.showSeparator ? Math.round(iconSize * 0.4) : 0

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    Layout.minimumWidth: vertical ? -1 : row.implicitWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: vertical ? row.implicitHeight : -1
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

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

    // Places a popup (bubble or menu) centred on the icon `anchor`, `gap`
    // pixels clear of it, before it is shown: Plasma's own popup placement
    // sized these wrong, and Wayland won't move a window once it is showing.
    // Measured from the icon, not the panel window (which is taller than the
    // dock you see and moves as the dock hides and shows).
    function placePopup(dialog, anchor, gap) {
        const win = anchor && anchor.Window ? anchor.Window.window : null;
        if (!win) {
            return false;
        }
        const pos = anchor.mapToItem(null, 0, 0);
        const left = win.x + pos.x;
        const top = win.y + pos.y;
        const screen = Plasmoid.containment.screenGeometry;
        // The size the window will have: its own can lag a frame behind its
        // content, and placing by that put popups over the icon.
        const item = dialog.mainItem;
        const m = dialog.margins;
        const w = item ? item.width + (m ? m.left + m.right : 0) : dialog.width;
        const h = item ? item.height + (m ? m.top + m.bottom : 0) : dialog.height;
        let x, y;
        switch (Plasmoid.location) {
        case PlasmaCore.Types.LeftEdge:
            x = left + anchor.width + gap;
            y = top + (anchor.height - h) / 2;
            break;
        case PlasmaCore.Types.RightEdge:
            x = left - w - gap;
            y = top + (anchor.height - h) / 2;
            break;
        case PlasmaCore.Types.TopEdge:
            x = left + (anchor.width - w) / 2;
            y = top + anchor.height + gap;
            break;
        default: // bottom dock
            x = left + (anchor.width - w) / 2;
            y = top - h - gap;
        }
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

    Flow {
        id: row
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight

        Repeater {
            id: repeater
            model: tasksModel
            delegate: DockItem {
                dock: root
                tasks: tasksModel
                repeaterCount: repeater.count
            }
        }

        // Thin divider between the apps and the stacks/trash, as on macOS.
        Item {
            visible: Plasmoid.configuration.showSeparator
            width: root.vertical ? root.thickness : root.separatorSpace
            height: root.vertical ? root.separatorSpace : root.thickness

            Rectangle {
                anchors.centerIn: parent
                width: root.vertical ? root.iconSize * 0.9 : 1
                height: root.vertical ? 1 : root.iconSize * 0.9
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
