# ALPHA Jarbo 1.0.9 Product Definition

Status: release-candidate scope

Platform: native macOS 14 or later

Release channel: alpha prerelease

## Promise

Jarbo is a local-first macOS gesture control surface that turns deliberate hand input into visible, configurable desktop actions while keeping camera use, permissions, and held-input release under the user's control.

Jarbo is not presented as a general autonomous agent in 1.0.9. The release concentrates on a dependable gesture-to-action loop, understandable personalized training, and predictable macOS application behavior.

## Primary user

The primary user is a technically comfortable Mac user who frequently switches among workspaces, media, browser, editor, and notes, and who wants an optional hands-free command surface without giving up the keyboard, trackpad, or ordinary macOS controls.

## Target scenarios

### 1. Point, click, and drag

The user explicitly turns the camera on, assigns one hand the pointer role, moves the pointer with relative clutch-style motion, and uses deterministic thumb-to-finger contact to begin, hold, and release mouse buttons. Tracking loss, Camera Off, configuration, and quit must release held controls.

### 2. Perform a bounded Mac action

The user assigns a deliberate gesture to an included action such as changing Space, opening Mission Control, controlling Spotify, opening a validated URL, or showing/hiding Jarbo. Jarbo shows the detected hand/gesture and reports a blocked or failed action rather than silently pretending it succeeded.

### 3. Teach a personalized static gesture

The user captures ten varied `No gesture / other` examples and ten samples for at least two eligible static classes. Jarbo explains exact readiness, requires a fresh complete 21-joint pose, warns about near-duplicate captures, builds a local Core ML model, and lets the user delete or rebuild that model.

## Anti-scenario

Jarbo must not convert a brief, ambiguous, stale, incomplete, or unrelated hand observation into a consequential desktop action. It must not hide camera use, retain raw camera frames by default, or rely on a cloud model to decide frame-level mouse-button state.

## MVP non-goals for 1.0.9

- Unbounded autonomous browsing, purchasing, messaging, or publishing.
- Always-on surveillance, covert capture, or automatic upload of camera footage or training data.
- Replacing all keyboard, trackpad, mouse, or macOS Accessibility interaction.
- General cross-platform support; macOS is the only supported operating system.
- A single learned model for static poses, dynamic motion, orientation, and safety-critical finger contact.
- Shipping MediaPipe, LiDAR, depth-camera, or visionOS tracking before comparative evaluation.
- Cloud/GPT inference in the real-time pointer, click, or release loop.
- Voice-command reliability, PDF understanding, image understanding, or the 3D model viewer as release-gate features.

## Supported environment

The declared build target is macOS 14 or later. The build produces a universal `arm64`/`x86_64` application and therefore intends to support Apple-silicon and Intel Macs that can run macOS 14. A compatible webcam is required for hand control. Xcode or its selected command-line developer tools, a Swift 6-capable toolchain, and a current macOS SDK are required to build from source.

This is an alpha support declaration, not a completed hardware matrix. Minimum-hardware, current-hardware, external-camera, multi-display, and clean-machine results remain pending in the v1.0.9 audit.

## Launch and application behavior

- Camera capture defaults to **Off** for a new or migrated profile without a saved camera preference.
- Jarbo persists the user's intended camera setting. On relaunch it starts capture only when that saved intent is enabled; the live menu label remains the authority for actual starting, on, stopping, denied, or unavailable state.
- The macOS privacy indicator remains controlled by macOS and must remain visible while the camera is active.
- Jarbo is a regular Dock and Command-Tab application with a normal-level window.
- Closing the HUD window does not quit Jarbo. Jarbo may continue in the background and can be restored from the Dock, Command-Tab, Mission Control where applicable, or its menu-bar control.
- Hiding the HUD does not itself change the intended camera state. Camera On/Off is a separate, explicit control.
- Jarbo does not opt into an always-on-top window for 1.0.9.

These behaviors are implemented intentions. Their release-candidate manual verification is tracked in `docs/V1.0.9-FEATURE-AUDIT.md`.

## Data-retention defaults

| Data | Default treatment |
|---|---|
| Camera frames | Processed in memory; not saved by Jarbo's training path. |
| Hand training data | Normalized landmark features, gesture label, selected hand, detector source, and capture time are stored locally in the user's Application Support directory. |
| Personalized model | Stored locally under `Application Support/Jarbo/Models`; no automatic upload. |
| Configuration | Stored locally in `Application Support/Jarbo/config.json` with atomic writes; malformed configuration is backed up for recovery. |
| Command log | Bounded in-memory UI history; no telemetry export is enabled by default. |
| Voice, screen, PDF, and image content | Outside the 1.0.9 release gate; no new retention promise is made for excluded prototypes beyond safe non-interference. |
| Telemetry | No automatic remote telemetry export in the 1.0.9 foundation. |

Deleting a personalized model does not imply deletion of training samples. The model and the sample dataset are separate controls.

## Initial success metrics

These are release gates, not current measured claims.

| Area | Initial target | v1.0.9 evidence state |
|---|---:|---|
| Static-gesture precision | at least 97% on a frozen validation set | Not measured; deferred to the evaluation/replay phase. |
| Static-gesture recall | at least 93% on a frozen validation set | Not measured; deferred to the evaluation/replay phase. |
| Unintended command activation | fewer than 1 per hour in representative negative testing | Not measured. |
| Median landmark-to-result latency | below 100 ms on supported hardware | Not measured. |
| Actions editor open-to-interactive | at most 500 ms on a supported Mac | Manual measurement pending. |
| Common settings feedback | at most 100 ms | Manual measurement pending. |
| Safety release | no held input after tracking loss, configuration, Camera Off, or quit | Foundational mock tracking-loss test exists; real-device paths remain pending. |
| Clean build | `./verify.sh` succeeds from a fresh checkout | Local and clean-checkout evidence pending for the designated release candidate. |

## Release boundary

ALPHA Jarbo 1.0.9 may be published only as a prerelease. A build completing automated verification is necessary but not sufficient for a go decision: the manual smoke test, camera/resource checks, input-release checks, permissions recovery, and performance/soak gates must also be recorded. Until then, the release decision is **HOLD**.
