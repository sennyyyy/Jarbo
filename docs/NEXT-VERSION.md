# ALPHA Jarbo 1.0.9 — Proposed Change List

Implementation checklist status is intentionally conservative. Repository artifacts may exist without a checked box until the designated release candidate has the required automated or manual evidence. See `V1.0.9-PHASE-0-REVIEW.md` and `V1.0.9-FEATURE-AUDIT.md`; the current decision is **HOLD**.

## Release objective

Make personalized gesture training understandable, measurable, and harder to misuse while improving recognition stability without replacing Jarbo's proven safety-critical pinch and release logic.

## Recognition strategy

Jarbo should optimize its current canonical 21-joint hand pipeline before requiring LiDAR, external depth cameras, or a 26-anchor spatial skeleton. The 21-joint representation remains the portable core shared by Apple Vision, future MediaPipe support, public landmark datasets, and personal calibration.

The target recognition pipeline is:

```text
Apple Vision 21-joint detection
              ↓
Tracking, filtering, and stable hand identity
              ↓
Versioned feature extraction
              ↓
Specialized recognizers
├─ Deterministic finger-contact detection
├─ HaGRID-trained general landmark model
├─ Apple Create ML pose classifier
├─ Personal calibration
├─ Motion recognizer
└─ Orientation estimator
              ↓
Conservative confidence fusion
              ↓
Temporal gesture state machine
              ↓
Safe gesture event
```

Additional sensors and extended skeletons remain optional providers for depth-sensitive gestures after the 21-joint baseline is measured and hardened.

## P0 — Release-critical

- [ ] Replace the disabled-only **Build Core ML Model** state with a visible readiness checklist.
  - Show `No gesture: n/10`.
  - Show every eligible static class and its sample count.
  - State exactly what remains: for example, `9 No gesture + 7 Point samples needed`.
  - Explain that dynamic and orientation samples do not count toward the static Core ML model.
- [ ] Add a guided training flow.
  - Prompt for variations in distance, position, small rotation, lighting, and finger spacing.
  - Warn when several captures are nearly identical.
  - Require the selected hand to show `21/21` fresh landmarks.
- [ ] Improve the `No gesture / other` workflow.
  - Provide examples such as relaxed hand, partially curled fingers, transition poses, and unrelated movement.
  - Warn if the ten rejection samples are too similar.
- [ ] Add per-class training readiness and model-build diagnostics to the command log.
- [ ] Preserve and display the last Core ML training error after the controls panel closes.
- [ ] Add a **Delete/Rebuild Personalized Model** control with confirmation.
- [ ] Add regression tests for the exact model-readiness rule:
  - Ten No Gesture samples are mandatory.
  - At least two static gesture classes must each have ten samples.
  - Dynamic and orientation classes must not enable the button.
  - Incomplete extra static classes must be excluded safely.
- [ ] Fix local build compatibility with current macOS Command Line Tools/SDKs and add an environment preflight check with actionable errors.

## P1 — Recognition quality

- [ ] Replace frame-count activation thresholds with elapsed-time thresholds so recognition behaves consistently at different frame rates.
- [ ] Add per-gesture entry and exit confidence thresholds with hysteresis.
- [ ] Introduce an explicit temporal state machine: `idle → candidate → active → releasing`.
- [ ] Add a One Euro or equivalent adaptive landmark filter for lower pointer jitter without increasing fast-motion lag.
- [ ] Improve two-hand identity continuity when hands cross or Apple Vision changes handedness.
- [ ] Track landmark age and reject stale, incomplete, or low-quality observations before classification.
- [ ] Measure joint-loss frequency and recovery time by joint, hand, and environment.
- [ ] Add class-specific confidence and ambiguity margins instead of one global acceptance policy.
- [ ] Record why a prediction was rejected: low confidence, ambiguous classes, incomplete landmarks, stale frame, or insufficient stability.
- [ ] Keep pinch begin/hold/release and global control release deterministic and independent of Core ML.

## P1 — Evaluation and diagnostics

