#!/usr/bin/env python3
"""Generates the BxRig icon theme (style A: superellipse tile, vertical glow, white Phosphor duotone glyph, one gradient per category).

    python3 tools/gen-icon-theme.py            write the SVGs, index.theme and the licence (stdlib only), then render the PNGs with tools/render-icon-theme.js
    python3 tools/gen-icon-theme.py --no-png   only the text files
    python3 tools/gen-icon-theme.py --check    fail when a text file is out of date (CI, bootstrap/gen-assets.sh --check); also checks every PNG exists
    python3 tools/gen-icon-theme.py --report   print the contrast of the white glyph on every category, full and small variant

Output (committed, embedded in the binary as resources, installed to ~/.local/share/icons/BxRig by `bxrig appearance icons bxrig`):
    assets/icons/theme/BxRig/index.theme          Inherits=Papirus-Dark,hicolor
    assets/icons/theme/BxRig/scalable/{apps,categories}/NAME.svg     the full drawing (duotone glyph, glow, gloss)
    assets/icons/theme/BxRig/SIZExSIZE/{apps,categories}/NAME.png    16 22 24 32 48 64 128 256 (rendered by tools/render-icon-theme.js)
    assets/icons/theme/BxRig/LICENSE-Phosphor.txt  the MIT licence of the glyphs
    assets/icons/theme/src/small/NAME.svg         the 16 and 22 px drawing: bold glyph, darker tile, less glow (source for those PNGs, not installed)
    assets/icons/theme/manifest.json              names, sizes and glyphs (read by the renderer and the tests)
The glyphs are Phosphor Icons (MIT, https://github.com/phosphor-icons/core), vendored in assets/icons/phosphor/ (duotone for 24 px and up,
bold for 16 and 22 px). `bxrig` and `bxrig-grid` are the existing BxRig laptop (assets/icons/bxrig*.svg) and the Launchpad grid plate.
Fetching a glyph: curl -O https://raw.githubusercontent.com/phosphor-icons/core/main/assets/duotone/NAME-duotone.svg (and .../bold/NAME-bold.svg)."""
import json, math, os, re, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
theme = os.path.join(root, 'assets/icons/theme')
out = os.path.join(theme, 'BxRig')
phos = os.path.join(root, 'assets/icons/phosphor')
SIZES = [16, 22, 24, 32, 48, 64, 128, 256]
SMALL = [16, 22]   # drawn with the bold glyph, a darker tile and less glow

# category: (top, bottom, glow); the palette of themes/bxrig/colors.toml and the owner's style A page
CATS = {
	'develop': ('#22d67c', '#00833c', '#00ff78'),
	'system': ('#1bbdea', '#0762c4', '#00dbff'),
	'look': ('#b682ea', '#7640c8', '#ca9ee6'),
	'control': ('#7f9cea', '#4a5fc4', '#8caaee'),
	'utility': ('#f0a43c', '#cf5f2a', '#ffd27a'),
	'alert': ('#ff7479', '#d0344f', '#ff7a85'),
}

