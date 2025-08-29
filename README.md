# BackstageFX — Backstage Audio Orchestrator (Flutter)

BackstageFX is an offline-first, big-button audio operator app for school events and stage shows. It focuses on reliability under pressure: simple controls, clear feedback, safe defaults, and instant recovery. Designed for Teacher’s Day on a tight timeline, with a pragmatic MVP that scales.

## Why
Running sound from a phone is hard when you need to juggle default background music, cues, fade timings, emergency stops, and on-the-fly changes. BackstageFX turns the phone into a purpose-built operator console with sessions, groups, tracks, and a Now/Next view so anyone can run a show confidently in low light.

## Key Features (MVP for 4 Sep)
- Sessions & Groups: Plan an entire run with nested groups and tracks.
- Default Track Channel: Always-available low-volume music with auto fade-in/out when idle.
- Fades & Crossfades: Per-track fade-in/out and global crossfade option (default on for Default Track).
- Cue Points/Markers: Start at timestamps; trim intro/outro.
- Volume Manager: Master + per-bus faders (Default, Music, SFX) and per-track gain.
- Now/Next Banner: Always-visible "Now Playing" plus "Up Next" with ETA.
- Two-Stage Confirms: Optional confirmation on Stop/Skip/Next.
- Emergency Silence Scene: One-tap hard cut with lock to prevent accidental unmute.
- Quick Access: Play Intro/Outro/SFX buttons; Anchor Speech (quick fade duck-and-return).
- Auto-Save & Recovery: 2–5s autosave; restore last session and console state on restart.
- Dark Mode + Big Buttons: Optimized for low light and quick recognition.
- Offline-First: All media local; no network required during operation.
- Keep Awake & Brightness Preset: Prevents sleep; sets/returns screen brightness.

## Nice-to-Have (Stretch if time allows)
- Peak/Clipping Meter: Pre-fader and master meters to avoid distortion (Android-first; iOS limited).
- Audio Ducking on Mic/SFX: Auto-lower background for anchors or SFX events.
- Scheduled Start: Auto-play at specific time (e.g., National Anthem) while app in foreground.
- Remote Control Mode: Anchor device triggers duck/stop/SFX via local pairing.
- Output Device Lock: Warn on route change (BT unplug); auto-recover Default Track.
- Run Log: Timestamped actions exportable as text/CSV.
- Risk Guard: Block "Next" until current has truly started (anti double-tap).
- Per-Group Color Tags & Quick Labeling: Visual grouping; long-press rename; emoji labels.
- Fast-Forward Dry Run: 5× preview; fade compression; detect silences/missing files.
- Session Split/Merge & Quick Export/Import: Move blocks across sessions; share easily.

## Screens at a Glance
- Library: Local tracks and folders, link files to tracks.
- Session Builder: Build tree of Groups → Tracks; set fades, cue points, labels, colors.
- Operator Console: Now/Next banner, transport, big faders, meters, quick actions, run log.
- Volume Manager: Full-screen faders for Master, Music, Default, SFX.
- Dry Run: Accelerated preview with flagging for gaps and missing files.
- Settings: Defaults for fade times, risk guard, DND/brightness/keep-awake, key mapping.

## Tech Stack
- Flutter (Dart) — UI + state management (Riverpod).
- Audio: `just_audio` (+ platform ExoPlayer/AVFoundation), `audio_session` for focus/routes.
- Storage: JSON files in app docs dir (export/import), plus lightweight local DB for fast autosave (Hive/Isar). MVP can start with JSON-only autosave.
- Platform: `wakelock_plus`, `screen_brightness`, `vibration`, `permission_handler`, `path_provider`, `file_picker`.
- Optional: `bonsoir` (mDNS) + `shelf` (WebSocket) for Remote Control; `flutter_dnd` (Android only) for DND suggestions.

## Audio Engine Overview
- Players (parallel):
  - DefaultBgPlayer — looped default track; fades in when idle, out when show resumes.
  - MusicPlayer — main track queue; crossfade optional per track.
  - SfxPlayer — one-shot sound effects; auto-ducks DefaultBgPlayer.
- Fades & Crossfades:
  - Smooth gain ramps implemented in Dart over per-player volume; crossfade via `just_audio` where suitable.
  - Default track always uses fade-in/out; performance tracks skip auto-fade unless configured.
- Cue Points:
  - Per-track startAt/endAt using `setClip` where available, with precise seek.
- Ducking:
  - Manual: Anchor button and SFX events auto-lower Default; optional mic-based (Android-first; iOS limited by policy).

## Data Model (Summary)
- Session: id, name, createdAt, defaultTrack, settings, groups, runLog.
- Group: id, name, colorTag, children (tracks and/or groups), notes.
- Track: id, name, filePath (or contentUri), gainDb, fadeInMs, fadeOutMs, crossfadeMs, startAtMs, endAtMs, labels, flags.
- Settings: default fade durations, risk guard, confirm style, brightness preset, wake lock, key mapping.
- Export: Single JSON with relative file references; warn on missing files.

## Reliability & Safety
- Frequent Autosave: Every 2–5 seconds and on every structural change.
- Crash Recovery: On launch, restore last session + console layout + last-known track pointer (paused by default).
- Two-Stage Confirm: Optional confirm sheets for Stop/Skip/Next.
- Emergency Silence: Hard-cut all outputs; lock to prevent accidental unmute.
- Output Route Watch: Warn on BT/cable loss; optional auto-fade-in Default track on recovery.

## Building & Running (after Flutter template is set up)
1) Ensure Flutter is installed and a device/simulator is ready.
2) Add packages (will be pinned in `pubspec.yaml` when we scaffold the app).
3) Place local audio files on device or import via file picker.
4) Run: `flutter run`.

Permissions: storage/media (file access), vibration, microphone (only if using mic-ducking), and audio background modes where applicable. iOS DND changes are not allowed; Android DND requires special entitlement — we will recommend manual DND.

## Folder Structure (planned)
- lib/
  - app/ (bootstrap, routing, theme)
  - core/ (utils, failure, result, platform services)
  - audio/ (engine, players, fades, meters, ducking)
  - features/
    - session/ (models, repo, JSON, autosave)
    - library/ (file links, validators)
    - console/ (now/next, transport, run log)
    - volume/ (faders, meters, key mapping)
    - dry_run/ (accelerated sim, reports)
    - settings/
  - ui/ (widgets, buttons, meters)

## Known Constraints
- True output peak meters are platform-specific; MVP may provide Android-first with a safe fallback. iOS may be approximated (no live tap of output).
- Scheduled starts guaranteed only while the app is foreground/awake.
- Mic-ducking reliability varies by platform/policy; manual Anchor button is primary.

## Roadmap
- MVP for Teacher’s Day (Sep 4): core operator console, sessions, fades, autosave, emergency, Now/Next.
- Stretch: meters, remote control, scheduled start, route lock, run log export.

---

This README is the operator-facing overview. See PLAN.md for the day-by-day build plan and deeper technical details.
