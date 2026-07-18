**PRODUCT • ENGINEERING • RESEARCH**

# JARBO

*A Context-Aware Multimodal Desktop Assistant*

**Comprehensive Project Roadmap & Software Design Plan**

> **NORTH STAR** — Reduce the friction between a person and their computer through reliable vision, voice, gesture, context, and safe automation.

Planning horizon: 36 weeks • Version 1.0 • July 2026

# Document Guide

How to use this roadmap

This is a build sequence, not a feature wish list. Each phase has a product outcome, engineering deliverables, measurable exit criteria, and explicit non-goals. Do not advance merely because time has elapsed; advance when the gate is met.

| **Audience** | **Use** |
|----|----|
| Builder / lead | Prioritize the weekly backlog and decide trade-offs. |
| Contributor | Understand interfaces, ownership, and definition of done. |
| Tester | Derive acceptance, performance, safety, and regression tests. |
| Reviewer / mentor | Evaluate progress against evidence rather than demo polish. |

## Planning assumptions

- Primary target is one desktop OS first; cross-platform support comes after the action layer stabilizes.

- One primary developer, with optional contributors. A solo schedule may stretch by 1.5–2×.

- Local-first data handling is preferred. Cloud AI is optional and must be isolated behind provider interfaces.

- Gesture control complements voice, keyboard, and mouse; it does not replace every pointer action.

> **DECISION RULE** — When scope conflicts arise, choose reliability, latency, safety, and clarity over novelty.

# Executive Summary

The recommended course of action

Build Jarbo as an AI interaction layer for the desktop: it observes permitted signals, understands a bounded request, proposes or executes a safe action, and communicates the result. The first compelling product is not a general autonomous agent. It is a dependable multimodal command surface for high-frequency desktop workflows.

## Sequence at a glance

| **Stage** | **Weeks** | **Outcome** | **Release gate** |
|----|----|----|----|
| 0\. Product foundation | 1–2 | Defined user, metrics, architecture, repository | Approved scope and runnable skeleton |
| 1\. Reliable input core | 3–6 | Wake, gesture, voice, event pipeline | Low false activation; measured latency |
| 2\. Desktop MVP | 7–10 | 10–15 safe actions and visible status | Complete demo path with recovery |
| 3\. Skills platform | 11–14 | Typed plugin contracts and permissions | Three independent skills pass contract tests |
| 4\. Context + screen | 15–19 | Active-app and opt-in screen grounding | Grounded answers with provenance |
| 5\. Memory + workflows | 20–24 | Preferences, routines, reversible macros | User can inspect/delete memory |
| 6\. Proactivity beta | 25–29 | Suggestion-only pattern assistance | Precision and annoyance thresholds met |
| 7\. Product hardening | 30–36 | Packaging, observability, docs, beta | Stable installer and release checklist |

## Success definition

- A new user understands Jarbo in 30 seconds.

- The top five workflows succeed repeatedly without developer intervention.

- Every consequential action is permissioned, previewable when appropriate, logged, and recoverable.

- The system can degrade gracefully when camera, network, model, or app integration fails.

# Product Definition

What Jarbo is—and is not

## One-sentence product promise

> **PROMISE** — Jarbo lets you control and understand your computer naturally through voice, gestures, and shared context.

## Primary user and jobs

- A technically comfortable desktop user who switches frequently among browser, editor, media, notes, and communication apps.

- Start a work setup, control media and windows, navigate content, ask about the visible screen, capture a note, and trigger repeatable routines.

- Stay in flow while hands are occupied, during presentations, or when keyboard/mouse interaction is inconvenient.

## Non-goals for the MVP

- Unbounded autonomous browsing or purchasing.

- Always-on surveillance, covert recording, or background screen capture.

- Replacing the operating system, accessibility stack, or full mouse vocabulary.

- Supporting every app and operating system from day one.

- Long-term personality simulation before core behavior is trustworthy.

## Product principles

| **Principle** | **Implication** |
|----|----|
| Reliability is a feature | Prefer ten excellent gestures/actions over fifty inconsistent ones. |
| Local by default | Process camera frames locally; retain no raw frames unless explicitly enabled. |
| Explicit agency | Show listening/seeing/executing state and provide stop/cancel. |
| Least privilege | Skills request only the capabilities needed. |
| Inspectable intelligence | Expose why an action was selected and what context was used. |
| Progressive autonomy | Move from suggest → confirm → auto-execute only with evidence. |

# System Architecture

Reference model

```text
SENSORS / CONTEXT
Camera Microphone Active Window Screen (opt-in) Time
\  | | | /
+--------+-------------+----------------+------------+
EVENT BUS
|
+-------------------+-------------------+
| | |
Gesture Engine Speech Pipeline Context Service
+-------------------+-------------------+
|
INTENT ORCHESTRATOR
classify → validate → plan → authorize → dispatch
|
SKILL REGISTRY + POLICY ENGINE
browser | windows | media | notes | workflows
|
OS / APP ADAPTERS
|
RESULT + AUDIT + USER FEEDBACK
```

