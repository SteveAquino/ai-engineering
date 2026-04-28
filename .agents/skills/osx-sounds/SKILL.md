---
name: osx-sounds
description: Play audio notifications from the macOS command line. Covers built-in system sounds, afplay, say, and osascript beep — including how to find sound files and patterns for success/failure audio cues.
---

# Skill: macOS Command-Line Sounds

Use this skill to play audio notifications from the terminal on macOS — useful for alerting you when a long-running agent task or command finishes.

---

## Tools Available

### `afplay` — play audio files
```bash
afplay /path/to/sound.aiff
afplay -v 0.5 /path/to/sound.aiff   # -v sets volume: 0.0 (silent) to 1.0 (full)
afplay -r 1.5 /path/to/sound.aiff   # -r sets playback rate (1.0 = normal)
```

### `say` — text-to-speech
```bash
say "Task complete"
say -v Alex "Build failed"          # -v sets the voice
say -r 200 "Done"                   # -r sets words-per-minute rate
```

### `osascript` — system alert beep
```bash
osascript -e 'beep'
osascript -e 'beep 3'               # beep N times
```

---

## Finding Built-In System Sounds

macOS ships with a set of `.aiff` sound files. List them with:

```bash
ls /System/Library/Sounds/
```

As of macOS Ventura/Sonoma, the built-in sounds are:

| File | Character |
|---|---|
| `Basso.aiff` | Deep thud — classic error/failure |
| `Blow.aiff` | Airy whoosh |
| `Bottle.aiff` | Hollow pop |
| `Frog.aiff` | Ribbit |
| `Funk.aiff` | Funky thud — attention-grabbing |
| `Glass.aiff` | Clean chime — pleasant success |
| `Hero.aiff` | Triumphant fanfare — great for task completion |
| `Morse.aiff` | Morse code blip |
| `Ping.aiff` | Short ping — quick attention |
| `Pop.aiff` | Soft pop |
| `Purr.aiff` | Gentle purr |
| `Sosumi.aiff` | Classic Mac alert |
| `Submarine.aiff` | Sonar ping |
| `Tink.aiff` | Light tap |

Preview all of them at once:
```bash
for f in /System/Library/Sounds/*.aiff; do echo "$f" && afplay "$f"; done
```

---

## Recommended Patterns

### Success / failure cue after any command
```bash
your-command \
  && afplay /System/Library/Sounds/Hero.aiff \
  || afplay /System/Library/Sounds/Basso.aiff
```

### Agent task complete notification
Append to any long-running agent or script to get notified when it finishes:
```bash
afplay /System/Library/Sounds/Hero.aiff
```

Or with a spoken message:
```bash
afplay /System/Library/Sounds/Hero.aiff && say "Agent task complete"
```

### Silent environments (just spoken alert)
```bash
say -v Samantha "Your task is done"
```

---

## Quick Reference

| Goal | Command |
|---|---|
| List all built-in sounds | `ls /System/Library/Sounds/` |
| Play a sound | `afplay /System/Library/Sounds/Hero.aiff` |
| Play at half volume | `afplay -v 0.5 /System/Library/Sounds/Hero.aiff` |
| Speak a message | `say "Done"` |
| System beep | `osascript -e 'beep'` |
| Success + failure cue | `cmd && afplay .../Hero.aiff \|\| afplay .../Basso.aiff` |
