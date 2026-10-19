import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.brhett.macdock

// macOS notifications. In the menu bar it is the date and time; clicking it
// slides Notification Center in from the right: each app's notifications as
// a stack of glass cards, then a Calendar widget. New notifications arrive as
// glass banners sliding in at the top right.
//
// Both are layer-shell windows of their own (not Plasma dialogs) so they sit
// exactly where macOS puts them and can animate; the org.brhett.macdock helper
// blurs behind each card and lets clicks through the rest. Replaces the stock
// notifications widget (and clock), which must be removed so this one owns
// the popups.
PlasmoidItem {
    id: root

    property var now: new Date()
    readonly property int cardWidth: 344
    readonly property int edge: 10
    readonly property int cardSpacing: 10

    readonly property bool dndOn: notificationSettings.notificationsInhibitedUntil > now
    readonly property bool inhibited: {
        if (!NotificationManager.Server.valid) {
            return false;
        }
        return dndOn
            || notificationSettings.notificationsInhibitedByApplication
            || (notificationSettings.inhibitNotificationsWhenFullscreen && notificationSettings.fullscreenFocused)
            || (notificationSettings.inhibitNotificationsWhenScreensMirrored && notificationSettings.screensMirrored);
    }
    onInhibitedChanged: NotificationManager.Server.inhibited = inhibited

    readonly property rect screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)

    function toggleDnd() {
        if (dndOn) {
            notificationSettings.notificationsInhibitedUntil = new Date(NaN);
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = until;
        }
        notificationSettings.save();
        now = new Date();
    }

    preferredRepresentation: compactRepresentation
    // Never shown (Notification Center is its own window), but without one
    // Plasma uses this item as the widget and never makes the clock.
    fullRepresentation: Item {}
    Plasmoid.icon: "preferences-desktop-notification-bell"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: ""
    toolTipSubText: ""

    // The widget's global shortcut (Meta+N): Notification Center, not the
    // empty placeholder popup.
    activationTogglesExpanded: false
    Connections {
        target: Plasmoid
        function onActivated() {
            center.toggle();
        }
    }

    // Ticks on the minute, for the clock and the cards' ages.
    Timer {
        id: clockTimer
        running: true
        interval: 60000 - Date.now() % 60000 + 20
        onTriggered: {
            root.now = new Date();
            interval = 60000 - Date.now() % 60000 + 20;
            restart();
        }
    }

    NotificationManager.Settings {
        id: notificationSettings
    }

    // Runs the calendar-app helper.
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    function openCalendarApp() {
        const helper = Qt.resolvedUrl("../code/calendarapp.sh").toString().replace("file://", "");
        executable.connectSource("sh '" + helper.replace(/'/g, "'\\''") + "'");
    }

    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
        blacklistedDesktopEntries: notificationSettings.historyBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.historyBlacklistedServices
        urgencies: NotificationManager.Notifications.CriticalUrgency
                   | NotificationManager.Notifications.NormalUrgency
                   | (notificationSettings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : 0)

        onRowsInserted: center.queueRebuild()
        onRowsRemoved: center.queueRebuild()
        onDataChanged: center.queueRebuild()
        onModelReset: center.queueRebuild()
        onLayoutChanged: center.queueRebuild()
    }

    NotificationManager.Notifications {
        id: popups
        limit: Math.max(1, Math.floor(bannerWindow.height / 90))
        showExpired: false
        showDismissed: false
        showJobs: false
        blacklistedDesktopEntries: notificationSettings.popupBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.popupBlacklistedServices
        whitelistedDesktopEntries: root.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: root.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedServices : []
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: {
            let u = 0;
            if (!root.inhibited || notificationSettings.criticalPopupsInDoNotDisturbMode) {
                u |= NotificationManager.Notifications.CriticalUrgency;
            }
            if (!root.inhibited) {
                u |= NotificationManager.Notifications.NormalUrgency;
                if (notificationSettings.lowPriorityPopups) {
                    u |= NotificationManager.Notifications.LowUrgency;
                }
            }
            return u;
        }
    }

    // ---- banners ------------------------------------------------------------
    // A column of cards in a tall, narrow window at the top right, under the
    // menu bar. Only the cards take clicks.
    Window {
        id: bannerWindow

        width: root.cardWidth + 2 * root.edge + 8
        height: Math.round(root.screenGeometry.height * 0.7)
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        // Hidden behind an open Notification Center, as on macOS.
        visible: bannerRepeater.count > 0 && !center.open

        LayerShell.Window.scope: "macnotifications"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        // Below the menu bar, not over it.
        LayerShell.Window.exclusionZone: 0

        GlassSurface {}

        Column {
            x: bannerWindow.width - root.edge - root.cardWidth
            y: root.edge
            width: root.cardWidth
            spacing: root.cardSpacing

            move: Transition {
                NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic }
            }

            Repeater {
                id: bannerRepeater
                model: popups

                onItemAdded: (index, item) => popups.playSoundHint(popups.index(index, 0))
                onItemRemoved: (index, item) => {
                    // Removed by a filter change: let the model time it out again.
                    if (!item.leaving) {
                        popups.startTimeout(item.notificationId);
                    }
                }

                delegate: NotificationCard {
                    id: banner

                    required property int index
                    required property var model
                    required property string notificationId
                    required applicationName
                    required applicationIconName
                    required iconName
                    required image
                    required summary
                    required body
                    required property date created
                    required property date updated
                    required actionNames
                    required actionLabels
                    required hasDefaultAction
                    required closable
                    required property bool resident
                    required property int timeout
                    required property int urgency
                    required property string desktopEntry
                    required property string notifyRcName

                    readonly property int effectiveTimeout: timeout === -1 ? notificationSettings.popupTimeout : timeout
                    property bool leaving: false
                    // Slides in from the screen edge, and out again.
                    property real slide: bannerWindow.width - x

                    function idx() {
                        return popups.index(index, 0);
                    }

                    // Slides out, then lets `done` remove it.
                    function leave(done) {
                        if (leaving) {
                            return;
                        }
                        leaving = true;
                        expireTimer.stop();
                        slideOut.done = done;
                        slideOut.start();
                    }

                    width: root.cardWidth
                    now: root.now
                    bodyLines: 3
                    time: isNaN(updated) ? created : updated
                    transform: Translate { x: banner.slide }

                    onHoveredChanged: {
                        if (hovered) {
                            model.read = true;
                            expireTimer.stop();
                        } else if (effectiveTimeout > 0 && !leaving) {
                            expireTimer.restart();
                        }
                    }
                    onCloseClicked: leave(() => popups.close(idx()))
                    onClicked: {
                        if (hasDefaultAction) {
                            popups.invokeDefaultAction(idx(), NotificationManager.Notifications.Close);
                        } else {
                            leave(() => popups.close(idx()));
                        }
                    }
                    onActionClicked: name => popups.invokeAction(idx(), name, NotificationManager.Notifications.Close)

                    NumberAnimation on slide {
                        id: slideIn
                        to: 0
                        duration: 380
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: slideOut
                        property var done
                        target: banner
                        property: "slide"
                        to: bannerWindow.width - banner.x
                        duration: 260
                        easing.type: Easing.InCubic
                        onFinished: done()
                    }

                    Timer {
                        id: expireTimer
                        interval: banner.effectiveTimeout
                        running: banner.effectiveTimeout > 0 && banner.urgency !== NotificationManager.Notifications.CriticalUrgency
                        onTriggered: banner.leave(() => {
                            if (banner.resident || banner.actionNames.length > 0 || banner.hasDefaultAction) {
                                // Kept in Notification Center so its actions still work.
                                banner.model.expired = true;
                            } else {
                                popups.expire(banner.idx());
                            }
                        })
                    }

                    Component.onCompleted: {
                        if (desktopEntry && !notifyRcName) {
                            notificationSettings.registerKnownApplication(desktopEntry);
                            notificationSettings.save();
                        }
                        // This banner times itself out.
                        popups.stopTimeout(idx());
                    }
                }
            }
        }
    }

    // ---- Notification Center -------------------------------------------------
    // Covers the screen between the menu bar and the dock (clicking anywhere
    // outside the cards closes it); the cards slide in along the right edge.
    Window {
        id: center

        property bool open: false
        property real slide: width
        property var groups: []
        property var expandedGroups: ({})
        // Every group slides away before Clear All empties the history.
        property bool clearingAll: false
        readonly property int cardSpacing: root.cardSpacing
        readonly property alias now: root.now

        function toggle() {
            open ? close() : show();
        }
        function show() {
            if (open) {
                return;
            }
            rebuild();
            if (!hideAnimation.running) {
                slide = column.width;
            }
            open = true;
            visible = true;
            requestActivate();
            hideAnimation.stop();
            showAnimation.start();
        }
        function close() {
            if (!open) {
                return;
            }
            open = false;
            showAnimation.stop();
            hideAnimation.start();
            history.lastRead = undefined; // everything seen counts as read
        }

        function queueRebuild() {
            Qt.callLater(rebuild);
        }

        // The history as macOS groups it: one group per app, newest app first.
        function rebuild() {
            const R = NotificationManager.Notifications;
            const byKey = {};
            const list = [];
            for (let row = 0; row < history.rowCount(); ++row) {
                const i = history.index(row, 0);
                const get = role => history.data(i, role);
                const created = get(R.CreatedRole);
                const updated = get(R.UpdatedRole);
                const n = {
                    id: get(R.IdRole),
                    appName: get(R.ApplicationNameRole) || "",
                    appIcon: get(R.ApplicationIconNameRole) || "",
                    iconName: get(R.IconNameRole) || "",
                    image: get(R.ImageRole),
                    summary: get(R.SummaryRole) || "",
                    body: get(R.BodyRole) || "",
                    time: updated && !isNaN(updated) ? updated : created,
                    actionNames: get(R.ActionNamesRole) || [],
                    actionLabels: get(R.ActionLabelsRole) || [],
                    hasDefaultAction: get(R.HasDefaultActionRole) === true
                };
                const key = get(R.DesktopEntryRole) || n.appName || String(n.id);
                if (!byKey[key]) {
                    byKey[key] = {key: key, name: n.appName, items: []};
                    list.push(byKey[key]);
                }
                byKey[key].items.push(n);
            }
            for (const g of list) {
                g.items.sort((a, b) => b.time - a.time);
            }
            list.sort((a, b) => b.items[0].time - a.items[0].time);
            groups = list;
        }

        function rowOf(id) {
            for (let row = 0; row < history.rowCount(); ++row) {
                const i = history.index(row, 0);
                if (history.data(i, NotificationManager.Notifications.IdRole) === id) {
                    return i;
                }
            }
            return null;
        }
        function closeNotification(id) {
            const i = rowOf(id);
            if (i) {
                history.close(i);
            }
        }
        function clearGroup(key) {
            const group = groups.find(g => g.key === key);
            if (group) {
                for (const n of group.items) {
                    closeNotification(n.id);
                }
            }
        }
        function clearAll() {
            if (!clearingAll) {
                clearingAll = true;
                clearAllTimer.start();
            }
        }
        function invokeDefault(id) {
            const i = rowOf(id);
            if (i) {
                history.invokeDefaultAction(i, NotificationManager.Notifications.Close);
                close();
            }
        }
        function invokeAction(id, name) {
            const i = rowOf(id);
            if (i) {
                history.invokeAction(i, name, NotificationManager.Notifications.Close);
                close();
            }
        }
        function setExpanded(key, on) {
            const map = Object.assign({}, expandedGroups);
            map[key] = on;
            expandedGroups = map;
        }

        width: root.screenGeometry.width
        height: root.screenGeometry.height
        color: "transparent"
        flags: Qt.FramelessWindowHint
        visible: false

        LayerShell.Window.scope: "macnotificationcenter"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        // Between the menu bar and the dock.
        LayerShell.Window.exclusionZone: 0

        // Switching to another window closes it.
        onActiveChanged: if (!active && open) close()

        Timer {
            id: clearAllTimer
            interval: 320
            onTriggered: {
                history.clear(NotificationManager.Notifications.ClearExpired);
                for (const g of center.groups) {
                    center.clearGroup(g.key);
                }
                // Gone from the list before the groups stop hiding.
                center.rebuild();
                center.clearingAll = false;
            }
        }

        NumberAnimation {
            id: showAnimation
            target: center
            property: "slide"
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: hideAnimation
            target: center
            property: "slide"
            to: center.width - column.x
            duration: 220
            easing.type: Easing.InCubic
            onFinished: {
                center.visible = false;
                center.expandedGroups = {};
            }
        }

        GlassSurface {
            clickThrough: false
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: center.close()

            MouseArea {
                anchors.fill: parent
                onClicked: center.close()
            }
        }

        Flickable {
            id: column
            x: center.width - width
            width: root.cardWidth + 2 * root.edge
            height: center.height
            contentWidth: width
            contentHeight: content.implicitHeight + 2 * root.edge
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            transform: Translate { x: center.slide }

            ColumnLayout {
                id: content
                x: root.edge
                y: root.edge
                width: root.cardWidth
                spacing: root.cardSpacing

                // macOS's ⓧ that becomes "Clear All" when pointed at.
                GlassButton {
                    Layout.alignment: Qt.AlignRight
                    visible: center.groups.length > 1
                    closeIcon: true
                    expandText: i18n("Clear All")
                    onClicked: center.clearAll()
                }

                Repeater {
                    model: center.groups
                    delegate: NotificationGroup {
                        Layout.fillWidth: true
                        nc: center
                    }
                }

                CalendarWidget {
                    Layout.fillWidth: true
                    Layout.topMargin: center.groups.length > 0 ? 6 : 0
                    now: root.now
                    onOpenApp: {
                        center.close();
                        root.openCalendarApp();
                    }
                }

                GlassButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    text: i18n("Notification Settings…")
                    onClicked: {
                        center.close();
                        KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications");
                    }
                }
            }
        }
    }

    // ---- menu bar -------------------------------------------------------------
    // The date and time, as macOS shows them; a moon while Do Not Disturb is on.
    compactRepresentation: MouseArea {
        property bool wasOpen: false

        Layout.minimumWidth: clockRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // Clicking the clock while it's open closes it, though the press
        // itself already took focus from it.
        onPressed: wasOpen = center.open || hideAnimation.running
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.MiddleButton) {
                root.toggleDnd();
            } else if (wasOpen) {
                center.close();
            } else {
                center.show();
            }
        }

        RowLayout {
            id: clockRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 1.5

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                visible: root.dndOn
                source: "weather-clear-night-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                text: Qt.formatDate(root.now, "ddd MMM d") + " " + Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
                textFormat: Text.PlainText
                // A point under the system font, like the menu titles.
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            }
        }
    }
}
