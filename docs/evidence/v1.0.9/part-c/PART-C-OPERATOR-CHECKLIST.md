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

- [ ] Start from an explicit `Camera Off` / offline state.
- [ ] Select Camera On once from the HUD.
- [ ] If macOS asks for Camera permission, record whether Allow or Deny was chosen.
- [ ] Confirm exactly one live camera feed starts.
- [ ] Confirm Jarbo reports Camera On rather than Starting/Unavailable.
- [ ] Confirm the macOS camera privacy indicator appears and remains visible.
- [ ] Confirm no duplicate preview/session or unexpected hand action occurs.

Result: **Pending**

Notes/evidence:

## C02 — Camera Off while tracking

- [ ] With hand controls still paused, show one hand until landmarks/status appear.
- [ ] Select Camera Off once from the HUD.
- [ ] Confirm the feed stops and preview changes to offline.
- [ ] Confirm landmarks, hand boxes, labels, and candidates clear promptly.
- [ ] Confirm Jarbo reports Camera Off rather than remaining Starting/Stopping.
- [ ] Confirm the macOS camera privacy indicator disappears after hardware release.
- [ ] Confirm no delayed gesture action fires.

Result: **Pending**

Notes/evidence: Full held-button release remains a later Part E safety test while
hand actions are paused here.

## C03 — Saved Off and saved On relaunch

This candidate is running with an isolated test profile. Do not relaunch it by
ordinary double-click during this row, because that would switch to the user's
normal profile. Ask Codex to relaunch the same isolated profile after each quit.

- [ ] Save Camera Off, quit with Command-Q, and have Codex relaunch the same profile.
- [ ] Confirm Camera remains Off with no privacy indication.
- [ ] Save Camera On, quit with Command-Q, and have Codex relaunch the same profile.
- [ ] Confirm camera intent resumes only once and live/permission state is explicit.

Result: **Pending**

Notes/evidence:

## C04 — Ten Camera On/Off cycles

- [ ] Record starting Jarbo CPU and memory in Activity Monitor.
- [ ] Complete ten deliberate On/Off cycles, waiting for the final state each time.
- [ ] Confirm each On creates one feed/privacy indication.
- [ ] Confirm each Off clears the feed/overlays/privacy indication.
- [ ] Confirm no duplicate session, stale hand, delayed action, or stuck control.
- [ ] Record ending CPU and memory and note any repeated-growth pattern.

Result: **Pending**

Notes/evidence:

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
