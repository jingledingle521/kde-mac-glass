#!/usr/bin/python3 -I
"""Print the newest entries in ~/Downloads as JSON for the dock's stack."""
import json
import mimetypes
import os
import sys

folder = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else '~/Downloads')
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 12
items = []
try:
    with os.scandir(folder) as it:
        for e in it:
            if e.name.startswith('.'):
                continue
            try:
                t = e.stat().st_mtime
            except OSError:
                continue
            if e.is_dir():
                icon = 'folder'
            else:
                mime = mimetypes.guess_type(e.name)[0] or 'application/octet-stream'
                icon = e.path if mime.startswith('image/') else mime.replace('/', '-')
            items.append({'name': e.name, 'path': e.path, 'icon': icon, 'time': t})
except OSError:
    pass
items.sort(key=lambda i: i['time'], reverse=True)
print(json.dumps(items[:limit]))
