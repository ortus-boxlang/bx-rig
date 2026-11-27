#!/usr/bin/env python3
"""Draws the BxRig wallpaper collection at 3840x2400 (16:10; a 16:9 screen crops a little off the top and bottom, a smaller one scales down sharply).

Everything is computed, nothing is a photo, so it is crisp at any size: perspective grids from a distance field, light from blurred emissive layers,
silhouettes from noise, stars, glow, a vignette and a little grain so the gradients do not band.

Scenes (each takes the colours of a theme, or its own):
  horizon   a neon grid running to a sun on the horizon, light trails (Tron)            horizon-wordmark adds the BxRig block letters
  city      a skyline in three layers, lit windows, a moon, fog
  aurora    ridges under curtains of light, a mirror lake
  orbit     a planet's limb with an atmosphere, stars, a nebula, a thin ring
  circuit   glowing traces and vias in three depths of focus
  rain      falling code in three depths
  waves     stacked ridge lines, one per row (Unknown Pleasures)

    python3 tools/gen-wallpapers.py                   the whole collection
    python3 tools/gen-wallpapers.py bxrig nord        only these
    WP_SCALE=0.25 python3 tools/gen-wallpapers.py bxrig    a quarter size preview

The accessible themes (contrast, colourblind) keep their plain wallpapers (tools/gen-contrast-wallpapers.py) and bxrig-retro its own
(tools/gen-retro-wallpaper.py). Needs numpy and Pillow: a developer tool, the product has no Python. Then run bootstrap/gen-assets.sh."""
import os, re, sys, zlib, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = float(os.environ.get('WP_SCALE', '1'))
W, H = int(3840 * SCALE), int(2400 * SCALE)
PX = SCALE                      # one pixel of the 4K design, in pixels of this render

# DOS Rebel, "BxRig" (bxrig ascii BxRig --font=dos-rebel)
WORDMARK = [
	" ███████████              ███████████    ███",
	"░░███░░░░░███            ░░███░░░░░███  ░░░",
	" ░███    ░███ █████ █████ ░███    ░███  ████   ███████",
	" ░██████████ ░░███ ░░███  ░██████████  ░░███  ███░░███",
	" ░███░░░░░███ ░░░█████░   ░███░░░░░███  ░███ ░███ ░███",
	" ░███    ░███  ███░░░███  ░███    ░███  ░███ ░███ ░███",
	" ███████████  █████ █████ █████   █████ █████░░███████",
	"░░░░░░░░░░░  ░░░░░ ░░░░░ ░░░░░   ░░░░░ ░░░░░  ░░░░░███",
	"                                              ███ ░███",
	"                                             ░░██████",
	"                                              ░░░░░░",
]

# ---------------------------------------------------------------- colour and maths
def hexrgb(h):
	return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32) / 255.0

def mix(a, b, t):
	return a * (1 - t) + b * t

