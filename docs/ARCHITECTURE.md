# ALPHA Jarbo 1.0.9 Architecture

Status: Phase 0 architecture record

Decision: native Swift/macOS first

## Context and decision

The long-range roadmap described a portable Python/Tauri option, but the existing Jarbo product is already a native macOS application with material investment in SwiftUI, AppKit, AVFoundation, Apple Vision, Core ML, Create ML, and macOS Accessibility automation. ALPHA Jarbo 1.0.9 keeps that native stack and adds typed seams around intent, policy, and execution rather than rewriting the working application during a stability release.

Consequences:

- macOS is the only supported platform for this release.
- Native frameworks provide camera, hand-pose, UI, model, media, and automation integration with no browser runtime in the control loop.
- Platform-independent concepts are expressed as Swift value types and protocols so they can later move into modules or support additional adapters.
- The new typed core is a tested foundation. The legacy production gesture engine has not yet been fully routed through it; completing that migration is foundation-hardening work, not a claim made by 1.0.9.

## Runtime overview

```text
AVCaptureSession
      |
Apple Vision hand-pose request
      |
Canonical Jarbo hand frame (up to 21 joints per hand)
      |
tracking + smoothing + contact/motion/static recognizers
      |
temporal gesture lifecycle and configured binding
      |
permission/validation boundary
      |
macOS automation adapter
      |
visible result / command log / HUD state
```

The Phase 0 contract seam is:

```text
JarboEvent -> JarboIntent -> ActionRequest
     -> Capability policy -> Action executor -> ActionResult
                                      |
                                  AuditEvent
```

The mock vertical slice proves that sequence without invoking real macOS automation. It deliberately keeps the test executor separate from `AutomationService`.

## Major components

| Component | Responsibility | Boundary |
|---|---|---|
| `JarboApp` / `AppDelegate` | Application, window, menu-bar, reopen, quit, and top-level dependency wiring | Owns lifecycle, not gesture classification. |
| `ControlCenterView` | HUD, Actions editor, training controls, readiness, and status display | Observes state and requests operations. |
| `HandTrackingService` | Camera session, Apple Vision request, canonical landmarks, temporal recognition, training snapshots, and safety release | Camera/perception boundary. |
| `HandLandmarks` | Detector-neutral 21-joint types and normalized hand frames | Canonical detector boundary. |
| `PersonalizedGestureClassifier` | Local Create ML training, compiled Core ML loading/inference, metadata, and diagnostics | Static personalized model only. |
| `Models` / `AppState` | Settings, bindings, local training samples, readiness calculation, migration, and debounced persistence | Local configuration/data boundary. |
| `AutomationService` | Validates and executes configured macOS actions and controls mouse-button lifecycle | Platform side-effect boundary. |
| `CoreContracts` | Typed event, intent, capability, request, result, policy, cancellation, executor, and mock slice | Phase 0 orchestration foundation. |
| `PerformanceSignposts` | Local signposts around editor and settings/training work | Measurement aid, not a completed benchmark. |

## Canonical 21-joint boundary

Apple Vision is the production detector in 1.0.9. Its output is converted into Jarbo's detector-neutral canonical hand representation before gesture logic or training consumes it. The boundary includes canonical joint identity, normalized position, confidence/quality, hand side, detector source, and capture time. Optional depth can be added later without changing the required 21-joint baseline.

This boundary exists so that:

- gesture rules and overlays do not depend directly on Apple Vision joint types;
- personal samples remain reusable if a future MediaPipe adapter is evaluated;
- quality, handedness, age, and completeness can be checked before classification;
- 21/21 fresh landmarks can be required for a saved static training pose.

MediaPipe, LiDAR, external depth cameras, and a visionOS 26-anchor provider are not bundled in 1.0.9.

## Recognition layers

Jarbo uses specialized recognition rather than one model for every control:

1. Deterministic thumb-to-finger contact logic owns mouse-button begin, hold, and release.
2. Motion history recognizes configured temporal gestures.
3. A personalized local Core ML classifier may recognize eligible static poses after readiness requirements are met.
4. Personal templates and bundled numeric priors can support static classification.
5. Conservative temporal confirmation and an explicit unknown/no-gesture outcome reduce one-frame activation.

The probabilistic model must never own emergency release. Tracking loss, Camera Off, configuration mode, and application termination are expected to invoke deterministic release paths.

## Personalized Core ML

The first personalized model is a local tabular classifier over forty normalized X/Y landmark features. It intentionally excludes dynamic and orientation samples from static-model readiness. A build requires:

- ten valid `No gesture / other` samples;
- ten valid samples for at least two eligible static gesture classes;
- forty features for every included sample;
- incomplete extra static classes to be ignored safely.

Training runs away from the main UI thread. The compiled model, metadata, and last build error are stored locally under `Application Support/Jarbo/Models`. The UI exposes exact readiness plus delete/rebuild controls. Model replacement and persistence still require release-candidate rehearsal; source presence alone is not proof of transactional behavior on every machine.

## Typed core contracts

