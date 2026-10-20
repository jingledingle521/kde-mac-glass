import QtQuick
import org.kde.kirigami as Kirigami

// The macOS menu-bar Wi-Fi fan: a dot and three arcs, the unlit ones faint.
// bars: 0-3 lit arcs; off: Wi-Fi switched off (faint with a slash);
// connecting: the arcs light up in turn.
Canvas {
    id: glyph

    property int bars: 3
    property bool off: false
    property bool connecting: false
    property color color: Kirigami.Theme.textColor
    property int step: 0

    implicitWidth: Math.round(implicitHeight * 1.12)
    implicitHeight: Kirigami.Units.iconSizes.small

    readonly property int shown: connecting ? step : bars

    Timer {
        interval: 400
        repeat: true
        running: glyph.connecting && glyph.visible
        onTriggered: glyph.step = (glyph.step + 1) % 4
    }

    onPaint: {
        const ctx = getContext("2d");
        const s = height / 16;
        const cx = width / 2, cy = height * 0.86;
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineWidth = 1.75 * s;
        const a0 = -Math.PI * 0.75, a1 = -Math.PI * 0.25;
        const radii = [4.6 * s, 8.0 * s, 11.4 * s];
        for (let i = 0; i < 3; ++i) {
            ctx.globalAlpha = (!off && i < shown) ? 1 : 0.28;
            ctx.strokeStyle = color;
            ctx.beginPath();
            ctx.arc(cx, cy, radii[i], a0, a1, false);
            ctx.stroke();
        }
        ctx.globalAlpha = off ? 0.28 : 1;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(cx, cy - 0.3 * s, 1.55 * s, 0, Math.PI * 2);
        ctx.fill();
        if (off) {
            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = "destination-out";
            ctx.lineWidth = 3.6 * s;
            ctx.beginPath();
            ctx.moveTo(cx - 6 * s, 1.5 * s);
            ctx.lineTo(cx + 6 * s, 14.5 * s);
            ctx.stroke();
            ctx.globalCompositeOperation = "source-over";
            ctx.lineWidth = 1.6 * s;
            ctx.beginPath();
            ctx.moveTo(cx - 6 * s, 1.5 * s);
            ctx.lineTo(cx + 6 * s, 14.5 * s);
            ctx.stroke();
        }
    }
    onBarsChanged: requestPaint()
    onOffChanged: requestPaint()
    onShownChanged: requestPaint()
    onColorChanged: requestPaint()
}
