import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The macOS menu-bar speaker: a filled speaker and three sound waves, the
// ones above the volume faint; an × when muted. Vector-drawn.
Item {
    id: glyph

    property int percent: 50
    property bool muted: false
    property color color: Kirigami.Theme.textColor

    readonly property int waves: muted ? 0 : percent <= 0 ? 0 : percent < 34 ? 1 : percent < 67 ? 2 : 3
    readonly property real s: height / 16
    readonly property real cy: height / 2

    implicitWidth: Math.round(implicitHeight * 1.12)
    implicitHeight: Math.round(Kirigami.Units.iconSizes.small * 0.875)

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1.2 * glyph.s
            strokeColor: glyph.color
            fillColor: glyph.color
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: [
                    Qt.point(1.2 * glyph.s, glyph.cy - 2.6 * glyph.s),
                    Qt.point(3.9 * glyph.s, glyph.cy - 2.6 * glyph.s),
                    Qt.point(7.6 * glyph.s, glyph.cy - 5.9 * glyph.s),
                    Qt.point(7.6 * glyph.s, glyph.cy + 5.9 * glyph.s),
                    Qt.point(3.9 * glyph.s, glyph.cy + 2.6 * glyph.s),
                    Qt.point(1.2 * glyph.s, glyph.cy + 2.6 * glyph.s),
                    Qt.point(1.2 * glyph.s, glyph.cy - 2.6 * glyph.s)
                ]
            }
        }

        Instantiator {
            model: 3
            delegate: ShapePath {
                required property int index
                strokeWidth: 1.6 * glyph.s
                strokeColor: glyph.muted ? "transparent" : index < glyph.waves ? glyph.color : Qt.alpha(glyph.color, 0.28)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    moveToStart: true
                    centerX: 8.4 * glyph.s
                    centerY: glyph.cy
                    radiusX: [3.2, 6.0, 8.8][index] * glyph.s
                    radiusY: radiusX
                    startAngle: -(54 - index * 4.5)
                    sweepAngle: 2 * (54 - index * 4.5)
                }
            }
            onObjectAdded: (index, object) => shape.data.push(object)
        }

        ShapePath {
            strokeWidth: 1.6 * glyph.s
            strokeColor: glyph.muted ? glyph.color : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 11.2 * glyph.s
            startY: glyph.cy - 2.8 * glyph.s
            PathLine { x: 16.2 * glyph.s; y: glyph.cy + 2.8 * glyph.s }
            PathMove { x: 16.2 * glyph.s; y: glyph.cy - 2.8 * glyph.s }
            PathLine { x: 11.2 * glyph.s; y: glyph.cy + 2.8 * glyph.s }
        }
    }
}