def smoothstep(a, b, x):
	t = np.clip((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)

def ramp(t, stops):
	"""t: an array in 0..1; stops: [(position, rgb)] -> array t.shape + (3,)."""
	t = np.clip(t, 0, 1)
	out = np.zeros(t.shape + (3,), dtype=np.float32)
	for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
		m = (t >= p0) & (t <= p1)
		k = ((t - p0) / max(1e-6, p1 - p0))[..., None]
		out = np.where(m[..., None], c0 * (1 - k) + c1 * k, out)
	return out

_gauss = {}
def blur(a, sigma):
	"""Gaussian blur by FFT. a: HxW or HxWx3 (float32); sigma in 4K pixels."""
	s = max(0.01, sigma * PX)
	if a.ndim == 3:
		return np.stack([blur(a[..., i], sigma) for i in range(a.shape[2])], axis=-1)
	key = (a.shape, round(s, 3))
	if key not in _gauss:
		fy = np.fft.fftfreq(a.shape[0])[:, None]
		fx = np.fft.rfftfreq(a.shape[1])[None, :]
		_gauss[key] = np.exp(-2 * (math.pi * s) ** 2 * (fx * fx + fy * fy)).astype(np.float32)
	return np.fft.irfft2(np.fft.rfft2(a) * _gauss[key], s=a.shape).astype(np.float32)

def noise1(n, rng, octaves=5, persistence=0.5, base=4):
	"""1D fractal value noise, n samples, 0..1."""
	out = np.zeros(n, dtype=np.float32)
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		k = base * (2 ** o) + 1
		pts = rng.random(k).astype(np.float32)
		xs = np.linspace(0, k - 1, n)
		i = np.minimum(xs.astype(int), k - 2)
		f = xs - i
		f = f * f * (3 - 2 * f)
		out += amp * (pts[i] * (1 - f) + pts[i + 1] * f)
		tot += amp
		amp *= persistence
	return out / tot

def noise2(shape, rng, octaves=5, persistence=0.55, base=3):
	"""2D fractal value noise, 0..1 (smooth: built from blurred-up random grids)."""
	h, w = shape
	out = np.zeros(shape, dtype=np.float32)
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		gh, gw = base * (2 ** o) + 2, int((base * (2 ** o) + 2) * w / h) + 2
		g = rng.random((gh, gw)).astype(np.float32)
		im = Image.fromarray(g, 'F').resize((w, h), Image.BICUBIC)
		out += amp * np.asarray(im)
		tot += amp
		amp *= persistence
	out /= tot
	return (out - out.min()) / (out.max() - out.min() + 1e-6)

def palette(name):
	"""The colours of a bundled theme (themes/<name>/colors.toml)."""
	text = open(os.path.join(root, 'themes', name, 'colors.toml')).read()
	def get(key, default=None):
		m = re.search(r'^' + key + r'\s*=\s*"(#[0-9a-fA-F]{6})"', text, re.M)
		return m.group(1) if m else default
	acc = get('accent')
	p = {
		'dark': re.search(r'^mode\s*=\s*"dark"', text, re.M) is not None,
		'bg': get('background'), 'deep': get('darker_background', get('background')), 'dim': get('dark_background', get('background')),
		'accent': acc, 'cyan': get('cyan', acc), 'blue': get('blue', acc), 'magenta': get('magenta', acc), 'green': get('green', acc),
		'orange': get('orange', acc), 'yellow': get('yellow', acc), 'red': get('red', acc), 'fg': get('foreground', '#ffffff'),
	}
	return {k: (hexrgb(v) if isinstance(v, str) else v) for k, v in p.items()}

def custom(dark, bg, deep, c1, c2, c3, c4=None):
	"""A palette that is not a theme's (for the extra BxRig wallpapers). c1 is the accent, c2 to c4 neighbours."""
	return {'dark': dark, 'bg': hexrgb(bg), 'deep': hexrgb(deep), 'dim': hexrgb(bg), 'accent': hexrgb(c1), 'cyan': hexrgb(c2), 'blue': hexrgb(c2),
			'magenta': hexrgb(c3), 'green': hexrgb(c1), 'orange': hexrgb(c4 or c3), 'yellow': hexrgb(c4 or c3), 'red': hexrgb(c3), 'fg': hexrgb('#ffffff')}

class Canvas:
	"""A render: `base` (what is lit by nothing) and `glow` (light that blooms). Light themes use `ink` colour layers over a pale base instead of light."""
	def __init__(self, p):
		self.p = p
		self.base = np.zeros((H, W, 3), dtype=np.float32)
		self.glow = np.zeros((H, W, 3), dtype=np.float32)

	def over(self, color, alpha):
		"""Composite a colour (3,) or an image (HxWx3) over the base with an alpha mask (HxW)."""
		a = alpha[..., None]
		self.base = self.base * (1 - a) + (color if np.ndim(color) == 3 else np.asarray(color)[None, None, :]) * a

	def light(self, color, intensity):
		"""Add light. On a dark theme it blooms; on a light theme it paints the colour in (an ink)."""
		if self.p['dark']:
			self.glow += (color if np.ndim(color) == 3 else np.asarray(color)[None, None, :]) * intensity[..., None]
		else:
			self.over(color, np.clip(intensity, 0, 1) * 0.9)

	def render(self, seed, bloom=(1.0, 0.7), vignette=0.38):
		img = self.base.copy()
		if self.p['dark']:
			g = self.glow
			img += g * 0.85
			img += blur(g, 8) * bloom[0] * 0.45 + blur(g, 40) * bloom[1] * 0.5 + blur(g, 160) * 0.32
		yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
		vv = np.sqrt(((xx / W) - 0.5) ** 2 + ((yy / H) - 0.5) ** 2) / 0.75
		img *= (1 - (vignette if self.p['dark'] else vignette * 0.3) * smoothstep(0.35, 1.0, vv))[..., None]
		img = np.clip(img, 0, 1)
		# tone: a little filmic shoulder so bright cores keep their colour
		img = img / (1 + 0.0 * img)
		grain = np.random.default_rng(seed).normal(0.0, 0.9 / 255.0, size=(H, W, 1)).astype(np.float32)
		img = np.clip(img + grain, 0, 1)
		return Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGB')

def stars(cv, rng, count, ymax=1.0, bright=1.0, tint=None):
	"""Scatter stars: mostly faint pin pricks, a few bright ones with a soft halo."""
	tint = tint if tint is not None else np.array([1, 1, 1], dtype=np.float32)
	layer = np.zeros((H, W), dtype=np.float32)
	n = int(count * SCALE * SCALE * 4)
	xs = rng.integers(0, W, n); ys = (rng.random(n) ** 1.3 * ymax * H).astype(int)
	vals = rng.random(n) ** 3
	layer[np.minimum(ys, H - 1), xs] = vals
	cv.light(tint, np.clip(layer * 1.0 * bright, 0, 1))
	big = rng.integers(0, max(1, n // 60), max(1, n // 60))
	h2 = np.zeros((H, W), dtype=np.float32)
	for i in range(max(1, n // 50)):
		h2[min(H - 1, int(rng.random() * ymax * H)), int(rng.random() * W)] = 1
	cv.light(tint, blur(h2, 2.0) * 22 * bright)

def wordmark(cv, p, cx, cy, cell=30, gradient=None, glow=1.0):
	"""The BxRig block letters (cells twice as tall as wide), centred on cx,cy in 4K pixels. gradient: (left, right) colours."""
	cw, ch = int(cell * PX), int(cell * 2 * PX)
	rows = WORDMARK
	mw, mh = max(len(r) for r in rows) * cw, len(rows) * ch
	x0, y0 = int(cx * PX) - mw // 2, int(cy * PX) - mh // 2
	solid = np.zeros((H, W), dtype=np.float32)
	shade = np.zeros((H, W), dtype=np.float32)
	for r, line in enumerate(rows):
		for c, chx in enumerate(line):
			ya, yb, xa, xb = y0 + r * ch, y0 + (r + 1) * ch, x0 + c * cw, x0 + (c + 1) * cw
			if ya < 0 or yb > H or xa < 0 or xb > W:
				continue
			if chx == '█':
				solid[ya:yb, xa:xb] = 1
			elif chx in '░▒▓':
				shade[ya:yb, xa:xb] = {'░': 0.30, '▒': 0.5, '▓': 0.7}[chx]
	a, b = gradient if gradient is not None else (hexrgb('#00d8ff'), hexrgb('#00ff78'))
	t = np.clip((np.arange(W, dtype=np.float32) - x0) / max(1, mw), 0, 1)
	grad = (a[None, :] * (1 - t[:, None]) + b[None, :] * t[:, None])[None, :, :]
	grad = np.broadcast_to(grad, (H, W, 3))
	if p['dark']:
		cv.glow += grad * (np.maximum(solid, shade * 0.5))[..., None] * 0.62
		cv.glow += grad * (blur(solid, 40) * 0.35 * glow)[..., None]
	else:
		cv.over(grad * 0.85, np.maximum(solid, shade))
	return (x0, y0, mw, mh)

# ---------------------------------------------------------------- scenes
def scene_horizon(name, p, rng, wm=False, sun=True, tint2=None):
	"""A neon grid to a sun on the horizon, with light trails."""
	cv = Canvas(p)
	dark = p['dark']
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	yh = 0.62 * H
	c1, c2 = p['accent'], (tint2 if tint2 is not None else p['cyan'])
	# the sky: deep at the top, the theme's colours near the horizon
	t = np.clip(yy / yh, 0, 1)
	if dark:
		sky = ramp(t, [(0.0, p['deep'] * 0.55), (0.55, mix(p['deep'], p['magenta'], 0.22)), (0.85, mix(p['deep'], c1, 0.30)), (1.0, mix(p['deep'], c1, 0.70))])
		floor = mix(p['deep'] * 0.7, p['deep'] * 0.3, np.clip((yy - yh) / (H - yh), 0, 1))[..., None] if False else None
	else:
		sky = ramp(t, [(0.0, mix(p['bg'], c2, 0.25)), (0.6, mix(p['bg'], p['magenta'], 0.18)), (1.0, mix(p['bg'], c1, 0.40))])
	cv.base[:] = sky
	below = yy > yh
	fl = np.clip((yy - yh) / (H - yh), 0, 1)
	floor_col = (p['deep'] * (0.55 - 0.3 * fl[..., None])) if dark else (mix(p['bg'], c1, 0.10) * (1 - 0.08 * fl[..., None]))
	cv.base = np.where(below[..., None], floor_col, cv.base)
	if dark:
		stars(cv, rng, 3500, ymax=0.55, bright=0.8)
	# the sun
	if sun:
		scx, scy, sr = W * 0.5, yh - 0.035 * H, 0.2 * H
		d = np.sqrt((xx - scx) ** 2 + (yy - scy) ** 2)
		disc = 1 - smoothstep(sr - 2 * PX, sr, d)
		g = np.clip((yy - (scy - sr)) / (2 * sr), 0, 1)
		scol = ramp(g, [(0.0, c2), (0.55, mix(c2, c1, 0.5)), (1.0, c1)])
		# gaps in the lower half, growing towards the bottom
		gaps = np.ones((H, W), dtype=np.float32)
		for k in range(9):
			gy = scy + sr * (0.05 + 0.09 * k + 0.012 * k * k)
			gh = (1.5 + 2.6 * k) * PX * 1.2
			gaps *= 1 - smoothstep(gh, gh * 0.5, np.abs(yy - gy)) * (yy > scy - 0.1 * sr)
		cv.light(scol, disc * gaps * (0.5 if dark else 1.0))
	# the grid: lines in perspective
	d = np.maximum(yy - yh, 1.0)
	cam = 1100.0 * PX
	z = cam / d
	F = 0.8 * W
	wx = (xx - W / 2) * z / F
	sx, sz = 0.11, 0.55
	gx = wx / sx
	footprint_x = 10.0 * z / F * (1 / sx) * 0.1 / 1.0
	fx = np.abs((gx + 0.5) % 1 - 0.5)
	px_x = fx / np.maximum(np.abs(np.gradient(gx, axis=1)), 1e-6)
	gz = z / sz
	fz = np.abs((gz + 0.5) % 1 - 0.5)
	px_z = fz / np.maximum(np.abs(np.gradient(gz, axis=0)), 1e-6)
	line = np.maximum(1 - smoothstep(0.6 * PX, 2.2 * PX, px_x), 1 - smoothstep(0.6 * PX, 2.2 * PX, px_z))
	far = smoothstep(2 * PX, 0.2 * H, d)
	line = line * far * below
	near = 1 - 0.35 * fl
	cv.light(mix(c1, c2, np.clip(fl * 1.5, 0, 1))[..., None] if False else mix(c1, c2, 0.35), line * near * (0.95 if dark else 0.55))
	# the horizon: a bright seam
	seam = np.exp(-(((yy - yh) / (6 * PX)) ** 2))
	cv.light(mix(c1, c2, 0.5), seam * 0.7)
	# mountains: two ridges with a rim of light along their edge
	for layer, (amp, base_n, shade) in enumerate(((0.14, 4, 0.55), (0.085, 7, 0.38))):
		ridge = (noise1(W, rng, 6, 0.52, base_n) - 0.25) * amp * H
		ridge = np.maximum(ridge, 0)
		top = yh - ridge
		m = (yy >= top[None, :]) & (yy <= yh)
		edge = np.exp(-(((yy - top[None, :]) / (2.2 * PX)) ** 2)) * (yy <= yh)
		cv.over(p['deep'] * shade if dark else mix(p['bg'], c1, 0.30 + 0.1 * layer), m.astype(np.float32))
		cv.glow *= (1 - m.astype(np.float32))[..., None]
		cv.light(mix(c1, c2, 0.4), edge * (0.55 if layer == 0 else 0.35))
	# far skyline silhouettes on the horizon
	nb = 160
	xs = np.linspace(0, W, nb + 1).astype(int)
	hts = (noise1(nb, rng, 4, 0.55, 5) ** 1.6 * 0.07 + 0.006) * H
	sil = np.zeros((H, W), dtype=np.float32)
	for i in range(nb):
		sil[int(yh - hts[i]):int(yh), xs[i]:xs[i + 1]] = 1
	cv.over(p['deep'] * 0.35 if dark else mix(p['bg'], c1, 0.32), sil * (1 - 0.0))
	# light trails: world paths on the grid, drawn as glowing lines
	trails = Image.new('L', (W, H), 0)
	core = Image.new('L', (W, H), 0)
	dr, dc = ImageDraw.Draw(trails), ImageDraw.Draw(core)
	def scr(wxx, zz):
		return (W / 2 + wxx * F / zz, yh + cam / zz)
	paths = [
		[(-0.55, 1.1), (-0.55, 6.5), (-0.14, 6.5), (-0.14, 40)],
		[(0.95, 1.1), (0.95, 3.2), (0.42, 3.2), (0.42, 40)],
		[(-1.4, 1.1), (-1.4, 2.6), (-0.9, 2.6), (-0.9, 40)],
	]
	for pi_, pts in enumerate(paths):
		sp = [scr(a, b) for a, b in pts]
		for (xa, ya), (xb, yb) in zip(sp, sp[1:]):
			wdt = max(2, int((14 if pi_ == 0 else 9) * PX * (1 + 3 * (max(ya, yb) - yh) / (H - yh))))
			dr.line([xa, ya, xb, yb], fill=255, width=wdt)
			dc.line([xa, ya, xb, yb], fill=255, width=max(1, wdt // 3))
	tmask = np.asarray(trails, dtype=np.float32) / 255
	cmask = np.asarray(core, dtype=np.float32) / 255
	for tc, a_ in ((c2, 1.0),):
		cv.light(tc, tmask * 0.28 * a_)
		cv.light(mix(tc, hexrgb('#ffffff'), 0.45), cmask * 0.8)
	if wm:
		wordmark(cv, p, 1920, 0.27 * 2400, cell=34, gradient=(mix(c2, hexrgb('#ffffff'), 0.1), c1))
	return cv.render(zlib.crc32(name.encode()) ^ 0x11)

def sky_base(cv, p, stops_dark, stops_light, ymax=1.0):
	"""Fill the base with a vertical sky ramp (positions 0..1 over ymax of the height)."""
	yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
	t = np.clip(yy / (ymax * H), 0, 1)
	cv.base[:] = ramp(t, stops_dark if p['dark'] else stops_light)
	return yy, t

def scene_city(name, p, rng, wm=False):
	"""A skyline in three layers with lit windows, a moon and fog."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2, c3 = p['accent'], p['cyan'] if dark else p['blue'], p['magenta']
	yy, t = sky_base(cv, p, [(0, p['deep'] * 0.5), (0.55, mix(p['deep'], c3, 0.28)), (0.85, mix(p['deep'], c1, 0.35)), (1, mix(p['deep'], c2, 0.5))],
		[(0, mix(p['bg'], c2, 0.30)), (0.6, mix(p['bg'], c3, 0.20)), (1, mix(p['bg'], c1, 0.35))], ymax=0.78)
	xx = np.mgrid[0:H, 0:W][1].astype(np.float32)
	if dark:
		stars(cv, rng, 2500, ymax=0.4, bright=0.7)
	# the moon
	mx, my, mr = rng.uniform(0.62, 0.8) * W, 0.2 * H, 0.075 * H
	dm = np.sqrt((xx - mx) ** 2 + (yy - my) ** 2)
	cv.light(mix(hexrgb('#ffffff'), c2, 0.25), (1 - smoothstep(mr - 2 * PX, mr, dm)) * (0.6 if dark else 0.9))
	ground = 0.86 * H
	layers = [(0.58, 0.70, 0.22, 90), (0.50, 0.58, 0.42, 70), (0.40, 0.46, 0.70, 45)]
	for li, (tallest, shortest, dim, count) in enumerate(layers):
		sil = np.zeros((H, W), dtype=np.float32)
		wins = np.zeros((H, W), dtype=np.float32)
		x = -40
		while x < W:
			bw = int(rng.uniform(0.012, 0.045) * W * (1 + 0.3 * li))
			bh = int(rng.uniform(shortest * 0.4, tallest) * H * (0.6 + 0.4 * rng.random()))
			top = int(ground - bh)
			sil[max(0, top):int(ground), max(0, x):min(W, x + bw)] = 1
			if li >= 1 and bw > 14 * PX:
				ws, wg = int((8 + 4 * li) * PX), int((22 + 8 * li) * PX)
				for wy in range(top + wg, int(ground) - wg, wg):
					row = rng.random((max(1, (bw - wg) // wg),)) < 0.35
					for k, on in enumerate(row):
						if on:
							xa = x + wg // 2 + k * wg
							if 0 <= xa < W - ws:
								wins[wy:wy + ws, xa:xa + ws] = 1
			x += bw + int(rng.uniform(0, 0.006) * W)
		fog = mix(p['deep'], c1, 0.18) if dark else mix(p['bg'], c1, 0.25)
		col = mix(p['deep'] * dim, fog, 0.25 * (2 - li)) if dark else mix(p['bg'] * (0.55 + 0.2 * li), c3, 0.15)
		cv.glow *= (1 - sil)[..., None]
		cv.over(col, sil)
		wc = mix(c1, c2, rng.random())
		cv.light(wc, wins * (0.55 + 0.1 * li))
		if li == 0:
			cv.light(mix(c1, c2, 0.5), np.clip(sil - np.roll(sil, 3, axis=0), 0, 1) * 0.6)
	# fog band on the ground
	fogb = smoothstep(ground - 0.14 * H, ground, yy)
	cv.over(mix(p['deep'], c1, 0.25) if dark else mix(p['bg'], c1, 0.4), fogb * 0.55)
	# a wet street: the lights reflected
	below = yy > ground
	refl = np.flipud(cv.glow)[: H, :, :]
	rsh = np.roll(np.flipud(cv.glow), int(2 * ground - H), axis=0) if False else None
	cv.over(p['deep'] * 0.3 if dark else mix(p['bg'], c1, 0.2), below.astype(np.float32))
	if wm:
		wordmark(cv, p, 1920, 0.2 * 2400, cell=26)
	return cv.render(zlib.crc32(name.encode()) ^ 0x22)

def scene_aurora(name, p, rng, wm=False):
	"""Ridges under curtains of light and a mirror lake."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2, c3 = p['accent'], p['cyan'] if dark else p['blue'], p['magenta']
	yy, t = sky_base(cv, p, [(0, p['deep'] * 0.45), (0.7, mix(p['deep'], c2, 0.12)), (1, mix(p['deep'], c1, 0.30))],
		[(0, mix(p['bg'], c2, 0.25)), (1, mix(p['bg'], c1, 0.30))], ymax=0.66)
	xx = np.mgrid[0:H, 0:W][1].astype(np.float32)
	if dark:
		stars(cv, rng, 4000, ymax=0.5, bright=0.9)
	# curtains: a wavy lower edge, rays above it that thin out upwards
	u = xx / W
	edge = 0.42 + 0.10 * np.sin(u * 5.1 + 1.3) + 0.06 * np.sin(u * 13.7) + 0.04 * np.sin(u * 29 + 2)
	edge = np.broadcast_to(edge, (H, W)) * H
	yrel = (edge - yy) / (0.34 * H)
	ray = 0.55 + 0.45 * np.sin(u * 410 + 3 * np.sin(u * 23)) * np.sin(u * 77 + 1)
	vert = np.where(yrel > 0, np.exp(-yrel * 1.7), np.exp(yrel * 14)) * (yrel > -0.12)
	cur = np.clip(vert * ray, 0, 1)
	cols = ramp(np.clip(yrel, 0, 1), [(0.0, c1), (0.5, c2), (1.0, c3)])
	cv.light(cols, cur * 0.75)
	cur2 = np.clip(np.where((edge - yy) > 0, np.exp(-((edge * 0.8 + 0.06 * H - yy) / (0.22 * H)) ** 2), 0) * (0.5 + 0.5 * np.sin(u * 190 + 8)), 0, 1)
	cv.light(mix(c2, c3, 0.5), cur2 * 0.30)
	# ridges, a lake below
	lake = 0.80 * H
	for i, (amp, base_n, shade) in enumerate(((0.20, 3, 0.35), (0.12, 6, 0.18))):
		ridge = (noise1(W, rng, 6, 0.5, base_n) - 0.2) * amp * H
		top = lake - np.maximum(ridge, 4)
		m = ((yy >= top[None, :]) & (yy <= lake)).astype(np.float32)
		cv.glow *= (1 - m)[..., None]
		cv.over(p['deep'] * shade if dark else mix(p['bg'], c1, 0.45 + 0.1 * i), m)
	# the lake: a flipped copy of the sky, dimmed and blurred
	im = np.clip(cv.base + cv.glow * 0.9, 0, 1)
	flip = np.flipud(im)
	shift = int(2 * lake - H)
	reflection = np.roll(flip, shift, axis=0) if shift else flip
	reflection = blur(reflection, 5)
	lm = (yy > lake).astype(np.float32)
	ripple = 0.85 + 0.15 * np.sin(yy * 0.5 / PX + noise2((H, W), rng, 3, 0.5, 2) * 40)
	cv.over(reflection * 0.45 * (ripple[..., None] if True else 1) + p['deep'][None, None, :] * 0.25 if dark else reflection * 0.8, lm)
	cv.glow *= (1 - lm)[..., None]
	if wm:
		wordmark(cv, p, 1920, 0.22 * 2400, cell=26)
	return cv.render(zlib.crc32(name.encode()) ^ 0x33)

def scene_orbit(name, p, rng, wm=False):
	"""A planet's limb with an atmosphere, stars, a nebula and a thin ring."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2, c3 = p['accent'], p['cyan'] if dark else p['blue'], p['magenta']
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	cv.base[:] = (p['deep'] * 0.5)[None, None, :] if dark else p['bg'][None, None, :]
	# nebula
	n1, n2 = noise2((H, W), rng, 6, 0.55, 2), noise2((H, W), rng, 5, 0.6, 3)
	neb = np.clip((n1 - 0.45) * 2.4, 0, 1) ** 1.6
	cv.light(mix(c3, c2, n2[..., None]) if False else ramp(n2, [(0, c3), (0.5, c2), (1, c1)]), neb * 0.32)
	if dark:
		stars(cv, rng, 9000, ymax=1.0, bright=1.0)
	# the planet: a huge circle below the frame, lit from the top left
	cx, cy, R = 0.42 * W, 1.62 * H, 0.98 * H
	d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
	inside = 1 - smoothstep(R - 1.5 * PX, R, d)
	lit = np.clip(((cy - yy) / R) * 0.9 + ((cx - xx) / R) * 0.35 + 0.35, 0, 1)
	tex = noise2((H, W), rng, 6, 0.5, 5)
	surface = mix(p['deep'] * 0.25, mix(c2, c1, tex[..., None]) * 0.5, lit[..., None] * 0.7)
	cv.glow *= (1 - inside)[..., None]
	cv.over(surface, inside)
	# the atmosphere: a bright rim, and a halo outside it
	rim = np.exp(-(((d - R) / (6 * PX)) ** 2)) * (0.4 + 0.6 * lit)
	halo = np.exp(-np.clip((d - R) / (0.06 * H), 0, 8)) * (d > R) * (0.3 + 0.7 * lit)
	cv.light(mix(c2, hexrgb('#ffffff'), 0.4), rim * 1.2)
	cv.light(c2, halo * 0.7)
	cv.light(c1, np.exp(-np.clip((R - d) / (0.03 * H), 0, 9)) * inside * lit * 0.25)
	# a thin ring: an ellipse around a far centre
	rx, ry = 0.95 * W, 0.26 * H
	ex = ((xx - 0.5 * W) / rx) ** 2 + ((yy - 0.46 * H) / ry) ** 2
	ring = np.exp(-(((np.sqrt(ex) - 1.0) * rx) / (4.0 * PX)) ** 2) * (yy < cy - R * 0.85) * 0.9
	cv.light(mix(c1, c2, 0.5), ring)
	if wm:
		wordmark(cv, p, 1920, 0.30 * 2400, cell=30)
	return cv.render(zlib.crc32(name.encode()) ^ 0x44)

def scene_circuit(name, p, rng, wm=False):
	"""Glowing traces and vias in three depths of focus."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2, c3 = p['accent'], p['cyan'] if dark else p['blue'], p['magenta']
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	cv.base[:] = mix(p['deep'] * 0.45, p['deep'] * 0.8, (yy / H)[..., None]) if dark else mix(p['bg'], c2, 0.12 + 0.1 * (yy / H)[..., None])
	for depth, (cell, lw, br, bl, nets) in enumerate(((140, 3, 0.55, 5.0, 26), (96, 5, 0.8, 0.0, 22), (210, 9, 0.5, 11.0, 8))):
		layer = Image.new('L', (W, H), 0)
		vias = Image.new('L', (W, H), 0)
		dr, dv = ImageDraw.Draw(layer), ImageDraw.Draw(vias)
		cs = int(cell * PX)
		for n in range(nets):
			x, y = int(rng.integers(0, W // cs)) * cs, int(rng.integers(0, H // cs)) * cs
			ang = rng.integers(0, 4)
			pts = [(x, y)]
			for step in range(int(rng.integers(5, 14))):
				run = int(rng.integers(2, 9)) * cs
				dx, dy = [(1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)][(ang + int(rng.integers(-1, 2))) % 4 if rng.random() < 0.8 else int(rng.integers(4, 8))]
				x, y = x + dx * run, y + dy * run
				pts.append((x, y))
				ang = (ang + int(rng.integers(0, 3)) - 1) % 4
			dr.line(pts, fill=255, width=max(1, int(lw * PX)), joint='curve')
			for (vx, vy) in (pts[0], pts[-1]):
				r = int(lw * 2.6 * PX)
				dv.ellipse([vx - r, vy - r, vx + r, vy + r], outline=255, width=max(1, int(lw * 0.7 * PX)))
		m = np.asarray(layer, dtype=np.float32) / 255 + np.asarray(vias, dtype=np.float32) / 255
		if bl > 0:
			m = blur(m, bl)
		col = (c1, c2, c3)[depth]
		cv.light(mix(col, hexrgb('#ffffff'), 0.2), np.clip(m, 0, 1) * br * 1.5)
	# a faint hex grid
	hx = (np.sin(xx / (60 * PX)) + np.sin((xx * 0.5 + yy * 0.866) / (60 * PX)) + np.sin((xx * 0.5 - yy * 0.866) / (60 * PX)))
	cv.light(c2, np.clip(hx - 2.55, 0, 1) * 0.35 * smoothstep(0.0, 1.0, 1 - np.abs(yy / H - 0.5) * 2))
	if wm:
		wordmark(cv, p, 1920, 0.5 * 2400, cell=34)
	return cv.render(zlib.crc32(name.encode()) ^ 0x55)

def scene_rain(name, p, rng, wm=False):
	"""Falling code in three depths."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2 = p['accent'], p['cyan'] if dark else p['blue']
	yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
	cv.base[:] = mix(p['deep'] * 0.5, p['deep'] * 0.9, (yy / H)[..., None]) if dark else mix(p['bg'], c2, 0.10)
	fontpath = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
	glyphs = '01{}()<>=/;:+-*&|$#@xXiIlL'
	for depth, (size, cols, br, bl) in enumerate(((22, 150, 0.35, 3.0), (34, 90, 0.7, 0.0), (64, 34, 0.9, 6.0))):
		fs = max(6, int(size * PX))
		font = ImageFont.truetype(fontpath, fs)
		layer = Image.new('L', (W, H), 0)
		dr = ImageDraw.Draw(layer)
		xs = rng.permutation(W // fs)[:cols]
		for cx in xs:
			x = int(cx) * fs
			head = int(rng.uniform(0.15, 1.0) * H)
			length = int(rng.uniform(6, 26))
			for k in range(length):
				y = head - k * int(fs * 1.25)
				if y < -fs or y > H:
					continue
				a = int(255 * (1 - k / length) ** 1.5)
				dr.text((x, y), glyphs[int(rng.integers(0, len(glyphs)))], font=font, fill=a)
		m = np.asarray(layer, dtype=np.float32) / 255
		if bl > 0:
			m = blur(m, bl)
		cv.light(mix(c1, c2, depth / 2.0 * 0.6), m * br * (1.6 if bl else 1.0))
	if wm:
		wordmark(cv, p, 1920, 0.5 * 2400, cell=34)
	return cv.render(zlib.crc32(name.encode()) ^ 0x66)

def scene_waves(name, p, rng, wm=False):
	"""Stacked ridge lines, one per row, each hiding the ones behind it."""
	cv = Canvas(p)
	dark = p['dark']
	c1, c2 = p['accent'], p['cyan'] if dark else p['blue']
	yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
	cv.base[:] = mix(p['deep'] * 0.4, p['deep'] * 0.9, (yy / H)[..., None]) if dark else mix(p['bg'], c2, 0.08)
	rows = 58
	img = Image.new('L', (W, H), 0)
	fill = Image.new('L', (W, H), 0)
	dl, df = ImageDraw.Draw(img), ImageDraw.Draw(fill)
	xs = np.linspace(0, W, 480)
	for r in range(rows):
		y0 = 0.22 * H + r * (0.70 * H / rows)
		bumps = np.zeros_like(xs)
		for k in range(3):
			c = rng.uniform(0.2, 0.8) * W
			bumps += rng.uniform(0.4, 1.0) * np.exp(-((xs - c) / (rng.uniform(0.04, 0.12) * W)) ** 2)
		jag = noise1(len(xs), rng, 4, 0.7, 40) - 0.5
		ys = y0 - (bumps * 0.07 * H * (0.4 + 0.6 * r / rows) + jag * 0.012 * H)
		poly = list(zip(xs, ys))
		df.polygon(poly + [(W, H), (0, H)], fill=255 - int(r * 255 / (rows * 1.0)) if False else 255)
		dl.line(poly, fill=255, width=max(1, int(3.2 * PX)))
		# earlier rows are hidden by this row's fill
		# (the later row is nearer: it is drawn on top, so rows are painted back to front below)
	# painted back to front: redo so each row occludes the lines behind it
	cv2_glow = np.zeros((H, W), dtype=np.float32)
	occ = Image.new('L', (W, H), 0)
	line_img = Image.new('L', (W, H), 0)
	dl2, do2 = ImageDraw.Draw(line_img), ImageDraw.Draw(occ)
	rng2 = np.random.default_rng(zlib.crc32(name.encode()))
	for r in range(rows):
		y0 = 0.22 * H + r * (0.70 * H / rows)
		bumps = np.zeros_like(xs)
		for k in range(3):
			c = rng2.uniform(0.2, 0.8) * W
			bumps += rng2.uniform(0.4, 1.0) * np.exp(-((xs - c) / (rng2.uniform(0.04, 0.12) * W)) ** 2)
		jag = noise1(len(xs), rng2, 4, 0.7, 40) - 0.5
		ys = y0 - (bumps * 0.07 * H * (0.4 + 0.6 * r / rows) + jag * 0.012 * H)
		poly = list(zip(xs, ys))
		do2.polygon(poly + [(W, H), (0, H)], fill=255)
		ImageDraw.Draw(line_img).polygon(poly + [(W, H), (0, H)], fill=0)
		ImageDraw.Draw(line_img).line(poly, fill=255, width=max(1, int(3.4 * PX)))
	lm = np.asarray(line_img, dtype=np.float32) / 255
	cv.light(mix(c1, c2, 0.3), lm * 0.85)
	if wm:
		wordmark(cv, p, 1920, 0.5 * 2400, cell=34)
	return cv.render(zlib.crc32(name.encode()) ^ 0x77)

# ---------------------------------------------------------------- the collection
THEME_SCENE = {
	# the themes, each with a scene that suits its character and its own colours
	'bxrig': ('horizon', {'wm': True}),
	'bxrig-light': ('horizon', {'wm': True}),
	'bxrig-cyan': ('horizon', {}),
	'bxrig-ember': ('city', {}),
	'bxrig-forest': ('aurora', {}),
	'bxrig-midnight': ('rain', {'wm': True}),
	'bxrig-dawn': ('city', {}),
	'bxrig-mint': ('waves', {}),
	'bxrig-paper': ('waves', {}),
	'bxrig-sky': ('horizon', {}),
	'catppuccin': ('orbit', {}),
	'catppuccin-latte': ('city', {}),
	'everforest': ('aurora', {}),
	'flexoki-light': ('circuit', {}),
	'gruvbox': ('circuit', {}),
	'kanagawa': ('waves', {}),
	'matte-black': ('circuit', {}),
	'nord': ('aurora', {}),
	'rose-pine': ('waves', {}),
	'tokyo-night': ('city', {}),
}

# the extra BxRig collection: its own neon palettes (dark, bg, deep, accent, neighbour, third[, fourth])
EXTRA = {
	'bxrig-tron': ('horizon', {'wm': True, 'tint2': hexrgb('#00e5ff')}, custom(True, '#05080f', '#05080f', '#ff8a1f', '#00e5ff', '#ff3d00')),
	'bxrig-neon': ('horizon', {'sun': True}, custom(True, '#0b0420', '#0b0420', '#ff2ec4', '#35e8ff', '#8a2dff')),
	'bxrig-city': ('city', {'wm': True}, custom(True, '#070a18', '#070a18', '#35e8ff', '#00ff78', '#ff2ec4')),
	'bxrig-aurora': ('aurora', {}, custom(True, '#050a14', '#050a14', '#00ff78', '#35e8ff', '#9d5cff')),
	'bxrig-orbit': ('orbit', {'wm': True}, custom(True, '#04060c', '#04060c', '#00ff78', '#35e8ff', '#7a2dff')),
	'bxrig-circuit': ('circuit', {'wm': True}, custom(True, '#04080a', '#04080a', '#00ff78', '#35e8ff', '#ffd400')),
	'bxrig-rain': ('rain', {'wm': True}, custom(True, '#02070a', '#02070a', '#00ff78', '#7dffb4', '#35e8ff')),
	'bxrig-waves': ('waves', {'wm': True}, custom(True, '#04070d', '#04070d', '#35e8ff', '#00ff78', '#9d5cff')),
}

def build(name):
	rng = np.random.default_rng(zlib.crc32(name.encode()))
	if name in EXTRA:
		scene, kw, p = EXTRA[name]
	else:
		scene, kw = THEME_SCENE[name]
		p = palette(name)
	fn = globals()['scene_' + scene]
	return fn(name, p, rng, **kw)

def main():
	names = sys.argv[1:] or sorted(list(THEME_SCENE) + list(EXTRA))
	out_dir = os.path.join(root, 'assets', 'wallpapers')
	for name in names:
		im = build(name)
		path = os.path.join(out_dir, name + ('.jpg' if SCALE == 1 else '-preview.png'))
		if SCALE == 1:
			im.save(path, 'JPEG', quality=90, subsampling=0, optimize=True)
			print(name, os.path.getsize(path) // 1024, 'KB')
		else:
			im.save('/tmp/shots/wp-' + name + '.png')
			print('preview /tmp/shots/wp-' + name + '.png')

if __name__ == '__main__':
	main()