## Architectural boundaries

- Perception emits normalized events; it never directly controls the desktop.

- The orchestrator operates on typed intents and validates parameters before dispatch.

- The policy engine decides whether an action is denied, allowed, or requires confirmation.

- Skills contain domain behavior; OS adapters contain platform-specific calls.

- The UI is a state observer and control surface, not the location of business logic.

## Core event contract

```text
Event {
id, timestamp, source, type, confidence, payload, session_id
}
Intent { name, parameters, evidence[], confidence, requested_capabilities[] }
ActionResult { status, output, side_effects[], undo_token?, error? }
```

# Runtime Flows

How requests become safe actions

## Deterministic command path

```text
wake detected → capture command → parse intent → schema validate
→ policy check → [confirm if needed] → execute skill
→ verify postcondition → respond → append audit event
```

## Multimodal grounding path

```text
point / gaze region + utterance + active-window metadata
↓ temporal alignment / session binding
↓ screen crop or accessibility-tree lookup (opt-in)
↓ grounded intent with evidence references
↓ answer OR proposed action
```

## Failure path

```text
low confidence / missing permission / adapter failure
↓
stop execution → preserve state → concise explanation
↓
offer retry, alternate input, settings, or safe manual step
```

## State machine

| **State**     | **Entry**                   | **Allowed transitions**      |
|---------------|-----------------------------|------------------------------|
| SLEEPING      | Default / privacy pause     | ARMED                        |
| ARMED         | Wake gesture or wake phrase | LISTENING, SLEEPING          |
| LISTENING     | Audio capture started       | UNDERSTANDING, CANCELLED     |
| UNDERSTANDING | Input finalized             | CONFIRMING, EXECUTING, ERROR |
| CONFIRMING    | Risk/ambiguity threshold    | EXECUTING, CANCELLED         |
| EXECUTING     | Authorized action           | DONE, ERROR, CANCELLED       |
| DONE / ERROR  | Result available            | ARMED, SLEEPING              |

# Repository & Folder Structure

A modular monorepo layout

```text
jarbo/
├── apps/
│ ├── desktop-ui/ # tray, overlay, settings
│ └── cli/ # diagnostics and developer control
├── packages/
│ ├── core/ # events, state machine, orchestration
│ ├── perception/ # gesture, speech, screen/context
│ ├── policy/ # permissions, confirmation, risk
│ ├── skills-sdk/ # manifests, schemas, base interfaces
│ ├── skills/ # first-party skills
│ ├── platform/ # macOS/Windows/Linux adapters
│ ├── memory/ # preferences, episodes, retrieval
│ ├── observability/ # logs, metrics, traces, replay
│ └── shared/ # config, types, utilities
├── models/ # manifests; large weights excluded
├── tests/
│ ├── unit/ integration/ contract/ e2e/ performance/ safety/
├── datasets/ # consented metadata and dataset cards
├── tools/ # profiling, labeling, release scripts
├── docs/ # ADRs, threat model, skill authoring
└── .github/workflows/
```

## Repository rules

- No platform API calls outside packages/platform.

- No model/provider calls outside defined provider adapters.

- No skill may bypass policy or write directly to the audit log.

- Large models, recordings, secrets, and user data are never committed.

- Every package owns a README, public API, tests, and an owner/reviewer field.

# Recommended Technology Stack

Choose boring interfaces around fast-moving AI components

| **Layer** | **Primary choice** | **Why / alternative** |
|----|----|----|
| Core runtime | Python 3.12 + asyncio + Pydantic | Excellent CV/AI ecosystem and typed schemas; Rust later for hot paths. |
| Desktop UI | Tauri + TypeScript/React | Small native shell; PySide6 is simpler for a Python-only prototype. |
| Vision | OpenCV + MediaPipe; ONNX Runtime | Fast landmarks and portable local inference. |
| Speech-to-text | faster-whisper / whisper.cpp | Local, streaming-capable; cloud adapter optional. |
| Text-to-speech | Piper or OS-native TTS | Low-latency local output; provider-neutral interface. |
| Intent | Rules + structured LLM fallback | Deterministic common path; LLM only for ambiguity/composition. |
| Storage | SQLite + SQLModel; encrypted secrets in OS keychain | Inspectable local persistence; migrations from day one. |
| IPC / events | In-process asyncio first; typed WebSocket/JSON-RPC to UI | Avoid premature distributed infrastructure. |
| Testing | pytest, Hypothesis, Playwright, golden event replays | Covers schemas, invariants, UI, and perception regressions. |
| Packaging | uv/lockfile + platform installers + signed artifacts | Reproducible builds and clear release path. |
| Telemetry | OpenTelemetry-style local traces; opt-in export | Debuggable without silent data collection. |

> **AVOID LOCK-IN** — Wrap every model and cloud service behind a narrow provider protocol. Pin versions and keep a small reference dataset for upgrade evaluation.

