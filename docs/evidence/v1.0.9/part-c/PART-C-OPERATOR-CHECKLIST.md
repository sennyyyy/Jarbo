# Jarbo 1.0.9 Part C Operator Checklist

Canonical app: `/Applications/Jarbo.app`

Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)

## Safety setup

- [ ] Confirm the running app is `/Applications/Jarbo.app`.
- [ ] Confirm no mouse button or keyboard modifier is held.
- [ ] Pause Hand Controls before turning Camera On.
- [ ] Prefer the HUD Camera button because the menu path has an open crash defect.
- [ ] If Jarbo closes or crashes, stop the current test and record the exact step.

## C01 — Camera On

- [x] Start from an explicit `Camera Off` / offline state.
- [x] Select Camera On once from the HUD.
- [x] No unexpected permission request or denial was reported.
- [x] Confirm exactly one live camera feed starts.
- [x] Confirm Jarbo reports Camera On rather than Starting/Unavailable.
- [x] Confirm the macOS camera privacy indicator appears and remains visible.
- [x] Confirm no duplicate preview/session or unexpected hand action occurs.

Result: **Pass**

Notes/evidence: Human tester confirmed `Camera On ready` after the live-feed and
privacy-indicator checks.

## C02 — Camera Off while tracking

- [ ] With hand controls still paused, show one hand until landmarks/status appear.
- [ ] Select Camera Off once from the HUD.
- [ ] Confirm the feed stops and preview changes to offline.
- [ ] Confirm landmarks, hand boxes, labels, and candidates clear promptly.
- [ ] Confirm Jarbo reports Camera Off rather than remaining Starting/Stopping.
- [ ] Confirm the macOS camera privacy indicator disappears after hardware release.
- [ ] Confirm no delayed gesture action fires.

Result: **Pass**

Notes/evidence: Human tester reported all C02 checks passed. Video/privacy timing
was not attached. Full held-button release remains a later Part E safety test
while hand actions are paused here.

## C03 — Saved Off and saved On relaunch

This candidate is running with an isolated test profile. Do not relaunch it by
ordinary double-click during this row, because that would switch to the user's
normal profile. Ask Codex to relaunch the same isolated profile after each quit.

- [x] Save Camera Off, quit with Command-Q, and have Codex relaunch the same profile.
- [x] Confirm Camera remains Off with no privacy indication.
- [x] Save Camera On, quit with Command-Q, and have Codex relaunch the same profile.
- [x] Confirm camera intent resumes only once and live/permission state is explicit.

Result: **Pass**

Notes/evidence: Normal quit completed, the isolated config remained
`cameraEnabled: false`, and exactly one `/Applications/Jarbo.app` process
relaunched with the same profile. The saved-On quit/relaunch also completed,
preserved `cameraEnabled: true`, and started exactly one canonical process. Final
human confirmation verified one resumed live feed, Camera On state, and the macOS
privacy indicator. See `C03-saved-off-relaunch.log` and
`C03-saved-on-relaunch.log`.

## C04 — Ten Camera On/Off cycles

- [x] Record starting Jarbo CPU and memory.
- [x] Complete ten deliberate On/Off cycles, waiting for the final state each time.
- [x] Confirm each On creates one feed/privacy indication.
- [x] Confirm each Off clears the feed/overlays/privacy indication.
- [x] Confirm no duplicate session, stale hand, delayed action, or stuck control.
- [x] Record ending CPU and memory and note any repeated-growth pattern.

Result: **Pass with limitations**

Notes/evidence: Ten cycles completed with the same process and no functional
failure. RSS started at 150,592 KB, peaked at 260,624 KB during cycling, and
settled to 112,496 KB, so no repeated-growth pattern was observed. Camera-Off
CPU remained approximately 49–55% in interval samples; JARBO-109-005. See
`C04-process-samples.log`, `C04-camera-off-settle.log`,
`C04-camera-off-top.log`, and `C04-process-summary.md`.

## C05 — Deny, retry, then grant Camera permission

Coordinate this row with Codex so the existing Camera permission can be reset
without touching unrelated privacy permissions.

- [ ] Reset only Jarbo's Camera permission while Jarbo is not running.
- [ ] Relaunch, select Camera On, and choose `Don't Allow`.
- [ ] Confirm Jarbo remains open and reports Camera Permission Required.
- [ ] Confirm retry/recovery guidance opens the correct System Settings page.
- [ ] Grant Camera access in System Settings and return to Jarbo.
- [ ] Confirm one camera session can start without duplicate processes or relaunch.

Result: **Pending**

Notes/evidence:

## C06 — Revoke Camera while active

- [ ] Begin with one active camera session and paused hand controls.
- [ ] In System Settings, revoke Camera access for Jarbo while it is active.
- [ ] Confirm capture stops or fails safely and the privacy indicator clears.
- [ ] Confirm overlays/candidates clear and no action fires.
- [ ] Confirm Jarbo remains open with accurate recovery guidance.
- [ ] Re-enable Camera only after the failure state has been recorded.

Result: **Pending**

Notes/evidence:
