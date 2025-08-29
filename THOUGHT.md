# BackstageFX — Design Rationale & Notes

This file captures the reasoning behind key decisions and trade-offs, so a new collaborator (or a future me) can understand context quickly without reverse‑engineering choices from code.

## Goals & Constraints
- Deadline: MVP by Sep 4 for a live event; reliability > feature count.
- Offline-first: No network dependency during show.
- Operability under pressure: Dark UI, big buttons, minimal text, strong feedback.
- Recoverability: Frequent autosave, deterministic state restore.

## Major Decisions
- Flutter + just_audio + audio_session
  - Cross-platform UI velocity with familiar ecosystem.
  - `just_audio` offers robust seek, speed, and platform-native backends.
  - `audio_session` provides audio focus and route change hooks.
- Three-player model (Music, Default, SFX)
  - Simple mental model; avoids fragile manual mixing in a single queue.
  - Enables independent fade/duck logic and quick SFX without impacting music timeline.
- JSON-first persistence
  - Faster to implement; human-readable for export/import and debugging.
  - Autosave snapshots + explicit export for portability.
- Riverpod for state
  - Lightweight, testable, and familiar to Flutter devs.
- MVP scope over completeness
  - True output peak meters and mic-ducking are platform-sensitive; treat as stretch.
  - Remote Control is valuable but deferrable compared to core operator console.

## Fades, Crossfade, Cue Points
- Fades: Implemented as volume ramps in Dart to retain predictable behavior across platforms.
- Crossfade: Enabled when transitioning between music tracks; default track always fades.
- Cue Points: Rely on `setClip` (where supported) for precise start/end; otherwise seek + guarded stop.

## Safety & UX
- Two-stage confirmations by default for destructive actions.
- Emergency Silence uses a lock (long press + confirm) to avoid accidental unmute.
- Risk Guard prevents skipping before track actually starts (anti double-tap).
- Persistent Now/Next banner reduces context loss in low light.

## Reliability & Recovery
- Debounced autosave (2–5s) to minimize I/O without risking data loss.
- Recovery prompts on cold start; default to paused state for safety.
- Run Log is append-only with timestamps to reconstruct operator actions.

## Route Changes & Output Lock
- Detect route changes; show banner and optionally fade-in Default track upon recovery.
- BT/cable pulls common during events; ensure fast visual + haptic alert.

## Meters
- Android: feasible to implement approximate output meter; iOS more restrictive.
- MVP: start with visual gain indicators; real RMS/peak meters as stretch on Android.

## Scheduled Start
- Works while foreground + wakelock engaged; background playback scheduling is out of scope for MVP.
- Provide haptic pre-roll alert to operator to avoid surprise cuts.

## Remote Control
- Pair over LAN using QR (WebSocket URL) and auth token; fallback to manual IP entry.
- mDNS (Bonjour) for discovery is a nice-to-have post-MVP.
- Command surface limited to duck/stop/SFX to reduce risk.

## Open Questions / Future Work
- iOS output metering feasibility without violating App Store rules.
- Safe mic-duck implementation without destabilizing playback (esp. on iOS).
- Waveform previews and cue editing UX (batch analysis vs. on-demand).
- Multi-device sync for redundant operator consoles.

## Out-of-Scope (MVP)
- Cloud sync; streaming; remote storage.
- Background scheduled playback when app is not foregrounded.
- Full DAW-style editing.

---

This document intentionally captures rationale, not internal step-by-step thoughts, so the team can align quickly and make informed changes.
