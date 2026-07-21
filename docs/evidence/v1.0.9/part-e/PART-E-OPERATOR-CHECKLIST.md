# Jarbo 1.0.9 Part E Operator Checklist

Canonical app: `/Applications/Jarbo.app`

Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)

Test pad: `pointer-event-test.html`

## Safety and evidence setup

- [ ] Confirm `/Applications/Jarbo.app` is the only running Jarbo process.
- [ ] Confirm Camera is On and Accessibility is granted.
- [ ] Confirm the physical left-hand role is `Pointer + clicks`.
- [x] Confirm sensitivity begins at `0.50×`.
- [ ] Confirm thumb/index, thumb/middle, and thumb/ring bindings target Left,
  Right, and Middle click respectively for the physical left hand.
- [ ] Keep Hand Controls paused until the test pad is frontmost.
- [ ] Keep the physical right hand out of frame; D05 found unsafe two-hand
  occlusion behavior.
- [ ] Use only the local test pad; do not hover over destructive controls,
  files, Dock items, or browser tabs while Hand Controls are active.
- [ ] If any button stays held, fully open/remove the hand and immediately use
  Pause Hand Controls or Camera Off. Stop the row and record the event counts.
- [x] Record the display arrangement and, if practical, video only the Jarbo
  preview plus the test pad.

Reset the test-pad counters before each button test. Do not infer a pass from a
visual label: the pad must receive the expected down/up events.

## E01 — Pointer movement, 0.50× sensitivity, and clutch

- [x] Resume Hand Controls with the test pad frontmost.
- [ ] Point with the physical left index finger and confirm Jarbo's translucent
  circular pointer replaces the normal macOS cursor while active.
- [x] Move slowly and then moderately in every direction.
- [x] Confirm movement is controllable at `0.50×`, without severe jitter,
  inversion, or runaway acceleration.
- [ ] Reach representative areas of the test pad without extending to the
  camera-frame edge.
- [x] Open/close/lift the hand to clutch, reposition it, then point again.
- [x] Confirm the cursor pauses while clutched and resumes without a large jump.
- [x] Pause Hand Controls immediately after the trial.

Result: **Fail**

Notes/evidence: Pointer movement at 0.50×, clutch pause, and no-jump resume
passed, with slight jitter. The circular
pointer was intermittent and required the index finger to be angled rather than
pointing naturally toward the screen. Camera-edge reach remained necessary.
The tester prefers direct proportional screen mapping with a lower
smoothing/sensitivity setting to improve pointing stability.
A pointer-only counter audit on the built-in display recorded 7 unintended Left
down/up pairs and 3 unintended Right down/up pairs. Middle remained 0/0 and all
buttons ended released. This is Critical JARBO-109-012: there was no stuck
input, but ordinary pointing produced unsafe clicks. Controls are now paused.
Video was not attached. JARBO-109-011/012; see `E01-pointer-observation.md` and
`E01-pointer-event-counters.md`.

## E02 — Sensitivity response and persistence

- [ ] With controls paused, change sensitivity from `0.50×` to a clearly
  different safe value (for example `0.30×`).
- [ ] Briefly resume on the test pad and confirm movement response changes.
- [ ] Pause controls and verify no button is held.
- [ ] Quit normally with Command-Q; coordinate the isolated-profile relaunch
  with Codex rather than double-clicking the app.
- [ ] Confirm the changed sensitivity persists after relaunch.
- [ ] Restore `0.50×` unless the changed value is intentionally retained.

Result: **Pending**

Notes/evidence:

## E03 — Left-button hold lifecycle

- [ ] Reset the test pad and resume controls.
- [ ] Touch physical left thumb to index over the safe pad.
- [ ] Confirm exactly one Left down and zero Left up while contact is held.
- [ ] Hold for two seconds and confirm no repeated down event.
- [ ] Separate thumb/index and confirm exactly one Left up.
- [ ] Confirm Right/Middle counters remain zero and the held indicator clears.
- [ ] Pause controls.

Result: **Pending**

Notes/evidence:

## E04 — Continuous left drag

- [ ] Reset the pad, position over the cyan drag target, and resume controls.
- [ ] Begin thumb/index contact and confirm one Left down.
- [ ] Keep contact held while moving the pointer.
- [ ] Confirm the target follows continuously without extra down/up events.
- [ ] Separate fingers and confirm one Left up and immediate drag stop.
- [ ] Move after release and confirm the target no longer follows.
- [ ] Pause controls.

Result: **Pending**

Notes/evidence:

## E05 — Right-button hold lifecycle

- [ ] Reset the test pad and resume controls.
- [ ] Touch physical left thumb to middle finger directly.
- [ ] Confirm exactly one Right down and zero Right up while held.
- [ ] Separate and confirm exactly one Right up.
- [ ] Confirm Left/Middle counters remain zero; no left-click collision occurs.
- [ ] Repeat once from a freshly presented hand without first opening the palm.
- [ ] Pause controls.

Result: **Pending**

Notes/evidence:

## E06 — Middle-button hold lifecycle

- [ ] Reset the test pad and resume controls.
- [ ] Touch physical left thumb to ring finger directly.
- [ ] Confirm exactly one Middle down and zero Middle up while held.
- [ ] Separate and confirm exactly one Middle up.
- [ ] Confirm Left/Right counters remain zero; no fist/pinch collision occurs.
- [ ] Repeat once from a freshly presented hand without first opening the palm.
- [ ] Pause controls.

Result: **Pending**

Notes/evidence:

## E07 — Interruption releases

Use all three buttons across these four safe interruption paths. Confirm the pad
changes from `HELD` to `released` with one matching up event each time.

- [ ] Hold Left, then remove the hand completely from frame.
- [ ] Hold Right, then open Actions using the normal UI/trackpad.
- [ ] Hold Middle, then choose Camera Off using the normal UI/trackpad.
- [ ] Relaunch safely, hold Left, then quit normally with Command-Q.
- [ ] No path leaves a held indicator, unmatched down event, or stuck macOS
  input after Jarbo stops/changes mode.

Result: **Pending**

Notes/evidence:

## E08 — Close-pose collision rejection

- [ ] Reset the test pad and resume controls.
- [ ] Present a fist without intentional thumb/fingertip contact.
- [ ] Present two other relaxed close/curled configurations without contact.
- [ ] Confirm none produces Left/Right/Middle down.
- [ ] Confirm no button becomes held and no false contact action occurs.
- [ ] Pause controls.

Result: **Pending**

Notes/evidence:
