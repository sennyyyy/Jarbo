# Jarbo

Jarbo is a native macOS menu-bar automation HUD with on-device dual-hand tracking.

## Build and run

```bash
chmod +x build-app.sh
./build-app.sh
open dist/Jarbo.app
```

On first launch, allow Camera and Accessibility. Voice commands additionally require Microphone and Speech Recognition. Jarbo stays available from the menu bar after its window closes.

## Controls

- Left hand defaults to precision relative pointer mode. Point with the index finger and make small movements. Hold a thumb/index pinch to hold or drag with the left button, then release the pinch to release the button. Thumb/middle does the same for right-click. Relax or remove the hand briefly to clutch and reposition.
- Right hand defaults to gesture controls. Swipe an open hand horizontally to move between macOS Spaces, show a peace sign for Mission Control, make a fist for play/pause, point left/right for tracks, use three fingers for App Exposé, or use thumbs-up/down for volume.
- Open **Actions** to change either hand role and map any supported gesture to Mac controls, URLs, apps, files, notes, speech, searches, image generation, or shell commands.
- The Actions screen includes three custom pose slots. Hold a pose in the camera, capture Custom A, B, or C, then map that custom pose to any action.

System automation requires macOS Accessibility permission. Jarbo displays a red warning whenever macOS is blocking cursor, click, or keyboard output. Shell commands run only when explicitly saved and triggered by the user.

## Publishing releases

Create `release-notes/v1.0.3.md` with **Working** and **Known limitations** sections, then publish with:

```bash
./release.sh 1.0.3
```

The release helper updates the app version and build number, builds and signs the app, creates a versioned zip, commits the source and notes, tags the commit, and pushes both the commit and tag. GitHub Actions then creates a GitHub Release from that version's notes.
