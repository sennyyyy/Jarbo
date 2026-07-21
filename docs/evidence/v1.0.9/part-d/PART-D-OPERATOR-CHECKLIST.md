# Jarbo 1.0.9 Part D Operator Checklist

Canonical app: `/Applications/Jarbo.app`

Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)

## Safety and evidence setup

- [x] Re-enable Jarbo in System Settings > Privacy & Security > Camera.
- [x] Confirm `/Applications/Jarbo.app` is the only running Jarbo process.
- [x] Turn Camera On and confirm one live feed/privacy indicator.
- [x] Pause Hand Controls before showing any gesture.
- [x] Confirm no mouse button or keyboard modifier is held.
- [x] Keep the pointer over a harmless empty area.
- [ ] If practical, record the Jarbo window with spoken physical left/right; do
  not record unrelated private windows.
- [ ] If Jarbo closes, an unintended action fires, or input becomes held, stop
  the current row immediately and record the exact pose/lighting/step.

The preview may be mirrored like a selfie, but `YOUR LEFT HAND` and `YOUR RIGHT
HAND` must refer to the tester's anatomical hands—not the side of the image.
Controls remain paused for all Part D rows; action dispatch is tested in Parts E
and F.

## D01 — Handedness and stable two-hand identity

- [x] Show only the physical left hand for five seconds.
- [x] Confirm one green box/skeleton appears and says `L · YOUR LEFT HAND`.
- [x] Confirm the left-hand role/label is understandable and does not flip.
- [x] Remove it; show only the physical right hand for five seconds.
- [x] Confirm one green box/skeleton appears and says `R · YOUR RIGHT HAND`.
- [x] Confirm the right-hand role/label is understandable and does not flip.
- [x] Show both hands, separated, for ten seconds.
- [x] Confirm two boxes appear, each anatomical label remains correct, and the
  labels/roles do not immediately swap or rapidly flicker.
- [x] Confirm selfie orientation is understandable and the preview is not
  horizontally stretched.

Result: **Pass**

Notes/evidence: Human tester reported `D01 passed`. Physical left-only,
right-only, and both-hand checks passed with correct anatomical labels, stable
roles, understandable selfie orientation, and no preview stretching. Written
observation only; the requested video was not attached. See
`D01-handedness-observation.md`.

## D02 — Representative gesture categories and HUD alignment

With Hand Controls paused, hold each static/contact/orientation pose for two to
three seconds. Perform motion gestures once deliberately, then return to neutral.

- [ ] Static: `Peace` is recognized distinctly. **Fail: detected about half the time.**
- [ ] Dynamic: `Swipe Up` is recognized once without a delayed repeat. **Fail:
  no detection.**
- [ ] Orientation: open palm facing the camera is labeled `Palm Facing Camera`
  (record the actual label if a static pose wins instead).
- [ ] Unknown: a relaxed ambiguous/partially curled pose safely reports `No
  gesture` or no candidate rather than a consequential gesture.
- [x] Contact: thumb/index contact reports `Finger Heart`.
- [ ] Contact: thumb/middle contact reports `Thumb + Middle`. **Passes only after
  first showing an open palm.**
- [ ] Contact: thumb/ring contact reports `Thumb + Ring`. **Passes only after
  first showing an open palm.**
- [x] Each detected hand has a green box, green skeleton, physical-hand label,
  gesture label, and readable action/detected-state label.
- [x] Boxes, joints, and labels remain aligned with the hand.
- [x] The camera image remains at a natural aspect ratio without stretching.
- [x] No action fires because Hand Controls are paused.

Result: **Fail**

Notes/evidence: Peace detected about half the time. Swipe Up never detected.
Palm-facing-camera produced No Gesture, while the back of the hand produced Open
Palm. The ambiguous Unknown pose became Finger Heart about half the time;
controls were paused, but that false label maps to a default click and is a
release-blocking safety risk (JARBO-109-007). Thumb/index passed. Thumb/middle
and thumb/ring passed only after first showing an open palm (JARBO-109-009).
Overlay alignment/aspect and action suppression passed. See
`D02-gesture-observation.md`; requested video was not attached.

## D03 — Hand/candidate disappearance

- [x] Hold a clearly recognized pose until its candidate/label appears.
- [x] Remove that hand completely from frame.
- [x] Confirm its box, skeleton, label, and candidate clear promptly.
- [x] Repeat with the other hand.
- [x] Repeat with both hands, removing one at a time.
- [x] Confirm no stale label remains and no delayed action fires.

Result: **Pass**

Notes/evidence: Human tester confirmed left removal, right removal,
one-at-a-time removal, and both-hand removal passed. Boxes, skeletons, labels,
and candidates cleared promptly, with no delayed action. Controls remained
paused, so held-button release remains Part E. See
`D03-removal-observation.md`.

## D04 — Quality rejection under difficult observations

Repeat with the physical left and right hands where practical.

- [ ] Normal lighting establishes a stable baseline.
- [ ] Dim/low lighting rejects or degrades safely without a false click/command.
- [ ] Fast hand motion rejects or recovers safely without a false action.
- [ ] Partially hide fingers behind the other hand or frame edge.
- [ ] Confirm incomplete/low-quality landmarks do not produce a consequential
  false gesture, stretched overlay, or stuck candidate.
- [ ] Return to normal conditions and confirm tracking recovers without relaunch.

Result: **Pending**

Notes/evidence: Deferred at the human tester's request on 2026-07-20 because
lighting conditions could not currently be tested. No partial result is inferred;
repeat all D04 conditions together later. See `D04-DEFERRED.md`.

## D05 — Crossed-hand identity uncertainty

- [x] Show both open hands separated and confirm correct labels.
- [x] Slowly cross the hands at the wrists, pause briefly, then uncross them.
- [x] Repeat once with one hand briefly occluding part of the other.
- [x] Record any label swap, flicker, disappearance, or delayed correction.
- [x] Confirm uncertainty resolves safely after separation.
- [ ] Confirm no wrong-hand consequential action or stuck input occurs. **Fail:
  consequential false labels appeared during occlusion; controls were paused.**

Result: **Fail**

Notes/evidence: Separated labels passed and correct identity recovered after
uncrossing. Close/brief occlusion reduced the display to one hand, caused rapid
handedness-label flicker, and produced consequential false gesture labels. The
exact false label was not recorded. No action dispatched because controls were
paused, and no ghost/stuck overlay remained afterward. JARBO-109-010. See
`D05-crossed-hands-observation.md`; requested video was not attached.
