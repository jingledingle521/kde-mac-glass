#!/usr/bin/python3 -I
"""Build the MacGlass Kvantum theme from KvMojave: rounded translucent menus
with a solid blue rounded hover, matching the Apple menu widget.

    make_kvantum.py OUTDIR [KvMojave dir]"""
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

out = sys.argv[1]
base = sys.argv[2] if len(sys.argv) > 2 else '/usr/share/Kvantum/KvMojave'

MENU_FILL = ('#2a2c30', 0.86)       # dark glass behind the items
MENU_BORDER = ('#ffffff', 0.10)     # light inner hairline
MENU_OUTLINE = ('#000000', 0.45)    # dark outer hairline
HIGHLIGHT = ('#315bef', 1.0)        # Apple menu hover blue
SEPARATOR = ('#ffffff', 0.16)
MENU_RADIUS = 10
ITEM_RADIUS = 5
PARTS = ['topleft', 'top', 'topright', 'left', '', 'right', 'bottomleft', 'bottom', 'bottomright']

SVG = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG)
ET.register_namespace('xlink', 'http://www.w3.org/1999/xlink')


def piece_name(prefix, part):
    return prefix if not part else f'{prefix}-{part}'


def frame(prefix, ox, oy, c, radius, fill, border=None, outline=None):
    """Nine-slice rounded rect with corner size c at (ox, oy); quarter-circle
    corners of `radius` (<= c). Rings are filled shapes so bounds are exact."""
    out = []
    color = lambda col: f'fill="{col[0]}" fill-opacity="{col[1]}"'
    r = radius

    def corner(part, x, y, fx, fy):
        def pt(u, v):
            return f'{x + (c - u if fx else u):g},{y + (c - v if fy else v):g}'
        sweep = 0 if fx != fy else 1
        back = 1 - sweep
        # Outer shape: square cell with the outer corner rounded by r.
        body = (f'M{pt(c, c)} L{pt(0, c)} L{pt(0, r)} A{r},{r} 0 0 {sweep} {pt(r, 0)} L{pt(c, 0)} Z')
        s = f'<path d="{body}" {color(fill)}/>'
        if outline:
            s += (f'<path d="M{pt(0, c)} L{pt(0, r)} A{r},{r} 0 0 {sweep} {pt(r, 0)} L{pt(c, 0)} L{pt(c, 1)} '
                  f'L{pt(r, 1)} A{r - 1},{r - 1} 0 0 {back} {pt(1, r)} L{pt(1, c)} Z" {color(outline)}/>')
        if border:
            r1 = r - 1
            s += (f'<path d="M{pt(1, c)} L{pt(1, r)} A{r1},{r1} 0 0 {sweep} {pt(r, 1)} L{pt(c, 1)} L{pt(c, 2)} '
                  f'L{pt(r, 2)} A{r1 - 1},{r1 - 1} 0 0 {back} {pt(2, r)} L{pt(2, c)} Z" {color(border)}/>')
        out.append(f'<g id="{piece_name(prefix, part)}">'
                   f'<rect x="{x}" y="{y}" width="{c}" height="{c}" fill="none"/>{s}</g>')

    def edge(part, x, y, horizontal, outer_first):
        s = f'<rect x="{x}" y="{y}" width="{c}" height="{c}" {color(fill)}/>'
        lines = [(outline, 0), (border, 1)]
        for col, off in lines:
            if not col:
                continue
            if horizontal:
                yy = y + off if outer_first else y + c - 1 - off
                s += f'<rect x="{x}" y="{yy}" width="{c}" height="1" {color(col)}/>'
            else:
                xx = x + off if outer_first else x + c - 1 - off
                s += f'<rect x="{xx}" y="{y}" width="1" height="{c}" {color(col)}/>'
        out.append(f'<g id="{piece_name(prefix, part)}">{s}</g>')

    corner('topleft', ox, oy, False, False)
    corner('topright', ox + 2 * c, oy, True, False)
    corner('bottomleft', ox, oy + 2 * c, False, True)
    corner('bottomright', ox + 2 * c, oy + 2 * c, True, True)
    edge('top', ox + c, oy, True, True)
    edge('bottom', ox + c, oy + 2 * c, True, False)
    edge('left', ox, oy + c, False, True)
    edge('right', ox + 2 * c, oy + c, False, False)
    out.append(f'<rect id="{prefix}" x="{ox + c}" y="{oy + c}" width="{c}" height="{c}" {color(fill)}/>')
    return out