`CoreContracts.swift` defines the minimum Phase 0 vocabulary:

- `JarboEvent`: timestamped normalized input such as a gesture, cancel, or tracking loss;
- `JarboIntent`: a bounded meaning resolved from an event;
- `Capability`: an open string-backed capability identifier with a known allowlist;
- `ActionRequest`: the authorized side-effect request;
- `ActionResult`: success, denial, cancellation, ignored, or failure plus verification state;
- `AuditEvent`: a typed record connecting event, intent, request, result, and detail;
- resolver, authorizer, executor, and control-release protocols;
- a thread-safe cancellation token.

The foundational tests prove a mock fist-to-media path, deny an unknown capability, prevent No Gesture from executing, prevent execution after cancellation, and release controls on tracking loss.

## Camera and application lifecycle

Jarbo models camera state separately from HUD visibility. The intended policy is:

- a new/migrated profile defaults to Camera Off;
- the user's camera intent is saved locally;
- the live state reports off, starting, on, stopping, permission denied, or unavailable;
- Camera Off stops capture, clears tracking/temporal state, and releases controls;
- Camera On requests permission only when needed and must not create duplicate sessions;
- the macOS camera privacy indicator is preserved while capture is active.

Jarbo uses a normal window level and a regular application activation policy. Closing the last HUD window does not terminate the process. The menu-bar item remains available for show/hide, camera state, configuration, model status, and quit. Hiding the HUD can permit background operation when the camera is explicitly enabled; status updates should not force Jarbo over the active app.

This is the documented contract. Ten-cycle camera tests, focus behavior, full-screen coexistence, Mission Control appearance, and resource release remain manual v1.0.9 gates.

## Local-first data flow

```text
camera frame (memory only)
  -> Apple Vision observation
  -> canonical landmarks
  -> live recognition (ephemeral)
  -> optional user-requested normalized sample
  -> Application Support/Jarbo/config.json
  -> optional local Core ML model under Application Support/Jarbo/Models
```

No camera-frame upload or automatic training-data upload exists in the 1.0.9 path. Bundled HaGRID-derived assets contain numeric landmark priors, not source photographs or user identifiers. Cloud image generation is a separate explicit action and is not part of hand detection or model training.

## Permissions and safety

- Camera permission gates capture.
- Accessibility gates mouse and keyboard output.
- Space switching uses direct Accessibility-authorized Control–Arrow events; Spotify scripting may require a separate Automation grant.
- URL and value-bearing bindings are validated before execution.
- Shell commands require an explicitly saved user binding and remain a high-risk capability.
- Unknown capabilities are denied in the typed core.
- No Gesture, cancellation, and tracking loss have explicit non-action/release tests.

The 1.0.9 policy layer is foundational, not a complete sandbox or third-party skill system. Consequential workflows, provider boundaries, confirmation classes, target revalidation, signed skills, and a full threat model remain later work.

## Performance approach

The release uses a bounded 720p/30 FPS capture target, throttled overlay publication and personalized inference, cached gesture catalogs, debounced/off-main persistence, configuration-mode suppression of expensive classification/action dispatch, bounded training capture, and local performance signposts. These are implemented optimization mechanisms, not measured gate results.

The Actions editor targets 500 ms open-to-interactive, 100 ms setting feedback, no sustained stall over 100 ms, no sustained CPU increase above the active-camera baseline, and no repeated memory-growth pattern. Measurements must be recorded in the feature audit before a go decision.

## Verification and CI

`./verify.sh` is the single repository verification command. It:

1. runs environment preflight;
2. runs the Swift test target;
3. builds the application;
4. validates the bundle and property list;
5. verifies the code signature; and
6. verifies a universal arm64/x86_64 executable.

The macOS CI workflow runs that command for pushes to `main` and pull requests. A workflow file is evidence of CI configuration, not evidence of a green release-candidate run. Clean-checkout and CI results must be linked from the Phase 0 review.

## Explicit 1.0.9 exclusions

- Voice controls and speech-command reliability.
- PDF reading and PDF understanding.
- Image reading and visual-content understanding.
- The 3D model viewer and related rendering/content workflows.
- MediaPipe/model fusion, landmark recording/replay, accuracy reports, and a general pretrained Core ML model.
- Developer ID signing, notarization, installer/update infrastructure, and stable-channel distribution.

Excluded prototypes must remain non-blocking and fail safely. Their presence in the interface is not evidence that they pass the 1.0.9 release gate.

## Known debt and next decisions

- Route the full production gesture path through the typed intent/capability/executor boundary.
- Add deterministic landmark recording and replay before making recognition-accuracy claims.
- Measure Apple Vision jitter, latency, handedness continuity, and joint loss on a hardware/environment matrix.
- Compare an adaptive filter and elapsed-time gesture state machine against the current baseline.
- Benchmark Apple Vision against MediaPipe before adding a second detector.
- Add formal ADRs, a complete threat model, module boundaries, structured/redacted diagnostics, and broader contract/resilience tests in v1.1.x.