# Phase 0 — Product & Engineering Foundation

Weeks 1–2

## Outcome

A sharply scoped product, reproducible development environment, documented decisions, and a runnable vertical skeleton from mock event to mock action.

## Milestones

- Write three target scenarios and one anti-scenario.

- Select the first OS and define hardware assumptions.

- Create the repository, package boundaries, dependency lock, formatting, linting, tests, and CI.

- Define Event, Intent, Capability, ActionRequest, ActionResult, and AuditEvent schemas.

- Create an architectural decision record (ADR) template and threat-model worksheet.

- Build a fake skill and CLI command that traverses the full pipeline.

## Exit criteria

- Fresh clone → one documented setup command → tests pass.

- A mock “play media” event reaches a mock adapter and returns a verified result.

- Success metrics and data-retention defaults are written and reviewed.

- Top ten technical/product risks have owners and mitigations.

## Rationale

Early schemas and boundaries reduce the cost of changing models, UI frameworks, and operating systems later. The vertical skeleton exposes integration friction before perception work creates a false sense of progress.

# Phase 1 — Reliable Multimodal Input

Weeks 3–6

## Scope

- Camera discovery, frame lifecycle, privacy indicator, FPS/latency counters.

- Hand landmarks, smoothing, handedness, orientation, static gesture classification.

- Wake/sleep gestures with hold time, cooldown, debounce, and confidence thresholds.

- Push-to-talk voice path first; wake phrase may follow after privacy and false-trigger testing.

- Event bus, temporal session binding, cancellation, and deterministic replay.

## Gesture vocabulary v0

| **Gesture** | **Meaning** | **Design note** |
|----|----|----|
| Open palm hold | Wake / arm | Distinct, deliberate, 500–800 ms hold. |
| Closed fist hold | Sleep / pause | Never overloaded with destructive action. |
| Pinch | Confirm / select | Requires stable cursor or explicit target. |
| Swipe left/right | Previous / next | Velocity + displacement + cooldown. |
| Two-finger vertical | Scroll mode | Mode indicator always visible. |
| Flat palm stop | Cancel current operation | Global, highest-priority interrupt. |

## Performance gates

- Median landmark-to-event latency \<100 ms on target hardware; p95 \<160 ms.

- False wake \<1 per hour in representative negative footage; cancel recognized \>95% in test set.

- No raw camera retention by default; camera release verified on pause/exit.

- Gesture tests cover lighting, distance, background, handedness, partial occlusion, and non-hand motion.

# Phase 1 — Implementation Steps

Build the input core in measured increments

1.  Create a camera abstraction returning timestamped frames and health status.

2.  Add landmark detection and an overlay available only in developer mode.

3.  Normalize landmarks by wrist position, palm scale, rotation, and handedness.

4.  Implement rule-based classifiers for 3–5 gestures before training a custom model.

5.  Add temporal buffers, hysteresis, hold duration, cooldown, and state-aware filtering.

6.  Record consented landmark sequences—not raw video where avoidable—with labels and environment metadata.

7.  Add streaming speech transcription behind the same event contract.

8.  Build a replay harness that feeds stored events into the orchestrator deterministically.

9.  Profile CPU/GPU, thermal behavior, memory, and end-to-end latency.

## Definition of done

> **GATE** — Jarbo can sleep, wake, accept a push-to-talk command, recognize cancel, and show its state for a 30-minute session without accidental action or resource leakage.

# Phase 2 — Desktop MVP

Weeks 7–10

## User outcome

A user can demonstrate a complete, dependable “start work and control the desktop” story without touching internal developer tools.

## Action set (prioritized)

| **Priority** | **Actions** |
|----|----|
| P0 | Open app; focus app; volume; play/pause; next/previous; scroll; cancel; show status. |
| P1 | Window snap/move; switch workspace; open URL; clipboard read with permission; create note; timer. |
| P2 | Brightness; file search; browser tab control; presentation next/previous. |

## Safety classes

| **Class** | **Examples** | **Default policy** |
|----|----|----|
| A — Read-only | Read active app, time, media state | Allow while session is armed. |
| B — Reversible | Volume, focus window, pause media | Allow; record result and undo where possible. |
| C — Consequential | Close app, type text, send message | Preview/confirm; verify target. |
| D — Sensitive | Credentials, purchases, delete, external publish | Deny in MVP or require explicit hardened flow. |

## MVP demo script

- Open palm wakes Jarbo and the overlay changes state.

- “Start coding setup” opens editor, terminal, browser, and music through a workflow skill.

- Swipe changes track; two-finger mode scrolls documentation.

- “Take a note: investigate caching” writes locally and confirms the location.

- Stop gesture cancels an in-progress action immediately.

# Phase 2 — Acceptance & UX

Make state and recovery obvious

## Overlay states

- Sleeping: minimal privacy-safe indicator.

- Armed: camera/mic availability and wake readiness.

