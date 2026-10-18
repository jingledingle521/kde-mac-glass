#!/usr/bin/python3 -I
"""Set the Mac Glass level: 0 = clear, 100 = frosted.

    glass.py blur LEVEL    only change KWin's blur strength (instant; for dragging)
    glass.py apply LEVEL   also re-tint the panels and reload the Plasma style

The panel artwork is regenerated from panel-base.svg by make_panel.py."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
THEME = os.path.dirname(HERE)
NAME = os.path.basename(THEME)


def run(*cmd):
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def set_blur(level):
    # KWin's blur strength runs 1..15; Mac Glass uses 6 (clear) .. 15 (frosted).
    strength = round(6 + 9 * level / 100)
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-blur', '--key', 'BlurStrength', str(strength))
    run('dbus-send', '--session', '--type=method_call', '--dest=org.kde.KWin', '/Effects',
        'org.kde.kwin.Effects.reconfigureEffect', 'string:blur')


def set_tint(level):
    subprocess.run([sys.executable, '-I', os.path.join(HERE, 'make_panel.py'), os.path.join(HERE, 'panel-base.svg'),
                    os.path.join(THEME, 'widgets', 'panel-background.svgz'), str(level)], check=True)
    with open(os.path.join(HERE, 'level'), 'w') as f:
        f.write(f'{level}\n')
    # Plasma doesn't watch theme files; switching away and back reloads the style.
    cache = os.path.expanduser('~/.cache')
    for entry in os.listdir(cache):
        if entry.startswith(f'plasma_theme_{NAME}'):
            os.remove(os.path.join(cache, entry))
    run('plasma-apply-desktoptheme', 'default')
    run('plasma-apply-desktoptheme', NAME)


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('blur', 'apply'):
        sys.exit(__doc__)
    level = max(0, min(100, int(sys.argv[2])))
    set_blur(level)
    if sys.argv[1] == 'apply':
        set_tint(level)


if __name__ == '__main__':
    main()
