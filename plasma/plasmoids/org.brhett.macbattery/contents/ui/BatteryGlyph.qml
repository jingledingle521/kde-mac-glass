import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The macOS menu-bar battery: a faint rounded outline with a nub on the
// right, a fill that tracks the charge (green while charging, red when low)
// and, when plugged in, a bolt with a gap cut around it. Vector-drawn.
Item {
    id: glyph

    property int percent: 0
    property bool charging: false
    property bool pluggedIn: false
    property color color: Kirigami.Theme.textColor

    readonly property bool low: !pluggedIn && percent <= 20
    readonly property real s: height / 16
    readonly property real bodyW: width - 3.2 * s
    readonly property real bodyH: 11 * s
    readonly property real bodyX: 0.6 * s
    readonly property real bodyY: (height - bodyH) / 2
    readonly property real inset: 2.1 * s
    readonly property real fillW: Math.max(2 * s, (bodyW - inset * 2) * Math.max(0, Math.min(100, percent)) / 100)

    // The bolt, inside the body around its centre.
    function bolt() {
        const bx = bodyX + bodyW / 2, by = height / 2, k = s * 0.8;
        const pts = [[0.6, -6.2], [1.6, -6.2], [0.9, -1.0], [3.8, -1.0], [-0.6, 6.2], [-1.6, 6.2], [-0.9, 1.0], [-3.8, 1.0], [0.6, -6.2]];
        return pts.map(p => Qt.point(bx + p[0] * k, by + p[1] * k));
    }
    // A closed polygon grown outwards by d (mitred, long spikes cut short).
    function grown(poly, d) {
        const pts = poly.slice(0, -1), n = pts.length;
        let area = 0;
        for (let i = 0; i < n; ++i) {
            const a = pts[i], b = pts[(i + 1) % n];
            area += a.x * b.y - b.x * a.y;
        }
        const sign = area > 0 ? 1 : -1;
        const normal = (a, b) => {
            const dx = b.x - a.x, dy = b.y - a.y, l = Math.hypot(dx, dy);
            return [sign * dy / l, -sign * dx / l];
        };
        const out = [];
        for (let i = 0; i < n; ++i) {
            const prev = pts[(i + n - 1) % n], v = pts[i], next = pts[(i + 1) % n];
            const n1 = normal(prev, v), n2 = normal(v, next);
            const dot = n1[0] * n2[0] + n1[1] * n2[1];
            let mx = (n1[0] + n2[0]) * d / (1 + dot), my = (n1[1] + n2[1]) * d / (1 + dot);
            const len = Math.hypot(mx, my), cap = d * 2.5;
            if (len > cap) {
                mx *= cap / len;
                my *= cap / len;
            }
            out.push(Qt.point(v.x + mx, v.y + my));
        }
        out.push(out[0]);
        return out;
    }
    readonly property var boltPts: bolt()
    // The gap, clipped to the fill so the even-odd hole never spills out of it.
    function clipped(poly) {
        const x0 = bodyX + inset, x1 = x0 + fillW, y0 = bodyY + inset, y1 = bodyY + bodyH - inset;
        const edges = [[p => p.x >= x0, (a, b) => Qt.point(x0, a.y + (b.y - a.y) * (x0 - a.x) / (b.x - a.x))],
                       [p => p.x <= x1, (a, b) => Qt.point(x1, a.y + (b.y - a.y) * (x1 - a.x) / (b.x - a.x))],
                       [p => p.y >= y0, (a, b) => Qt.point(a.x + (b.x - a.x) * (y0 - a.y) / (b.y - a.y), y0)],
                       [p => p.y <= y1, (a, b) => Qt.point(a.x + (b.x - a.x) * (y1 - a.y) / (b.y - a.y), y1)]];
        let out = poly.slice(0, -1);
        for (const [inside, cut] of edges) {
            const src = out;
            out = [];
            for (let i = 0; i < src.length; ++i) {
                const a = src[i], b = src[(i + 1) % src.length];
                if (inside(a)) {
                    out.push(a);
                    if (!inside(b)) out.push(cut(a, b));
                } else if (inside(b)) {
                    out.push(cut(a, b));
                }
            }
            if (out.length === 0) return [];
        }
        out.push(out[0]);
        return out;
    }

    implicitWidth: Math.round(implicitHeight * 1.75)
    implicitHeight: Math.round(Kirigami.Units.iconSizes.small * 0.875)

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath { // outline
            strokeWidth: 1.1 * glyph.s
            strokeColor: Qt.alpha(glyph.color, 0.42)
            fillColor: "transparent"
            PathRectangle {
                x: glyph.bodyX; y: glyph.bodyY
                width: glyph.bodyW; height: glyph.bodyH
                radius: 3.4 * glyph.s
            }
        }
        ShapePath { // nub
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: Qt.alpha(glyph.color, 0.42)
            PathRectangle {
                x: glyph.bodyX + glyph.bodyW + 1.0 * glyph.s; y: glyph.height / 2 - 2.2 * glyph.s
                width: 1.6 * glyph.s; height: 4.4 * glyph.s
                radius: 0.8 * glyph.s
            }
        }
        ShapePath { // charge, with the bolt's gap as an even-odd hole
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: glyph.charging ? "#30d158" : glyph.low ? "#ff453a" : glyph.color
            fillRule: ShapePath.OddEvenFill
            PathRectangle {
                x: glyph.bodyX + glyph.inset; y: glyph.bodyY + glyph.inset
                width: glyph.fillW; height: glyph.bodyH - glyph.inset * 2
                radius: 1.7 * glyph.s
            }
            PathPolyline {
                path: glyph.pluggedIn ? glyph.clipped(glyph.grown(glyph.bolt(), 1.1 * glyph.s)) : []
            }
        }
        ShapePath { // bolt
            strokeWidth: -1 // fill only
            strokeColor: "transparent"
            fillColor: glyph.pluggedIn ? glyph.color : "transparent"
            PathPolyline { path: glyph.boltPts }
        }
    }
}