- [ ] Add a privacy-conscious landmark recorder that stores normalized landmarks, timestamps, labels, confidence, backend, and hand side—never camera frames by default.
- [ ] Add deterministic replay of recorded landmark sessions.
- [ ] Generate per-class precision, recall, and confusion-matrix reports.
- [ ] Measure false activations during `No gesture` sessions.
- [ ] Track median and p95 landmark-to-prediction latency.
- [ ] Add a developer diagnostics view showing:
  - Detector FPS
  - Recognition FPS
  - Landmark completeness
  - Active/candidate gesture
  - Core ML confidence and runner-up class
  - End-to-end latency
- [ ] Establish initial release gates:
  - Static precision ≥ 97% on the validation set.
  - Static recall ≥ 93% on the validation set.
  - Fewer than one unintended command activation per hour in negative testing.
  - Median landmark-to-result latency below 100 ms on supported hardware.

## P2 — Data and model improvements

- [ ] Expand the current small HaGRID prior library into a subject-separated general training dataset using compatible HaGRID landmark annotations.
- [ ] Include a large and diverse `No gesture` class in general model training and evaluation.
- [ ] Document every external gesture-label mapping and exclude ambiguous or incompatible classes.
- [ ] Expand static-pose features beyond normalized X/Y coordinates with joint angles, finger curl, fingertip distances, and landmark-quality values.
- [ ] Compare the existing boosted-tree model against logistic regression and a small MLP using the same frozen validation set.
- [ ] Train a general Core ML-compatible static model that works before personal calibration.
- [ ] Blend the general model and personal calibration rather than fully replacing general knowledge after ten captures.
- [ ] Add per-class calibration quality based on sample diversity, not only sample count.
- [ ] Version the feature schema and personalized model metadata so incompatible models can be detected and rebuilt safely.
- [ ] Store model creation date, included classes, sample totals, detector backend, feature version, and evaluation summary.

## P2 — Apple classifier and model fusion

- [ ] Train an Apple Create ML hand-pose classifier from a labeled image subset using the same class definitions and subject-separated evaluation policy as the landmark model.
- [ ] Benchmark the Apple classifier against the HaGRID landmark classifier individually before enabling fusion.
- [ ] Calibrate each model's output probabilities; do not compare or average raw confidence values directly.
- [ ] Add conservative ensemble behavior:
  - Strong agreement permits normal temporal confirmation.
  - One confident model plus one uncertain model requires longer stability and geometric support.
  - Model disagreement resolves to `No gesture`, never to the marginally higher score.
  - Two uncertain predictions resolve to `No gesture`.
- [ ] Add per-class fusion weights only after the validation set demonstrates that they outperform rule-based voting.
- [ ] Use a cascaded inference path where the secondary classifier runs only when the primary model is uncertain, unless profiling shows that continuous dual inference is inexpensive.
- [ ] Display both model predictions, calibrated confidence, disagreement reason, and final fused decision in developer diagnostics.
- [ ] Require the ensemble to reduce false activations by at least 30% relative to the best individual classifier before shipping it as the default.
- [ ] Keep median secondary-model overhead below 20 ms on supported Apple-silicon hardware.

## Stretch goals

- [ ] Prototype Dynamic Time Warping for speed-independent motion-template comparison.
- [ ] Build a separate temporal dataset for swipes, circles, pushes, pulls, and waves.
- [ ] Prototype a dedicated orientation estimator using pose-aware features that retain wrist rotation.
- [ ] Benchmark a MediaPipe detector adapter against Apple Vision for latency, jitter, handedness stability, occlusion recovery, signing footprint, and application size.
- [ ] Add optional model/data export and import for testing between Jarbo installations.
- [ ] Add an optional spatial-sensor provider interface for LiDAR, external depth cameras, stereo cameras, or visionOS hand tracking.
- [ ] Preserve the canonical 21 joints while allowing optional depth, palm transform, wrist transform, forearm transform, and 3D velocity fields.
- [ ] Prototype a visionOS 26-anchor companion only after a measured 21-joint limitation justifies it.

## Explicitly deferred

- A single neural model combining static poses, dynamic movement, and orientation.
- Automatic cloud upload of training data or camera footage.
- Replacing deterministic mouse-button release behavior with learned inference.
- Enabling consequential commands solely from a one-frame prediction.
- Shipping MediaPipe before completing a measured Apple Vision comparison.

## Suggested implementation order

