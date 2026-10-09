# vps-pulseaudio-forward

Hear a headless Linux VPS on your laptop: route VPS audio (including
opencode's attention mp3s) over SSH to a PulseAudio listener on macOS.

```
VPS app (ALSA) → ~/.asoundrc → PulseAudio client → PULSE_SERVER=localhost:4713
  → SSH RemoteForward → macOS pulseaudio (TCP, loopback) → Mac speakers
```

No tunnel up? `PULSE_SERVER` stays unset and ALSA plays into the local null
sink silently (also kills the `cannot find card '0'` ALSA error spam).

## Files

| File                                | Runs on | Purpose                                  |
| ----------------------------------- | ------- | ---------------------------------------- |
| `vps-setup-pulseaudio-forward.sh`   | VPS     | Install, ALSA→Pulse route, daemon, tests, `~/.bashrc` snippet |
| `macos-receiver-pulseaudio.sh`      | Mac     | brew install, loopback TCP listener, self-test ding |

## VPS quickstart (Ubuntu, sudo needed for apt only)

```bash
./vps-setup-pulseaudio-forward.sh
./vps-setup-pulseaudio-forward.sh --test   # re-run tests any time
```

## Mac quickstart

```bash
./macos-receiver-pulseaudio.sh
```

Then expose the listener to the VPS — pick one:

- **A. SSH (recommended):** laptop `~/.ssh/config`
  ```
  Host <your-vps-alias>
    RemoteForward 4713 localhost:4713
  ```
  Reconnect (VS Code Remote-SSH: reload window).
- **B. Tunnel-only:** from the laptop keep a side connection running:
  ```
  ssh -N -R 4713:localhost:4713 <user>@<vps-host>
  ```

Back on the VPS: `--test` should print `FORWARD OK`. Then flip opencode
`tui.json` `attention.sound` to `true`, open a new terminal (so `~/.bashrc`
sets `PULSE_SERVER`), and restart opencode.

## Troubleshooting

| Symptom | Check |
| ------- | ----- |
| `Port 4713 closed` on `--test` | Mac listener not running (`pulseaudio --kill`, rerun script) or forward missing |
| opencode still silent | Terminal predates `~/.bashrc` change; `echo $PULSE_SERVER` must show `tcp:127.0.0.1:4713` |
| ALSA errors back | `~/.asoundrc` missing or daemon down (`pulseaudio --start`) |
| Stop everything | Mac: `pulseaudio --kill`. VPS: `pulseaudio --kill`, unset `PULSE_SERVER` |
