#!/usr/bin/env bash
# macos-receiver-pulseaudio — run on your LAPTOP (macOS). Listens on
# 127.0.0.1:4713 for PulseAudio forwarded from the VPS over SSH and plays it
# through your Mac speakers.
#
# Prereqs: Homebrew (https://brew.sh). No sudo needed.
# Security: the TCP module binds loopback only + anonymous auth. The port is
# reachable solely via your own SSH reverse tunnel, but prefer a trusted
# network anyway. Stop with: pulseaudio --kill
set -euo pipefail

PORT=4713

step() { echo "==> $*"; }

if ! command -v brew >/dev/null; then
  echo "ERROR: Homebrew not found. Install from https://brew.sh first." >&2
  exit 1
fi

if ! command -v pulseaudio >/dev/null; then
  step "Installing pulseaudio via Homebrew…"
  brew install pulseaudio
else
  echo "pulseaudio already installed ($(pulseaudio --version))."
fi

step "Starting loopback-only TCP listener on 127.0.0.1:$PORT…"
pulseaudio --kill 2>/dev/null || true
sleep 1
pulseaudio -n --exit-idle-time=-1 --daemon \
  --load=module-native-protocol-unix \
  --load="module-native-protocol-tcp listen=127.0.0.1 auth-anonymous=1" \
  --load=module-coreaudio-detect
sleep 1

step "Local self-test (Mac speakers should ding)…"
python3 - /tmp/mac-tone.wav <<'PY'
import math, struct, sys, wave
rate, dur = 44100, 0.5
frames = bytearray()
for i in range(int(rate * dur)):
    frames += struct.pack("<h", int(0.5 * 32767 * math.sin(2 * math.pi * 660.0 * i / rate)))
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(bytes(frames))
PY
paplay /tmp/mac-tone.wav && echo "LOCAL PLAYBACK OK"

cat <<EOF

Receiver is up. Now expose it to the VPS — pick ONE:
  A. VS Code Remote-SSH / ssh (recommended): add to laptop ~/.ssh/config:
       Host <your-vps-alias>
         RemoteForward $PORT localhost:$PORT
     then reconnect. Verify from the VPS: ./vps-setup-pulseaudio-forward.sh --test
  B. Tunnel-only (no ssh): from the laptop run a side connection:
       ssh -N -R $PORT:localhost:$PORT <user>@<vps-host>
     (needs sshd reachable on the VPS). Keep it running alongside the tunnel.

Stop the receiver anytime with: pulseaudio --kill
EOF
