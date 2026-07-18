# ALPHA Jarbo 1.0.9 Risk Register

Review cadence: at every release-candidate gate and after a critical/high defect

Current release decision: **HOLD pending verification**

Likelihood and impact use Low / Medium / High. “Mitigating” means a control exists in source but the release-candidate evidence is not yet complete; it does not mean the risk is closed.

| ID | Risk | Owner | Likelihood | Impact | Mitigation | Trigger / stop condition | Status |
|---|---|---|---|---|---|---|---|
| R-01 | False or ambiguous gestures execute unintended actions. | Perception lead | High | High | Explicit No Gesture class; class/readiness requirements; temporal confirmation; binding enable/disable; conservative unknown outcome; planned replay/negative evaluation. | Any consequential one-frame activation, repeated collision, or negative-test rate at/above one unintended command per hour blocks release. | Mitigating; accuracy and negative-session evidence pending. |
| R-02 | A mouse button or modifier remains held after contact release, tracking loss, camera stop, configuration, or quit. | macOS automation lead | Medium | Critical | Deterministic contact lifecycle independent of Core ML; global release methods; tracking-loss core test; release calls in camera/configuration/termination paths. | Any stuck input or release path over 200 ms in manual testing is release-blocking. | Mitigating; real-device lifecycle tests pending. |
| R-03 | Camera remains active contrary to user intent or duplicate sessions consume the resource. | Camera/lifecycle lead | Medium | High | Explicit camera state, safe default Off, saved intent, idempotent session start, stop/clear path, menu status, OS privacy indication preserved. | Incorrect live state, hidden continued capture after Off, duplicate session, or failure across ten On/Off cycles blocks release. | Mitigating; ten-cycle/resource evidence pending. |
| R-04 | Apple Vision hand identity, landmarks, or 2D occlusion produce wrong-hand or wrong-contact behavior. | Perception lead | High | High | Canonical 21-joint boundary; handedness and freshness metadata; 21/21 capture requirement; contact arbitration; clutching; low-quality/incomplete rejection. | Frequent hand-role swaps, unsafe contact under occlusion, or unusable pointer on supported hardware forces hold/revise. | Open; hardware/environment matrix not run. |
| R-05 | macOS Accessibility, Camera, or Automation permissions fail silently or recover incorrectly. | Platform lead | High | High | Permission preflight/status UI; action rejection/logging; camera-denied state and recovery link; direct Accessibility events for desktop switching; visible Spotify failures. | Silent no-op, permission bypass, repeated prompts, or controls continuing after revocation blocks release. | Mitigating; grant/revoke/recovery tests pending. |
| R-06 | User-created actions target an invalid or unsafe value, especially URLs, files, applications, or shell commands. | Action/policy lead | Medium | High | Binding validation; explicit saved actions; typed capability allowlist in Phase 0; error reporting; high-risk shell action documented. | Unknown capability executes, invalid URL/script scheme launches, wrong target receives input, or a shell command runs without explicit binding blocks release. | Open/mitigating; typed policy is not yet the full production route. |
| R-07 | Personalized training overfits, accepts stale/incomplete data, or replaces a usable model incorrectly. | ML/training lead | High | High | Exact 10+10+10 readiness; eligible-static filtering; 21/21 fresh capture; diversity prompts and duplicate warnings; local build diagnostics; delete/rebuild; compiled-model validation and metadata. | Build enables early, dynamic/orientation data contaminates the static model, failed rebuild removes the usable model, or relaunch cannot recover it blocks release. | Mitigating; build/delete/rebuild/relaunch rehearsal pending. |
| R-08 | Actions/configuration work causes main-thread stalls, CPU growth, thermal load, or retained camera/model tasks. | Performance lead | Medium | High | 720p/30 FPS target; throttled display/model work; cached catalogs; debounced off-main persistence; configuration-mode suppression; signposts; bounded histories. | Editor exceeds 500 ms open, ordinary edit stalls exceed 100 ms, sustained CPU rises above active-camera baseline, or memory grows across ten cycles blocks release. | Open; baseline, final measurements, and soak pending. |
| R-09 | Local configuration, training landmarks, notes, logs, or future provider data are retained or exposed unexpectedly. | Privacy/security lead | Medium | High | Raw camera frames not saved by training; Application Support local storage; atomic config writes and corrupt backup; bounded in-memory command log; no automatic telemetry/training upload. | Raw frame persistence, automatic upload, secret in shared diagnostics/repository, or unrecoverable settings loss blocks release. | Mitigating; formal retention/deletion and diagnostics audit pending. |
| R-10 | Alpha packaging/build differences create an app that will not launch, retain permission identity, or run across supported architectures. | Release lead | Medium | High | Dynamic Xcode/SDK preflight; Swift tests; universal build; bundle/plist/signature/architecture checks; macOS CI; prerelease-only policy. | Fresh checkout fails `./verify.sh`, CI is red, app fails Finder launch, or supported architecture is missing blocks publication. | Open; clean-checkout, CI, Finder launch, signing/notarization limits pending. |

## Accepted release limitations

The following do not close the risks above, but define the alpha boundary:

- The app is ad-hoc signed rather than Developer ID signed and notarized.
- Pointer targeting is intended primarily for the main display; the multi-display matrix is not complete.
- Webcam tracking remains sensitive to blur, lighting, severe occlusion, and hand visibility.
- Personalized Core ML covers eligible static gestures only; motion and orientation use separate recognition paths.
- Voice reliability, PDF/image understanding, and the 3D viewer are excluded from the 1.0.9 go gate.
- MediaPipe, depth sensing, and model fusion are deferred until the Apple Vision baseline is measured.

## Escalation policy

- Any Critical risk realization is an immediate **HOLD**.
- Any open High-severity defect without a safe workaround is an immediate **HOLD**.
- A Medium defect may ship only in an alpha prerelease when its workaround, affected scope, and regression test are recorded in the feature audit and release notes.
- A risk may move to Closed only with linked test evidence on the designated release-candidate commit; source inspection alone is insufficient.

## Next review

Record the reviewer, date, release-candidate commit, linked CI run, clean-checkout log, smoke-test evidence, and decision in `docs/V1.0.9-PHASE-0-REVIEW.md`. The current status remains **HOLD** until those fields are complete.
