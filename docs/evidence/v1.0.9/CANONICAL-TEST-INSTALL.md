# Jarbo 1.0.9 Canonical Test Installation

Installed and verified: 2026-07-19

## Designated application

- Release-candidate source commit: `58246c2`
- Application path: `/Applications/Jarbo.app`
- Bundle identifier: `com.senhong.jarbo`
- Display version/build: ALPHA Jarbo `1.0.9` (`9`)
- Architectures: `x86_64 arm64`
- Signature: ad-hoc development signature, valid under `codesign --deep --strict`
- Executable SHA-256: `74f3ce20cea946b373609ac5e26fd2aba18b18cf275cd07a3577eba0be8af501`
- Source archive: `dist/Jarbo-1.0.9-RC-58246c2.zip`
- Source archive SHA-256: `d02b23d6df4794f4090e7b9d35c6dc4b31c4c6e29b8b694d2b487a6b44b0c0b2`

## Installation audit

The standard `/Applications` and `~/Applications` locations contain exactly
one Jarbo application: `/Applications/Jarbo.app`. Temporary clean-checkout and
extracted test app bundles were removed after installation.

The canonical app was launched with a fresh isolated profile. One Jarbo process
was observed, running from:

`/Applications/Jarbo.app/Contents/MacOS/Jarbo`

The canonical launch stderr reproduced the non-crashing SwiftUI
`AttributeGraph: cycle detected` warning tracked as JARBO-109-002. Separate
macOS crash reports from the same arm64 candidate UUID are preserved under
`part-b/crashes/` and tracked as JARBO-109-003/004.

Historical `dist/` app bundles under the source and Desktop archives are project
build artifacts, not installed applications. They remain only to preserve build
history. All interactive testing must launch `/Applications/Jarbo.app`, not an
app bundle inside `Documents`, `Desktop`, `dist`, or a temporary folder.

## Camera-state note

The canonical verification launch used an isolated empty profile so Camera
defaulted to Off. The user's normal saved Jarbo profile currently records Camera
On intent. A later ordinary double-click launch without the isolated profile may
therefore attempt to start the camera immediately; change the saved state to Off
from Jarbo before shutdown if that is not desired.
