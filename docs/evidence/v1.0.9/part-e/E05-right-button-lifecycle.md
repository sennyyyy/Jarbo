# E05 Right-Button Lifecycle Observation

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Test surface: Local pointer-event test pad
- Enabled mouse binding during test: Context click only
- Human result: Fail

| Check | Human observation | Result |
|---|---|---|
| Direct fresh-hand detection | Detected | Pass |
| Direct HUD label | Correct | Pass |
| Detection after open palm | Worked only about half the time / very occasionally | Fail |
| Hold lifecycle | Released early while thumb/middle remained held | Fail |
| Separation | Released | Pass |
| Left/Middle counters | Zero | Pass under isolated-binding setup |
| Repeated/early events | Occasional early/repeated/false events | Fail |
| Final state | Released | Pass |
| Post-test binding state | Context click disabled again | Pass |

The Right-button lifecycle is not reliable enough for use. Although no button
remained stuck, premature release breaks hold/drag semantics and early/repeated
events may create unintended context clicks. JARBO-109-013 is release-blocking.

Design preference recorded: use index+middle extended as the pointer pose,
thumb/index contact for Left click, and thumb/middle contact for Right click.

Evidence limitation: video was not attached; the result is based on the human
tester's written event-counter and HUD observations.
