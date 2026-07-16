#!/usr/bin/env python3
"""Build compact Jarbo landmark priors from the official HaGRIDv2 annotations archive."""

import json
import math
import sys
import zipfile
from pathlib import Path

MAPPING = {
    "fist": "Fist",
    "palm": "Open palm",
    "like": "Thumbs up",
    "point": "Point",
    "peace": "Peace",
    "three": "Three fingers",
    "four": "Four",
    "little_finger": "Pinky",
    "rock": "Rock",
    "call": "Shaka",
    "ok": "OK",
    "thumb_index": "Pinch",
}

JOINT_ORDER = [4, 3, 2, 1, 8, 7, 6, 5, 12, 11, 10, 9, 16, 15, 14, 13, 20, 19, 18, 17]


def features(points):
    wrist, middle, index, little = points[0], points[9], points[5], points[17]
    scale = max(math.hypot(index[0] - little[0], index[1] - little[1]), 0.035)
    angle = math.atan2(middle[1] - wrist[1], middle[0] - wrist[0]) - math.pi / 2
    c, s = math.cos(-angle), math.sin(-angle)
    result = []
    for joint in JOINT_ORDER:
        x = (points[joint][0] - wrist[0]) / scale
        y = (points[joint][1] - wrist[1]) / scale
        result.extend((x * c - y * s, x * s + y * c))
    return [round(value, 6) for value in result]


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: build_hagrid_priors.py <annotations.zip> <output.json>")
    archive, output = Path(sys.argv[1]), Path(sys.argv[2])
    priors = []
    with zipfile.ZipFile(archive) as zf:
        for source, gesture in MAPPING.items():
            payload = json.loads(zf.read(f"annotations/test/{source}.json"))
            candidates = []
            for record in payload.values():
                for landmarks in record.get("hand_landmarks") or []:
                    if landmarks and len(landmarks) == 21:
                        candidates.append(landmarks)
            step = max(1, len(candidates) // 30)
            for landmarks in candidates[::step][:30]:
                priors.append({"gesture": gesture, "features": features(landmarks)})
                mirrored = [[1 - point[0], point[1]] for point in landmarks]
                priors.append({"gesture": gesture, "features": features(mirrored)})
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(priors, separators=(",", ":")))
    print(f"wrote {len(priors)} attributed priors to {output}")


if __name__ == "__main__":
    main()
