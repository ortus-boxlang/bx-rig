#!/usr/bin/env bash
# The install screen end to end in a real pseudo-terminal: `bxrig init --answers=FILE --yes --screen` runs the plan with a fake bxrig on the
# progress screen (a slow step, a failing step), the log opens with `v`, Ctrl+C asks first, and the log file keeps every line. Usage: install-screen-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/self" <<'FAKE'
#!/usr/bin/env bash
echo "bxrig $*" >> "$LOG"
if [[ "$1 $2" == "setup shell" ]]; then echo "installing the shell"; echo "error: target not found: zsh-foo" >&2; exit 3; fi
if [[ "$1" == "install" ]]; then echo "(1/3) installing alpha"; sleep 1; echo "(2/3) installing beta"; sleep "${APPS_SLEEP:-1}"; echo "(3/3) installing gamma"; exit 0; fi
echo "ok $1 $2"
FAKE
printf '#!/usr/bin/env bash\necho "git $*" >> "$LOG"\n' > "$tmp/bin/git"
chmod +x "$tmp/self" "$tmp/bin/git"
echo '{"desktops":"hyprland","terminal":"ghostty","shell":"zsh","ai_orchestrators":["pane"],"toolchains":["python"]}' > "$tmp/a.json"
screen() {  # OUT KEYS APPS_SLEEP: runs the screen in a pty, sends keys (python escapes, | between), writes everything drawn to OUT, returns the exit code
	APPS_SLEEP="$3" python3 - "$binary" "$tmp/a.json" "$1" "$2" <<'PY'
import os, pty, select, sys, time, struct, fcntl, termios
sys.path.insert(0, os.environ['BXRIG_TEST_LIB'])
bin, answers, out, keys = sys.argv[1:5]
keys = keys.encode().decode('unicode_escape').encode('latin-1')
env = dict(os.environ, BXRIG_CONFIG_HOME=os.environ['T'] + '/cfg', BXRIG_STATE_HOME=os.environ['T'] + '/state', BXRIG_SELF=os.environ['T'] + '/self', HOME=os.environ['T'] + '/home', PATH=os.environ['T'] + '/bin:' + os.environ['PATH'])
pid, fd = pty.fork()
if pid == 0:
    os.execve(bin, [bin, 'init', '--answers=' + answers, '--yes', '--screen'], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 36, 120, 0, 0))
buf = b''
def pump(t):
    global buf
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                d = os.read(fd, 65536)
                if not d: return
                buf += d
            except OSError: return
pump(1.8)   # (the screen animates all the time, so waiting for it to go quiet would never end)
for k in keys.split(b'|'):
    if k.startswith(b'WAIT'): pump(float(k[4:])); continue
    os.write(fd, k); pump(0.4)
pump(0.5)
rc = None
for _ in range(100):
    p, status = os.waitpid(pid, os.WNOHANG)
    if p: rc = os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1; break
    pump(0.2)
import re
open(out, 'wb').write(re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][0-9A-B]|\x1b[=>]', b'', buf))
sys.exit(rc if rc is not None else 99)
PY
}
export T="$tmp"
# the plan runs on the screen; at the end Enter leaves. One step fails, so the exit code is 7 (some done, some failed).
rc=0; screen "$tmp/s1.out" 'WAIT0.3|v|WAIT1.0|v|WAIT9|\r' 4 || rc=$?
[[ "$rc" == 7 ]] || fail "the screen run exits 7 (some failed), got $rc"
grep -q 'Finished' "$tmp/s1.out" || fail 'the end of the run says Finished'
grep -q 'of 3' "$tmp/s1.out" || fail 'the apps step shows its own progress (n of 3)'
grep -q 'Log' "$tmp/s1.out" && grep -q 'installing alpha' "$tmp/s1.out" || fail 'v shows the live log with the lines'
grep -q 'What failed' "$tmp/s1.out" || fail 'the end shows what failed'
# the summary printed after the screen, and the log file with every line, the failing step's error and the exit codes
log="$(ls "$tmp"/state/bxrig/logs/init-*.log 2>/dev/null | head -1)"
[[ -f "$log" ]] || fail "no log file: $(find "$tmp/state" | head)"
grep -q '\[apps\] (1/3) installing alpha' "$log" || fail "the log has the apps lines: $(head -30 "$log")"
grep -q 'error: target not found: zsh-foo' "$log" || fail 'the log has the failing step stderr'
grep -q 'exit 3 after' "$log" && grep -q 'exit 0 after' "$log" || fail 'the log has the exit codes'
grep -q 'finished: .* done, 1 failed' "$log" || fail 'the log has the finish line'
ls "$tmp"/state/bxrig/logs/init-*/ | grep -q 'shell.log' || fail 'the raw step output is kept in its own file'
# the same commands as the plain run, in the same order
grep -q '^bxrig setup shell --shell=zsh --yes' "$LOG" && grep -q '^bxrig profile-install python --yes' "$LOG" || fail "the steps ran: $(cat "$LOG")"
# Ctrl+C asks first; y stops: the running step is killed and the rest does not run
rm -rf "$tmp/state/bxrig/logs"; : > "$LOG"
rc=0; screen "$tmp/s2.out" 'WAIT1.5|\x03|WAIT0.3|y|WAIT0.5|\r' 30 || rc=$?
grep -q 'Stop the install?' "$tmp/s2.out" || fail 'Ctrl+C asks before stopping'
[[ "$rc" != 0 ]] || fail "a stopped install does not exit 0"
log="$(ls "$tmp"/state/bxrig/logs/init-*.log | head -1)"
grep -q 'stop requested' "$log" && grep -q 'stopped' "$log" || fail "the log says it was stopped: $(tail -8 "$log")"
! pgrep -f 'sleep 30' >/dev/null || fail 'the stopped step is still running'
echo "install-screen-test ok"
