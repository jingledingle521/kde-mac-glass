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
