import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// The dock's right-click menu: the same Mac menu as the Menu Bar widget
// (rounded glass, accent highlight, the blink on choosing), in one popup that
// every dock icon reuses. Entries are MenuView entries; `trigger` runs the
// chosen one after the blink.
PlasmaCore.Dialog {
    id: menu

    required property Item dock
    property var entries: []
    readonly property bool opened: visible
    // The icon it opened from: it's placed again whenever its size settles.
    property Item anchorItem: null

    type: PlasmaCore.Dialog.PopupMenu
    // Placed by the dock (centred on the icon, clear of the dock's edge):
    // Plasma's own placement put popups over the icons.
    location: PlasmaCore.Types.Floating
    flags: Qt.WindowStaysOnTopHint
    // Clicking anywhere else closes it (it takes focus while open).
    hideOnWindowDeactivate: true
    visible: false

    // Opens above (or beside) `parentItem`, just outside the dock. The new
    // entries size the window first; Wayland won't move a window that's
    // showing, so it is placed while hidden.
    function place() {
        return anchorItem && dock.placePopup(menu, anchorItem, Kirigami.Units.gridUnit);
    }

    // The menu's rows lay out on the next frame or so; until then the window
    // is short, and placing it then left it over the icon.
    onWidthChanged: if (visible) place()
    onHeightChanged: if (visible) place()

    function popup(parentItem, list) {
        visible = false;
        anchorItem = parentItem;
        entries = list;
        view.current = -1;
        // Show once the new entries have sized the menu, or the window
        // comes up at the old (or no) size.
        Qt.callLater(() => {
            if (!menu.place()) {
                return;
            }
            menu.visible = true;
            view.forceActiveFocus();
        });
    }

    mainItem: MenuView {
        id: view

        entries: menu.entries
        focus: true
        onActivated: entry => {
            menu.visible = false;
            if (entry && entry.trigger) {
                entry.trigger();
            }
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                menu.visible = false;
                break;
            case Qt.Key_Up:
                view.move(-1);
                break;
            case Qt.Key_Down:
                view.move(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (view.current >= 0) {
                    view.choose(view.current);
                }
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }
}
