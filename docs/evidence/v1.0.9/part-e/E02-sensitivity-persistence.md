# E02 Sensitivity Persistence Observation

- Date: 2026-07-21
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Profile: Normal user profile (`/Users/senhong/Library/Application Support/Jarbo/config.json`)

## Active response

- Initial sensitivity: `0.50×`
- Test sensitivity: `0.70×`
- Human observation: response changed and felt better
- Human preference: approximately `0.75–0.90×` in the current relative mode
- Click bindings during trial: Left, Right, and Middle disabled
- Event-pad counters: all zero
- Controls after trial: Paused

## Persistence audit

- Pre-quit PID: 15349
- Normal quit: Completed
- Saved sensitivity after quit: `0.7000000000000001`
- Relaunch PID: 23491
- Relaunched process count: One canonical `/Applications/Jarbo.app` process
- Saved sensitivity after relaunch: `0.7000000000000001`
- Saved click bindings after relaunch: Left, Right, and Middle remain disabled
- Saved camera intent: Off
- Human post-relaunch HUD confirmation: Slider displays `0.70×`
- Human post-relaunch Actions confirmation: Left, Right, and Middle bindings remain disabled
- Final result: Pass

The July 21 process uses the normal user profile. The July 20 isolated test
profile was not used for this row. File/process evidence and human HUD
confirmation both verify persistence. `0.70×` is intentionally retained for
continued testing rather than restored to `0.50×`.
