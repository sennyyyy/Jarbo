# Jarbo 1.0.9 Part A Observations

Date: 2026-07-19

Designated candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)

## A01 — Fresh-clone verification

The branch was cloned with `--no-local --single-branch` into
`/private/tmp/jarbo-a01-58246c2`, then `./verify.sh` was run from that clean
checkout. All 13 Swift tests passed. The script produced and verified an
ad-hoc-signed universal `x86_64 arm64` application bundle.

Evidence: `A01-clean-verify-58246c2.log`.

The verified application was packaged as
`dist/Jarbo-1.0.9-RC-58246c2.zip`. SHA-256:

`d02b23d6df4794f4090e7b9d35c6dc4b31c4c6e29b8b694d2b487a6b44b0c0b2`

Exact-candidate CI also passed:
[Verify Jarbo #4](https://github.com/sennyyyy/Jarbo/actions/runs/29677667695).

## A02 — Clean launch

No existing Jarbo process was present. The verified app was launched through
macOS LaunchServices using `open -F`, which macOS documents as the equivalent
of double-clicking an application. It used an isolated empty profile through
`CFFIXED_USER_HOME=/private/tmp/jarbo-smoke-home`.

One Jarbo process and one HUD window were observed. The process remained alive
after launch and no immediate crash or duplicate window appeared.

Evidence: `A02-clean-launch.png` and `A02-process-observation.txt`.

## A03 — Dock, Command-Tab, and Mission Control

The human tester confirmed that Jarbo appears in the Dock, appears and can be
selected in the Command-Tab switcher, and appears in Mission Control/F3. The
check returned to one HUD without creating a duplicate window. A03 is **Pass**.

The earlier automated `System Events` attempt was denied assistive access
(`-1719`), so this result is based on the human observation rather than source
inspection or test-harness automation.

## A04 — Camera-off default

The isolated profile contained no saved Jarbo configuration. On the first
launch, the HUD showed both `Camera Off` and `Camera Offline`. No macOS camera
privacy indicator was visible, and no camera-permission prompt appeared.

Evidence: `A02-clean-launch.png`.

## A05 — Menu-bar appearance and accessibility

The human tester reported that all of the following passed:

- Expected menu items are present and otherwise accurate.
- The icon is clear in both Dark and Light appearance.
- The icon is not confused with the macOS camera privacy indicator.
- VoiceOver or Accessibility Inspector identifies it as `Jarbo controls`.
- No crash, unexpected camera activation, duplicate process, or duplicate HUD
  occurred during the check.

One limitation was observed: `Quit Jarbo` is present but greyed out and cannot
be clicked. A05 is therefore **Pass with limitations**, and the unusable Quit
path is recorded as defect JARBO-109-001. The B06 menu-bar termination test is
also **Fail** at its first step; shutdown/relaunch behavior has not yet been
tested.

## Runtime diagnostic note

The captured stderr later contained one non-crashing warning:

`AttributeGraph: cycle detected through attribute 379544`

No visible rendering failure, crash, duplicate HUD, or focus problem accompanied
the warning during the recorded Part A observations. Its trigger and impact are
unknown, so it is tracked separately as low-severity JARBO-109-002 rather than
being treated as a Part A functional failure.
