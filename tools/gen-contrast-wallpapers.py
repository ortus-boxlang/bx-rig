#!/usr/bin/env python3
"""Draws the wallpapers of the three accessible themes: a plain background with one thin accent line, nothing that moves the eye.

    python3 tools/gen-contrast-wallpapers.py      writes assets/wallpapers/bxrig-contrast-dark.jpg, bxrig-contrast-light.jpg, bxrig-colorblind.jpg

Colours come from themes/<name>/colors.toml (background and accent). 3840x2400, JPEG quality 92. Then run bootstrap/gen-assets.sh."""
import os, re
from PIL import Image, ImageDraw

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 3840, 2400

def colors(name):
	text = open(os.path.join(root, 'themes', name, 'colors.toml')).read()
	get = lambda key: re.search(r'^' + key + r'\s*=\s*"(#[0-9a-fA-F]{6})"', text, re.M).group(1)
	return get('background'), get('accent')

for name in ('bxrig-contrast-dark', 'bxrig-contrast-light', 'bxrig-colorblind'):
	bg, accent = colors(name)
	im = Image.new('RGB', (W, H), bg)
	d = ImageDraw.Draw(im)
	# one short accent line, low and centred: a quiet mark, far from where windows and text go
	d.rounded_rectangle([W // 2 - 240, H - 180, W // 2 + 240, H - 168], radius=6, fill=accent)
	out = os.path.join(root, 'assets', 'wallpapers', name + '.jpg')
	im.save(out, 'JPEG', quality=92, subsampling=0)
	print('wrote', os.path.relpath(out, root))