- Listening: live but non-sensitive transcript preview.

- Understanding: brief progress state with cancel affordance.

- Confirming: action, target, side effects, and confirm/cancel.

- Executing: current step and timeout.

- Done/error: result, recovery, and optional undo.

## Acceptance checklist

- Every action has a stable intent schema and postcondition.

- App/window targeting uses identifiers, not only titles or screen coordinates.

- Timeouts and adapter exceptions produce user-readable recovery.

- Global cancel preempts queued actions.

- No high-risk action can be triggered by gesture confidence alone.

- A clean install completes the demo script three times consecutively.

## Metrics dashboard

| **Metric** | **Target** |
|----|----|
| Command success rate (top 10) | ≥95% in controlled acceptance suite |
| Median wake-to-feedback | \<250 ms |
| Median deterministic action completion | \<1.0 s, excluding app launch |
| Unrecoverable crash rate | 0 in 2-hour soak test |
| Cancel acknowledgement | \<200 ms |
| User-visible ambiguous failures | \<5% of test commands |

# Phase 3 — Skills Platform

Weeks 11–14

## Skill contract

```text
SkillManifest
id, version, description, intents[], capabilities[], platforms[]
Skill
can_handle(intent, context) -> score
validate(intent) -> ValidatedRequest
execute(request, adapter) -> ActionResult
undo(token) -> ActionResult (optional)
health() -> HealthStatus
```

## Required platform services

- Registry and semantic version checks.

- Capability declaration and policy evaluation.

- Schema validation and parameter coercion.

- Timeout, retry, idempotency, and cancellation rules.

- Structured logs and per-skill health status.

- Mock adapter kit, fixtures, contract-test runner, and authoring guide.

## Reference skills

- Media: play, pause, skip, volume, current track.

- Windows: open, focus, move, resize, workspace navigation.

- Notes: append, search, tag, and open a local note.

- Workflow: compose permitted skills with step-level confirmation and rollback hints.

## Exit gate

> **GATE** — A contributor can add a fourth skill without editing core orchestration, and all first-party skills pass the same contract, permission, timeout, cancellation, and failure tests.

# Phase 4 — Context & Screen Understanding

Weeks 15–19

## Context ladder

| **Level** | **Signal** | **Privacy / reliability** |
|----|----|----|
| 0 | Time, OS, Jarbo state | Low sensitivity; always available. |
| 1 | Active app/process and window ID | Local metadata; permission documented. |
| 2 | Accessibility tree / browser DOM via integration | Structured and more reliable than pixels. |
| 3 | User-selected screen region or screenshot | Explicit capture with visible indicator. |
| 4 | Continuous screen understanding | Defer; high privacy, cost, and error risk. |

## Implementation order

- Create ContextSnapshot with source, timestamp, scope, and expiry.

- Add active-app and window metadata adapters.

- Prefer accessibility APIs and structured browser data over OCR.

- Implement explicit “look at this” capture with selection boundary and preview.

- Attach evidence references to grounded answers and actions.

- Expire visual context quickly; never silently retain screenshots.

- Evaluate OCR/vision model on a labeled set of code, browser, PDF, dialog, and presentation screens.

## Grounded scenarios

- “What does this error mean?” uses selected terminal text and active project metadata.

- Point + “open this” resolves a bounded visible element, previews the target, then activates it.

- “Summarize this page” uses DOM/accessibility content when possible; image understanding is fallback.

# Phase 5 — Memory & Workflows

Weeks 20–24

## Memory model

| **Type** | **Examples** | **Retention / control** |
|----|----|----|
| Session | Current command, selected object, temporary screen crop | Minutes; cleared on session end. |
| Preference | Preferred browser, music volume, confirmation level | Until edited; visible settings. |
| Workflow | Coding setup, study setup, presentation sequence | User-created/versioned; previewable. |
| Episode | A completed interaction and result | Short retention; opt-in and deletable. |
| Semantic | Stable project/app relationships | Derived cautiously; source and confidence stored. |

## Rules

- Memory is data, not hidden prompt text. Store typed records with provenance, confidence, timestamps, and retention class.

- Do not infer sensitive traits. Do not store secrets, raw audio, or screenshots as memory.

- Provide view, edit, export, delete, and “forget this” controls.

- Separate retrieval from authorization: remembered context never grants a capability.

- Workflows are declarative steps with preconditions, postconditions, timeout, stop-on-error, and optional undo.

## Exit gate

- User creates “start coding” through UI or conversation and previews every step.

- Workflow runs idempotently and handles an already-open app.

- All stored memory is discoverable and deletable.

- A clean profile and an existing profile produce predictable tests.

# Phase 6 — Proactivity Beta

Weeks 25–29

## Progressive autonomy ladder

