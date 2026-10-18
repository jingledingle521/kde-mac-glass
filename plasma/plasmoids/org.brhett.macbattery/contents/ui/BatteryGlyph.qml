import QtQuick
import org.kde.kirigami as Kirigami

// The macOS menu-bar battery: a rounded outline with a nub on the right, a
// fill that tracks the charge (green while charging, red when low) and a
// bolt over it when plugged in.
Item {
    id: glyph

    property int percent: 0
    property bool charging: false
    property bool pluggedIn: false
    property color color: Kirigami.Theme.textColor

    readonly property bool low: !pluggedIn && percent <= 20
    readonly property real bodyHeight: Math.round(height * 0.62)

    implicitWidth: Math.round(height * 1.75)
    implicitHeight: Kirigami.Units.iconSizes.small

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: parent.width - nub.width - 1
        height: glyph.bodyHeight
        radius: Math.round(height * 0.3)
        color: "transparent"
        border.color: glyph.color
        border.width: 1
        opacity: 0.5
    }

    Rectangle {
        anchors.left: body.left
        anchors.verticalCenter: body.verticalCenter
        anchors.leftMargin: 2
        width: Math.max(2, Math.round((body.width - 4) * Math.max(0, Math.min(100, glyph.percent)) / 100))
        height: body.height - 4
        radius: Math.max(1, body.radius - 1)
        color: glyph.charging ? "#30d158" : glyph.low ? "#ff453a" : glyph.color
    }

    Rectangle {
        id: nub
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, Math.round(glyph.height * 0.09))
        height: Math.round(body.height * 0.4)
        radius: width
        color: glyph.color
        opacity: 0.5
    }

    // Lightning bolt, outlined in the bar color so it reads over the fill.
    Canvas {
        anchors.centerIn: body
        width: Math.round(body.height * 0.95)
        height: Math.round(glyph.height * 0.78)
        visible: glyph.pluggedIn
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.reset();
            ctx.beginPath();
            ctx.moveTo(w * 0.62, 0);
            ctx.lineTo(w * 0.12, h * 0.56);
            ctx.lineTo(w * 0.46, h * 0.56);
            ctx.lineTo(w * 0.36, h);
            ctx.lineTo(w * 0.88, h * 0.42);
            ctx.lineTo(w * 0.54, h * 0.42);
            ctx.closePath();
            ctx.lineJoin = "round";
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = Kirigami.Theme.backgroundColor;
            ctx.stroke();
            ctx.fillStyle = glyph.color;
            ctx.fill();
        }
        onVisibleChanged: requestPaint()
    }
}
