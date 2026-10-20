import QtQuick
import org.kde.kirigami as Kirigami

// The macOS menu-bar battery: a faint rounded outline with a nub on the
// right, a fill that tracks the charge (green while charging, red when low)
// and, when plugged in, a bolt cut out of it.
Canvas {
    id: glyph

    property int percent: 0
    property bool charging: false
    property bool pluggedIn: false
    property color color: Kirigami.Theme.textColor

    readonly property bool low: !pluggedIn && percent <= 20

    implicitWidth: Math.round(implicitHeight * 1.7)
    implicitHeight: Kirigami.Units.iconSizes.small

    function roundRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    onPaint: {
        const ctx = getContext("2d");
        const s = height / 16;
        const bw = width - 2.6 * s, bh = 11 * s;
        const x = 0.6 * s, y = (height - bh) / 2;
        ctx.reset();
        // Outline and nub.
        ctx.globalAlpha = 0.42;
        ctx.strokeStyle = color;
        ctx.lineWidth = 1.1 * s;
        roundRect(ctx, x, y, bw - 0.6 * s, bh, 3.4 * s);
        ctx.stroke();
        ctx.fillStyle = color;
        roundRect(ctx, bw + 0.5 * s, height / 2 - 2.2 * s, 1.6 * s, 4.4 * s, 0.8 * s);
        ctx.fill();
        // Charge.
        ctx.globalAlpha = 1;
        ctx.fillStyle = charging ? "#30d158" : low ? "#ff453a" : color;
        const inset = 2.1 * s;
        const full = bw - 0.6 * s - inset * 2;
        const fw = Math.max(2 * s, full * Math.max(0, Math.min(100, percent)) / 100);
        roundRect(ctx, x + inset, y + inset, fw, bh - inset * 2, 1.7 * s);
        ctx.fill();
        if (pluggedIn) {
            const bx = x + (bw - 0.6 * s) / 2, by = height / 2;
            const pts = [[0.9, -6.4], [-3.6, 0.9], [-0.3, 0.9], [-0.9, 6.4], [3.6, -0.9], [0.3, -0.9]];
            ctx.beginPath();
            ctx.moveTo(bx + pts[0][0] * s, by + pts[0][1] * s);
            for (let i = 1; i < pts.length; ++i) {
                ctx.lineTo(bx + pts[i][0] * s, by + pts[i][1] * s);
            }
            ctx.closePath();
            ctx.lineJoin = "round";
            ctx.globalCompositeOperation = "destination-out";
            ctx.lineWidth = 2.4 * s;
            ctx.stroke();
            ctx.globalCompositeOperation = "source-over";
            ctx.fillStyle = color;
            ctx.fill();
        }
    }
    onPercentChanged: requestPaint()
    onChargingChanged: requestPaint()
    onPluggedInChanged: requestPaint()
    onColorChanged: requestPaint()
}
