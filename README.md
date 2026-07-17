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

- Left hand defaults to precision relative pointer mode. Thumb/index holds or drags with the left button, thumb/middle holds the right button, and thumb/ring holds the middle button. Separating the fingers immediately releases the corresponding button. Relax or remove the hand briefly to clutch and reposition.
- Right hand defaults to gesture controls. Swipe an open hand horizontally to move between macOS Spaces, show a peace sign for Mission Control, make a fist for play/pause, point left/right for tracks, use three fingers for App Exposé, or use thumbs-up/down for volume.
- Open **Actions** to change either hand role and map any supported gesture to Mac controls, URLs, apps, files, notes, speech, searches, image generation, or shell commands.
- Personal Training exposes 20 static configurations, 20 dynamic motions, and 10 wrist orientations, plus Custom A/B/C. Every gesture has its own independent 0/10 sample counter.
- Static and orientation entries capture the current pose. For dynamic entries, perform the movement and immediately add the recent 1.3-second trajectory.
- Personalized Core ML training is available for static poses. Capture 10 **No gesture / other** samples and 10 samples each for at least two static gestures, then choose **Build Core ML Model**. The model runs locally and persists between launches.
- Training records detector-neutral normalized landmarks, the detector source, hand, and capture time—not camera images. This allows future Apple Vision and MediaPipe samples to share one classifier dataset.
- Jarbo includes 720 attributed HaGRIDv2 landmark priors for 12 safely matched static classes. Ten personal samples for a gesture replace its research priors and calibrate recognition to your hand.
- Playback, next-track, and previous-track actions control Spotify by default.

System automation requires macOS Accessibility permission. Jarbo displays a red warning whenever macOS is blocking cursor, click, or keyboard output. Shell commands run only when explicitly saved and triggered by the user.

## Publishing releases

Create `release-notes/v1.0.7.md` with **Working** and **Known limitations** sections, then publish with:

```bash
./release.sh 1.0.7
```

The release helper updates the app version and build number, builds and signs the app, creates a versioned zip, commits the source and notes, tags the commit, and pushes both the commit and tag. GitHub Actions then creates an **ALPHA Jarbo** GitHub Release from that version's notes.
