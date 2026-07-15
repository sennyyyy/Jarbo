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

- Left hand defaults to pointer mode. Point with the index finger; pinch thumb/index to click and thumb/middle to right-click.
- Right hand defaults to gesture controls. Swipe to move between macOS Spaces, show an open palm for Mission Control, make a fist for play/pause, or give a thumbs-up for volume.
- Open **Actions** to change either hand role and map any supported gesture to Mac controls, URLs, apps, files, notes, speech, searches, image generation, or shell commands.

System automation requires macOS Accessibility permission. Shell commands run only when explicitly saved and triggered by the user.

## Publishing releases

After configuring an `origin` Git remote, publish a new version with:

```bash
./release.sh 1.0.2
```

The release helper updates the app version and build number, builds and signs the app, creates a versioned zip, commits the source, tags the commit, and pushes both the commit and tag. The current initial release is `v1.0.1`.
