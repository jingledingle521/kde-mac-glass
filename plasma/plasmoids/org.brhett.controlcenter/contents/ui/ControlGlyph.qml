import QtQuick
import org.kde.kirigami as Kirigami

// The macOS Control Center glyph: two switches, the top one an outline
// with its knob on the left, the bottom one filled with its knob on the right.
Canvas {
    id: glyph

    property color color: Kirigami.Theme.textColor

    implicitWidth: implicitHeight
    implicitHeight: Kirigami.Units.iconSizes.small

    onPaint: {
        const ctx = getContext("2d");
        const s = height / 16;
        const w = 14.6 * s, h = 6.6 * s, r = h / 2, x = (width - w) / 2;
        const y1 = height / 2 - h - 1.0 * s, y2 = height / 2 + 1.0 * s;
        const knob = 1.4 * s, hole = 1.7 * s;
        ctx.reset();
        ctx.fillStyle = color;
        ctx.strokeStyle = color;
        function capsule(y) {
            ctx.beginPath();
            ctx.arc(x + r, y + r, r, Math.PI / 2, Math.PI * 1.5, false);
            ctx.arc(x + w - r, y + r, r, -Math.PI / 2, Math.PI / 2, false);
            ctx.closePath();
        }
        ctx.lineWidth = 1.2 * s;
        ctx.beginPath();
        ctx.arc(x + r, y1 + r, r - 0.6 * s, Math.PI / 2, Math.PI * 1.5, false);
        ctx.arc(x + w - r, y1 + r, r - 0.6 * s, -Math.PI / 2, Math.PI / 2, false);
        ctx.closePath();
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(x + r, y1 + r, knob, 0, Math.PI * 2);
        ctx.closePath();
        ctx.fill();
        capsule(y2);
        ctx.fill();
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(x + w - r, y2 + r, hole, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalCompositeOperation = "source-over";
    }
    onColorChanged: requestPaint()
}
