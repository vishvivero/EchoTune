#!/usr/bin/env python3
"""Validate the versioned EchoTune benchmark result contract."""
import json
import sys
from pathlib import Path

REQUIRED = {
    "schemaVersion": int,
    "fixtureDurationSeconds": (int, float),
    "modelID": str,
    "modelPath": str,
    "loadSeconds": (int, float),
    "transcriptionSeconds": (int, float),
    "peakRssKiB": (int, float),
    "cpuPercent": (int, float),
    "transcript": str,
    "success": bool,
}

def validate(path: Path) -> None:
    payload = json.loads(path.read_text())
    missing = sorted(set(REQUIRED) - set(payload))
    if missing:
        raise ValueError(f"missing required fields: {', '.join(missing)}")
    for key, expected in REQUIRED.items():
        if not isinstance(payload[key], expected) or (key == "schemaVersion" and payload[key] != 1):
            raise ValueError(f"invalid {key}: expected schema version 1 and typed benchmark fields")
    if payload.get("recordType") == "performanceSession":
        for key in ("decodeMs", "cloudSeconds"):
            if not isinstance(payload.get(key), (int, float)) or payload[key] < 0:
                raise ValueError(f"invalid non-negative session metric: {key}")
        for key in ("firstTickMs", "p50TickMs", "p95TickMs", "enhancementMs"):
            if payload.get(key) is not None and (not isinstance(payload[key], (int, float)) or payload[key] < 0):
                raise ValueError(f"invalid optional session metric: {key}")
        print(f"PASS {path}: schemaVersion=1, performance session, model={payload['modelID']}")
        return
    if payload["fixtureDurationSeconds"] <= 0 or payload["loadSeconds"] < 0 or payload["transcriptionSeconds"] < 0:
        raise ValueError("durations must be non-negative and fixture duration must be positive")
    print(f"PASS {path}: schemaVersion=1, fixture={payload['fixtureDurationSeconds']}s, model={payload['modelID']}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate_benchmark_json.py RESULT.json")
    try:
        validate(Path(sys.argv[1]))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL {sys.argv[1]}: {exc}", file=sys.stderr)
        raise SystemExit(1)