# name, glyph, category, where (apps or categories), title, what it is for
ICONS = [
	('bxrig-develop', 'code', 'develop', 'categories', 'Develop', 'the Develop folder of the BxRig menu'),
	('bxrig-system', 'cpu', 'system', 'categories', 'System', 'the System folder of the BxRig menu'),
	('bxrig-look', 'paint-brush', 'look', 'categories', 'Look', 'the Look folder and the Look page'),
	('bxrig-control-center', 'sliders-horizontal', 'control', 'apps', 'Control Center', 'the Control Center launcher'),
	('bxrig-wizard', 'magic-wand', 'look', 'apps', 'Setup Wizard', 'the Setup Wizard launcher'),
	('bxrig-runner', 'rocket-launch', 'control', 'apps', 'Runner', 'the Runner menu launcher'),
	('bxrig-apps', 'squares-four', 'control', 'apps', 'Apps', 'the Apps page'),
	('bxrig-dashboard', 'gauge', 'system', 'apps', 'Dashboard', 'the Dashboard page'),
	('bxrig-ports', 'plugs-connected', 'develop', 'apps', 'Ports', 'the Ports page'),
	('bxrig-network', 'wifi-high', 'system', 'apps', 'Network', 'the Network page'),
	('bxrig-backups', 'cloud-arrow-up', 'system', 'apps', 'Backups', 'backups'),
	('bxrig-updates', 'arrow-circle-up', 'develop', 'apps', 'Updates', 'updates'),
	('bxrig-agents', 'robot', 'look', 'apps', 'AI agents', 'the AI agents'),
	('bxrig-vpn', 'shield-check', 'system', 'apps', 'VPN', 'the VPN panel'),
	('bxrig-dev-services', 'stack', 'develop', 'apps', 'Dev services', 'the developer panel (databases, containers, VMs)'),
	('bxrig-about', 'info', 'control', 'apps', 'About', 'the About launcher'),
	('bxrig-boxlang', 'cube', 'develop', 'apps', 'BoxLang', 'the BoxLang page'),
	('bxrig-modules', 'stack', 'develop', 'apps', 'BoxLang modules', 'the BoxLang modules page'),
	('bxrig-servers', 'globe', 'develop', 'apps', 'Servers', 'the Servers page'),
	('bxrig-tasks', 'list-checks', 'system', 'apps', 'Tasks', 'the Tasks page'),
	('bxrig-java', 'coffee', 'develop', 'apps', 'Java', 'the Java page'),
	('bxrig-maven', 'wrench', 'develop', 'apps', 'Maven', 'the Maven page'),
	('bxrig-gradle', 'hammer', 'develop', 'apps', 'Gradle', 'the Gradle page'),
	('bxrig-versions', 'tag', 'develop', 'apps', 'Versions', 'the Versions page'),
	('bxrig-databases', 'database', 'develop', 'apps', 'Databases', 'the Databases page'),
	('bxrig-mail', 'envelope', 'utility', 'apps', 'Mail', 'the Mail page'),
	('bxrig-machines', 'desktop-tower', 'system', 'apps', 'Machines', 'the Machines page'),
	('bxrig-storage', 'hard-drives', 'system', 'apps', 'Storage', 'the Storage page'),
	('bxrig-secrets', 'key', 'utility', 'apps', 'Secrets', 'the Secrets page'),
	('bxrig-logs', 'scroll', 'system', 'apps', 'Logs', 'the Logs page'),
	('bxrig-packages', 'package', 'utility', 'apps', 'Packages', 'the Packages page'),
	('bxrig-shortcuts', 'keyboard', 'control', 'apps', 'Shortcuts', 'the Shortcuts page'),
	('bxrig-themes', 'palette', 'look', 'apps', 'Themes', 'the Themes page'),
	('bxrig-accessibility', 'person-arms-spread', 'look', 'apps', 'Accessibility', 'the Accessibility page'),
]
# existing artwork reused as it is: name -> (scalable source, small source, where)
REUSED = {
	'bxrig': ('assets/icons/bxrig.svg', 'assets/icons/bxrig-small.svg', 'apps'),
	'bxrig-grid': ('assets/icons/plates/bxrig-grid.svg', 'assets/icons/plates/bxrig-grid.svg', 'apps'),
}


def lum(hexc):
	r, g, b = [int(hexc[i:i + 2], 16) / 255 for i in (1, 3, 5)]
	f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
	return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def mix(a, b, t):
	pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
	pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
	return '#%02x%02x%02x' % tuple(round(x + (y - x) * t) for x, y in zip(pa, pb))


def contrast(c):   # white on c
	return 1.05 / (lum(c) + 0.05)


def tile_colors(cat, small):
	top, bot, glow = CATS[cat]
	if small:   # darken the tile until white reads at 16 px (WCAG 3:1 for graphics) in the worst spot of the glyph
		k = 0.0
		while k < 0.7 and contrast(under_glyph(mix(top, '#000000', k), mix(bot, '#000000', k), glow, 0.25)) < 3.2:
			k += 0.05
		top, bot = mix(top, '#000000', k), mix(bot, '#000000', k)
	return top, bot, glow


def under_glyph(top, bot, glow, glow_alpha):
	"""The lightest colour behind the glyph: the bottom of the glyph (y = 78), tile gradient plus the glow from below (r 62 around (50, 104))."""
	base = mix(top, bot, 0.78)
	a = max(0.0, 1 - 26 / 62) * glow_alpha
	return mix(base, glow, a)


def superellipse(n=5, r=49, c=50, per=24):
	pts = []
	for i in range(per * 4):
		t = 2 * math.pi * i / (per * 4)
		ct, st = math.cos(t), math.sin(t)
		x = c + r * math.copysign(abs(ct) ** (2 / n), ct)
		y = c + r * math.copysign(abs(st) ** (2 / n), st)
		pts.append('%.1f,%.1f' % (x, y))
	return 'M' + ' L'.join(pts) + 'Z'


def glyph_inner(name, weight):
	svg = open(os.path.join(phos, ('bold/%s-bold.svg' if weight == 'bold' else '%s-duotone.svg') % name)).read()
	return re.search(r'<svg[^>]*>(.*)</svg>', svg, re.S).group(1).strip()


def tile_svg(glyph, cat, small):
	top, bot, glow = tile_colors(cat, small)
	ga = 0.25 if small else 0.6
	inner = glyph_inner(glyph, 'bold' if small else 'duotone')
	size, x, y = (64, 18, 18) if small else (56, 22, 22)
	s = size / 256
	shadow = 0.32 if small else 0.22
	gloss = '' if small else '<use xlink:href="#t" fill="url(#gl)"/>'
	return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100" width="256" height="256">'
		'<defs><path id="t" d="%s"/>'
		'<linearGradient id="v" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
		'<radialGradient id="g" cx="50" cy="104" r="62" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="%s" stop-opacity="%s"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>'
		'<linearGradient id="gl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".30"/><stop offset=".55" stop-color="#fff" stop-opacity="0"/></linearGradient>'
		'<linearGradient id="r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="%s"/><stop offset=".45" stop-color="#fff" stop-opacity=".08"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
		'<g id="p">%s</g></defs>'
		'<use xlink:href="#t" fill="url(#v)"/><use xlink:href="#t" fill="url(#g)"/>%s'
		'<use xlink:href="#t" fill="none" stroke="url(#r)" stroke-width="1.6"/>'
		'<g transform="translate(%s %s) scale(%.5f)" fill="#000" opacity="%s"><use xlink:href="#p"/></g>'
		'<g transform="translate(%s %s) scale(%.5f)" fill="#fff"><use xlink:href="#p"/></g></svg>\n'
		) % (superellipse(), top, bot, glow, ga, glow, '.45' if small else '.65', inner, gloss, x, y + 2.2, s, shadow, x, y, s)


