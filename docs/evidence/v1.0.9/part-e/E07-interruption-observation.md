# E07 Interruption Release Observation

- Started: 2026-07-22
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Test surface: Local pointer-event test pad
- Overall result: Pass with limitations

| Path | Button | Observation | Result |
|---|---|---|---|
| Hand leaves frame | Left | Initial hold passed; released promptly after full-hand removal; no repeated/wrong event; final released; Primary disabled again | Pass |
| Open Actions | Right | Actions opened and released held Right with very little delay; no Left/Middle event; final released. Detection barely worked and repeated behavior passed only about half the time; Context disabled and controls paused afterward. | Pass with limitations; JARBO-109-013 |
| Camera Off | Middle | Camera Off released held Middle with very little delay, cleared capture/privacy, produced no Left/Right or repeated event, and ended released. Detection barely worked unless preceded by a clear camera-facing open palm and could not be established from point pose; Middle disabled and controls paused afterward. | Pass with limitations; JARBO-109-009/014 |
| Normal quit | Left | Initial hold, Command-Tab selection, normal Command-Q, prompt release, no repeat/wrong event, and final released state passed. Human saw “Jarbo quit unexpectedly”; system audit found voluntary `(0,0,0)` exit and no crash report. | Pass with limitations; JARBO-109-015 |

The first path confirms the isolated Left button is not left stuck after tracking
loss. The second confirms opening Actions releases isolated Right promptly, but
the underlying Right detector remains extremely unreliable. The third confirms
Camera Off releases isolated Middle and clears camera/privacy promptly, but
thumb/ring acquisition remains history/orientation-sensitive. The fourth path
confirms normal quit releases isolated Left. Its unexpected-quit alert conflicts
with system evidence of a voluntary exit and remains JARBO-109-015. All four
paths end without stuck input, but these results do not mitigate Critical
false-click defect JARBO-109-012.

Evidence limitation: four-path video was not attached; results use written
event-counter observations.
