#!/usr/bin/env python3
"""Records any terminal command (a Control Center page, a few bxrig commands) for docs and pull requests: runs it in a pseudo-terminal,
plays a scripted list of keystrokes, emulates the screen with pyte, draws every frame with Pillow and encodes a video and a GIF with ffmpeg.
A dev tool, not part of BxRig. Same renderer as record-controlcenter.py.
Usage: python3 tools/record-term.py --name NAME --cmd 'bxrig tui look --demo' --script steps.json [--out DIR] [--cols 120] [--rows 38]
steps.json: [[seconds to wait after, action, optional screenshot name], ...]; action is a key name (enter, down, up, left, right, space,
tab, esc, backtab, bs), "wait", "redraw" (a resize, so a full-screen program paints again), "text:..." typed one character at a time, or "line:..." typed and then Enter."""
import argparse, codecs, os, pty, select, struct, fcntl, termios, time, subprocess, sys, shutil, json
import pyte
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))  # tools/
ap = argparse.ArgumentParser()
ap.add_argument('--name', required=True)
ap.add_argument('--cmd', required=True)
ap.add_argument('--script', required=True)
ap.add_argument('--out', default=os.path.join(here, '..', 'recording'))
ap.add_argument('--cwd', default=os.getcwd())
ap.add_argument('--env', action='append', default=[], help='NAME=VALUE for the command (repeatable)')
ap.add_argument('--cols', type=int, default=120)
ap.add_argument('--rows', type=int, default=38)
ap.add_argument('--fps', type=int, default=12)
args = ap.parse_args()

KEYS = {'enter': '\r', 'down': '\x1b[B', 'up': '\x1b[A', 'left': '\x1b[D', 'right': '\x1b[C', 'space': ' ', 'tab': '\t', 'esc': '\x1b', 'backtab': '\x1b[Z', 'bs': '\x7f', 'backslash': chr(92)}
SCENARIO = [list(s) for s in json.load(open(args.script))]
# "line:TEXT" is the text and then Enter
_exp = []
for s in SCENARIO:
	if s[1].startswith('line:'): _exp.append([0.05, 'text:' + s[1][5:]]); _exp.append([s[0], 'enter'] + s[2:])
	else: _exp.append(s)
SCENARIO = _exp
args.out = os.path.join(args.out, args.name)

cols, rows = args.cols, args.rows
os.makedirs(args.out, exist_ok=True)
frames_dir = os.path.join(args.out, 'frames')
shutil.rmtree(frames_dir, ignore_errors=True); os.makedirs(frames_dir)

# --- run the command in a pty and capture timestamped output ---
pid, fd = pty.fork()
if pid == 0:
	env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor')
	os.chdir(args.cwd)
	os.execvpe('bash', ['bash', '--norc', '--noprofile', '-c', args.cmd], dict(env, LANG='C.UTF-8', PS1='$ ', **{k: v for k, v in (e.split('=', 1) for e in args.env)}))
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
t0 = time.time(); chunks = []
def pump(until):
	while time.time() < until:
		r, _, _ = select.select([fd], [], [], 0.02)
		if r:
			try: data = os.read(fd, 65536)
			except OSError: return False
			if not data: return False
			chunks.append((time.time() - t0, data))
	return True
alive = pump(t0 + 0.8)
shots = []
for step in SCENARIO:
	delay, action = step[0], step[1]
	if not alive: break
	if action.startswith('text:'):
		for ch in action[5:]:
			os.write(fd, ch.encode()); alive = pump(time.time() + 0.045)
	elif action == 'redraw':
		# a resize makes a full-screen program draw everything again (over any stray text on the screen)
		fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows - 1, cols, 0, 0)); os.kill(pid, 28); alive = pump(time.time() + 0.3)
		fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0)); os.kill(pid, 28)
	elif action != 'wait':
		os.write(fd, (KEYS.get(action) or action).encode())
	alive = pump(time.time() + delay)
	if len(step) > 2: shots.append((step[2], time.time() - t0))
pump(time.time() + 0.5)
total = max(chunks[-1][0] if chunks else 1, time.time() - t0 - 0.4)
try: os.waitpid(pid, os.WNOHANG)
except ChildProcessError: pass
print(f'captured {len(chunks)} chunks over {total:.1f}s')

# --- render frames ---
FS = 18
def font(path, size=FS):
	return ImageFont.truetype(path, size)