def clear(prefix, ox, oy, c):
    """Fully transparent nine-slice (normal, un-hovered menu items)."""
    cells = {'topleft': (0, 0), 'top': (c, 0), 'topright': (2 * c, 0), 'left': (0, c), '': (c, c),
             'right': (2 * c, c), 'bottomleft': (0, 2 * c), 'bottom': (c, 2 * c), 'bottomright': (2 * c, 2 * c)}
    return [f'<rect id="{piece_name(prefix, p)}" x="{ox + x}" y="{oy + y}" width="{c}" height="{c}" fill="#000" fill-opacity="0"/>'
            for p, (x, y) in cells.items()]


# ---- SVG ----
tree = ET.parse(os.path.join(base, 'KvMojave.svg'))
root = tree.getroot()
replace = re.compile(r'^(menu-normal|menuitem-(normal|focused|pressed|toggled))(-|$)')


def prune(parent):
    for child in list(parent):
        if replace.match(child.get('id') or ''):
            parent.remove(child)
        else:
            prune(child)


prune(root)
w, h = float(root.get('width', '1000').rstrip('px')), float(root.get('height', '1000').rstrip('px'))
X = int(w) + 20
pieces = []
pieces += frame('menu-normal', X, 0, MENU_RADIUS, MENU_RADIUS, MENU_FILL, MENU_BORDER, MENU_OUTLINE)
pieces += clear('menuitem-normal', X, 50, ITEM_RADIUS)
for i, state in enumerate(('focused', 'pressed', 'toggled')):
    pieces += frame(f'menuitem-{state}', X + 30 * i, 80, ITEM_RADIUS, ITEM_RADIUS, HIGHLIGHT)
# Separator: a light hairline centred in its strip (KvMojave has none).
pieces.append(f'<g id="menuitem-separator"><rect x="{X}" y="110" width="20" height="9" fill="none"/>'
              f'<rect x="{X}" y="114" width="20" height="1" fill="{SEPARATOR[0]}" fill-opacity="{SEPARATOR[1]}"/></g>')
root.set('width', str(int(w) + 140))
root.set('viewBox', f'0 0 {int(w) + 140} {int(max(h, 120))}')
root.set('height', str(int(max(h, 120))))
xml = ET.tostring(root, encoding='unicode')
xml = xml[:xml.rfind('</svg>')] + '\n'.join(pieces) + '\n</svg>'

os.makedirs(out, exist_ok=True)
with open(os.path.join(out, 'MacGlass.svg'), 'w') as f:
    f.write(xml)

# ---- kvconfig ----
cfg = open(os.path.join(base, 'KvMojave.kvconfig')).read()


def set_keys(section, values):
    global cfg
    m = re.search(rf'^\[{re.escape(section)}\]\n(.*?)(?=^\[|\Z)', cfg, re.S | re.M)
    body = m.group(1)
    for key, value in values.items():
        if re.search(rf'^{re.escape(key)}=', body, re.M):
            body = re.sub(rf'^{re.escape(key)}=.*$', f'{key}={value}', body, flags=re.M)
        else:
            body = body.rstrip('\n') + f'\n{key}={value}\n'
    cfg = cfg[:m.start(1)] + body.rstrip('\n') + '\n\n' + cfg[m.end(1):]


set_keys('%General', {
    'comment': 'MacGlass: macOS-style menus (rounded glass, blue hover), based on KvMojave by Tsu Jan',
    'menu_shadow_depth': 7, 'menu_blur_radius': 2, 'popup_blurring': 'true', 'translucent_windows': 'true',
    'composite': 'true', 'submenu_overlap': 0, 'reduce_menu_opacity': 0,
    # Inset items from the menu edge so the blue highlight floats, as on macOS.
    'spread_menuitems': 'false', 'menu_separator_height': 9,
})
set_keys('Menu', {
    'frame.top': 6, 'frame.bottom': 6, 'frame.left': 6, 'frame.right': 6,
    'frame.expansion': 2 * MENU_RADIUS, 'text.normal.color': '#f5f5f7',
})
set_keys('MenuItem', {
    'frame.top': 2, 'frame.bottom': 2, 'frame.left': 6, 'frame.right': 6, 'frame.expansion': 2 * ITEM_RADIUS,
    'text.margin.top': 1, 'text.margin.bottom': 1, 'text.normal.color': '#f5f5f7', 'text.focus.color': '#ffffff',
    'text.press.color': '#ffffff', 'text.toggle.color': '#ffffff', 'text.shadow': 'false',
})
with open(os.path.join(out, 'MacGlass.kvconfig'), 'w') as f:
    f.write(cfg)
print('wrote', out)
