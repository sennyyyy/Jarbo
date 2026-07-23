# E01 Pointer-Only Event Counters

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- Display: Built-in only
- Trial: Pointer movement without intended fingertip contact
- Controls after trial: Paused

| Button | Down | Up | Final state |
|---|---:|---:|---|
| Left | 7 | 7 | Released |
| Right | 3 | 3 | Released |
| Middle | 0 | 0 | Released |

All down events had matching up events, so no button remained stuck. However,
ten unintended click lifecycles occurred during ordinary pointer movement. This
is Critical JARBO-109-012 and blocks release. Further pointer/sensitivity trials
must disable all mouse-button bindings; deliberate button tests must enable only
the single binding under test and remain on the local event pad.
