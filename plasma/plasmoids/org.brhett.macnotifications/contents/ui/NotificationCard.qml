import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kquickcontrolsaddons as KQuickAddons
import org.kde.kirigami as Kirigami

// One macOS notification on glass: the app's icon, a bold title with its age
// on the right, the body under it, a picture the app sent on the right, and
// action capsules at the bottom. On hover a round close button sits over the
// top-left corner.
Item {
    id: card

    property string applicationName
    property string applicationIconName
    property string iconName
    property var image
    property string summary
    property string body
    property date time
    property var now: new Date()
    property var actionNames: []
    property var actionLabels: []
    property bool closable: true
    property bool hasDefaultAction: false
    property int bodyLines: 4
    // Lower cards of a collapsed stack: glass only, and only the part below
    // `clipTop` (the rest is behind the card above, which is see-through).
    property bool contentVisible: true
    property real clipTop: 0
    property real strength: 1
    property real contentOpacity: contentVisible ? 1 : 0
    Behavior on contentOpacity {
        NumberAnimation { duration: 200 }
    }
    readonly property bool hovered: cardHover.hovered || closeHover.hovered
    readonly property int padding: 12
    readonly property bool hasImage: image !== undefined && image !== null && imageItem.nativeWidth > 0
    readonly property var visibleActions: {
        const list = [];
        for (let i = 0; i < actionNames.length; ++i) {
            if (actionNames[i] !== "default" && actionLabels[i]) {
                list.push({name: actionNames[i], label: actionLabels[i]});
            }
        }
        return list;
    }

    signal closeClicked()
    signal clicked()
    signal actionClicked(string actionName)

    function age() {
        if (isNaN(time.getTime())) {
            return "";
        }
        const mins = Math.floor((now - time) / 60000);
        if (mins < 1) {
            return i18n("now");
        }
        if (mins < 60) {
            return i18nc("minutes ago, short", "%1m ago", mins);
        }
        if (mins < 24 * 60) {
            return i18nc("hours ago, short", "%1h ago", Math.floor(mins / 60));
        }
        if (mins < 48 * 60) {
            return i18n("Yesterday");
        }
        return Qt.formatDate(time, "ddd");
    }

    implicitWidth: 344
    implicitHeight: Math.max(layout.implicitHeight, appIcon.height) + 2 * padding

    Item {
        y: card.clipTop
        width: card.width
        height: Math.max(0, card.height - card.clipTop)
        clip: card.clipTop > 0

        GlassCard {
            y: -card.clipTop
            width: card.width
            height: card.height
            hovered: card.hovered && card.contentVisible
            strength: card.strength
            // Clicks reach the close button hanging over the corner.
            inputMargin: 10
        }
    }

    HoverHandler {
        id: cardHover
        cursorShape: card.contentVisible ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        // Takes the click for itself: in Notification Center a click that
        // reached the window behind the cards would close it.
        gesturePolicy: TapHandler.ReleaseWithinBounds
        // The close button and action capsules handle their own clicks.
        onTapped: if (!closeHover.hovered && !actionsHover.hovered) card.clicked()
    }

    Kirigami.Icon {
        id: appIcon
        x: card.padding
        y: card.padding
        width: 36
        height: 36
        opacity: card.contentOpacity
        visible: opacity > 0
        source: card.applicationIconName || card.iconName || "preferences-desktop-notification-bell"
        roundToIconSize: false
    }

    ColumnLayout {
        id: layout
        opacity: card.contentOpacity
        visible: opacity > 0
        anchors.left: appIcon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: card.padding
        y: card.padding - 1
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: card.summary || card.applicationName
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            PlasmaComponents3.Label {
                text: card.age()
                opacity: 0.5
                font: Kirigami.Theme.smallFont
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                visible: text.length > 0
                text: card.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.bodyLines
                elide: Text.ElideRight
                opacity: 0.85
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // A picture the app sent (a contact photo, a screenshot).
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: card.hasImage ? 40 : 0
                Layout.preferredHeight: Layout.preferredWidth
                visible: card.hasImage
                radius: 8
                color: "transparent"
                clip: true

                KQuickAddons.QImageItem {
                    id: imageItem
                    anchors.fill: parent
                    image: card.image !== undefined && card.image !== null ? card.image : undefined
                    fillMode: KQuickAddons.QImageItem.PreserveAspectCrop
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 6
            visible: card.visibleActions.length > 0

            HoverHandler {
                id: actionsHover
            }
            Repeater {
                model: card.visibleActions
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 8
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, actionMouse.containsMouse ? 0.2 : 0.12)

                    PlasmaComponents3.Label {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: parent.modelData.label
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: card.actionClicked(parent.modelData.name)
                    }
                }
            }
        }
    }

    // macOS close button: a small round ⓧ over the top-left corner.
    GlassCard {
        x: -7
        y: -7
        width: 22
        height: 22
        radius: 11
        strength: 1.3
        visible: card.closable && card.contentVisible && card.hovered
        hovered: closeHover.hovered

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 10
            height: 10
            source: "window-close-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
        }
        HoverHandler {
            id: closeHover
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: card.closeClicked()
        }
    }
}
