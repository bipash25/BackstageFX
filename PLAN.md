# BackstageFX — Build Plan (Aug 29 → Sep 4)

## Objectives
- Deliver a reliable, offline-first operator app to run Teacher’s Day.
- Prioritize stability, clear UI, fast recovery, and safe defaults over extras.
- Ship an MVP by Sep 4 with a path to stretch features if time allows.

## MVP Scope (Ship by Sep 4)
- Sessions: group + track tree, reorder via drag, per-track settings.
- Default background track with automatic fade-in/out when idle.
- Per-track fades, optional crossfade, cue points (startAt/endAt), per-track gain.
- Operator Console: Now/Next banner with ETA, transport controls, run log.
- Volume Manager: Master + Music + Default + SFX faders; per-track gain.
- Quick Actions: Intro/Outro buttons, Anchor Speech (quick duck), Emergency Silence.
- Safety: Two-stage confirms, autosave every 2–5s, crash recovery, keep awake.
- Validation: Missing file alerts, session validator before showtime.
- Dark mode + big-button UI.

## Stretch Scope (If time remains)
- Peak/clipping meter (Android-first), route lock warnings, scheduled start (foreground),
  remote control pairing, run log export, per-group color tags, risk guard, fast-forward dry run, session split/merge, live time stretch preview.

## Timeline & Milestones
- Aug 29 (Today):
  - Finalize scope, architecture, data model, screens; create docs (README/PLAN/THOUGHT).
  - Set up Flutter template and packages; create skeleton modules and state scaffolding.
- Aug 30:
  - Implement Session model + JSON persistence + autosave; Session Builder UI (basic tree + reorder).
  - File import/link flow with validator; missing file highlights.
- Aug 31:
  - Audio engine (players: default, music, sfx) with fades, cue points, crossfade toggles.
  - Operator Console baseline: transport, Now/Next, run log, two-stage confirms.
- Sep 1:
  - Volume Manager screen with bus faders and per-track gain; Anchor Speech quick duck.
  - Keep-awake, brightness preset, vibration feedback; safety polish.
- Sep 2:
  - Dry Run (5× speed, fade compression), basic analytics (missing files, long silences).
  - Risk guard; per-group color tags; quick labeling.
- Sep 3:
  - Reliability pass: autosave robustness, crash recovery, route change warnings, emergency scene lock.
  - Buffer for bug fixing, UX polish, rehearsal QA checklist.
- Sep 4:
  - Final dress rehearsal, export/import sanity check, create backup session copy.

## Architecture Overview
- State: Riverpod providers for session, playback, buses, settings, run log.
- Audio: Three players via `just_audio`; centralized fade/duck engine; route observer via `audio_session`.
- Data: JSON per session file in app docs dir; autosave mirror; optional local DB later (Hive/Isar).
- UI: Feature-first folders; reusable big-button widgets; platform-safe haptics; dark theme.
- Services: File picker, path provider, vibration, brightness, wakelock, permission handler.

## Modules & Tasks
- Audio Engine
  - Players: defaultBg, music, sfx; shared timeline; events stream.
  - Fade Engine: linear and cosine ramps; configurable durations; cancelable.
  - Crossfade: enable at boundaries when configured; otherwise straight cut.
  - Cue Points: use `setClip` when supported; fallback to manual stop at endAt.
  - Ducking: Anchor button; automatic duck on SFX start; optional mic-duck (Android-only experimental).
  - Output Route: listen to route changes; warn and optionally bring back default track.
- Session & Storage
  - Models: Session, Group, Track, Settings, RunLog.
  - JSON IO: export/import; relative file refs; validator for existence and duration reads.
  - Autosave: debounce 2s; snapshot to `session.autosave.json`.
  - Recovery: on startup, load autosave + last-known playhead (paused), confirm restore.
- Operator Console
  - Now/Next banner with ETA; transport controls (Play/Pause/Stop/Next/Prev).
  - Quick actions: Intro/Outro/SFX; Anchor Speech button (duck 6 dB for 3–5s).
  - Two-stage confirms for destructive actions; Run Log panel with timestamps.
- Volume Manager
  - Full-screen faders: Master, Music, Default, SFX; lock mode; hardware volume mapping option.
  - Temporary Mute button with countdown visual.
- Dry Run
  - Speed 5×; fade compression to 150ms; highlight long gaps (> N seconds) and missing files.
  - Report view showing issues by group/track.
- Settings
  - Defaults for fade-in/out, crossfade, duck level, confirm prompts, brightness, keep-awake, key mapping.

## Data Model (Draft JSON)
```json
{
  "id": "sess-2024-09-05",
  "name": "Teacher's Day 2024",
  "createdAt": "2024-08-29T10:00:00Z",
  "defaultTrack": {
    "filePath": "music/ambient.mp3",
    "fadeInMs": 1200,
    "fadeOutMs": 800,
    "gainDb": -14.0
  },
  "settings": {
    "riskGuard": true,
    "confirmDestructive": true,
    "brightnessPreset": 0.35,
    "keepAwake": true,
    "defaultFadeInMs": 300,
    "defaultFadeOutMs": 300
  },
  "groups": [
    {
      "id": "grp-open",
      "name": "Opening",
      "colorTag": "#3B82F6",
      "children": [
        {
          "type": "track",
          "id": "trk-anthem",
          "name": "National Anthem",
          "filePath": "music/anthem.mp3",
          "startAtMs": 0,
          "endAtMs": null,
          "fadeInMs": 0,
          "fadeOutMs": 0,
          "crossfadeMs": 0,
          "gainDb": -3.0
        }
      ]
    }
  ]
}
```

## Packages (to be pinned)
- just_audio, audio_session
- path_provider, file_picker, permission_handler
- riverpod (or flutter_riverpod)
- wakelock_plus, screen_brightness, vibration
- json_serializable (optional), freezed (optional), uuid
- Optional: bonsoir, shelf, flutter_dnd

## Validation & QA Checklist
- Session Validator: missing files, unreadable files, duplicate IDs, invalid times.
- Console: Now/Next shows correct ETA; Risk Guard blocks premature Next.
- Fades: Default track auto-fade on idle; no unintended fades on performance tracks.
- Emergency: Hard cut works and locks; unlock requires long-press + confirm.
- Autosave: Kill app mid-play; restart; offer recovery prompt; no crash.
- Route Change: Unplug BT/cable; warning banner shows; default track recovery works.
- Dry Run: 5× speed preview; flags long silences; generates report.

## Risks & Mitigations
- Peak Metering: True output meters are platform-specific; Android-first with a safe fallback; iOS approximated.
- Mic-Ducking: OS policies may block simultaneous capture+playback; keep manual Anchor button as primary.
- Scheduled Start: Guaranteed only in foreground; show notice and vibrate pre-roll.
- File Permissions: Use media/document picker to avoid brittle raw paths; cache SAF/URI.
- Time Crunch: Keep scope tight; defer Remote Control if core stability needs time.

## Deliverables
- A runnable Flutter app with: Session Builder, Operator Console, Volume Manager, Dry Run, Settings.
- JSON-based session export/import.
- Run Log view with timestamped actions; basic export if time permits.

## Next Steps
- Create Flutter template, add dependencies, scaffold folders and providers.
- Implement Session model + storage + validator; basic Session Builder UI.
- Build audio engine and wire to Operator Console; ship MVP flows.
