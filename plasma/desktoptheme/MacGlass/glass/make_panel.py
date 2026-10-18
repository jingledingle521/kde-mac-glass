"""Rebuild panel-background.svg with liquid-glass frames.

Keeps every hint/shadow element of the source so margins and layout stay
identical; replaces only the visible frame pieces and blur masks of the
default, north- (top bar) and south- (dock) prefixes."""
import re
import sys
import xml.etree.ElementTree as ET

SVG = '{http://www.w3.org/2000/svg}'
PARTS = ['topleft', 'top', 'topright', 'left', 'center', 'right', 'bottomleft', 'bottom', 'bottomright']

src, dst = sys.argv[1], sys.argv[2]
# Glass level 0 (clear) .. 100 (frosted): how much white tint the panels get.
level = max(0, min(100, int(sys.argv[3]))) / 100 if len(sys.argv) > 3 else 0.4
ET.register_namespace('', 'http://www.w3.org/2000/svg')
for p, uri in [('inkscape', 'http://www.inkscape.org/namespaces/inkscape'),
               ('sodipodi', 'http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd'),
               ('xlink', 'http://www.w3.org/1999/xlink')]:
    ET.register_namespace(p, uri)
tree = ET.parse(src)
root = tree.getroot()

drop = set()
for pre in ['', 'north-', 'south-']:
    drop.update(pre + p for p in PARTS)
    drop.update(pre + 'mask-' + p for p in PARTS)
drop.add('hint-tile-center')


def prune(parent):
    for child in list(parent):
        if child.get('id') in drop:
            parent.remove(child)
        else:
            prune(child)


prune(root)

out = []
X0 = 200  # free area right of the existing artwork


def rgba(a, c='#ffffff'):
    return f'fill="{c}" fill-opacity="{a}"'


def frame(pre, ox, oy, c, fill, rim, outline, mask=True):
    """Nine pieces of a glass rect whose corners are full quarter circles
    (radius = corner size c). rim = (top, side, bottom) opacities of the inner
    highlight. Strokes sit inside each piece so its bounds stay exactly c x c;
    Qt's SVG renderer has no clipping, so every piece is explicit geometry."""
    top, side, bottom = rim
    gid = pre.strip('-') or 'base'
    rx, ry = ox + 3 * c + 8, oy  # mask sheet next to the frame

    def grad(name, y0, y1, a0, a1):
        out.append(f'<defs><linearGradient id="{name}" x1="0" y1="{y0}" x2="0" y2="{y1}" gradientUnits="userSpaceOnUse">'
                   f'<stop offset="0" stop-color="#fff" stop-opacity="{a0}"/>'
                   f'<stop offset="1" stop-color="#fff" stop-opacity="{a1}"/></linearGradient></defs>')

    def corner(name, X, Y, fx, fy, mX, mY):
        def pt(u, v):
            return f'{X + (c - u if fx else u):g},{Y + (c - v if fy else v):g}'
        sweep = 0 if fx != fy else 1
        def ring(r0, r1):
            # Filled quarter ring between radii r0 > r1 (exact bounds, unlike strokes).
            back = 1 - sweep
            return (f'M{pt(c - r0, c)} A{r0:g},{r0:g} 0 0 {sweep} {pt(c, c - r0)} L{pt(c, c - r1)} '
                    f'A{r1:g},{r1:g} 0 0 {back} {pt(c - r1, c)} Z')
        def mpt(u, v):
            return f'{mX + (c - u if fx else u):g},{mY + (c - v if fy else v):g}'
        fillp = f'M{pt(0, c)} A{c},{c} 0 0 {sweep} {pt(c, 0)} L{pt(c, c)} Z'
        g = f'rim-{gid}-{name}'
        if fy:
            grad(g, Y, Y + c, side, bottom)
        else:
            grad(g, Y, Y + c, top, side)
        out.append(f'<g id="{pre}{name}"><path d="{fillp}" {rgba(fill)}/>'
                   f'<path d="{ring(c, c - 1)}" fill="#000" fill-opacity="{outline}"/>'
                   f'<path d="{ring(c - 1, c - 2)}" fill="url(#{g})"/></g>')
        if mask:
            out.append(f'<path id="{pre}mask-{name}" d="M{mpt(0, c)} A{c},{c} 0 0 {sweep} {mpt(c, 0)} L{mpt(c, c)} Z"/>')

    def edge(name, X, Y, horizontal, outer_at_start, a):
        # Fill cell, then a dark hairline on the outer side and the rim 1px in.
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
        out.append(f'<g id="{pre}{name}">{body}</g>')

    corner('topleft', ox, oy, False, False, rx, ry)
    corner('topright', ox + 2 * c, oy, True, False, rx + 2 * c, ry)
    corner('bottomleft', ox, oy + 2 * c, False, True, rx, ry + 2 * c)
    corner('bottomright', ox + 2 * c, oy + 2 * c, True, True, rx + 2 * c, ry + 2 * c)
    edge('top', ox + c, oy, True, True, top)
    edge('bottom', ox + c, oy + 2 * c, True, False, bottom)
    edge('left', ox, oy + c, False, True, side)
    edge('right', ox + 2 * c, oy + c, False, False, side)
    out.append(f'<rect id="{pre}center" x="{ox + c}" y="{oy + c}" width="{c}" height="{c}" {rgba(fill)}/>')
    if mask:
        for name, (x, y) in {'top': (c, 0), 'bottom': (c, 2 * c), 'left': (0, c), 'right': (2 * c, c), 'center': (c, c)}.items():
            out.append(f'<rect id="{pre}mask-{name}" x="{rx + x}" y="{ry + y}" width="{c}" height="{c}"/>')


