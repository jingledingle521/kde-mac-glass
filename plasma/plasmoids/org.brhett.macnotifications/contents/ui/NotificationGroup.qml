import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// One app's notifications in Notification Center, as on macOS: collapsed, the
// newest card with the next two peeking out below it as a stack; clicking the
// stack spreads it out under a header with Show Less and Clear. The same cards
// move between the two layouts, so expanding and collapsing animate, and a
// dismissed card (or the whole group) slides away before it is removed.
ColumnLayout {
    id: group

    required property var modelData
    required property var nc
    readonly property var items: modelData.items
    readonly property bool stacked: items.length > 1
    readonly property bool expanded: stacked && nc.expandedGroups[modelData.key] === true

    readonly property int peek: 8
    readonly property int gap: 8
    readonly property int duration: 320
    // Animate only while expanding or collapsing, not while cards first
    // appear and size themselves.
    property bool animating: false

    // The whole group is sliding away (cleared), and the cards sliding away
    // on their own, by index.
    property bool leaving: false
    readonly property bool gone: leaving || nc.clearingAll
    property var leavingIndexes: []
    readonly property int remaining: items.length - leavingIndexes.length

    // Each card's own height, by index.
    property var heights: []
    readonly property real topHeight: heights[0] || 0
    readonly property real expandedHeight: Math.max(0, expandedY(items.length) - gap)
    readonly property real collapsedHeight: topHeight + Math.min(items.length - 1, 2) * peek

    function setHeight(index, height) {
        if (heights[index] !== height) {
            const list = heights.slice();
            list[index] = height;
            heights = list;
        }
    }
    // Cards sliding away take no room, so the rest move up into the gap.
    function expandedY(index) {
        let y = 0;
        for (let i = 0; i < index; ++i) {
            if (leavingIndexes.indexOf(i) < 0) {
                y += (heights[i] || 0) + gap;
            }
        }
        return y;
    }

    function startAnimation() {
        animating = true;
        settle.restart();
    }
    // Slides the whole group away, then clears it.
    function dismissGroup() {
        if (leaving) {
            return;
        }
        startAnimation();
        leaving = true;
        removeGroup.start();
    }
    // Slides one card away; the last one left takes the group with it.
    function dismissCard(index) {
        if (remaining <= 1) {
            dismissGroup();
        } else if (leavingIndexes.indexOf(index) < 0) {
            startAnimation();
            leavingIndexes = leavingIndexes.concat([index]);
        }
    }

    spacing: 0
    // 1 while shown, 0 once slid away; its gap closes along with it,
    // spacing included.
    property real presence: gone ? 0 : 1
    property real slide: gone ? width + 30 : 0
    Behavior on presence {
        NumberAnimation { duration: group.duration; easing.type: Easing.InOutCubic }
    }
    Behavior on slide {
        NumberAnimation { duration: group.duration; easing.type: Easing.InCubic }
    }

    clip: presence < 1
    opacity: presence
    Layout.preferredHeight: implicitHeight * presence
    Layout.bottomMargin: -nc.cardSpacing * (1 - presence)
    transform: Translate { x: group.slide }

    onExpandedChanged: {
        animating = true;
        settle.restart();
    }

    Timer {
        id: settle
        interval: group.duration + 50
        onTriggered: group.animating = false
    }

    Timer {
        id: removeGroup
        interval: group.duration
        onTriggered: group.nc.clearGroup(group.modelData.key)
    }

    Item {
        Layout.fillWidth: true
        readonly property bool shown: group.expanded && group.remaining > 1
        Layout.preferredHeight: shown ? 26 + group.gap : 0
        opacity: shown ? 1 : 0
        visible: opacity > 0
        clip: true

        Behavior on Layout.preferredHeight {
            enabled: group.animating
            NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: group.duration * 0.6 }
        }

        RowLayout {
            width: parent.width
            height: 26

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: group.modelData.name
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                font.weight: Font.Bold
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            GlassButton {
                text: i18n("Show Less")
                onClicked: group.nc.setExpanded(group.modelData.key, false)
            }
            GlassButton {
                closeIcon: true
                expandText: i18n("Clear")
                onClicked: group.dismissGroup()
            }
        }
    }

    Item {
        id: stackArea
        Layout.fillWidth: true
        Layout.preferredHeight: group.expanded ? group.expandedHeight : group.collapsedHeight

        Behavior on Layout.preferredHeight {
            enabled: group.animating
            NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: group.items
            delegate: NotificationCard {
                id: card

                required property var modelData
                required property int index
                // Collapsed: 0 is the top card, 1 and 2 peek out, the rest
                // hide behind them.
                readonly property int depth: Math.min(index, 2)
                readonly property bool front: group.expanded || index === 0
                readonly property bool leaving: group.leavingIndexes.indexOf(index) >= 0

                z: -index
                x: group.expanded ? 0 : depth * 10
                y: group.expanded ? group.expandedY(index) : depth * group.peek
                width: stackArea.width - 2 * x
                height: front ? implicitHeight : group.topHeight
                clipTop: front ? 0 : Math.max(0, group.topHeight - group.peek)
                strength: front ? 1 : (depth === 1 ? 0.75 : 0.6)
                opacity: (group.expanded || index <= 2) && !leaving ? 1 : 0
                visible: opacity > 0
                contentVisible: front
                closable: front

                now: group.nc.now
                applicationName: modelData.appName
                applicationIconName: modelData.appIcon
                iconName: modelData.iconName
                image: modelData.image
                summary: modelData.summary
                body: modelData.body
                time: modelData.time
                // A collapsed stack shows no buttons, as on macOS.
                actionNames: group.expanded || !group.stacked ? modelData.actionNames : []
                actionLabels: group.expanded || !group.stacked ? modelData.actionLabels : []
                hasDefaultAction: modelData.hasDefaultAction
                bodyLines: group.expanded ? 4 : 3

                property real slide: leaving ? stackArea.width + 30 : 0
                Behavior on slide {
                    NumberAnimation { duration: group.duration; easing.type: Easing.InCubic }
                }
                transform: Translate { x: card.slide }

                // Removed once it has slid away.
                onLeavingChanged: if (leaving) removeCard.start()
                Timer {
                    id: removeCard
                    interval: group.duration
                    onTriggered: group.nc.closeNotification(card.modelData.id)
                }

                onImplicitHeightChanged: group.setHeight(index, implicitHeight)
                Component.onCompleted: group.setHeight(index, implicitHeight)

                onClicked: {
                    if (group.stacked && !group.expanded) {
                        group.nc.setExpanded(group.modelData.key, true);
                    } else {
                        group.nc.invokeDefault(modelData.id);
                    }
                }
                // Closing a collapsed stack clears the whole app, as on macOS.
                onCloseClicked: group.expanded ? group.dismissCard(index) : group.dismissGroup()
                onActionClicked: name => group.nc.invokeAction(modelData.id, name)

                Behavior on x {
                    enabled: group.animating
                    NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: group.animating
                    NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: group.animating
                    NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
                }
                Behavior on clipTop {
                    enabled: group.animating
                    NumberAnimation { duration: group.duration; easing.type: Easing.OutCubic }
                }
                Behavior on strength {
                    enabled: group.animating
                    NumberAnimation { duration: group.duration }
                }
                Behavior on opacity {
                    enabled: group.animating
                    // A dismissed card fades as it slides, not before.
                    NumberAnimation { duration: card.leaving ? group.duration : group.duration * 0.6 }
                }
            }
        }
    }
}
