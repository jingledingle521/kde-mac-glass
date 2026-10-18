import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Gray section title with a disclosure arrow right after the text; clicking
// anywhere on the row toggles the section.
MouseArea {
    id: header

    property alias text: label.text
    property bool expanded: false

    signal toggled()

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled()

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(Kirigami.Units.smallSpacing / 2)

        PlasmaComponents3.Label {
            id: label
            leftPadding: Kirigami.Units.mediumSpacing
            topPadding: Kirigami.Units.smallSpacing / 2
            bottomPadding: Kirigami.Units.smallSpacing / 2
            font.weight: Font.DemiBold
            opacity: header.containsMouse ? 0.8 : 0.5
        }
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            source: "go-next-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: label.opacity
            rotation: header.expanded ? 90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }
}
