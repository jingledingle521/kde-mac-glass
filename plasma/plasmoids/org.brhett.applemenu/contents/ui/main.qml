import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string helper: Qt.resolvedUrl("../code/helper.py").toString().replace("file://", "")
    property string fullName: ""
    property var recentApps: []
    property var recentDocs: []

    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Runs a command detached from plasmashell and closes the menu.
    function launch(cmd) {
        executable.exec("setsid -f " + cmd + " >/dev/null 2>&1");
        root.expanded = false;
    }

    function dbus(service, path, method) {
        launch("dbus-send --session --type=method_call --dest=" + service + " " + path + " " + method);
    }

    function helperJson(command, callback) {
        executable.exec("python3 -I " + shellQuote(helper) + " " + command, stdout => {
            try {
                callback(JSON.parse(stdout));
            } catch (e) {
                console.warn("applemenu: helper " + command + " failed:", e);
            }
        });
    }

    function refreshRecent() {
        helperJson("recent", data => {
            recentApps = data.apps;
            recentDocs = data.docs;
        });
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

    Component.onCompleted: helperJson("user", data => fullName = data.name)

    onExpandedChanged: if (root.expanded) refreshRecent()

    ForceQuitWindow {
        id: forceQuitWindow
        onForceQuit: pid => executable.exec("kill -9 " + pid)
    }

    AboutWindow {
        id: aboutWindow
        logo: Plasmoid.configuration.icon
        onMoreInfo: root.launch("kinfocenter")
    }

    compactRepresentation: MouseArea {
        id: compact

        property bool wasExpanded: false

        Layout.minimumWidth: Plasmoid.configuration.iconSize + Kirigami.Units.largeSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        // macOS shows a soft rounded highlight behind the logo while open.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing
            height: Math.min(parent.height - Kirigami.Units.smallSpacing, Plasmoid.configuration.iconSize + Kirigami.Units.smallSpacing * 2)
            radius: 4
            color: Kirigami.Theme.textColor
            opacity: root.expanded ? 0.18 : 0
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Plasmoid.configuration.iconSize
            height: Plasmoid.configuration.iconSize
            source: Plasmoid.configuration.icon
            isMask: Plasmoid.configuration.monochrome
            color: Kirigami.Theme.textColor
            roundToIconSize: false
        }
    }

    fullRepresentation: Item {
        id: menu

        readonly property int menuWidth: Math.max(column.implicitWidth, Kirigami.Units.gridUnit * 14)

        Layout.minimumWidth: menuWidth
        Layout.maximumWidth: menuWidth
        Layout.preferredWidth: menuWidth
        Layout.minimumHeight: column.implicitHeight
        Layout.maximumHeight: column.implicitHeight
        Layout.preferredHeight: column.implicitHeight

        Connections {
            target: root
            function onExpandedChanged() {
                if (!root.expanded) {
                    recentPopup.close();
                }
            }
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: 0

            MacMenuItem {
                text: i18n("About This Computer")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: {
                    root.expanded = false;
                    aboutWindow.showInfo(root);
                }
            }
            MacMenuSeparator {}
            MacMenuItem {
                text: i18n("System Settings…")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.launch("systemsettings")
            }
            MacMenuItem {
                text: i18n("App Store…")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.launch("plasma-discover")
            }
            MacMenuSeparator {}
            MacMenuItem {
                id: recentRow
                text: i18n("Recent Items")
                hasSubmenu: true
                submenuOpen: recentPopup.opened
                onContainsMouseChanged: if (containsMouse) recentPopup.open()
                onClicked: recentPopup.open()
            }
            MacMenuSeparator {}
            MacMenuItem {
                text: i18n("Force Quit…")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: {
                    root.expanded = false;
                    forceQuitWindow.showRefreshed();
                }
            }
            MacMenuSeparator {}
            MacMenuItem {
                text: i18n("Sleep")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.launch("systemctl suspend")
            }
            MacMenuItem {
                text: i18n("Restart…")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot")
            }
            MacMenuItem {
                text: i18n("Shut Down…")
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptShutDown")
            }
            MacMenuSeparator {}
            MacMenuItem {
                text: i18n("Lock Screen")
                shortcut: "⌘L"
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.dbus("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver.Lock")
            }
            MacMenuItem {
                text: root.fullName ? i18n("Log Out %1…", root.fullName) : i18n("Log Out…")
                shortcut: "⌃⌥⌦"
                onContainsMouseChanged: if (containsMouse) recentPopup.close()
                onTriggered: root.dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptLogout")
            }
        }

        // Cascading submenu in its own window so it can extend past the menu.
        PlasmaComponents3.Popup {
            id: recentPopup

            parent: recentRow
            popupType: QQC2.Popup.Window
            x: recentRow.width + Kirigami.Units.smallSpacing
            y: -topPadding
            width: Math.max(recentColumn.implicitWidth + leftPadding + rightPadding, Kirigami.Units.gridUnit * 14)
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

            contentItem: ColumnLayout {
                id: recentColumn
                spacing: 0

                MacMenuHeader {
                    text: i18n("Applications")
                    visible: root.recentApps.length > 0
                }
                Repeater {
                    model: root.recentApps
                    delegate: MacMenuItem {
                        required property var modelData
                        text: modelData.name
                        iconSource: modelData.icon
                        onTriggered: root.launch("kstart --application " + root.shellQuote(modelData.id))
                    }
                }
                MacMenuSeparator {
                    visible: root.recentApps.length > 0 && root.recentDocs.length > 0
                }
                MacMenuHeader {
                    text: i18n("Documents")
                    visible: root.recentDocs.length > 0
                }
                Repeater {
                    model: root.recentDocs
                    delegate: MacMenuItem {
                        required property var modelData
                        text: modelData.name
                        iconSource: modelData.icon
                        onTriggered: root.launch("xdg-open " + root.shellQuote(modelData.path))
                    }
                }
                MacMenuItem {
                    text: i18n("No Recent Items")
                    enabled: false
                    visible: root.recentApps.length === 0 && root.recentDocs.length === 0
                }
                MacMenuSeparator {}
                MacMenuItem {
                    text: i18n("Clear Menu")
                    enabled: root.recentApps.length > 0 || root.recentDocs.length > 0
                    onTriggered: root.helperJson("clear", () => root.refreshRecent())
                }
            }
        }
    }
}
