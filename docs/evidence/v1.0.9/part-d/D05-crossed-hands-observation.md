# D05 Crossed-Hands Observation

- Date: 2026-07-20
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Hand controls: Paused
- Human result: D05 failed identity-uncertainty safety

| Trial | Human observation | Result |
|---|---|---|
| Separated labels | Correct | Pass |
| Crossing | `passed-ish`; uncertainty observed around close overlap | Limitation |
| After uncrossing | Correct labels recovered | Pass |
| Brief/close occlusion | Only one hand shown; label flickered rapidly when too close | Fail |
| Consequential false labels | Appeared while hands somewhat occluded; exact label not recorded | Fail |
| Ghost/stuck overlays | None | Pass |
| Action dispatch | None while controls paused | Pass |

The unsafe condition is bounded to two-hand overlap in this observation and
recovered after separation, but a consequential candidate during identity
uncertainty could route to the wrong physical-hand binding when controls are
active. This is release-blocking JARBO-109-010.

Evidence limitation: the requested video was not attached; this result is based
on the tester's written observations.