def bar(pre, ox, oy, c, fill, line):
    """Square top-bar frame: flat glass with a light hairline along the bottom."""
    cells = {'topleft': (0, 0), 'top': (c, 0), 'topright': (2 * c, 0), 'left': (0, c), 'center': (c, c),
             'right': (2 * c, c), 'bottomleft': (0, 2 * c), 'bottom': (c, 2 * c), 'bottomright': (2 * c, 2 * c)}
    for name, (x, y) in cells.items():
        body = f'<rect x="{ox + x}" y="{oy + y}" width="{c}" height="{c}" {rgba(fill)}/>'
        if name.startswith('bottom'):
            body += f'<rect x="{ox + x}" y="{oy + y + c - 1}" width="{c}" height="1" {rgba(line)}/>'
        out.append(f'<g id="{pre}{name}">{body}</g>')


# Dock: 16px corners (as before), radius 16.
glass_fill = round(0.05 + 0.30 * level, 3)
frame('south-', X0, 0, 16, fill=glass_fill, rim=(0.25, 0.08, 0.10), outline=0.22)
# Fallback frame for other panels/edges: same glass, 12px corners.
frame('', X0, 70, 12, fill=glass_fill, rim=(0.25, 0.08, 0.10), outline=0.22)
# Top bar: flat, square.
bar('north-', X0, 130, 12, fill=round(0.04 + 0.26 * level, 3), line=0.16)
# Dock side padding: Plasma pads panel contents by these hint margins, and
# without them it falls back to the 16 px corner size. (WhiteSur's own
# south hints are misspelled "south-hint-hint-*", so they never applied.)
DOCK_SIDE_MARGIN = 6
out.append(f'<rect id="south-hint-left-margin" x="{X0}" y="200" width="{DOCK_SIDE_MARGIN}" height="4" fill="none"/>')
out.append(f'<rect id="south-hint-right-margin" x="{X0 + 10}" y="200" width="{DOCK_SIDE_MARGIN}" height="4" fill="none"/>')
# Stretch edges instead of tiling them.
out.append(f'<rect id="hint-stretch-borders" x="{X0}" y="180" width="4" height="4" fill="none"/>')

root.set('width', '320')
root.set('height', '260')
root.set('viewBox', '0 0 320 260')
xml = ET.tostring(root, encoding='unicode')
xml = xml[:xml.rfind('</svg>')] + '\n'.join(out) + '\n</svg>'
if dst.endswith('.svgz'):
    import gzip
    with gzip.open(dst, 'wt', compresslevel=9) as f:
        f.write(xml)
else:
    open(dst, 'w').write(xml)
