#!/usr/bin/python3 -I
"""Find and trigger standard items in an app's global menu (com.canonical.dbusmenu).

    appmenu_action.py SERVICE PATH APPNAME probe        -> {"about": true, ...}
    appmenu_action.py SERVICE PATH APPNAME about|settings|quit

Used by the active-app widget for its macOS-style app menu."""
import json
import re
import sys

import gi

gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib  # noqa: E402

IFACE = 'com.canonical.dbusmenu'
# Settings items that are about something else.
NOT_SETTINGS = re.compile(r'shortcut|toolbar|notification|keyboard|spell|language|editor|profile|session|tab', re.I)


def clean(label):
    """Drop mnemonics and trailing dots: '_Configure Konsole…' -> 'configure konsole'."""
    label = label.replace('__', '\0').replace('_', '').replace('&&', '\0').replace('&', '').replace('\0', '_')
    return label.rstrip('.…').strip().lower()


def items(bus, service, path):
    def call(method, args, reply):
        return bus.call_sync(service, path, IFACE, method, args, GLib.VariantType(reply),
                             Gio.DBusCallFlags.NONE, 2000, None).unpack()

    # Some apps fill submenus lazily; ask top-level menus to update first.
    _rev, (root, _props, children) = call('GetLayout', GLib.Variant('(iias)', (0, 1, [])), '(u(ia{sv}av))')
    for child in children:
        try:
            call('AboutToShow', GLib.Variant('(i)', (child[0],)), '(b)')
        except GLib.Error:
            pass
    _rev, layout = call('GetLayout', GLib.Variant('(iias)', (0, -1, [])), '(u(ia{sv}av))')
    out = []

    def walk(node):
        nid, props, kids = node
        # Skip separators and submenu headings (e.g. the "Settings" menu itself).
        is_submenu = props.get('children-display') == 'submenu' or bool(kids)
        if props.get('visible', True) and props.get('type') != 'separator' and 'label' in props and not is_submenu:
            out.append((nid, clean(props['label']), props.get('enabled', True)))
        for kid in kids:
            walk(kid)

    walk(layout)
    return call, out


def find(entries, action, app):
    app = app.lower()
    scored = []
    for nid, label, enabled in entries:
        if not enabled:
            continue
        score = 0
        if action == 'about':
            if label.startswith('about ') and label not in ('about kde', 'about qt'):
                score = 3 if app and app in label else 1
        elif action == 'settings':
            if label in ('settings', 'preferences'):
                score = 3
            elif label.startswith('configure ') and not NOT_SETTINGS.search(label):
                score = 3 if app and app in label else 2
            elif label.endswith(' settings') and not NOT_SETTINGS.search(label):
                score = 2 if app and app in label else 1
        elif action == 'quit':
            if label in ('quit', 'exit') or (app and label in ('quit ' + app, 'exit ' + app)):
                score = 3
        if score:
            scored.append((score, nid))
    return max(scored)[1] if scored else None


def main():
    service, path, app, action = sys.argv[1:5]
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    try:
        call, entries = items(bus, service, path)
    except GLib.Error:
        print(json.dumps({}) if action == 'probe' else 'notfound')
        return
    if action == 'probe':
        print(json.dumps({a: find(entries, a, app) is not None for a in ('about', 'settings', 'quit')}))
        return
    nid = find(entries, action, app)
    if nid is None:
        print('notfound')
        return
    call('Event', GLib.Variant('(isvu)', (nid, 'clicked', GLib.Variant('i', 0), 0)), '()')
    print('ok')


if __name__ == '__main__':
    main()
