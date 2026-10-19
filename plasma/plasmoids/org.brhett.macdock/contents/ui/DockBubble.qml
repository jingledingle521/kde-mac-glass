import QtQuick
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// The macOS dock label: the app's name in a frosted-glass bubble with a tail
// pointing at the icon, a little above the dock, shown at once while `shown`
// (no tooltip delay).
//
// The body is a Plasma tooltip window: the theme's tooltip frame is the
// dock's liquid glass (MacGlass/glass/make_tooltip.py), and KWin blurs behind
// it. A theme frame can't have a tail, so the tail is its own tiny window
// tucked under the body.
Item {
    id: bubble

    required property Item dock
    required property Item anchor
    property string text
    property bool shown: false

    readonly property int tail: 7
    // How far above the icon the bubble's tail tip sits: clear of the dock.
    readonly property int lift: Kirigami.Units.gridUnit

    function place() {
        if (!dock.placePopup(body, anchor, lift + tail)) {
            return false;
        }
        // By the content's size, like placePopup: the window's can lag.
        const w = label.width + body.margins.left + body.margins.right;
        const h = label.height + body.margins.top + body.margins.bottom;
        tailWindow.x = Math.round(body.x + (w - tailWindow.width) / 2);
        tailWindow.y = body.y + h - 1;
        return true;
    }

    onShownChanged: {
        if (shown && text !== "") {
            if (place()) {
                body.visible = true;
                tailWindow.visible = true;
            }
        } else {
            body.visible = false;
            tailWindow.visible = false;
        }
    }

    PlasmaCore.Dialog {
        id: body

        type: PlasmaCore.Dialog.Tooltip
        location: PlasmaCore.Types.Floating
        flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
        visible: false

        // The first time, the window can still be its old (or no) size when
        // it's placed, which left it over the icon: place it again once the
        // size settles.
        onWidthChanged: if (visible) bubble.place()
        onHeightChanged: if (visible) bubble.place()

        mainItem: PlasmaComponents3.Label {
            id: label
            // The window takes its size from these.
            width: implicitWidth
            height: implicitHeight
            text: bubble.text
            leftPadding: Kirigami.Units.smallSpacing
            rightPadding: Kirigami.Units.smallSpacing
        }
    }

    PlasmaCore.Dialog {
        id: tailWindow

        type: PlasmaCore.Dialog.Tooltip
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
        visible: false

        mainItem: Shape {
            width: bubble.tail * 2 + 2
            height: bubble.tail + 1
            preferredRendererType: Shape.CurveRenderer

            // A downward tail in the glass's dark tint (make_tooltip.py) with
            // its outline, open at the top where it meets the body.
            ShapePath {
                fillColor: Qt.rgba(0.149, 0.149, 0.165, 0.75)
                strokeColor: Qt.rgba(0, 0, 0, 0.22)
                strokeWidth: 1
                startX: 0.5; startY: 0
                PathLine { x: bubble.tail + 1; y: bubble.tail + 0.5 }
                PathLine { x: bubble.tail * 2 + 1.5; y: 0 }
            }
        }
    }
}