1. Complete the minimal Phase 0 documents, contracts, mock vertical slice, tests, verification command, CI, and risk register.
2. Rehearse a clean checkout and formally close the Phase 0 gate.
3. Add the Core ML readiness checklist and guided training experience.
4. Fix build preflight and SDK compatibility.
5. Add the timing-based gesture state machine, hysteresis, and adaptive filtering.
6. Add the landmark recorder, replay harness, metrics, negative testing, and release gates.
7. Run feature/model experiments behind a feature flag.
8. Prototype dynamic, orientation, or spatial inputs only if the core gates are met.

## Proposed release sequence

### v1.0.9 — Phase 0 closeout, stability, and training experience

#### Required Phase 0 closeout

- [ ] Add `docs/PRODUCT.md` with Jarbo's promise, primary user, three target scenarios, one anti-scenario, MVP non-goals, supported hardware/macOS, initial success metrics, and data-retention defaults.
- [ ] Add minimal typed core contracts for `JarboEvent`, `JarboIntent`, `Capability`, `ActionRequest`, and `ActionResult`.
- [ ] Add a minimal action-execution protocol that separates recognized intent from real macOS automation.
- [ ] Add a mock vertical slice proving `mock gesture → intent → capability check → mock executor → verified result` without controlling the real Mac.
- [ ] Add a Swift test target with foundational pipeline and safety-invariant tests.
- [ ] Test that unknown capabilities are denied, `No gesture` cannot execute an action, cancellation prevents execution, and tracking loss releases held controls.
- [ ] Add a single `./verify.sh` command that checks the environment, runs tests, builds the app, and verifies that the app bundle exists.
- [ ] Add a macOS CI workflow that runs tests and the application build for pushes and pull requests.
- [ ] Add `docs/ARCHITECTURE.md` documenting native Swift/macOS-first development, Apple Vision, the canonical 21-joint boundary, local Core ML, local-first training data, and deterministic contact safety.
- [ ] Add `docs/RISK-REGISTER.md` with the ten principal product/technical risks, owner, likelihood, impact, mitigation, trigger, and status.
- [ ] Rehearse the documented setup and `./verify.sh` process from a clean checkout.
- [ ] Complete a Phase 0 go/no-go review and record the evidence for every exit criterion.

#### Recognition and training improvements

- [ ] Core ML readiness checklist with exact missing sample counts.
- [ ] Guided, diverse sample capture and duplicate-sample warnings.
- [ ] Improved `No gesture` collection guidance.
- [ ] Persistent model-build diagnostics and delete/rebuild controls.
- [ ] Current macOS SDK build compatibility and environment preflight.

#### v1.0.9 application stabilization

