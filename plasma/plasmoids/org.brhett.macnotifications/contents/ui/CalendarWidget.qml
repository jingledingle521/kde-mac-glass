import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// macOS's medium Calendar widget: today and its events on the left, the month
// on the right with today circled in red. Events come from the calendars
// KOrganizer uses (Akonadi, through Plasma's calendar plugin); clicking the
// widget opens the calendar app.
GlassCard {
    id: widget

    property date now: new Date()
    property var events: []
    readonly property int maxEvents: 2
    readonly property color red: "#ff453a"
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7 // 0 = Sunday

    // 42 cells (six weeks) starting on the week that holds the 1st; days of
    // other months are blank.
    readonly property var cells: {
        const first = new Date(now.getFullYear(), now.getMonth(), 1);
        const lead = (first.getDay() - firstDay + 7) % 7;
        const days = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const list = [];
        for (let i = 0; i < 42; ++i) {
            const day = i - lead + 1;
            list.push(day >= 1 && day <= days ? day : 0);
        }
        // Drop a blank last week.
        return list.slice(36).every(d => d === 0) ? list.slice(0, 35) : list;
    }

    signal openApp()

    function refreshEvents() {
        const list = calendar.daysModel.eventsForDate(now)
            .filter(e => !e.isMinor)
            .map(e => ({
                title: e.title,
                color: e.eventColor,
                allDay: e.isAllDay,
                start: e.startDateTime,
                end: e.endDateTime
            }));
        list.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
        events = list;
    }

    function eventTime(e) {
        if (e.allDay) {
            return i18n("All-day");
        }
        const format = Qt.locale().timeFormat(Locale.ShortFormat);
        return Qt.formatTime(e.start, format) + " – " + Qt.formatTime(e.end, format);
    }

    onNowChanged: refreshEvents()

    PlasmaCalendar.EventPluginsManager {
        id: eventPlugins
        Component.onCompleted: populateEnabledPluginsList(["pimevents"])
    }

    PlasmaCalendar.Calendar {
        id: calendar
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: widget.now
        Component.onCompleted: daysModel.setPluginsManager(eventPlugins)
    }

    Connections {
        target: calendar.daysModel
        function onAgendaUpdated(date) {
            widget.refreshEvents();
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: widget.openApp()
    }

    implicitWidth: 344
    implicitHeight: Math.max(168, today.implicitHeight + 28)

    ColumnLayout {
        id: today
        x: 16
        y: 14
        width: 120
        spacing: 0

        PlasmaComponents3.Label {
            text: Qt.formatDate(widget.now, "dddd").toUpperCase()
            color: widget.red
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        PlasmaComponents3.Label {
            text: widget.now.getDate()
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 3
            font.weight: Font.Light
        }
        PlasmaComponents3.Label {
            Layout.topMargin: 6
            visible: widget.events.length === 0
            text: i18n("No events today")
            opacity: 0.5
            font: Kirigami.Theme.smallFont
        }

        // Today's events: a coloured bar, the title and the time.
        Repeater {
            model: widget.events.slice(0, widget.maxEvents)
            delegate: RowLayout {
                required property var modelData
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 3
                    radius: 1.5
                    color: parent.modelData.color || widget.red
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.title
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: widget.eventTime(parent.parent.modelData)
                        opacity: 0.55
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                        elide: Text.ElideRight
                    }
                }
            }
        }
        PlasmaComponents3.Label {
            Layout.topMargin: 4
            visible: widget.events.length > widget.maxEvents
            text: i18np("1 more event", "%1 more events", widget.events.length - widget.maxEvents)
            opacity: 0.5
            font: Kirigami.Theme.smallFont
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 14
        spacing: 4

        PlasmaComponents3.Label {
            Layout.leftMargin: 4
            text: Qt.formatDate(widget.now, "MMMM").toUpperCase()
            color: widget.red
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        Grid {
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: 7
                delegate: PlasmaComponents3.Label {
                    required property int index
                    width: 25
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneDayName((index + widget.firstDay) % 7, Locale.NarrowFormat)
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.5
                }
            }
            Repeater {
                model: widget.cells
                delegate: Item {
                    required property int modelData
                    readonly property bool today: modelData === widget.now.getDate()
                    width: 25
                    height: widget.cells.length > 35 ? 17 : 20

                    Rectangle {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        radius: width / 2
                        color: widget.red
                        visible: parent.today
                    }
                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        visible: parent.modelData > 0
                        text: parent.modelData
                        color: parent.today ? "white" : Kirigami.Theme.textColor
                        font.weight: parent.today ? Font.Bold : Font.Normal
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                    }
                }
            }
        }
    }
}
