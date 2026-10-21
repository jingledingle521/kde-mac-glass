import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The macOS menu-bar Wi-Fi fan: a dot and three arcs, the unlit ones faint.
// bars: 0-3 lit arcs; off: Wi-Fi switched off (faint with a slash);
// connecting: the arcs light up in turn. Vector-drawn (sharp at any scale).
Item {
    id: glyph

    property int bars: 3
    property bool off: false
    property bool connecting: false
    property color color: Kirigami.Theme.textColor
    property int step: 0

    readonly property int shown: connecting ? step : bars
    readonly property real s: height / 16
    readonly property real cx: width / 2
    readonly property real cy: height * 0.86

    function tone(lit) {
        return lit ? color : Qt.alpha(color, 0.28);
    }

    implicitWidth: Math.round(implicitHeight * 1.12)
    implicitHeight: Math.round(Kirigami.Units.iconSizes.small * 0.875)

    Timer {
        interval: 400
        repeat: true
        running: glyph.connecting && glyph.visible
        onTriggered: glyph.step = (glyph.step + 1) % 4
    }

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Instantiator {
            model: 3
            delegate: ShapePath {
                required property int index
                strokeWidth: 1.75 * glyph.s
                strokeColor: glyph.tone(!glyph.off && index < glyph.shown)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    moveToStart: true
                    centerX: glyph.cx
                    centerY: glyph.cy
                    radiusX: [4.6, 8.0, 11.4][index] * glyph.s
                    radiusY: radiusX
                    startAngle: -135
                    sweepAngle: 90
                }
            }
            onObjectAdded: (index, object) => shape.data.push(object)
        }

        ShapePath {
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: glyph.tone(!glyph.off)
            PathAngleArc {
                moveToStart: true
                centerX: glyph.cx
                centerY: glyph.cy - 0.3 * glyph.s
                radiusX: 1.55 * glyph.s
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: glyph.off ? 1.6 * glyph.s : 0
            strokeColor: glyph.off ? glyph.color : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: glyph.cx - 6 * glyph.s
            startY: 1.5 * glyph.s
            PathLine { x: glyph.cx + 6 * glyph.s; y: 14.5 * glyph.s }
        }
    }
}