- [ ] Complete and maintain `docs/V1.0.9-FEATURE-AUDIT.md` as the release-candidate source of truth for passes, limitations, failures, exclusions, evidence, defects, performance measurements, and the final go/no-go decision.
- [ ] Add a dedicated Jarbo menu-bar status-item icon that is visually distinct from FaceTime, macOS camera/video-effects indicators, and the Dock application icon where appropriate.
- [ ] Supply proper light/dark template artwork and accessible text for the Jarbo menu-bar icon; verify it remains legible at normal menu-bar scale and does not appear as an oversized camera overlay.
- [ ] Preserve the macOS camera privacy indicator while capture is active; do not attempt to suppress or imitate system privacy UI.
- [ ] Add an explicit **Camera On/Off** control to Jarbo's menu-bar menu with an accurate live state label and icon.
- [ ] When Camera Off is selected, stop the capture session, stop frame processing, clear stale hand observations, cancel gesture candidates, release held mouse/keyboard controls, and prevent camera-dependent actions.
- [ ] When Camera On is selected, request permission only when necessary, start one capture session, restore tracking without duplicating observers/tasks, and report startup failure clearly.
- [ ] Persist the user's intended camera setting where safe, while requiring an explicit and visible active-camera state after relaunch; document the chosen launch default.
- [ ] Ensure turning the camera off releases the hardware so macOS can clear its camera-use privacy indication after the operating system updates its status.
- [ ] Make Jarbo behave as a normal macOS application rather than a permanently dominant overlay.
- [ ] Ensure the HUD does not automatically cover or take priority over full-screen applications, Spaces, presentations, games, video playback, or system overlays.
- [ ] Use a normal application window level by default and avoid `floating`, screen-saver, or always-on-top levels unless the user explicitly enables a temporary HUD mode.
- [ ] Ensure showing, hiding, updating, or receiving a gesture does not steal keyboard focus or activate Jarbo over the user's current application unnecessarily.
- [ ] Keep Jarbo available in the Dock, Command-Tab application switcher, and Mission Control/F3 window overview when its window is open.
- [ ] Allow Jarbo to run in the background with the HUD hidden while menu-bar controls and explicitly enabled camera/gesture services continue operating.
- [ ] Define predictable behavior when the HUD is closed versus hidden: closing the window must not silently quit Jarbo, and reopening from Dock, Command-Tab, Mission Control, or the menu bar must restore it.
- [ ] Add a user-controlled HUD visibility/behavior setting if needed: normal window by default, background operation allowed, and any always-on-top behavior explicitly opt-in and visibly indicated.
- [ ] Complete a regression audit of every currently supported feature except voice controls, PDF reading, image reading, and the 3D model viewer.
- [ ] Verify the Actions editor can create, edit, enable, disable, reorder where supported, test, and remove bindings without corrupting configuration.
- [ ] Verify every supported action type uses the correct hand, gesture, target, value, and begin/end lifecycle.
- [ ] Verify pointer movement, left click/drag, right click, middle click, and emergency release behavior.
- [ ] Verify desktop switching, Mission Control, App Exposé, Show Desktop, volume, mute, media playback, track navigation, URL opening, app opening, file opening, web search, notes, shell commands, image generation, and HUD toggling where configured and permitted.
- [ ] Verify action failures report an understandable reason instead of silently doing nothing.
- [ ] Verify Accessibility, Camera, Automation, and other required permission states are detected accurately and recover gracefully after permission changes.
- [ ] Verify all Settings controls persist across ordinary quit/relaunch, including theme, hand roles, action bindings, pointer sensitivity, training samples, notes, and HUD state where intended.
- [ ] Verify reset/restore controls return Jarbo to safe defaults without leaving held buttons or invalid bindings.
- [ ] Verify the Dock, Command-Tab, menu-bar, show/hide HUD, configure controls, pause/resume controls, and quit paths behave consistently.
- [ ] Verify Jarbo appears correctly in Mission Control/F3 and does not force itself above full-screen applications.
- [ ] Verify Jarbo continues intended background operation with the HUD hidden and does not steal focus when gestures or menu state update.
- [ ] Verify the menu-bar camera toggle through at least ten on/off cycles without duplicated capture sessions, stale gestures, stuck controls, runaway CPU, or camera resource leakage.
- [ ] Verify opening configuration pauses action execution, releases held controls, and keeps only the landmark work required for training.
- [ ] Add automated coverage for settings encoding/decoding, migration defaults, action binding lifecycle, invalid action values, cancellation, and control release.
- [ ] Add a manual v1.0.9 smoke-test checklist with expected results and evidence fields for every included feature.

#### Actions-menu performance and code optimization

- [ ] Profile the Actions/settings menu before optimizing and record CPU, memory, UI responsiveness, redraw frequency, configuration writes, and camera/classifier activity.
- [ ] Keep expensive camera classification and gesture-action dispatch paused while the Actions editor is open, while retaining only the fresh landmark snapshots needed for training.
- [ ] Ensure camera frames, landmark updates, model predictions, command logs, and settings changes do not trigger unnecessary full-list or full-window redraws.
- [ ] Move expensive filtering, validation, serialization, model work, and file access away from the main UI thread.
- [ ] Cache derived gesture/action lists and avoid repeated filtering inside SwiftUI view rendering where profiling shows it is material.
- [ ] Use stable row identity and localized state updates so editing one action does not rebuild every action row unnecessarily.
- [ ] Keep configuration persistence debounced and flush pending changes safely during normal termination.
- [ ] Avoid synchronous camera-queue access from the main thread except for bounded training capture with a measured timeout.
- [ ] Check for retained camera buffers, unbounded histories, duplicate observers, runaway tasks, and repeated model loading.
- [ ] Add performance signposts or equivalent measurements around opening Actions, editing a binding, scrolling the list, saving settings, and closing configuration.
- [ ] Establish v1.0.9 performance gates on supported hardware:
  - Actions editor opens and becomes interactive within 500 ms from an already-running HUD.
  - Common setting edits provide visible feedback within 100 ms.
  - Scrolling and editing do not produce sustained UI stalls longer than 100 ms.
  - Opening Actions does not cause sustained CPU usage above the normal active-camera baseline.
  - Memory returns near its pre-editor baseline after the editor closes, with no repeated-growth pattern across ten open/close cycles.
