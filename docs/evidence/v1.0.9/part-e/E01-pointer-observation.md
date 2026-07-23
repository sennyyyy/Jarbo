# E01 Pointer Observation

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Initial sensitivity: `0.50×`
- Display arrangement: Built-in display only
- Human result: E01 failed full acceptance

| Check | Human observation | Result |
|---|---|---|
| Circular Jarbo pointer | Tester reports very poor index-finger detection and that the pointer barely works reliably; it works only when the hand/index is angled rather than pointing straight toward the screen | Fail |
| Movement at 0.50× | Controllable in current relative mode | Pass |
| Axis/jitter | Correct axis with slight jitter | Pass with limitation |
| Camera-edge reach | Could not continue in a direction when beginning at the relevant edge; tester prefers direct proportional pointing | Fail |
| Clutch pause | Passed | Pass |
| Resume jump | No large jump | Pass |
| Unexpected button events | Pointer-only follow-up: Left 7 down/7 up, Right 3 down/3 up, Middle 0 down/0 up; all released | Critical safety failure |

The full E01 row fails because index-finger pointer detection is very poor, the
pointer barely works reliably, and camera-edge reach remains necessary. These
violate core acceptance even though movement, clutching, and resume behavior
worked when tracking engaged. JARBO-109-011 is release-blocking.

Design preference recorded after the trial: use direct proportional mapping
from a comfortable camera-space region to the screen, with a lower effective
sensitivity and stronger low-speed smoothing/dead-zone behavior for stability.
For absolute mapping, this control should tune filtering and gain around the
mapped point rather than reducing the ability to reach the full display.

The follow-up event audit confirmed that misclassification was not limited to
HUD labels: ordinary pointing synthesized seven left-click and three
right-click lifecycles. Matching up counts prevented stuck input, but the events
themselves are unsafe. JARBO-109-012 is a Critical release blocker. Keep all
mouse bindings disabled for general pointer/sensitivity trials; enable only the
single binding deliberately under test on the local pad.

Evidence limitation: video was not attached.
