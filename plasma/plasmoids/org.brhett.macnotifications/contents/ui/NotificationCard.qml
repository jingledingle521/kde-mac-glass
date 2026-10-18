import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kquickcontrolsaddons as KQuickAddons
import org.kde.kirigami as Kirigami

// One macOS notification: app icon on the left, bold title with the age on
// the right, body underneath, action buttons when the app offers any, and a
// round close button that appears in the top-left corner on hover.
MouseArea {
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
    property bool drawBackground: true
    property int bodyLines: 4

    signal closeClicked()
    signal defaultActionClicked()
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
        return Qt.formatDate(time, Qt.locale().dateFormat(Locale.ShortFormat));
    }

    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2
    hoverEnabled: true
    cursorShape: hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (hasDefaultAction) defaultActionClicked()

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2.5
        visible: card.drawBackground
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, card.containsMouse ? 0.11 : 0.07)
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing
            Layout.preferredHeight: Layout.preferredWidth

            Kirigami.Icon {
                anchors.fill: parent
                source: card.applicationIconName || card.iconName || "preferences-desktop-notification-bell"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(Kirigami.Units.smallSpacing / 2)

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: card.summary || card.applicationName
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                PlasmaComponents3.Label {
                    text: card.age()
                    opacity: 0.55
                    font: Kirigami.Theme.smallFont
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.bodyLines
                elide: Text.ElideRight
                opacity: 0.85
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            KQuickAddons.QImageItem {
                id: imageItem
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.preferredHeight: visible ? Math.min(Kirigami.Units.gridUnit * 8, width * nativeHeight / Math.max(1, nativeWidth)) : 0
                visible: card.image !== undefined && card.image !== null && nativeWidth > 0 && card.iconName === ""
                image: card.image !== undefined && card.image !== null ? card.image : undefined
                fillMode: KQuickAddons.QImageItem.PreserveAspectFit
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing
                visible: card.actionNames.length > 0

                Repeater {
                    model: card.actionNames.length
                    delegate: PlasmaComponents3.Button {
                        required property int index
                        text: card.actionLabels[index] || ""
                        visible: card.actionNames[index] !== "default"
                        onClicked: card.actionClicked(card.actionNames[index])
                    }
                }
            }
        }
    }

    // macOS close button: a small round X over the icon's top-left corner.
    // Kept inside the card so hovering it doesn't end the card's hover.
    Rectangle {
        x: Math.round(Kirigami.Units.smallSpacing / 2)
        y: x
        width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
        height: width
        radius: width / 2
        visible: card.closable && card.containsMouse
        color: closeArea.containsMouse ? Qt.rgba(0.35, 0.35, 0.37, 1) : Qt.rgba(0.22, 0.22, 0.24, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.6)
            height: width
            source: "window-close-symbolic"
            isMask: true
            color: "white"
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.closeClicked()
        }
    }
}
