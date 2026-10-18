import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.notificationmanager as NotificationManager
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

// macOS Notification Center: banners slide in at the top right under the menu
// bar, and the bar icon opens a panel listing earlier notifications with
// Do Not Disturb and Clear All. Replaces the stock notifications widget, which
// must be removed from the tray so this one owns the popups.
PlasmoidItem {
    id: root

    property var now: new Date()
    readonly property int cardWidth: Kirigami.Units.gridUnit * 20
    readonly property int edgeDistance: Kirigami.Units.largeSpacing
    readonly property int bannerSpacing: Kirigami.Units.smallSpacing * 2

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

    // The available area of this screen in global coordinates (excludes the bar).
    readonly property rect screenRect: {
        const c = Plasmoid.containment;
        if (!c) {
            return Qt.rect(0, 0, -1, -1);
        }
        return Qt.rect(c.screenGeometry.x + c.availableScreenRect.x,
                       c.screenGeometry.y + c.availableScreenRect.y,
                       c.availableScreenRect.width,
                       c.availableScreenRect.height);
    }
    onScreenRectChanged: Qt.callLater(positionBanners)

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

    function positionBanners() {
        if (screenRect.width <= 0) {
            return;
        }
        let y = screenRect.y + edgeDistance;
        for (let i = 0; i < banners.count; ++i) {
            const banner = banners.objectAt(i);
            if (!banner) {
                continue;
            }
            const x = screenRect.x + screenRect.width - edgeDistance - banner.width;
            // Always show the newest; drop the rest once they'd cover most of the screen.
            const show = i === 0 || y + banner.height < screenRect.y + screenRect.height * 0.8;
            if (banner.visible && (banner.x !== x || banner.y !== y)) {
                // Wayland ignores moves of a mapped window, so remap it at the new spot.
                banner.visible = false;
            }
            banner.x = x;
            banner.y = y;
            banner.visible = show;
            y += banner.height + (banner.height > 0 ? bannerSpacing : 0);
        }
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: dndOn ? "notifications-disabled" : "notifications"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: ""
    toolTipSubText: ""

    onExpandedChanged: {
        if (expanded) {
            now = new Date();
        } else {
            history.lastRead = undefined; // everything seen counts as read
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    NotificationManager.Settings {
        id: notificationSettings
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
    }

    NotificationManager.Notifications {
        id: popups
        limit: Math.max(1, Math.ceil(root.screenRect.height / (Kirigami.Units.gridUnit * 4)))
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

    Instantiator {
        id: banners
        model: popups
        delegate: PlasmaCore.Dialog {
            id: banner

            required property int index
            required property var model
            required property string notificationId
            required property string applicationName
            required property string applicationIconName
            required property var iconName
            required property var image
            required property string summary
            required property string body
            required property date created
            required property date updated
            required property list<string> actionNames
            required property list<string> actionLabels
            required property bool hasDefaultAction
            required property bool closable
            required property bool resident
            required property int timeout
            required property int urgency
            required property string desktopEntry
            required property string notifyRcName

            readonly property int effectiveTimeout: timeout === -1 ? notificationSettings.popupTimeout : timeout

            function idx() {
                return popups.index(index, 0);
            }

            type: PlasmaCore.Dialog.Notification
            flags: Qt.WindowDoesNotAcceptFocus
            location: PlasmaCore.Types.Floating
            visible: false
            onHeightChanged: Qt.callLater(root.positionBanners)

            mainItem: NotificationCard {
                width: root.cardWidth
                drawBackground: false
                now: root.now
                applicationName: banner.applicationName
                applicationIconName: banner.applicationIconName
                iconName: banner.iconName || ""
                image: banner.image
                summary: banner.summary
                body: banner.body
                time: isNaN(banner.updated) ? banner.created : banner.updated
                actionNames: banner.actionNames
                actionLabels: banner.actionLabels
                closable: banner.closable
                hasDefaultAction: banner.hasDefaultAction
                bodyLines: 3

                onContainsMouseChanged: {
                    if (containsMouse) {
                        banner.model.read = true;
                        expireTimer.stop();
                    } else if (banner.effectiveTimeout > 0) {
                        expireTimer.restart();
                    }
                }
                onCloseClicked: popups.close(banner.idx())
                onDefaultActionClicked: popups.invokeDefaultAction(banner.idx(), NotificationManager.Notifications.Close)
                onActionClicked: name => popups.invokeAction(banner.idx(), name, NotificationManager.Notifications.Close)

                Timer {
                    id: expireTimer
                    interval: banner.effectiveTimeout
                    running: banner.effectiveTimeout > 0 && banner.urgency !== NotificationManager.Notifications.CriticalUrgency
                    onTriggered: {
                        if (banner.resident || banner.actionNames.length > 0 || banner.hasDefaultAction) {
                            // Keep it in Notification Center so its actions still work.
                            banner.model.expired = true;
                        } else {
                            popups.expire(banner.idx());
                        }
                    }
                }
            }

            Component.onCompleted: {
                if (desktopEntry && !notifyRcName) {
                    notificationSettings.registerKnownApplication(desktopEntry);
                    notificationSettings.save();
                }
                // This banner handles the timeout itself now.
                popups.stopTimeout(idx());
            }
        }
        onObjectAdded: (index, object) => {
            root.positionBanners();
            popups.playSoundHint(popups.index(index, 0));
        }
        onObjectRemoved: (index, object) => {
            // Banner destroyed by a filter change: let the model time it out again.
            popups.startTimeout(object.notificationId);
            Qt.callLater(root.positionBanners);
        }
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        Layout.minimumWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onPressed: wasExpanded = root.expanded
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.MiddleButton) {
                root.toggleDnd();
            } else {
                root.expanded = !wasExpanded;
            }
        }

        Kirigami.Icon {
            id: bell
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }

        // Blue dot for notifications that arrived since the panel was last opened.
        Rectangle {
            anchors.right: bell.right
            anchors.top: bell.top
            anchors.rightMargin: -2
            anchors.topMargin: -1
            width: Math.round(Kirigami.Units.smallSpacing * 1.75)
            height: width
            radius: width / 2
            color: Kirigami.Theme.highlightColor
            visible: !root.dndOn && history.unreadNotificationsCount > 0
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.preferredWidth: root.cardWidth + Kirigami.Units.mediumSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.preferredHeight: Math.min(implicitHeight, Kirigami.Units.gridUnit * 34)
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Notifications")
                font.weight: Font.Bold
            }
            PlasmaComponents3.ToolButton {
                text: i18n("Clear All")
                visible: history.count > 0
                onClicked: history.clear(NotificationManager.Notifications.ClearExpired)
            }
        }

        // Do Not Disturb row, styled like the macOS Focus toggle.
        MouseArea {
            id: dndRow
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            implicitHeight: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
            hoverEnabled: true
            onClicked: root.toggleDnd()

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 2.5
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, dndRow.containsMouse ? 0.11 : 0.07)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: root.dndOn ? "#5e5ce6" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "weather-clear-night-symbolic"
                        isMask: true
                        color: root.dndOn ? "white" : Kirigami.Theme.textColor
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: i18n("Do Not Disturb")
                        font.weight: Font.DemiBold
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: root.dndOn ? i18n("On") : i18n("Off")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }
            }
        }

        PlasmaComponents3.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: list.contentHeight
            visible: history.count > 0

            ListView {
                id: list
                model: history
                spacing: Kirigami.Units.smallSpacing
                leftMargin: Kirigami.Units.mediumSpacing
                rightMargin: Kirigami.Units.mediumSpacing
                bottomMargin: Kirigami.Units.smallSpacing
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: NotificationCard {
                    id: entry

                    required property int index
                    required property var model

                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    now: root.now
                    applicationName: model.applicationName || ""
                    applicationIconName: model.applicationIconName || ""
                    iconName: model.iconName || ""
                    image: model.image
                    summary: model.summary || ""
                    body: model.body || ""
                    time: isNaN(model.updated) ? model.created : model.updated
                    actionNames: model.actionNames || []
                    actionLabels: model.actionLabels || []
                    closable: true
                    hasDefaultAction: model.hasDefaultAction === true

                    onCloseClicked: history.close(history.index(index, 0))
                    onDefaultActionClicked: {
                        history.invokeDefaultAction(history.index(index, 0), NotificationManager.Notifications.Close);
                        root.expanded = false;
                    }
                    onActionClicked: name => {
                        history.invokeAction(history.index(index, 0), name, NotificationManager.Notifications.Close);
                        root.expanded = false;
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: history.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: NotificationManager.Server.valid ? i18n("No Notifications") : i18n("Notifications are handled by another app")
            opacity: 0.55
        }

        PlasmaComponents3.ToolButton {
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            text: i18n("Notification Settings…")
            onClicked: {
                root.expanded = false;
                KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications");
            }
        }
    }
}