- [ ] Run a 30-minute Actions/settings soak test and ten repeated open/edit/close cycles without a crash, held control, runaway CPU use, or material memory growth.

#### Explicit v1.0.9 functional exclusions

The following features are not required to pass the v1.0.9 closeout gate and must be recorded as known limitations rather than allowed to delay the foundation release:

- Voice controls and speech-command reliability.
- PDF reading and PDF understanding.
- Image reading and visual-content understanding.
- The 3D model viewer and related rendering/content workflows.

These exclusions do not permit the features to crash Jarbo or degrade unrelated functionality. If present in the interface, they must fail safely, remain clearly labeled, or be temporarily disabled for v1.0.9.

### v1.1.0 — Foundation hardening and general recognition model

#### Additional foundation work

- [ ] Expand the initial architecture record into a reusable ADR template and focused ADRs for platform choice, detector boundaries, data retention, model strategy, and safety-critical controls.
- [ ] Expand the risk register into a detailed threat model covering false activation, wrong-target actions, shell commands, Accessibility privileges, training-data exposure, future skills, and update integrity.
- [ ] Introduce explicit package/module boundaries beyond the initial core contracts where they reduce coupling without forcing a full rewrite.
- [ ] Add a developer diagnostics CLI for the mock pipeline, environment health, model metadata, and verification summaries.
- [ ] Add consistent Swift formatting/linting and enforce it in CI.
- [ ] Expand contract, resilience, privacy, performance, and regression tests beyond the minimal Phase 0 suite.
- [ ] Add structured local diagnostics with correlation identifiers and redaction rules.
- [ ] Document contributor setup, architecture decisions, testing conventions, and the release checklist.

#### General recognition model

- [ ] Replace frame-count gesture activation with elapsed-time thresholds and hysteresis.
- [ ] Add adaptive landmark smoothing and measure jitter versus fast-motion latency.
- [ ] Improve left/right-hand identity continuity when hands cross or detector handedness changes.
- [ ] Expanded HaGRID landmark dataset and documented label mappings.
- [ ] General static classifier that works without personal training.
- [ ] Large `No gesture` rejection class.
- [ ] Landmark recording, deterministic replay, and evaluation reports.
- [ ] Per-class thresholds and ambiguity margins.
- [ ] Feature/model schema versioning and metadata.
- [ ] Accuracy, false-activation, latency, and resource release gates.

### v1.1.1 — Conservative model fusion

- [ ] Apple Create ML comparison classifier.
- [ ] Calibrated dual-model voting or cascade.
- [ ] Local personal calibration layered over general recognition.
- [ ] Disagreement-to-unknown safety behavior.
- [ ] Developer diagnostics for both models and the fused decision.
- [ ] Measured ensemble improvement over both individual baselines.

### v1.1.2 and later — Optional spatial inputs

- [ ] Evaluate which remaining failures genuinely require depth or additional joints.
- [ ] Prototype LiDAR for push/pull and 3D orientation.
- [ ] Prototype an optional 26-anchor visionOS provider without changing the required 21-joint core.
- [ ] Add external sensor support only when it passes accuracy, latency, power, and graceful-fallback gates.

## Version numbering policy

- After `v1.0.9`, the next release is `v1.1.0`.
- After `v1.1.0`, continue with patch releases: `v1.1.1`, `v1.1.2`, `v1.1.3`, and so on.
- Increment the minor version to `v1.2.0` only when Jarbo introduces a deliberately scoped feature generation or a compatibility-level milestone—not merely because another build is published.
- Keep every release marked as a GitHub prerelease until Jarbo meets the defined stability, safety, packaging, and beta exit gates.

## Definition of done

- A new user can determine why model training is unavailable without consulting documentation.
- Jarbo identifies the exact missing sample classes and counts.
- A personalized model can be built, deleted, rebuilt, persisted, and reloaded without restarting the application unexpectedly.
- Recognition changes are supported by replayable evaluation results rather than subjective testing alone.
- No regression can leave a mouse button held when tracking is lost, configuration opens, the camera stops, or the application exits.
- The application builds successfully on the documented minimum and current supported macOS development environments.
