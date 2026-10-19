import QtQuick
import org.kde.plasma.PimCalendars
import org.kde.kitemmodels

// Shows every calendar in the Calendar widget, as macOS does, when none has
// been picked yet: Plasma's events plugin starts with an empty list (picked
// in the Digital Clock's settings, which this pack doesn't use). Loaded by
// CalendarWidget through a Loader: the module comes with KOrganizer's add-ons
// (kdepim-addons), and without it only this part fails to load.
Item {
    id: setup

    PimCalendarsModel {
        id: calendars
    }

    Instantiator {
        id: rows
        model: KDescendantsProxyModel {
            model: calendars
        }
        delegate: QtObject {
            required property int collectionId
            required property bool isChecked
            required property bool isEnabled
        }
    }

    // Akonadi fills the list asynchronously.
    Timer {
        running: true
        interval: 5000
        onTriggered: {
            const all = [];
            for (let i = 0; i < rows.count; ++i) {
                const row = rows.objectAt(i);
                if (row.isChecked) {
                    return;
                }
                if (row.isEnabled && all.indexOf(row.collectionId) < 0) {
                    all.push(row.collectionId);
                }
            }
            if (all.length === 0) {
                return;
            }
            for (const id of all) {
                calendars.setChecked(id, true);
            }
            calendars.saveConfig();
        }
    }
}
