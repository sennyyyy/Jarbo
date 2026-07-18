# ALPHA Jarbo 1.0.9

Jarbo is a native, local-first macOS gesture-control HUD. It uses Apple Vision hand landmarks, configurable two-hand roles, deterministic finger-contact mouse controls, and optional personalized Core ML classification for eligible static poses.

Version 1.0.9 is an alpha prerelease candidate. The source contains its Phase 0 contracts, tests, verification command, training-readiness work, and camera/application lifecycle changes; hardware, performance, soak, clean-checkout, and release-candidate audit results remain pending.

## Requirements

- macOS 14 or later.
- An Apple-silicon or Intel Mac and a compatible camera for hand controls.
- Xcode or selected Xcode Command Line Tools with a Swift 6-capable compiler and macOS SDK to build from source.
- Camera permission for hand detection.
- Accessibility permission for cursor, mouse-button, and keyboard output.
- Spotify Automation permission may be requested for media controls.
- Spotify is the default target for play/pause and track navigation.

The build creates a universal `arm64`/`x86_64` app. It is ad-hoc signed for development, not Developer ID signed or notarized.

## Verify, build, and run

From Terminal, change to the repository folder and run:

```bash
./verify.sh
open dist/Jarbo.app
```

`verify.sh` checks the development environment, runs Swift tests, builds Jarbo, validates the bundle and property list, verifies the signature, and confirms both supported architectures.

For a faster local build without running the complete verification suite:

```bash
./preflight.sh
./build-app.sh
open dist/Jarbo.app
```

On first launch, grant only the permissions needed for the controls you intend to use. If macOS blocks the first development launch, right-click `dist/Jarbo.app` in Finder and choose **Open**; do not suppress macOS privacy indicators.

## Camera and application behavior

- Camera capture defaults to **Off** for a new or migrated profile with no saved camera preference.
- Use the menu-bar **Camera On/Off** control to change camera intent. The live menu state distinguishes starting, on, stopping, permission denied, unavailable, and off.
- Jarbo preserves the macOS camera privacy indicator while capture is active. Camera Off is intended to stop the capture session, clear stale tracking, cancel gesture candidates, and release held controls.
- Jarbo is a regular Dock and Command-Tab app with a normal-level window. It is not always on top by default.
- Closing or hiding the HUD does not quit Jarbo. Reopen it from the Dock, Command-Tab, Mission Control where applicable, or the menu-bar control.
- Hiding the HUD does not silently toggle the camera. Explicitly enabled services may continue in the background.

These are release contracts; the manual lifecycle matrix and ten-cycle camera/resource checks are still tracked as pending in the feature audit.

## Default hand controls

- The left hand defaults to precision relative pointer mode at 0.5× sensitivity. Thumb/index holds the left button, thumb/middle holds the right button, and thumb/ring holds the middle button. Separating the fingers ends the corresponding hold. Relax or remove the hand to clutch and reposition.
- The right hand defaults to gesture controls. Open-palm swipes change Spaces, Peace opens Mission Control, Fist controls play/pause, Point Left/Right changes Spotify tracks, Three Fingers opens App Exposé, and Thumbs Up/Down changes volume.
- The camera HUD is designed to show a green box/skeleton plus hand, gesture, and current-action labels for detected hands.
- Open **Actions** to change hand roles and map supported gestures to Mac controls, URLs, applications, files, search, notes, spoken text, image generation, explicit shell commands, or HUD visibility.

System control must show a usable Accessibility state. Desktop switching also requires at least two Spaces and enabled Control–Left/Right Arrow Mission Control shortcuts. Spotify media actions may request Automation permission.

## Personalized training

The training catalog contains 20 static finger configurations, 20 dynamic motions, 10 wrist orientations, and Custom A/B/C. Each entry has its own bank of up to ten samples.

For the personalized static Core ML model:

1. Turn the camera on and wait for the selected hand to report `21/21` fresh landmarks.
2. Capture ten varied `No gesture / other` examples, including relaxed, partially curled, transition, and unrelated poses.
3. Capture ten varied samples for at least two eligible static gestures.
4. Use the readiness checklist to resolve every reported missing count.
5. Build the model, then confirm its status and recognition behavior before assigning consequential actions.

Dynamic and orientation samples do not count toward the static model. Jarbo prompts for changes in distance, frame position, small rotation, lighting, palm angle, and finger spacing, and warns when several captures are nearly identical. The trained model and normalized samples remain local in the user's Application Support folder; the training path does not save camera frames.

Model build/delete/rebuild/relaunch behavior must still pass the v1.0.9 hardware rehearsal before the release can be approved.

## Safety and limitations

- Learned inference never replaces deterministic mouse-button release behavior.
- Webcam landmarks can still fail under blur, severe occlusion, poor lighting, or incomplete hand visibility.
- Pointer behavior is primarily designed around the main display; the multi-display matrix is not complete.
- MediaPipe, LiDAR/depth input, general-model fusion, replay evaluation, and measured recognition gates are deferred.
- Voice-command reliability, PDF/image understanding, and the 3D model viewer are excluded from the v1.0.9 release gate.
- Image generation is a separate explicit cloud action and requires user configuration; it is not used for live gesture recognition.
- Shell commands run only from an explicitly saved and triggered binding and should be treated as high risk.

## Project evidence

- [Product definition](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Risk register](docs/RISK-REGISTER.md)
- [v1.0.9 manual smoke test](docs/V1.0.9-SMOKE-TEST.md)
- [v1.0.9 feature audit](docs/V1.0.9-FEATURE-AUDIT.md)
- [Phase 0 review](docs/V1.0.9-PHASE-0-REVIEW.md)
- [Proposed version scope](docs/NEXT-VERSION.md)

The current Phase 0 and release decision is **HOLD** until the designated release candidate passes clean-checkout verification, CI, manual safety/permission tests, performance gates, and soak testing.

## Publishing a prerelease

After all gates are complete, ensure `release-notes/v1.0.9.md` accurately matches the observed candidate, then run:

```bash
./release.sh 1.0.9
```

The release helper updates version/build metadata, verifies and packages the universal app, commits the intended source and notes, tags the commit, and pushes the branch and tag. GitHub Actions publishes **ALPHA Jarbo 1.0.9** as a prerelease. Do not publish while the Phase 0 review remains HOLD.
