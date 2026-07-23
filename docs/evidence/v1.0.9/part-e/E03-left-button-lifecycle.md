# E03 Left-Button Lifecycle Observation

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Test surface: Local pointer-event test pad
- Enabled mouse binding during test: Primary click only
- Human result: Pass

| Check | Result |
|---|---|
| Before intended contact | No early event; pass |
| Thumb/index hold | Exactly one Left down, zero Left up, held for two seconds |
| Separation | Exactly one Left up |
| Repeated events | None |
| Right/Middle collision | None |
| Final button state | Released |
| Post-test binding state | Primary click disabled again |

This deliberate isolated lifecycle passed. It does not mitigate Critical
JARBO-109-012: ordinary pointer movement with multiple click bindings enabled
previously produced unintended left/right click events.

Evidence limitation: video was not attached; the result is based on the human
tester's written event-counter observation.
