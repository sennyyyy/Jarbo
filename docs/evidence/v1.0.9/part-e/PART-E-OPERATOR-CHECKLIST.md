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
passed when tracking engaged, with slight jitter. The tester reports that
index-finger detection is very poor and the pointer barely works reliably. The
circular pointer required the index finger to be angled rather than pointing
naturally toward the screen. Camera-edge reach remained necessary.
The tester prefers direct proportional screen mapping with a lower
smoothing/sensitivity setting to improve pointing stability.
A pointer-only counter audit on the built-in display recorded 7 unintended Left
down/up pairs and 3 unintended Right down/up pairs. Middle remained 0/0 and all
buttons ended released. This is Critical JARBO-109-012: there was no stuck
input, but ordinary pointing produced unsafe clicks. Controls are now paused.
Video was not attached. JARBO-109-011/012; see `E01-pointer-observation.md` and
`E01-pointer-event-counters.md`.

## E02 — Sensitivity response and persistence

- [x] With controls paused, change sensitivity from `0.50×` to a clearly
  different safe value (`0.70×` used).
- [x] Briefly resume on the test pad and confirm movement response changes.
- [x] Pause controls and verify no button is held.
- [x] Quit normally and relaunch the same active profile with Codex. The July 21
  test session uses the normal user profile, not the July 20 isolated profile.
- [x] Confirm the changed sensitivity persists after relaunch.
- [x] Restore `0.50×` unless the changed value is intentionally retained.
  **0.70× intentionally retained during testing.**

Result: **Pass**

Notes/evidence: Human tester confirmed 0.70× changed response and felt better
than 0.50×, with 0.75–0.90× described as the preferred range. With all three
click bindings disabled, Left/Right/Middle counters remained 0 and controls
were paused again. The normal-profile config saved 0.70×. A controlled normal
quit/relaunch changed PID 15349 to PID 23491 with exactly one canonical process;
the config still contains `pointerSensitivity: 0.7000000000000001` and all
three disabled click bindings. Human tester confirmed the post-launch HUD slider
displayed 0.70× and the click bindings remained disabled. 0.70× is intentionally
retained during testing. See `E02-sensitivity-persistence.md`.

## E03 — Left-button hold lifecycle

- [x] Reset the test pad and resume controls.
- [x] Touch physical left thumb to index over the safe pad.
- [x] Confirm exactly one Left down and zero Left up while contact is held.
- [x] Hold for two seconds and confirm no repeated down event.
- [x] Separate thumb/index and confirm exactly one Left up.
- [x] Confirm Right/Middle counters remain zero and the held indicator clears.
- [x] Pause controls.

Result: **Pass**

Notes/evidence: With only Primary click enabled, the human tester confirmed no
early event, exactly one Left down during a two-second thumb/index hold, exactly
one Left up on separation, no repeat or Right/Middle collision, and final
released state. Primary click was disabled again after the trial. Written event
counter observation; video not attached. See `E03-left-button-lifecycle.md`.

## E04 — Continuous left drag

- [x] Reset the pad, position over the cyan drag target, and resume controls.
- [x] Begin thumb/index contact and confirm one Left down.
- [x] Keep contact held while moving the pointer.
- [x] Confirm the target follows continuously without extra down/up events.
- [x] Separate fingers and confirm one Left up and immediate drag stop.
- [x] Move after release and confirm the target no longer follows.
- [x] Pause controls.

Result: **Pass**

Notes/evidence: With only Primary click enabled, one Left down started a
continuous drag; the counts stayed 1/0 while held. One Left up stopped the drag
immediately, the target did not follow after release, no wrong/repeated event
occurred, and final state was released. Primary click was disabled again.
Written counter observation; video not attached. See
`E04-left-drag-lifecycle.md`.

## E05 — Right-button hold lifecycle

- [x] Reset the test pad and resume controls.
- [x] Touch physical left thumb to middle finger directly.
- [ ] Confirm exactly one Right down and zero Right up while held. **Fail:
  released prematurely while contact remained held.**
- [x] Separate and confirm exactly one Right up/final released state.
- [x] Confirm Left/Middle counters remain zero; no left-click collision occurs.
- [x] Repeat once from a freshly presented hand without first opening the palm.
- [x] Pause controls.

Result: **Fail**

Notes/evidence: Direct fresh-hand thumb/middle detection and the expected HUD
label passed. After an open palm, detection worked only about half the time.
Right released while contact remained held, and occasional early/repeated/false
events occurred. Separation and final released state passed. With only Context
enabled, Left/Middle counters remained zero; Context was disabled again.
Tester preference: index+middle extended to point, thumb/index for Left, and
thumb/middle for Right. JARBO-109-009/013; see
`E05-right-button-lifecycle.md`.

## E06 — Middle-button hold lifecycle

- [x] Reset the test pad and resume controls.
- [x] Touch physical left thumb to ring finger directly.
- [x] Confirm exactly one Middle down and zero Middle up while held.
- [x] Separate and confirm exactly one Middle up.
- [ ] Confirm Left/Right counters remain zero; no fist/pinch collision occurs.
  **Counters stayed zero with isolated Middle binding, but the HUD sometimes
  changed to Finger Heart.**
- [x] Repeat once from a freshly presented hand without first opening the palm.
- [x] Pause controls.

Result: **Fail**

Notes/evidence: Direct fresh-hand and after-open-palm thumb/ring detection,
expected HUD label, Middle hold, separation, and final release passed. With only
Middle enabled, Left/Right counters remained zero. However, the classifier
sometimes changed to Finger Heart, violating the no-collision criterion and
risking a wrong Left click with normal bindings. Middle was disabled again.
The tester wants contact detection while pointing naturally toward the screen,
not only around an open-palm presentation. JARBO-109-014; see
`E06-middle-button-lifecycle.md`.

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
