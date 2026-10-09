#!/usr/bin/env bash
# vps-setup-pulseaudio-forward — route VPS audio (incl. opencode mp3s) to your
# laptop over SSH. Run on the VPS (Ubuntu). Needs sudo for the apt step only.
#
# How it works: opencode plays sound via ALSA -> ~/.asoundrc reroutes ALSA to
# PulseAudio client -> PULSE_SERVER points at localhost:4713 -> your SSH
# RemoteForward carries it to pulseaudio listening on your laptop.
# No tunnel up? PULSE_SERVER stays unset and ALSA plays into the local null
# sink silently (no more ALSA error spam).
#
# Usage:
#   ./vps-setup-pulseaudio-forward.sh        # full setup (install + local test + bashrc)
#   ./vps-setup-pulseaudio-forward.sh --test # re-run playback tests only
set -euo pipefail

PORT=4713
TONE="${TMPDIR:-/tmp}/opencode-tone.wav"
BASHRC="$HOME/.bashrc"
MARKER="# opencode audio forward"

step() { echo "==> $*"; }

install_pkgs() {
  step "Installing PulseAudio client + ALSA bridge (sudo)…"
  sudo apt-get update
  sudo apt-get install -y pulseaudio-utils libasound2-plugins alsa-utils
}

write_asoundrc() {
  step "Routing ALSA default -> PulseAudio…"
  if [[ -f "$HOME/.asoundrc" && ! -f "$HOME/.asoundrc.pre-opencode" ]]; then
    cp "$HOME/.asoundrc" "$HOME/.asoundrc.pre-opencode"
    echo "Backed up existing ~/.asoundrc"
  fi
  cat > "$HOME/.asoundrc" <<'EOF'
# Managed by vps-setup-pulseaudio-forward: ALSA apps (opencode) -> PulseAudio.
pcm.!default { type pulse }
ctl.!default { type pulse }
EOF
}

start_daemon() {
  step "Starting user PulseAudio daemon (null sink, keeps ALSA quiet)…"
  if pulseaudio --check 2>/dev/null; then
    echo "Daemon already running."
  else
    pulseaudio --start
    sleep 1
  fi
  pactl info | grep -E "Server Name|Default Sink" || true
}

synth_tone() {
  step "Synthesizing test tone ($TONE)…"
  python3 - "$TONE" <<'PY'
import math, struct, sys, wave
path = sys.argv[1]
rate, dur = 44100, 0.8
frames = bytearray()
for i in range(int(rate * dur)):
    f = 440.0 + (880.0 - 440.0) * i / (rate * dur)
    frames += struct.pack("<h", int(0.5 * 32767 * math.sin(2 * math.pi * f * i / rate)))
with wave.open(path, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(bytes(frames))
print(f"wrote {path}")
PY
}

test_local() {
  step "Test 1/2: PulseAudio native path (paplay, no server set)…"
  env -u PULSE_SERVER paplay "$TONE" && echo "paplay OK"
  step "Test 2/2: ALSA path — the one opencode uses (aplay via pulse bridge)…"
  env -u PULSE_SERVER aplay -q "$TONE" && echo "aplay OK"
}

test_forward() {
  step "Test 3/3: forwarded path (needs laptop listener + SSH RemoteForward)…"
  if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
    PULSE_SERVER="tcp:127.0.0.1:$PORT" paplay "$TONE" && echo "FORWARD OK — you should have heard it on the laptop"
  else
    echo "Port $PORT closed: laptop listener/forward not up. Skipping (run macos-receiver-pulseaudio.sh first)."
  fi
}

install_bashrc() {
  step "Installing conditional PULSE_SERVER snippet in ~/.bashrc…"
  if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    echo "Snippet already present, skipping."
    return
  fi
  cat >> "$BASHRC" <<EOF
$MARKER (only active when the SSH audio forward is up)
if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
  export PULSE_SERVER="tcp:127.0.0.1:$PORT"
else
  unset PULSE_SERVER
fi
EOF
  echo "Added. Open a NEW terminal (or source ~/.bashrc) afterwards."
}

if [[ "${1:-}" == "--test" ]]; then
  synth_tone
  test_local
  test_forward
  exit 0
fi

install_pkgs
write_asoundrc
start_daemon
synth_tone
test_local
test_forward
install_bashrc

cat <<'EOF'

Done. Next, on your LAPTOP (macOS):
  1. Run macos-receiver-pulseaudio.sh from this same folder.
  2. Add to ~/.ssh/config (laptop):
       Host <your-vps-alias>
         RemoteForward 4713 localhost:4713
     then reconnect (VS Code Remote-SSH: reload window).
  3. Back here: ./vps-setup-pulseaudio-forward.sh --test  (expect FORWARD OK)
  4. Flip tui.json attention.sound to true and restart opencode.
EOF
