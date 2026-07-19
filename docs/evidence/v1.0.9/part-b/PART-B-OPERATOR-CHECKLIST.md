# Jarbo 1.0.9 Part B Operator Checklist

Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)

Date: 2026-07-19

Record `Pass`, `Pass with limitations`, `Fail`, or `Blocked` for each test and
write down any unexpected focus change, duplicate HUD, crash, camera activation,
or stuck control.

## Safety setup

- [ ] Confirm only one Jarbo HUD is open.
- [ ] Confirm no mouse button or keyboard modifier is held.
- [ ] Keep Camera Off for B01, B02, and B04 unless a step says otherwise.
- [ ] Use `Pause Hand Controls` before enabling the camera for B03/B05.

## B01 — Hide/show paths

### Menu-bar path

- [ ] Open the Jarbo menu-bar menu and select `Hide Jarbo HUD`.
- [ ] Confirm the HUD hides exactly once and Jarbo remains in the Dock/menu bar.
- [ ] Reopen the menu and confirm the label changed to `Show Jarbo HUD`.
- [ ] Select `Show Jarbo HUD` and confirm exactly one HUD appears.
- [ ] Confirm the label returns to `Hide Jarbo HUD`.

### Configured action path

- [ ] If a `Toggle HUD` gesture is already configured and trusted, trigger it once
  to hide and once to show the HUD.
- [ ] Confirm there is no rapid repeat, duplicate HUD, or unexpected action.
- [ ] If no trusted binding exists, mark this subcheck `Deferred` until gesture
  input is validated in Parts D–F. Do not create or activate an unverified hand
  binding solely for this lifecycle test.

Result: **Pending**

Notes/evidence:

## B02 — Close and restore paths

Test each path from a freshly closed HUD so results do not overlap.

### Dock restore

- [ ] Close the HUD with the red window button.
- [ ] Confirm Jarbo remains running in the Dock and menu bar.
- [ ] Click Jarbo in the Dock and confirm exactly one HUD reopens.

### Command-Tab restore

- [ ] Close the HUD again and focus another application.
- [ ] Command-Tab to Jarbo and confirm exactly one HUD reopens.

### Mission Control/F3 observation

- [ ] With the HUD visible, confirm it appears once in Mission Control/F3.
- [ ] After closing the HUD, confirm no stale/ghost Jarbo window appears there.

### Menu-bar restore

- [ ] Close the HUD again.
- [ ] Open the Jarbo menu and select `Show Jarbo HUD`.
- [ ] Confirm exactly one HUD reopens.

Result: **Pending**

Notes/evidence:

## B03 — Focus preservation

- [ ] Select `Pause Hand Controls` from the Jarbo menu.
- [ ] Turn Camera On and confirm its live state is explicit.
- [ ] Focus a harmless text editor and type a short sentence.
- [ ] While the editor remains focused, move a hand so Jarbo tracking/status updates.
- [ ] Confirm Jarbo does not activate, move in front, or steal keyboard focus.
- [ ] Confirm typed text continues going only to the editor.
- [ ] Turn Camera Off after the observation unless it is intentionally needed for B05.

Result: **Pending**

Notes/evidence:

## B04 — Full screen and Spaces

- [ ] Keep Camera Off and hand controls paused.
- [ ] Put a harmless app or video into full screen.
- [ ] Confirm Jarbo does not force itself above the full-screen content.
- [ ] Open Mission Control and move between at least two Spaces.
- [ ] Confirm Jarbo does not appear above every Space unexpectedly.
- [ ] Return to Jarbo and confirm one HUD remains usable.

Result: **Pending**

Notes/evidence:

## B05 — 30-minute hidden/background observation

- [ ] Record Jarbo CPU and memory at the start in Activity Monitor.
- [ ] Set the intended state explicitly: Camera On or Off, controls Paused or Active.
- [ ] Hide the HUD from the menu bar.
- [ ] Use another application normally for 30 minutes.
- [ ] Confirm Jarbo never activates or steals focus unexpectedly.
- [ ] Confirm the menu-bar item remains responsive throughout.
- [ ] If Camera On was intended, confirm the system privacy indicator remains present.
- [ ] After 30 minutes, show the HUD and confirm one responsive window appears.
- [ ] Record ending CPU and memory; note any sustained increase or instability.

Result: **Pending**

Notes/evidence:

## B06 — Quit and relaunch

Current result: **Fail — JARBO-109-001**

- [x] `Quit Jarbo` is present in the menu-bar menu.
- [x] The item is disabled/grey and cannot be clicked.
- [ ] Process exit, camera release, settings flush, and relaunch restoration cannot
  be evaluated through the required menu-bar path until the defect is fixed.

Do not replace this result with a Command-Q test; that can be recorded as a
separate workaround observation but does not satisfy B06.
