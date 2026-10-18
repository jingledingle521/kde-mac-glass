import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.clipboard as Clipboard
import org.kde.kirigami as Kirigami

// Clipboard history in a macOS menu-bar style: search field, All/Pinned
// switch, rows with the accent highlight, image thumbnails, and pin/delete
// buttons on hover. Click a row to put it back on the clipboard. Uses KDE's
// clipboard service (Klipper), so Meta+V keeps working.
PlasmoidItem {
    id: root

    // HistoryItemType flags from klipper's historyitem.h
    readonly property int imageType: 4
    readonly property int urlType: 8

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "clipboard-outline-symbolic"
    toolTipMainText: ""
    toolTipSubText: ""

    onExpandedChanged: {
        if (!expanded) {
            history.filterRegularExpression = new RegExp("");
            history.starredOnly = false;
        }
    }

    Clipboard.HistoryModel {
        id: history
        filterCaseSensitivity: Qt.CaseInsensitive
    }

    Clipboard.KlipperInterface {
        id: klipper
    }

    compactRepresentation: MouseArea {
        property bool wasExpanded: false

        Layout.minimumWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        id: panel
        spacing: Kirigami.Units.smallSpacing
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    search.text = "";
                    search.forceActiveFocus();
                    list.currentIndex = 0;
                    list.positionViewAtBeginning();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Clipboard")
                font.weight: Font.Bold
            }

            // macOS-style segmented control
            Rectangle {
                implicitWidth: seg.implicitWidth + 4
                implicitHeight: seg.implicitHeight + 4
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)

                Row {
                    id: seg
                    anchors.centerIn: parent
                    Repeater {
                        model: [i18n("All"), i18n("Pinned")]
                        delegate: MouseArea {
                            required property int index
                            required property string modelData
                            readonly property bool selected: history.starredOnly === (index === 1)
                            implicitWidth: segLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                            implicitHeight: segLabel.implicitHeight + Kirigami.Units.smallSpacing
                            onClicked: history.starredOnly = index === 1

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                visible: parent.selected
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                            }
                            PlasmaComponents3.Label {
                                id: segLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                font: Kirigami.Theme.smallFont
                            }
                        }
                    }
                }
            }
        }

        PlasmaExtras.SearchField {
            id: search
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            onTextChanged: history.setFilterFixedString(text)
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: {
                if (list.currentItem) {
                    list.currentItem.select();
                }
            }
            Keys.onEscapePressed: root.expanded = false
        }

        PlasmaComponents3.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

            ListView {
                id: list
                model: history
                clip: true
                leftMargin: Kirigami.Units.mediumSpacing
                rightMargin: Kirigami.Units.mediumSpacing
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                keyNavigationWraps: false

                delegate: MouseArea {
                    id: row

                    required property int index
                    required property var model
                    required property var uuid
                    required property int type
                    required property var decoration
                    required property string display

                    readonly property bool isImage: type === root.imageType
                    readonly property bool highlighted: containsMouse || (ListView.isCurrentItem && search.activeFocus && search.text.length > 0)
                    readonly property color foreground: highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

                    function select() {
                        history.moveToTop(uuid);
                        root.expanded = false;
                    }

                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    implicitHeight: (isImage ? Kirigami.Units.gridUnit * 4 : label.implicitHeight) + Kirigami.Units.smallSpacing * 2
                    hoverEnabled: true
                    onClicked: select()

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Kirigami.Theme.highlightColor
                        visible: row.highlighted
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.mediumSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                            source: row.type === root.urlType ? "link-symbolic" : "text-plain-symbolic"
                            color: row.foreground
                            isMask: true
                            visible: !row.isImage
                            opacity: 0.6
                        }

                        PlasmaComponents3.Label {
                            id: label
                            Layout.fillWidth: true
                            visible: !row.isImage
                            text: row.display.trim().replace(/\s*\n\s*/g, " ⏎ ").slice(0, 300)
                            textFormat: Text.PlainText
                            color: row.foreground
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // decoration is an image:// URL from Klipper's image provider
                        Image {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                            visible: row.isImage
                            source: row.isImage ? row.decoration : ""
                            sourceSize.height: Kirigami.Units.gridUnit * 8
                            horizontalAlignment: Image.AlignLeft
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            smooth: true
                        }

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                            source: "starred-symbolic"
                            color: row.foreground
                            isMask: true
                            visible: row.model.starred === true && !row.containsMouse
                        }

                        // Hover actions: pin and delete
                        PlasmaComponents3.ToolButton {
                            visible: row.containsMouse
                            icon.name: row.model.starred ? "starred-symbolic" : "non-starred-symbolic"
                            icon.color: row.foreground
                            display: PlasmaComponents3.AbstractButton.IconOnly
                            text: row.model.starred ? i18n("Unpin") : i18n("Pin")
                            onClicked: row.model.starred = !row.model.starred
                            PlasmaComponents3.ToolTip.text: text
                            PlasmaComponents3.ToolTip.visible: hovered
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                        PlasmaComponents3.ToolButton {
                            visible: row.containsMouse
                            icon.name: "edit-delete-remove-symbolic"
                            icon.color: row.foreground
                            display: PlasmaComponents3.AbstractButton.IconOnly
                            text: i18n("Remove")
                            onClicked: history.remove(row.uuid)
                            PlasmaComponents3.ToolTip.text: text
                            PlasmaComponents3.ToolTip.visible: hovered
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: list.count === 0
                    iconName: "clipboard-outline-symbolic"
                    text: search.text.length > 0 ? i18n("No Matches")
                        : history.starredOnly ? i18n("No Pinned Items")
                        : i18n("Clipboard Is Empty")
                    explanation: history.starredOnly && search.text.length === 0 ? i18n("Hover an item and click the star to keep it here.") : ""
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.mediumSpacing
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            implicitHeight: 1
            color: Kirigami.Theme.textColor
            opacity: 0.15
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                text: i18n("Clear History")
                enabled: history.sourceCount > history.starredCount
                onClicked: history.clearHistory()
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents3.ToolButton {
                text: i18n("Clipboard Settings…")
                onClicked: {
                    root.expanded = false;
                    klipper.configure();
                }
            }
        }
    }
}
