# D02 Gesture and HUD Observation

- Date: 2026-07-20
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Hand controls: Paused
- Human result: D02 failed gesture-recognition acceptance

| Trial | Human observation | Result |
|---|---|---|
| Peace | Detected about half the time | Fail |
| Swipe Up | No detection | Fail |
| Palm Facing Camera | No Gesture; the back of the hand instead produced Open Palm | Fail |
| Unknown/ambiguous pose | Correct about half the time; otherwise Finger Heart | Fail; unsafe false contact candidate |
| Thumb + Index | Finger Heart detected | Pass |
| Thumb + Middle | Detected only after the palm was previously opened | Pass with limitations |
| Thumb + Ring | Detected only after the palm was previously opened | Pass with limitations |
| Green box/skeleton/alignment/aspect | Passed | Pass |
| Action suppression while paused | No action fired | Pass |

The false Finger Heart label is consequential because the default physical-left
binding maps it to Left click. No click fired in D02 because Hand Controls were
paused. This is JARBO-109-007 and must be resolved or remain release-blocking.
Static/dynamic/orientation failures are JARBO-109-008. Contact detector
state-dependence is JARBO-109-009.

Evidence limitation: the requested video was not attached; this result is based
on the tester's written observations.
