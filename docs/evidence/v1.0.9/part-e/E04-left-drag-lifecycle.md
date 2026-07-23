# E04 Left-Drag Lifecycle Observation

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Test surface: Local pointer-event drag target
- Enabled mouse binding during test: Primary click only
- Human result: Pass

| Check | Result |
|---|---|
| Initial Left down | Pass |
| Continuous drag while thumb/index held | Pass |
| Counts while held | Left 1 down / 0 up |
| Separation | Left 1 down / 1 up |
| Immediate drag stop | Pass |
| Target follows after release | No; pass |
| Wrong/repeated events | None |
| Final state | Released |
| Post-test binding state | Primary click disabled again |

This deliberate isolated drag lifecycle passed. It does not mitigate Critical
JARBO-109-012, because ordinary pointer movement with multiple click bindings
enabled previously generated unintended click events.

Evidence limitation: video was not attached; the result is based on the human
tester's written event-counter observation.
