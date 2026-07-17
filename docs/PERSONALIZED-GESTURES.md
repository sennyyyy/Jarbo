# Personalized gesture pipeline

Jarbo separates landmark detection from gesture interpretation:

1. A `HandLandmarkDetector` converts a camera frame into canonical 21-joint `HandLandmarkFrame` values.
2. Tracking mirrors the detector output into display coordinates and smooths each hand independently.
3. Pinch contacts and their mouse-down/mouse-up lifecycle stay deterministic.
4. Motion templates handle temporal trajectories.
5. The personalized Core ML model classifies normalized static-pose features.
6. Existing personal templates, landmark rules, and bundled priors remain fallbacks.

## Training

- Capture ten natural variations per gesture across small changes in angle and distance.
- Capture ten `No gesture / other` samples with visible but deliberately unrelated poses.
- Complete at least two static gesture classes plus `No gesture / other`.
- Choose `Build Core ML Model`. Training occurs off the main UI thread.
- The compiled model is stored under `Application Support/Jarbo/Models` and loaded on launch.

The model receives 40 values: normalized X/Y coordinates for 20 finger joints relative to the wrist and palm width. Wrist rotation is normalized for static gestures. Camera frames are not saved.

## Detector backends

Apple Vision is the current production backend. Its results are converted at the detector boundary, so a MediaPipe adapter can populate the same canonical frame—including optional estimated depth—without rewriting gesture classification, overlays, or training storage.

MediaPipe is not bundled yet. Its macOS packaging, runtime latency, signing impact, handedness stability, and landmark jitter must be measured against Apple Vision before it becomes a selectable production backend.

## Safety behavior

- A personalized prediction must meet its confidence threshold before activation.
- `No gesture / other` is a first-class rejection class.
- Pinch begin, hold, and release do not depend on the learned classifier.
- Removing a hand still releases active mouse buttons.