| **Level** | **Behavior** | **Release condition** |
|----|----|----|
| 0 | Respond only | Default through MVP. |
| 1 | Suggest with dismiss | High precision and low interruption cost. |
| 2 | Suggest and prepare preview | Stable target/context; no side effects. |
| 3 | Execute reversible routine | Explicit user rule, quiet hours, and undo. |
| 4 | Consequential autonomy | Out of roadmap; requires separate governance. |

## Candidate signals

- Repeated app sequence at a similar time or project context.

- Long uninterrupted work session with user-configured break policy.

- Known presentation app enters full screen.

- A user-authored trigger such as “when headphones connect, offer focus mode.”

## Anti-annoyance controls

- Global proactive-off switch and per-suggestion category controls.

- Quiet hours, cooldowns, daily caps, confidence thresholds, and dismiss learning.

- Never interrupt during calls, presentations, typing bursts, or do-not-disturb.

- Measure suggestion precision, acceptance, dismiss, disable, and regret/undo rates.

> **LAUNCH STANDARD** — Do not ship proactive execution because a model predicts a habit. Ship suggestions first; promote only user-authored, reversible rules with strong evidence.

# Phase 7 — Product Hardening & Beta

Weeks 30–36

## Engineering deliverables

- Installer/uninstaller, first-run permission flow, hardware check, and model download strategy.

- Signed binaries, reproducible builds, dependency/SBOM review, secrets scanning, and update channel.

- Crash recovery, safe mode, configuration migration, database backup/restore, and data reset.

- Local diagnostics bundle with redaction and explicit user review before sharing.

- Accessibility: keyboard-only settings, captions, contrast, scalable text, and no gesture-only critical action.

- Beta documentation: quick start, privacy, troubleshooting, supported actions, skill guide, and known limits.

## Beta gates

| **Area** | **Gate** |
|----|----|
| Reliability | 20-hour soak; no critical leak/crash; recovery verified. |
| Performance | Targets met on minimum and recommended hardware. |
| Security | Threat model reviewed; dependency and permission audit complete. |
| Privacy | Retention and consent behavior verified by tests. |
| Usability | Five external testers complete core scenario unaided. |
| Operations | Rollback, update, issue intake, and release checklist rehearsed. |

# 36-Week Delivery Calendar

Weekly goals and evidence

| **Week** | **Goal** | **Evidence** |
|----|----|----|
| 1 | Product charter, target OS, scenarios | Signed scope and non-goals |
| 2 | Repo, CI, typed skeleton | Green pipeline; mock vertical slice |
| 3 | Camera lifecycle and privacy state | Start/pause/exit tests |
| 4 | Landmarks and normalization | Latency profile; overlay |
| 5 | Gesture temporal engine | Replay suite; confusion matrix |
| 6 | Voice + multimodal sessions | 30-minute stability gate |
| 7 | Platform adapter and policy core | Capability tests |
| 8 | First five actions | Postcondition checks |
| 9 | Second five actions + overlay | End-to-end acceptance |
| 10 | MVP demo hardening | Three clean demo runs |
| 11 | Skill manifest + registry | Schema/registry tests |
| 12 | Contract and mock kits | Contributor example |
| 13 | Workflow skill | Failure/undo tests |
| 14 | SDK docs and skill gate | Independent fourth skill |
| 15 | Context snapshot and active app | Expiry/source tests |
| 16 | Accessibility/DOM adapter | Structured grounding eval |
| 17 | Selected-region capture | Consent/retention tests |
| 18 | Grounded Q&A | Evidence-linked benchmark |
| 19 | Context polish and red team | Adversarial results |
| 20 | Memory schema + controls | CRUD/export/delete tests |
| 21 | Preferences and retrieval | Deterministic personalization |
| 22 | Declarative workflow editor | Preview/version tests |
| 23 | Idempotency and recovery | Fault injection results |
| 24 | Memory/workflow gate | External scenario test |
| 25 | Suggestion engine offline | Precision evaluation |
| 26 | Quiet hours/caps/dismiss | Interruption policy tests |
| 27 | Suggestion-only beta | Telemetry review |
| 28 | User-authored triggers | Undo and disable tests |
| 29 | Proactivity gate | Go/no-go review |
| 30 | Installer and onboarding | Clean-machine test |
| 31 | Safe mode and migrations | Upgrade/rollback test |
| 32 | Performance and soak | Hardware matrix report |
| 33 | Security/privacy review | Threat model closure |
| 34 | Docs/accessibility | Audit checklist |
| 35 | External beta rehearsal | Five tester report |
| 36 | Release candidate | Signed artifacts and notes |

# Backlog & Feature Checklists

A practical definition of “built”

## Perception

- [ ] Camera/mic health and permission status

- [ ] Wake/sleep/cancel

- [ ] Static and dynamic gesture tests

- [ ] Lighting and occlusion evaluation

- [ ] Voice streaming, endpointing, and cancellation

- [ ] Timestamped multimodal session binding

- [ ] Privacy indicator and resource release

## Core and skills

- [ ] Typed schemas and versioning

- [ ] Policy check before dispatch

- [ ] Timeouts, retries, idempotency

