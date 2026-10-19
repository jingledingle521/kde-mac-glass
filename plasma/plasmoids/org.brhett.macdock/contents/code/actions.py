#!/usr/bin/python3 -I
"""List or run an app's extra actions (desktop-file "Desktop Action"
sections, e.g. "New Private Window") for the dock's right-click menu.

    actions.py list URL      JSON list of {"id", "name", "icon"}
    actions.py run URL ID    start that action

URL is the dock's launcher URL: "applications:foo.desktop" or a file URL.
"""
import configparser
import json
import os
import shlex
import subprocess
import sys
from urllib.parse import unquote, urlparse


def find_desktop_file(url):
    if url.startswith('applications:'):
        name = url[len('applications:'):]
        dirs = [os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))]
        dirs += os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
        dirs += ['/var/lib/snapd/desktop', '/var/lib/flatpak/exports/share', os.path.expanduser('~/.local/share/flatpak/exports/share')]
        for d in dirs:
            path = os.path.join(d, 'applications', name)
            if os.path.isfile(path):
                return path
        return None
    if url.startswith('file:'):
        path = unquote(urlparse(url).path)
        return path if os.path.isfile(path) else None
    return url if os.path.isfile(url) else None


def read(path):
    parser = configparser.RawConfigParser(strict=False, interpolation=None)
    parser.optionxform = str  # keys are case-sensitive
    parser.read(path, encoding='utf-8')
    return parser


def actions(path):
    desktop = read(path)
    entry = 'Desktop Entry'
    if entry not in desktop:
        return []
    out = []
    for action in [a for a in desktop[entry].get('Actions', '').split(';') if a]:
        section = f'Desktop Action {action}'
        if section in desktop and desktop[section].get('Exec'):
            out.append({'id': action, 'name': desktop[section].get('Name', action),
                        'icon': desktop[section].get('Icon', '')})
    return out


def run(path, action):
    desktop = read(path)
    section = f'Desktop Action {action}'
    if section not in desktop:
        return
    # Drop field codes (%u, %F…): the dock passes no files.
    args = [a for a in shlex.split(desktop[section].get('Exec', '')) if not (len(a) == 2 and a[0] == '%')]
    if args:
        subprocess.Popen(args, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if len(sys.argv) < 3:
        print('[]')
        return
    path = find_desktop_file(sys.argv[2])
    if sys.argv[1] == 'list':
        print(json.dumps(actions(path) if path else []))
    elif sys.argv[1] == 'run' and path and len(sys.argv) > 3:
        run(path, sys.argv[3])


if __name__ == '__main__':
    main()
