# Gesture model research

Jarbo uses three layers, in priority order:

1. Ten per-gesture personal samples for user-specific calibration.
2. Bundled, attributed landmark priors where a source label maps cleanly to Jarbo's gesture.
3. Deterministic geometric fallbacks for common poses and swipes.

## Primary sources

- **HaGRIDv2:** https://github.com/hukenovs/hagrid — more than one million labeled RGB images, with auto-annotated hand landmarks. Jarbo derives compact priors from a subset of test annotations under the dataset's CC BY-SA variant. The app does not bundle the source images or personal metadata.
- **HaGRID WACV paper:** https://openaccess.thecvf.com/content/WACV2024/html/Kapitanov_HaGRID_--_HAnd_Gesture_Recognition_Image_Dataset_WACV_2024_paper.html
- **EgoGesture paper:** https://nlpr.ia.ac.cn/iva/yfzhang/datasets/EgoGesture.pdf — an RGB-D video benchmark for static and dynamic egocentric gestures. It informed the decision to model motion as a temporal sequence rather than a still pose.
- **MediaPipe Gesture Recognizer:** https://developers.google.com/edge/mediapipe/solutions/vision/gesture_recognizer — documents a real-time landmark model plus customizable gesture classifier and supports image, video, and live-stream inputs.

## Why Jarbo does not scrape arbitrary images

Search-engine images do not provide consistent gesture definitions, temporal labels, camera orientation, licensing, or landmark quality. Mixing them directly into a control model would create ambiguous classes and unpredictable false triggers. Jarbo imports only labels that map confidently and uses personal training for the rest.

## Current HaGRID mappings

Fist, Open Palm, Thumbs Up, Point, Peace, Three, Four, Pinky, Rock, Shaka, OK, and Finger Heart use HaGRID landmark priors. Other requested classes remain personal-only until a compatible, licensed source with an unambiguous definition is integrated.
