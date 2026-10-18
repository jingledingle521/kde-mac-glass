"""Rebuild widgets/tooltip.svgz as the dock's liquid glass.

Plasma draws tooltips (and the dock's name bubbles) in this frame, and KWin
blurs behind it through the mask pieces. This keeps the base's hints and
shadow (so margins and the drop shadow stay the same) and replaces the nine
frame pieces and their masks with glass matching panel-background (see
make_panel.py): the same white tint for the glass level, a dark hairline
outline and a light inner rim, with rounded corners.

    make_tooltip.py tooltip-base.svg tooltip.svgz LEVEL
"""
import gzip
import sys
import xml.etree.ElementTree as ET

PARTS = ['topleft', 'top', 'topright', 'left', 'center', 'right', 'bottomleft', 'bottom', 'bottomright']

src, dst = sys.argv[1], sys.argv[2]
level = max(0, min(100, int(sys.argv[3]))) / 100 if len(sys.argv) > 3 else 0.4
for p, uri in [('', 'http://www.w3.org/2000/svg'),
               ('inkscape', 'http://www.inkscape.org/namespaces/inkscape'),
               ('sodipodi', 'http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd'),
               ('xlink', 'http://www.w3.org/1999/xlink')]:
    ET.register_namespace(p, uri)
tree = ET.parse(src)
root = tree.getroot()

drop = set(PARTS) | {'mask-' + p for p in PARTS} | {'hint-tile-center'}


def prune(parent):
    for child in list(parent):
        if child.get('id') in drop:
            parent.remove(child)
        else:
            prune(child)


prune(root)

out = []
W = float(root.get('width'))
OX, OY = W + 20, 0  # free area right of the base artwork
C = 10  # corner size = corner radius


def rgba(a, c='#ffffff'):
    return f'fill="{c}" fill-opacity="{a}"'


# Same glass as the dock: white tint for the level, dark outline, light rim.
fill = round(0.05 + 0.30 * level, 3)
# The bubble floats over anything, so it gets a touch more body than the dock.
fill = round(min(0.45, fill + 0.06), 3)
outline = 0.22
top, side, bottom = 0.30, 0.10, 0.10
MX, MY = OX + 3 * C + 8, OY  # mask sheet next to the frame


def grad(name, y0, y1, a0, a1):
    out.append(f'<defs><linearGradient id="{name}" x1="0" y1="{y0}" x2="0" y2="{y1}" gradientUnits="userSpaceOnUse">'
               f'<stop offset="0" stop-color="#fff" stop-opacity="{a0}"/>'
               f'<stop offset="1" stop-color="#fff" stop-opacity="{a1}"/></linearGradient></defs>')


def corner(name, X, Y, fx, fy, mX, mY):
    c = C

    def pt(u, v):
        return f'{X + (c - u if fx else u):g},{Y + (c - v if fy else v):g}'

    def mpt(u, v):
        return f'{mX + (c - u if fx else u):g},{mY + (c - v if fy else v):g}'

    sweep = 0 if fx != fy else 1

    def ring(r0, r1):
        back = 1 - sweep
        return (f'M{pt(c - r0, c)} A{r0:g},{r0:g} 0 0 {sweep} {pt(c, c - r0)} L{pt(c, c - r1)} '
                f'A{r1:g},{r1:g} 0 0 {back} {pt(c - r1, c)} Z')

    g = f'tooltip-rim-{name}'
    grad(g, Y, Y + c, side, bottom) if fy else grad(g, Y, Y + c, top, side)
    out.append(f'<g id="{name}"><path d="M{pt(0, c)} A{c},{c} 0 0 {sweep} {pt(c, 0)} L{pt(c, c)} Z" {rgba(fill)}/>'
               f'<path d="{ring(c, c - 1)}" fill="#000" fill-opacity="{outline}"/>'
               f'<path d="{ring(c - 1, c - 2)}" fill="url(#{g})"/></g>')
    out.append(f'<path id="mask-{name}" d="M{mpt(0, c)} A{c},{c} 0 0 {sweep} {mpt(c, 0)} L{mpt(c, c)} Z"/>')


def edge(name, X, Y, horizontal, outer_at_start, a):
    c = C
    body = f'<rect x="{X}" y="{Y}" width="{c}" height="{c}" {rgba(fill)}/>'
    if horizontal:
        yo = Y if outer_at_start else Y + c - 1
        yr = Y + 1 if outer_at_start else Y + c - 2
        body += f'<rect x="{X}" y="{yo}" width="{c}" height="1" fill="#000" fill-opacity="{outline}"/>'
        body += f'<rect x="{X}" y="{yr}" width="{c}" height="1" {rgba(a)}/>'
    else:
        xo = X if outer_at_start else X + c - 1
        xr = X + 1 if outer_at_start else X + c - 2
        body += f'<rect x="{xo}" y="{Y}" width="1" height="{c}" fill="#000" fill-opacity="{outline}"/>'
        body += f'<rect x="{xr}" y="{Y}" width="1" height="{c}" {rgba(a)}/>'
    out.append(f'<g id="{name}">{body}</g>')


corner('topleft', OX, OY, False, False, MX, MY)
corner('topright', OX + 2 * C, OY, True, False, MX + 2 * C, MY)
corner('bottomleft', OX, OY + 2 * C, False, True, MX, MY + 2 * C)
corner('bottomright', OX + 2 * C, OY + 2 * C, True, True, MX + 2 * C, MY + 2 * C)
edge('top', OX + C, OY, True, True, top)
edge('bottom', OX + C, OY + 2 * C, True, False, bottom)
edge('left', OX, OY + C, False, True, side)
edge('right', OX + 2 * C, OY + C, False, False, side)
out.append(f'<rect id="center" x="{OX + C}" y="{OY + C}" width="{C}" height="{C}" {rgba(fill)}/>')
for name, (x, y) in {'top': (C, 0), 'bottom': (C, 2 * C), 'left': (0, C), 'right': (2 * C, C), 'center': (C, C)}.items():
    out.append(f'<rect id="mask-{name}" x="{MX + x}" y="{MY + y}" width="{C}" height="{C}"/>')
# Stretch edges instead of tiling them.
out.append(f'<rect id="hint-stretch-borders" x="{OX}" y="{OY + 3 * C + 4}" width="4" height="4" fill="none"/>')

width = MX + 3 * C + 4
height = max(float(root.get('height')), OY + 3 * C + 12)
root.set('width', f'{width:g}')
root.set('height', f'{height:g}')
root.set('viewBox', f'0 0 {width:g} {height:g}')
xml = ET.tostring(root, encoding='unicode')
xml = xml[:xml.rfind('</svg>')] + '\n'.join(out) + '\n</svg>'
with gzip.open(dst, 'wt', compresslevel=9) as f:
    f.write(xml)