- [ ] Cancellation propagation

- [ ] Postcondition verification

- [ ] Undo token where feasible

- [ ] Skill health and contract tests

## User experience

- [ ] Visible state at all times

- [ ] Transcript/action preview

- [ ] Confirm/cancel controls

- [ ] Error recovery without stack traces

- [ ] Onboarding and calibration

- [ ] Keyboard/mouse fallback

- [ ] Settings, diagnostics, reset

## Release

- [ ] Locked dependencies and SBOM

- [ ] Signed installer/update

- [ ] Migration and rollback

- [ ] Privacy and security review

- [ ] Performance/soak report

- [ ] Known limitations and support path

# Testing Strategy

Test the whole interaction, not only individual models

| **Layer** | **What to test** | **Tools / artifacts** |
|----|----|----|
| Unit | Schemas, classifiers, policies, reducers, utilities | pytest, Hypothesis, deterministic seeds |
| Contract | Every skill/adapter meets protocol | Shared fixtures and mock OS |
| Integration | Event → intent → policy → skill → result | Recorded event streams; temporary DB |
| Perception | Accuracy across people/environments | Versioned landmarks/audio; dataset cards |
| End-to-end | Real app/window flows | Isolated test account and UI automation |
| Performance | Latency, FPS, CPU/GPU, thermal, memory | Benchmarks on hardware matrix |
| Resilience | Timeout, missing app, model crash, device loss | Fault injection and soak runs |
| Safety/privacy | Permission bypass, retention, prompt injection | Abuse cases and red-team corpus |
| Usability | Discoverability, errors, interruption cost | Task observation and short interviews |

## Golden replay suite

Store normalized, consented events and expected intents/results. Re-run them on every classifier, prompt, model, or policy change. Golden tests should detect both correctness regressions and latency drift.

## Model evaluation

- Freeze a representative validation set before tuning thresholds.

- Report precision/recall per gesture and a confusion matrix, not only aggregate accuracy.

- Evaluate “none of the above” negative data aggressively.

- Track results by lighting, distance, handedness, device, skin tone, motion, and occlusion where ethically and practically possible.

# Safety, Privacy & Security

Trust is part of the architecture

## Threats to design for

- Prompt or screen injection attempts to trigger skills.

- Malicious skill requesting excessive capabilities.

- Accidental action against the wrong app/window/contact.

- Secret leakage through logs, screenshots, clipboard, or model providers.

- Replay or spoofed gesture/voice input.

- Supply-chain compromise and unsigned updates.

- Over-retention of sensitive context or derived memory.

## Controls

| **Control** | **Implementation** |
|----|----|
| Capability sandbox | Manifest-declared permissions; deny unknown capabilities. |
| Target binding | Use stable process/window/document identifiers and re-check before execution. |
| Confirmation policy | Risk-based preview with explicit target and side effects. |
| Data minimization | Prefer landmarks/structured text; short TTL; redact logs. |
| Provider boundary | Per-provider consent, payload preview, and no implicit cloud fallback. |
| Audit trail | Append-only local action events; user-readable history and clear/delete. |
| Emergency stop | Global gesture/button/hotkey cancels and releases devices. |
| Update trust | Signed artifacts, pinned dependencies, rollback channel. |

## Privacy defaults

> **DEFAULT** — Camera frames remain in memory only; microphone activates only in visible listening state; screen capture is selection-based; telemetry export is off; history has a short retention window.

# Observability & Evaluation

Know why it failed

## Trace shape

```text
session_id
├─ perception span: device → event (latency, confidence)
├─ intent span: evidence → parsed schema (model/rule version)
├─ policy span: capabilities → decision (reason)
├─ action span: adapter call → postcondition (side effects)
└─ response span: result → user feedback
```

## Key metrics

- Reliability: task success, false activation, ambiguous intent, adapter/postcondition failure.

- Latency: sensor-to-event, utterance-to-intent, policy time, action duration, time-to-feedback.

- Safety: confirmation rate, denied actions, wrong-target near misses, undo/regret.

- Product: successful sessions, repeat workflows, onboarding completion, suggestion acceptance/dismiss/disable.

- Resource: idle/active CPU, memory, GPU, thermal throttling, battery impact.

## Logging rules

- Structured events, monotonic timestamps, stable error codes, correlation IDs.

- Redact transcripts, paths, clipboard, screen text, and tokens by default.

- Developer mode is time-limited and visibly enabled.

- Diagnostics export shows exactly what will leave the machine.

# Deployment & Release Plan

From developer build to trustworthy beta

## Environments

| **Channel** | **Purpose** | **Data / stability** |
|----|----|----|
| Dev | Fast iteration and debug overlays | Synthetic/test profiles; assertions on. |
| Canary | Builder’s daily use | Migration rehearsal; verbose local traces. |
| Alpha | Trusted technical testers | Feature flags; manual updates; rapid rollback. |
| Beta | Broader invited users | Signed installer; stable migrations; support intake. |
| Stable | Future | Only after beta metrics and security gate. |

