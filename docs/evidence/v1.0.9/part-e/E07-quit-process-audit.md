# E07-D Quit Process Audit

- Date: 2026-07-22
- Candidate: `58246c2` (ALPHA Jarbo 1.0.9 build 9)
- App: `/Applications/Jarbo.app`
- Jarbo PID: 80867
- Human observation: “Jarbo quit unexpectedly” alert appeared

## Button result

- Initial isolated Left hold: Pass
- Jarbo selected through Command-Tab: Pass
- Command-Q exit: Completed
- Held Left released during quit: Pass
- Release delay: Passed
- Repeated/wrong-button events: None
- Final button state: Released
- Process remained closed: Yes

## Process and crash audit

- No `/Applications/Jarbo.app` process remained.
- No `Jarbo-2026-07-22-*.ips` crash report was present in DiagnosticReports.
- At `2026-07-22 14:37:34.310`, runningboard reported termination for PID 80867
  as `(0, 0, 0)`.
- At `2026-07-22 14:37:34.321`, Control Center recorded
  `RBSProcessExitContext| voluntary`.
- Launch services logged `QUITTING` for PID 80867.

The process evidence supports a voluntary quit rather than a crash. The human
alert remains a real contradictory user-visible limitation and is tracked as
JARBO-109-015 until reproduced or identified as a stale earlier notification.

## Saved post-quit profile

- Camera intent: Off
- Primary click: Disabled
- Context click: Disabled
- Middle click: Disabled
- Sensitivity: `0.70×`

The profile is safe for relaunch.
