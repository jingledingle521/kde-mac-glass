import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// Shows the active window's application name in bold, like "Finder" in the
// macOS menu bar. With no window focused it shows "Desktop". Clicking it opens
// the app menu: About, Settings…, Hide, Hide Others, Show All, Quit. About,
// Settings and Quit use the app's own global-menu items when it has them.
PlasmoidItem {
    id: root

    property string activeName: ""
    property string activeAppId: ""
    property string menuService: ""
    property string menuPath: ""
    // Which app-menu items were found in the app's global menu.
    property var found: ({})

    readonly property string helper: Qt.resolvedUrl("../code/appmenu_action.py").toString().replace("file://", "")

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""

    Layout.minimumWidth: label.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    Layout.fillHeight: true

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMinimized: false
    }

    Instantiator {
        model: tasks
        delegate: QtObject {
            required property var model
            readonly property bool active: model.IsActive === true
            readonly property string name: model.AppName || model.display || ""
            onActiveChanged: root.update()
            onNameChanged: if (active) root.update()
        }
        onObjectAdded: root.update()
        onObjectRemoved: root.update()
    }

    function update() {
        // Keep the current app while our own menu is open.
        if (appMenu.opened) {
            return;
        }
        const idx = tasks.activeTask;
        if (idx && idx.valid) {
            const name = tasks.data(idx, TaskManager.AbstractTasksModel.AppName) || tasks.data(idx, Qt.DisplayRole);
            activeName = name || "";
            activeAppId = tasks.data(idx, TaskManager.AbstractTasksModel.AppId) || "";
            menuService = tasks.data(idx, TaskManager.AbstractTasksModel.ApplicationMenuServiceName) || "";
            menuPath = tasks.data(idx, TaskManager.AbstractTasksModel.ApplicationMenuObjectPath) || "";
        } else {
            activeName = "";
            activeAppId = "";
            menuService = "";
            menuPath = "";
        }
    }

    Connections {
        target: tasks
        function onActiveTaskChanged() {
            root.update();
        }
    }

    P5Support.DataSource {
        id: executable
        property var callbacks: ({})
        property int serial: 0
        engine: "executable"
        connectedSources: []

        function exec(cmd, callback) {
            // A unique suffix so repeated identical commands still run.
            const source = cmd + " #" + (++serial);
            if (callback) {
                callbacks[source] = callback;
            }
            connectSource(source);
        }
        onNewData: (sourceName, data) => {
            const callback = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (callback) {
                callback(data["stdout"] || "");
            }
        }
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function menuCommand(action, callback) {
        executable.exec("python3 -I " + shellQuote(helper) + " " + shellQuote(menuService) + " "
                        + shellQuote(menuPath) + " " + shellQuote(activeName) + " " + action, callback);
    }

    function probe() {
        found = {};
        if (!menuService || !menuPath) {
            return;
        }
        menuCommand("probe", out => {
            try {
                root.found = JSON.parse(out) || {};
            } catch (e) {
                root.found = {};
            }
        });
    }

    // Runs `fn(index)` for every window, with whether it belongs to the active app.
    function forEachWindow(fn) {
        for (let i = 0; i < tasks.rowCount(); ++i) {
            const idx = tasks.index(i, 0);
            fn(idx, tasks.data(idx, TaskManager.AbstractTasksModel.AppId) === activeAppId);
        }
    }

    function minimized(idx) {
        return tasks.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true;
    }

    function hideApp(mine) {
        forEachWindow((idx, isApp) => {
            if (isApp === mine && !minimized(idx)) {
                tasks.requestToggleMinimized(idx);
            }
        });
    }

    function showAll() {
        forEachWindow((idx, isApp) => {
            if (minimized(idx)) {
                tasks.requestToggleMinimized(idx);
            }
        });
    }

    function quitApp() {
        if (found.quit) {
            menuCommand("quit");
            return;
        }
        // No Quit item: close the app's windows instead.
        forEachWindow((idx, isApp) => {
            if (isApp) {
                tasks.requestClose(idx);
            }
        });
    }

    MouseArea {
        id: button
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.activeName !== ""

        onPressed: {
            if (appMenu.opened) {
                appMenu.close();
            } else {
                root.probe();
                appMenu.openRelative();
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Kirigami.Units.smallSpacing / 2
            anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: appMenu.opened ? 0.15 : (button.containsMouse ? 0.08 : 0)
        }
    }

    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        text: root.activeName || i18n("Desktop")
        font.weight: Font.Bold
        textFormat: Text.PlainText
    }

    // A Qt menu (like the global menu) so it gets the same MacGlass look.
    PlasmaExtras.Menu {
        id: appMenu
        readonly property bool opened: status === PlasmaExtras.Menu.Open
        visualParent: button
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        onStatusChanged: if (status === PlasmaExtras.Menu.Closed) root.update()

        PlasmaExtras.MenuItem {
            text: i18n("About %1", root.activeName)
            enabled: root.found.about === true
            onClicked: root.menuCommand("about")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Settings…")
            enabled: root.found.settings === true
            onClicked: root.menuCommand("settings")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Hide %1", root.activeName)
            onClicked: root.hideApp(true)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Hide Others")
            onClicked: root.hideApp(false)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Show All")
            onClicked: root.showAll()
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Quit %1", root.activeName)
            onClicked: root.quitApp()
        }
    }
}