## Release pipeline

10. Lint, type check, unit, contract, integration, safety, and replay tests.

11. Build locked artifacts on clean runners.

12. Generate dependency inventory/SBOM and scan licenses/vulnerabilities.

13. Sign/notarize platform packages and publish checksums.

14. Run clean-install, upgrade, downgrade/rollback, and uninstall tests.

15. Stage rollout with feature flags and a kill switch for risky providers/skills.

16. Publish release notes, known limitations, data migrations, and support instructions.

## Model assets

Version model manifests separately from application code. Verify hashes, license, size, hardware requirements, and evaluation results. Downloads must be resumable, optional when possible, and removable from settings.

# Risk Register

Review at the end of every phase

| **Risk** | **Likelihood / impact** | **Mitigation / trigger** |
|----|----|----|
| False activations erode trust | High / High | Deliberate wake, cooldown, negative dataset; halt release if target missed. |
| Gesture performance varies by environment | High / High | Calibration, confidence bands, fallback input, hardware matrix. |
| OS automation is brittle | High / High | Stable APIs/IDs, adapter contracts, postcondition verification. |
| LLM chooses unsafe/wrong action | Medium / High | Structured output, allowlist, policy engine, confirmation, no direct tool access. |
| Privacy perception blocks adoption | Medium / High | Visible indicators, local defaults, short retention, inspect/delete. |
| Scope expands faster than quality | High / Medium | Phase gates, non-goals, top-ten workflows, backlog quarantine. |
| Cross-platform cost doubles | High / Medium | One OS first, strict adapter boundary, shared contract tests. |
| Cloud/provider churn | Medium / Medium | Provider interfaces, pinned versions, reference eval suite. |
| Solo-developer burnout | Medium / High | Weekly demo, small slices, automated QA, explicit cut list. |
| Third-party skill abuse | Future / High | Signed packages, review, sandbox, capability prompts; defer marketplace. |

# Decision Framework & Governance

Keep the roadmap coherent

## Feature scoring

| **Dimension** | **Question** | **Weight** |
|----|----|----|
| User friction | How often and how much effort does it remove? | 30% |
| Reliability | Can it meet a measurable success threshold? | 20% |
| Safety/privacy | Can risks be bounded and explained? | 20% |
| Strategic fit | Does it strengthen multimodal desktop interaction? | 15% |
| Engineering leverage | Does it improve reusable platform capability? | 10% |
| Demo appeal | Does it communicate the vision quickly? | 5% |

## Definition of ready

- User story and non-goal are clear.

- Input evidence, intent schema, capability, and adapter are identified.

- Risk class and confirmation policy are assigned.

- Acceptance metric and test fixture exist.

- Dependencies and rollback/fallback are known.

## Definition of done

- Code reviewed, typed, documented, and tested.

- Performance budget and privacy behavior are verified.

- Failure, cancel, timeout, and recovery paths work.

- Metrics/trace make diagnosis possible.

- User-facing help and known limitation are updated.

## Architecture decisions

Record major choices as ADRs: context, decision, options, outcome, consequences, revisit trigger. Examples: first OS; UI shell; IPC; local speech engine; gesture classifier; storage encryption; provider strategy.

# Research Roadmap

Advanced ideas after the product core is stable

| **Theme** | **Question** | **Prototype / metric** |
|----|----|----|
| Multimodal reference | Can pointing + speech reliably bind to an on-screen object? | Timed alignment study; target-selection accuracy. |
| Personalized gestures | Can few-shot calibration reduce errors without overfitting? | Per-user adapter; cross-session precision. |
| Accessibility trees + vision | When should structured UI data beat pixels? | Router benchmark by app class. |
| On-device language models | Can a small local model route intents within latency/power budgets? | Schema accuracy, p95 latency, watts. |
| Continual learning | How can preferences adapt without unsafe hidden behavior? | User-visible hypotheses and reversible updates. |
| Uncertainty communication | Which UI makes ambiguity easy to resolve? | Task time, wrong-action, cancellation. |
| Workflow induction | Can repeated actions become suggested declarative macros? | Precision, acceptance, edit distance. |
| Privacy-preserving analytics | Can quality improve without exporting raw data? | Local aggregation / opt-in metrics. |
| Spatial input | Would depth cameras improve intentional pointing? | False target rate versus RGB baseline. |
| Embodied companion | What hardware adds real value beyond a desktop app? | Prototype only after validated use cases. |

## Research discipline

- Write a hypothesis and falsification criterion before building.

- Use offline prototypes and small studies before product integration.

- Never let research code bypass production policy or retention rules.

- Publish dataset/model cards and negative results where appropriate.

# Demo & Portfolio Strategy

Show a system, not a montage

## Three-minute narrative

- Problem (20s): desktop interaction fragments attention and requires manual context transfer.

- Wake and control (30s): deliberate gesture, visible state, fast media/window action.