JB = '/usr/share/fonts/truetype/jetbrains-mono/'
f_reg = font(JB + 'JetBrainsMono-Regular.ttf'); f_bold = font(JB + 'JetBrainsMono-Bold.ttf')
import glob
_sym = (glob.glob(os.path.expanduser('~/.local/share/fonts/*Symbols*Nerd*Mono*.ttf')) + glob.glob('/usr/share/fonts/**/*Symbols*Nerd*Mono*.ttf', recursive=True) + glob.glob('/tmp/nf/SymbolsNerdFontMono-Regular.ttf'))
f_sym = font(_sym[0]) if _sym else None
f_fb = font('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'); f_fbb = font('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf')
bbox = f_reg.getbbox('M'); cw = int(round(f_reg.getlength('M'))); ch_h = int(FS * 1.25)
W, H = cols * cw, rows * ch_h
cache = {}
def has_glyph(f, c):
	key = (id(f), c)
	if key not in cache:
		try:
			m = f.getmask(c); cache[key] = m.getbbox() is not None or c == ' '
		except Exception: cache[key] = False
	return cache[key]
NAMED = {'black':(0,0,0),'red':(205,49,49),'green':(13,188,121),'brown':(229,229,16),'blue':(36,114,200),'magenta':(188,63,188),'cyan':(17,168,205),'white':(229,229,229),
		 'brightblack':(102,102,102),'brightred':(241,76,76),'brightgreen':(35,209,139),'brightbrown':(245,245,67),'brightblue':(59,142,234),'brightmagenta':(214,112,214),'brightcyan':(41,184,219),'brightwhite':(255,255,255)}
DEF_FG, DEF_BG = (0xc6,0xd0,0xf5), (0x30,0x34,0x46)
def color(c, default):
	if c == 'default': return default
	if c in NAMED: return NAMED[c]
	if len(c) == 6:
		try: return (int(c[0:2],16), int(c[2:4],16), int(c[4:6],16))
		except ValueError: pass
	return default

screen = pyte.Screen(cols, rows); stream = pyte.Stream(screen)
decoder = codecs.getincrementaldecoder('utf-8')('replace')
def draw_frame(path):
	img = Image.new('RGB', (W, H), DEF_BG); d = ImageDraw.Draw(img)
	for y in range(rows):
		line = screen.buffer[y]
		for x in range(cols):
			c = line[x]
			bg = color(c.bg, DEF_BG); fgc = color(c.fg, DEF_FG)
			if c.reverse: bg, fgc = fgc, bg
			if bg != DEF_BG: d.rectangle([x*cw, y*ch_h, (x+1)*cw, (y+1)*ch_h], fill=bg)
			if c.data in ('▀', '▄', '█'):
				x0, y0, x1, y1 = x*cw, y*ch_h, (x+1)*cw, (y+1)*ch_h
				ym = (y0 + y1) // 2
				box = (x0, y0, x1, y1) if c.data == '█' else (x0, y0, x1, ym) if c.data == '▀' else (x0, ym, x1, y1)
				d.rectangle([box[0], box[1], box[2] - 1, box[3] - 1], fill=fgc)
				continue
			if c.data and c.data != ' ':  # a wide character leaves an empty cell after it
				f = f_bold if c.bold else f_reg
				if f_sym and 0xe000 <= ord(c.data[0]) <= 0xf8ff: f = f_sym
				elif not has_glyph(f, c.data):
					f = f_sym if (f_sym and (0xe000 <= ord(c.data[0]) <= 0xf8ff) and has_glyph(f_sym, c.data)) else (f_fbb if c.bold else f_fb)
				d.text((x*cw, y*ch_h + 1), c.data, font=f, fill=fgc)
	img.save(path)

shots_dir = os.path.join(args.out, 'screenshots'); os.makedirs(shots_dir, exist_ok=True)
for f in os.listdir(shots_dir): os.remove(os.path.join(shots_dir, f))
shot_times = sorted(shots, key=lambda s: s[1])
n = int(total * args.fps) + 1
idx = 0; si = 0
for i in range(n):
	t = i / args.fps
	while idx < len(chunks) and chunks[idx][0] <= t:
		stream.feed(decoder.decode(chunks[idx][1])); idx += 1
	draw_frame(os.path.join(frames_dir, f'f{i:05d}.png'))
	while si < len(shot_times) and shot_times[si][1] <= t + 1 / args.fps:
		shutil.copy(os.path.join(frames_dir, f'f{i:05d}.png'), os.path.join(shots_dir, shot_times[si][0] + '.png')); si += 1
print('frames', n, 'size', W, 'x', H, 'screenshots', len(os.listdir(shots_dir)))

# --- encode ---
mp4 = os.path.join(args.out, args.name + '.mp4'); gif = os.path.join(args.out, args.name + '.gif')
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-c:v','libx264','-pix_fmt','yuv420p','-crf','20',mp4], check=True)
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-vf','scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer',gif], check=True)
shutil.rmtree(frames_dir, ignore_errors=True)
print('wrote', mp4, gif)
