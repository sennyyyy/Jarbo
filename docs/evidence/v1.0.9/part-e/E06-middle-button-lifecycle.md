# E06 Middle-Button Lifecycle Observation

- Date: 2026-07-22
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Test surface: Local pointer-event test pad
- Enabled mouse binding during test: Middle click only
- Human result: Fail due to gesture collision

| Check | Human observation | Result |
|---|---|---|
| Direct fresh-hand detection | Detected | Pass |
| Direct HUD label | Correct | Pass |
| Direct hold lifecycle | Remained held | Pass |
| Direct separation | Released | Pass |
| Detection after open palm | Detected | Pass |
| After-open-palm hold | Remained held | Pass |
| Left/Right counters | Zero | Pass under isolated-binding setup |
| Collision labels | Sometimes changed to Finger Heart | Fail |
| Final state | Released | Pass |
| Post-test binding state | Middle click disabled again | Pass |

The isolated Middle lifecycle works, but the thumb/ring pose is not distinct
enough from Finger Heart. With the normal Primary binding enabled, this
classification collision could create a Left click instead of an intended
Middle click. JARBO-109-014 is release-blocking.

Design preference recorded: detection should work while pointing naturally
toward the screen and should not require an open-palm presentation.

Evidence limitation: video was not attached; the result is based on the human
tester's written event-counter and HUD observations.
