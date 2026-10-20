import QtQuick
import org.kde.kirigami as Kirigami

// The macOS menu-bar speaker: a filled speaker and three sound waves, the
// ones above the volume faint; a slash when muted.
Canvas {
    id: glyph

    property int percent: 50
    property bool muted: false
    property color color: Kirigami.Theme.textColor

    implicitWidth: Math.round(implicitHeight * 1.12)
    implicitHeight: Kirigami.Units.iconSizes.small

    readonly property int waves: muted ? 0 : percent <= 0 ? 0 : percent < 34 ? 1 : percent < 67 ? 2 : 3

    onPaint: {
        const ctx = getContext("2d");
        const s = height / 16;
        const cy = height / 2;
        ctx.reset();
        ctx.fillStyle = color;
        ctx.strokeStyle = color;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        // Speaker: a small box and the cone.
        ctx.lineWidth = 1.2 * s;
        ctx.beginPath();
        ctx.moveTo(1.2 * s, cy - 2.6 * s);
        ctx.lineTo(3.9 * s, cy - 2.6 * s);
        ctx.lineTo(7.6 * s, cy - 5.9 * s);
        ctx.lineTo(7.6 * s, cy + 5.9 * s);
        ctx.lineTo(3.9 * s, cy + 2.6 * s);
        ctx.lineTo(1.2 * s, cy + 2.6 * s);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        // Waves.
        ctx.lineWidth = 1.6 * s;
        const radii = [3.2 * s, 6.0 * s, 8.8 * s];
        for (let i = 0; i < 3; ++i) {
            ctx.globalAlpha = muted ? 0 : i < waves ? 1 : 0.28;
            const a = (0.30 - i * 0.025) * Math.PI;
            ctx.beginPath();
            ctx.arc(8.4 * s, cy, radii[i], -a, a, false);
            ctx.stroke();
        }
        ctx.globalAlpha = 1;
        if (muted) {
            ctx.lineWidth = 1.6 * s;
            ctx.beginPath();
            ctx.moveTo(11.2 * s, cy - 2.8 * s);
            ctx.lineTo(16.2 * s, cy + 2.8 * s);
            ctx.moveTo(16.2 * s, cy - 2.8 * s);
            ctx.lineTo(11.2 * s, cy + 2.8 * s);
            ctx.stroke();
        }
    }
    onWavesChanged: requestPaint()
    onMutedChanged: requestPaint()
    onColorChanged: requestPaint()
}
