import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The macOS Control Center glyph: two switches, the top one an outline
// with its knob on the left, the bottom one filled with its knob cut out on
// the right. Vector-drawn.
Item {
    id: glyph

    property color color: Kirigami.Theme.textColor

    readonly property real s: height / 16
    readonly property real w: 14.6 * s
    readonly property real h: 6.6 * s
    readonly property real x0: (width - w) / 2
    readonly property real y1: height / 2 - h - 1.0 * s
    readonly property real y2: height / 2 + 1.0 * s

    implicitWidth: implicitHeight
    implicitHeight: Math.round(Kirigami.Units.iconSizes.small * 0.875)

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1.2 * glyph.s
            strokeColor: glyph.color
            fillColor: "transparent"
            PathRectangle {
                x: glyph.x0 + 0.6 * glyph.s; y: glyph.y1 + 0.6 * glyph.s
                width: glyph.w - 1.2 * glyph.s; height: glyph.h - 1.2 * glyph.s
                radius: height / 2
            }
        }
        ShapePath {
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: glyph.color
            PathAngleArc {
                moveToStart: true
                centerX: glyph.x0 + glyph.h / 2; centerY: glyph.y1 + glyph.h / 2
                radiusX: 1.4 * glyph.s; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: glyph.color
            fillRule: ShapePath.OddEvenFill
            PathRectangle {
                x: glyph.x0; y: glyph.y2
                width: glyph.w; height: glyph.h
                radius: height / 2
            }
            PathAngleArc {
                moveToStart: true
                centerX: glyph.x0 + glyph.w - glyph.h / 2; centerY: glyph.y2 + glyph.h / 2
                radiusX: 1.7 * glyph.s; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