- Shared context (50s): selected screen region + natural question + evidence-grounded answer.

- Workflow (45s): “start coding” executes a previewed, reversible sequence.

- Trust (25s): stop gesture, permissions, history, delete memory.

- Architecture (30s): concise pipeline, metrics, and what was measured.

- Close (20s): Jarbo is an interaction layer, not a chatbot wrapper.

## Portfolio artifacts

- One polished video with uncut reliability segments.

- Architecture diagram, threat model, ADRs, and skill SDK example.

- Benchmark report with latency, confusion matrix, and hardware.

- Privacy statement and explicit limitations.

- Issue roadmap showing phase gates and completed evidence.

> **CREDIBILITY** — Demonstrate recovery and cancellation on camera. A trustworthy failure path is more impressive than a hidden perfect take.

# First 30 Days

Immediate action plan

| **Week** | **Build** | **Measure / decide** |
|----|----|----|
| 1 | Charter, first OS, repo, CI, schemas, mock vertical slice | Approve top five workflows and non-goals. |
| 2 | Camera lifecycle, state overlay, landmark pipeline | Baseline FPS, latency, CPU, privacy behavior. |
| 3 | Wake/sleep/cancel with temporal filtering and replay | Confusion matrix and negative false-wake run. |
| 4 | Push-to-talk voice, one safe action, end-to-end trace | Complete first real vertical slice and demo three times. |

## Day-one backlog

- Create PRODUCT.md with promise, primary user, five scenarios, non-goals, and metrics.

- Create architecture ADR-0001 and threat-model skeleton.

- Scaffold packages/core, perception, policy, skills-sdk, platform, UI, and tests.

- Implement typed event/intent/result contracts and a fake action.

- Add CI and a single command for setup/test/run.

- Create benchmark harness before optimizing the gesture model.

## Cut list if behind

- Defer wake phrase; retain push-to-talk.

- Defer trained custom gestures; use landmark rules.

- Defer cross-platform; keep adapter interface.

- Defer cloud LLM; use fixed intents and structured rules.

- Defer proactive assistance, face recognition, and hardware.

# Appendix A — Core Interface Sketches

Illustrative pseudocode

```text
class PolicyEngine:
def authorize(self, request, context) -> Decision:
# DENY | CONFIRM | ALLOW
+class Skill(Protocol):
manifest: SkillManifest
async def execute(self, request, ctx, cancel) -> ActionResult: ...
+async def handle(event):
intent = await router.resolve(event, context.snapshot())
request = registry.validate(intent)
decision = policy.authorize(request, context.snapshot())
if decision.requires_confirmation:
await ui.confirm(decision.preview)
result = await registry.execute(request, cancel_token)
verified = await verifier.check(result.postconditions)
audit.append(event, intent, decision, verified)
```

## Configuration layers

- Hard safety policy: shipped and signed; cannot be weakened by a skill.

- User policy: confirmation preferences within safe bounds.

- Environment: devices, model paths, feature flags.

- Skill configuration: provider/account, bounded to declared capability.

- Session overrides: temporary and visibly active.

# Appendix B — Sample Acceptance Scenarios

Given / when / then

## Wake without action

Given Jarbo is sleeping and a person performs unrelated hand motion, when confidence briefly crosses the gesture threshold but hold duration is not met, then Jarbo remains sleeping and no intent is emitted.

## Wrong target prevention

Given two browser windows are open and the active window changes after confirmation, when Jarbo is about to type into the original target, then target re-validation fails and Jarbo asks the user to confirm again.

## Cancel propagation

Given a workflow is opening multiple apps, when the global stop gesture is recognized, then the current cancellable step stops, future steps do not start, devices remain usable, and Jarbo reports completed side effects.

## Cloud boundary

Given local intent routing is unavailable and cloud fallback is disabled, when a complex command arrives, then Jarbo explains the limitation and does not send text, audio, or screen data externally.

## Memory deletion

Given a saved preference and workflow history exist, when the user selects “forget this” and confirms, then the record and derived index are removed and subsequent retrieval tests return no reference.

# Appendix C — Phase Review Template

Use at every go/no-go gate

| **Review item** | **Evidence / decision** |
|----|----|
| Outcome delivered | What can a user now do reliably? |
| Metrics | Targets, measured values, hardware, dataset version. |
| Reliability defects | Open severity 1–2 issues and workarounds. |
| Safety/privacy | New data, capabilities, threats, and mitigations. |
| Architecture | ADRs added; debt accepted; interfaces changed. |
| User feedback | What surprised, confused, delighted, or annoyed testers? |
| Scope changes | What moved, why, and what is explicitly cut? |
| Go / hold / revise | Decision, owner, and next review date. |

## Final recommendation

> **BUILD ORDER** — Foundation → reliable input → safe desktop actions → skills → bounded context → inspectable memory → suggestion-only proactivity → product hardening. Keep hardware and broad autonomy as research until software usage proves the need.
