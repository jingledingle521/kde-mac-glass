import QtQuick
import org.kde.kirigami as Kirigami
import org.brhett.macdock

// macOS notification glass: KWin blurs behind it (GlassPane), with a
// translucent fill and a faint shadow. No rim: a Rectangle's border replaces
// its fill at the edge, so it showed as a light outline around the card.
GlassPane {
    id: pane

    property bool hovered: false
    // Lower cards of a stack are fainter.
    property real strength: 1
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    radius: 18

    // Shadow: a few soft rings just outside the edge, a little lower.
    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            readonly property real grow: (index + 1) * 1.5
            x: -grow
            y: -grow + 1.5
            width: pane.width + 2 * grow
            height: pane.height + 2 * grow
            radius: pane.radius + grow
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(0, 0, 0, 0.07 * (1 - index / 4) * pane.strength)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: pane.radius
        color: pane.dark
            ? Qt.rgba(0.16, 0.16, 0.17, (pane.hovered ? 0.62 : 0.52) * pane.strength)
            : Qt.rgba(0.97, 0.97, 0.98, (pane.hovered ? 0.72 : 0.62) * pane.strength)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }
}
