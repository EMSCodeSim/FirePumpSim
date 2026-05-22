#!/usr/bin/env python3
"""Validate FirePumpSim scenario content before an App Store / Play Store build.

Checks:
- all scenario JSON files parse
- scenario/problem IDs are present and unique after normalization
- referenced images exist in assets/images or assets/printable
- manifest and pack file references point to bundled JSON
"""
from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ROOT / "assets" / "scenarios"
IMAGES = ROOT / "assets" / "images"
PRINTABLE = ROOT / "assets" / "printable"

INDEX_FILES = {
    "scenario_manifest.json",
    "scenario-packs.json",
    "daily-challenge-index.json",
}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def read_json(path: Path, errors: list[str]) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - validation script should capture all parse failures
        fail(errors, f"Invalid JSON: {path.relative_to(ROOT)} — {exc}")
        return None


def normalize_asset_path(raw: str, default_dir: str) -> str:
    value = raw.strip()
    if not value:
        return ""
    if value.startswith("assets/"):
        return value
    return f"{default_dir}/{value}"


def scenario_list(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, dict) and isinstance(data.get("scenarios"), list):
        return [s for s in data["scenarios"] if isinstance(s, dict)]
    if isinstance(data, dict):
        return [data]
    return []


def problem_list(scenario: dict[str, Any]) -> list[dict[str, Any]]:
    raw = scenario.get("problems") or scenario.get("variations")
    if isinstance(raw, list) and raw:
        return [p for p in raw if isinstance(p, dict)]
    return [scenario]


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    image_paths = {str(p.relative_to(ROOT)).replace("\\", "/") for p in IMAGES.glob("*") if p.is_file()}
    image_paths |= {str(p.relative_to(ROOT)).replace("\\", "/") for p in PRINTABLE.glob("*") if p.is_file()}

    scenario_ids: dict[str, Path] = {}
    problem_ids: dict[str, Path] = {}
    scenario_count = 0
    problem_count = 0

    scenario_jsons = sorted(
        p for p in SCENARIOS.rglob("*.json")
        if p.name not in INDEX_FILES and "packs" not in p.relative_to(SCENARIOS).parts
    )

    for path in scenario_jsons:
        data = read_json(path, errors)
        if data is None:
            continue
        for scenario in scenario_list(data):
            scenario_count += 1
            sid = str(scenario.get("id") or scenario.get("scenarioId") or "").strip()
            if not sid:
                fail(errors, f"Missing scenario id in {path.relative_to(ROOT)}")
            else:
                key = sid.lower()
                if key in scenario_ids:
                    fail(errors, f"Duplicate scenario id '{sid}' in {path.relative_to(ROOT)} and {scenario_ids[key].relative_to(ROOT)}")
                scenario_ids[key] = path

            image = str(scenario.get("image") or scenario.get("scene") or scenario.get("thumbnail") or "").strip()
            image_path = normalize_asset_path(image, "assets/images")
            if image_path and image_path not in image_paths:
                fail(errors, f"Missing image for scenario '{sid}': {image_path} referenced by {path.relative_to(ROOT)}")

            for problem in problem_list(scenario):
                problem_count += 1
                pid = str(problem.get("id") or "").strip()
                if pid:
                    key = pid.lower()
                    if key in problem_ids:
                        fail(errors, f"Duplicate problem id '{pid}' in {path.relative_to(ROOT)} and {problem_ids[key].relative_to(ROOT)}")
                    problem_ids[key] = path

                answer = problem.get("answerValue") or problem.get("correctAnswer") or problem.get("answer") or problem.get("correctPP")
                if answer is None and not isinstance(problem.get("answers"), dict):
                    warnings.append(f"No obvious answer key for problem '{pid or sid}' in {path.relative_to(ROOT)}")

    manifest = read_json(SCENARIOS / "scenario_manifest.json", errors)
    if isinstance(manifest, dict):
        for raw in manifest.get("files", []):
            ref = normalize_asset_path(str(raw), "assets/scenarios")
            if not (ROOT / ref).exists():
                fail(errors, f"Manifest references missing scenario file: {ref}")

    packs = read_json(SCENARIOS / "scenario-packs.json", errors)
    if isinstance(packs, dict):
        for pack in packs.get("packs", []):
            if not isinstance(pack, dict):
                continue
            for raw in pack.get("scenarioFiles", []):
                ref = normalize_asset_path(str(raw), "assets/scenarios")
                if not (ROOT / ref).exists():
                    fail(errors, f"Pack '{pack.get('packId', '')}' references missing scenario file: {ref}")

    print(f"Validated {scenario_count} scenarios and {problem_count} playable problems.")
    if warnings:
        print("Warnings:")
        for w in warnings:
            print(f"  - {w}")
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("Scenario validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