def index_theme():
	dirs = []
	for ctx in ('apps', 'categories'):
		dirs.append('scalable/' + ctx)
		for z in SIZES: dirs.append('%dx%d/%s' % (z, z, ctx))
	lines = ['[Icon Theme]', 'Name=BxRig', 'Comment=BxRig icons: superellipse tiles with a Phosphor duotone glyph. Everything else comes from Papirus-Dark.',
		'Inherits=Papirus-Dark,hicolor', 'Example=bxrig', 'Directories=' + ','.join(dirs), '']
	for ctx, context in (('apps', 'Applications'), ('categories', 'Categories')):
		lines += ['[scalable/%s]' % ctx, 'Size=128', 'MinSize=16', 'MaxSize=512', 'Type=Scalable', 'Context=' + context, '']
		for z in SIZES: lines += ['[%dx%d/%s]' % (z, z, ctx), 'Size=%d' % z, 'Type=Fixed', 'Context=%s' % context, '']
	return '\n'.join(lines)


def files():
	"""{ path: text } for every text file the generator owns."""
	f = {}
	for name, glyph, cat, where, title, use in ICONS:
		f['BxRig/scalable/%s/%s.svg' % (where, name)] = tile_svg(glyph, cat, False)
		f['src/small/%s.svg' % name] = tile_svg(glyph, cat, True)
	for name, (full, small, where) in REUSED.items():
		f['BxRig/scalable/%s/%s.svg' % (where, name)] = open(os.path.join(root, full)).read()
		f['src/small/%s.svg' % name] = open(os.path.join(root, small)).read()
	f['BxRig/index.theme'] = index_theme()
	f['BxRig/LICENSE-Phosphor.txt'] = ('The glyphs in these icons are Phosphor Icons (https://phosphoricons.com, https://github.com/phosphor-icons/core), used under the MIT licence:\n\n'
		+ open(os.path.join(phos, 'LICENSE')).read())
	names = [i[0] for i in ICONS] + list(REUSED)
	where = {i[0]: i[3] for i in ICONS}; where.update({k: v[2] for k, v in REUSED.items()})
	f['manifest.json'] = json.dumps({'theme': 'BxRig', 'sizes': SIZES, 'small': SMALL, 'icons': [
		{'name': i[0], 'glyph': i[1], 'category': i[2], 'context': i[3], 'title': i[4], 'use': i[5]} for i in ICONS] + [
		{'name': k, 'glyph': '', 'category': 'brand', 'context': v[2], 'title': k, 'use': 'reused artwork'} for k, v in REUSED.items()]}, indent='\t') + '\n'
	return f


def png_paths():
	for name, glyph, cat, where, title, use in ICONS: yield name, where
	for k, v in REUSED.items(): yield k, v[2]


def report():
	print('%-9s %-12s %s' % ('category', 'full 24+', 'small 16/22'))
	for cat in CATS:
		tf, bf, g = tile_colors(cat, False); ts, bs, g = tile_colors(cat, True)
		print('%-9s %-12s %s' % (cat, '%.2f:1' % contrast(under_glyph(tf, bf, g, 0.6)), '%.2f:1 (tile %s to %s)' % (contrast(under_glyph(ts, bs, g, 0.25)), ts, bs)))


def main():
	arg = sys.argv[1] if len(sys.argv) > 1 else ''
	if arg == '--report': return report()
	want = files()
	if arg == '--check':
		bad = []
		for rel, text in want.items():
			p = os.path.join(theme, rel)
			if not os.path.exists(p) or open(p).read() != text: bad.append(rel)
		for name, where in png_paths():
			for z in SIZES:
				if not os.path.exists(os.path.join(out, '%dx%d/%s/%s.png' % (z, z, where, name))): bad.append('%dx%d/%s/%s.png' % (z, z, where, name))
		if bad:
			print('icon theme is out of date (%d files, first: %s): run python3 tools/gen-icon-theme.py' % (len(bad), bad[0]), file=sys.stderr); sys.exit(1)
		print('icon theme is current (%d icons)' % len(list(png_paths()))); return
	for rel, text in want.items():
		p = os.path.join(theme, rel)
		os.makedirs(os.path.dirname(p), exist_ok=True)
		open(p, 'w').write(text)
	print('wrote %d files for %d icons' % (len(want), len(list(png_paths()))))
	if arg != '--no-png':
		subprocess.check_call(['node', os.path.join(root, 'tools/render-icon-theme.js')])


main()
