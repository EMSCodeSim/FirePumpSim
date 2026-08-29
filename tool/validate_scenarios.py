#!/usr/bin/env python3
"""Validate FirePumpSim scenario content before a store build.

Checks JSON parsing, unique IDs, image/file references, duplicated answer keys,
and hydrant available-flow formula consistency.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ROOT / "assets" / "scenarios"
IMAGES = ROOT / "assets" / "images"
PRINTABLE = ROOT / "assets" / "printable"
INDEX_FILES = {"scenario_manifest.json", "scenario-packs.json", "daily-challenge-index.json"}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def read_json(path: Path, errors: list[str]) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        fail(errors, f"Invalid JSON: {path.relative_to(ROOT)} — {exc}")
        return None


def normalize_asset_path(raw: str, default_dir: str) -> str:
    value = raw.strip()
    if not value:
        return ""
    return value if value.startswith("assets/") else f"{default_dir}/{value}"


def scenario_list(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, dict) and isinstance(data.get("scenarios"), list):
        return [s for s in data["scenarios"] if isinstance(s, dict)]
    return [data] if isinstance(data, dict) else []


def problem_list(scenario: dict[str, Any]) -> list[dict[str, Any]]:
    raw = scenario.get("problems") or scenario.get("variations")
    return [p for p in raw if isinstance(p, dict)] if isinstance(raw, list) and raw else [scenario]


def numeric(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def values_disagree(a: Any, b: Any) -> bool:
    na, nb = numeric(a), numeric(b)
    if na is not None and nb is not None:
        return abs(na - nb) > 0.01
    return str(a).strip() != str(b).strip()


def check_answer_consistency(problem: dict[str, Any], label: str, errors: list[str]) -> None:
    answers = problem.get("answers") if isinstance(problem.get("answers"), dict) else {}
    candidates: list[tuple[str, Any]] = []
    for key in ("answerValue", "correctAnswer", "answer", "value"):
        if problem.get(key) is not None:
            candidates.append((f"top.{key}", problem[key]))
        if answers.get(key) is not None:
            candidates.append((f"answers.{key}", answers[key]))

    # Only compare pumpPressure/correctPP when the answer surface itself requests
    # a pressure. A governing-line question may mention pump discharge pressure
    # in its wording but still correctly expect "1" or "2" as the answer.
    answer_surface = " ".join(
        str(problem.get(k) or "") for k in ("title", "answerLabel", "inputLabel", "answerUnit")
    ).lower()
    is_pressure_answer = (
        ("pressure" in answer_surface or "pdp" in answer_surface)
        and not any(term in answer_surface for term in ("line number", "governing line", "additional line", "additional stream"))
    )
    if is_pressure_answer:
        for key in ("correctPP", "pumpPressure"):
            value = problem.get(key) if problem.get(key) is not None else answers.get(key)
            if value is not None:
                candidates.append((key, value))

    if len(candidates) < 2:
        return
    base_name, base_value = candidates[0]
    for name, value in candidates[1:]:
        if values_disagree(base_value, value):
            fail(errors, f"Conflicting answer keys for {label}: {base_name}={base_value!r} vs {name}={value!r}")


def check_hydrant_available_flow(problem: dict[str, Any], label: str, errors: list[str]) -> None:
    formula = " ".join(str(v) for v in (problem.get("formulaBreakdown") or []))
    text = f"{problem.get('title', '')} {problem.get('question', '')} {formula}".lower()
    if "available flow" not in text and "available-flow" not in text:
        return
    if "static" not in text or "residual" not in text:
        return
    if "0.54" not in text or re.search(r"\^\s*0\.50\b", text) or "sqrt((" in text:
        fail(errors, f"Hydrant available-flow formula must use exponent 0.54 for {label}")


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
                label = f"'{pid or sid}' in {path.relative_to(ROOT)}"
                if pid:
                    key = pid.lower()
                    if key in problem_ids:
                        fail(errors, f"Duplicate problem id '{pid}' in {path.relative_to(ROOT)} and {problem_ids[key].relative_to(ROOT)}")
                    problem_ids[key] = path
                answer = problem.get("answerValue") or problem.get("correctAnswer") or problem.get("answer") or problem.get("correctPP")
                if answer is None and not isinstance(problem.get("answers"), dict):
                    warnings.append(f"No obvious answer key for problem '{pid or sid}' in {path.relative_to(ROOT)}")
                check_answer_consistency(problem, label, errors)
                check_hydrant_available_flow(problem, label, errors)

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
        for warning in warnings:
            print(f"  - {warning}")
    if errors:
        print("Errors:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("Scenario validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
