import QtQuick
import org.kde.kirigami as Kirigami

// macOS menu-bar slider: a thick capsule whose filled part is white, with a
// round knob at the end and an optional glyph inside the left edge.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real value: 0
    property string iconName: ""
    readonly property real position: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property bool pressed: mouse.pressed

    signal moved(real value)

    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.35)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        clip: true

        Rectangle {
            width: Math.max(track.height, track.height / 2 + slider.position * (track.width - track.height / 2))
            height: parent.height
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.92)
        }
    }

    Kirigami.Icon {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(slider.height * 0.22)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(slider.height * 0.62)
        height: width
        source: slider.iconName
        visible: slider.iconName !== ""
        isMask: true
        color: "#5a5a5e"
    }

    // Knob
    Rectangle {
        width: slider.height
        height: width
        radius: width / 2
        x: slider.position * (slider.width - width)
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.12)
        border.width: 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        preventStealing: true

        function update(mx) {
            const p = Math.max(0, Math.min(1, (mx - slider.height / 2) / (slider.width - slider.height)));
            slider.moved(slider.from + p * (slider.to - slider.from));
        }

        onPressed: mouseEvent => update(mouseEvent.x)
        onPositionChanged: mouseEvent => {
            if (pressed) {
                update(mouseEvent.x);
            }
        }
        onWheel: wheel => {
            const step = (slider.to - slider.from) / 20;
            slider.moved(Math.max(slider.from, Math.min(slider.to, slider.value + (wheel.angleDelta.y > 0 ? step : -step))));
        }
    }
}
