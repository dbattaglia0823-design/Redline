#!/usr/bin/env python3
"""Audit paint-mask versus replacement-body PNG alignment without altering assets."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Pillow is required. Install with: python -m pip install Pillow") from exc

ROOT = Path(__file__).resolve().parents[1]


def local_path(reference: str) -> Path:
    if not reference.startswith("res://"):
        raise ValueError("Expected project asset path: " + reference)
    target = (ROOT / reference.removeprefix("res://")).resolve()
    if not target.is_relative_to(ROOT):
        raise ValueError("Asset escapes repository: " + reference)
    return target


def audit() -> list[dict]:
    manifest = json.loads((ROOT / "assets/vehicles/manifest.json").read_text(encoding="utf-8"))
    rows = []
    for car_id, definition in sorted(manifest.items()):
        paint_path = local_path(definition["layers"]["paint_mask"])
        body_path = local_path(definition["body"] % (0, "gloss"))
        with Image.open(paint_path) as source:
            mask = source.convert("RGBA")
        with Image.open(body_path) as source:
            body = source.convert("RGBA")
        original_size = list(mask.size)
        resized = mask.size != body.size
        # Only compute a proposed correction; the audit never writes to source PNGs.
        candidate = mask.resize(body.size, Image.Resampling.LANCZOS) if resized else mask
        mask_alpha = candidate.getchannel("A").tobytes()
        body_alpha = body.getchannel("A").tobytes()
        selected = sum(value > 0 for value in mask_alpha)
        excluded = sum(paint > 0 and color < 255 for paint, color in zip(mask_alpha, body_alpha))
        ratio = excluded / selected if selected else 1.0
        significantly_transparent = sum(
            paint > 0 and color < 243 for paint, color in zip(mask_alpha, body_alpha)
        )
        alpha_histogram = {
            "zero": 0, "low_1_127": 0, "mid_128_251": 0,
            "near_opaque_252_254": 0, "opaque_255": 0,
        }
        for paint, color in zip(mask_alpha, body_alpha):
            if paint == 0:
                continue
            if color == 0:
                alpha_histogram["zero"] += 1
            elif color < 128:
                alpha_histogram["low_1_127"] += 1
            elif color < 252:
                alpha_histogram["mid_128_251"] += 1
            elif color < 255:
                alpha_histogram["near_opaque_252_254"] += 1
            else:
                alpha_histogram["opaque_255"] += 1
        rows.append({
            "id": car_id,
            "paint_mask": str(paint_path.relative_to(ROOT)),
            "body": str(body_path.relative_to(ROOT)),
            "mask_size": original_size,
            "body_size": list(body.size),
            "resized_for_comparison": resized,
            "selected_pixels": selected,
            "pixels_outside_opaque_body": excluded,
            "excluded_fraction": round(ratio, 6),
            "below_95pct_opaque_pixels": significantly_transparent,
            "below_95pct_fraction": round(significantly_transparent / selected if selected else 1.0, 6),
            "body_alpha_at_mask_pixels": alpha_histogram,
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, default=Path(".qa/paint_mask_audit.json"))
    args = parser.parse_args()
    rows = audit()
    for row in rows:
        print(f'{row["id"]}: mask={row["mask_size"]}, body={row["body_size"]}, '
              f'excluded={row["pixels_outside_opaque_body"]}/{row["selected_pixels"]} '
              f'({row["excluded_fraction"] * 100:.3f}%) '
              f'alpha_below_95%={row["below_95pct_fraction"] * 100:.3f}% '
              f'alpha_hist={row["body_alpha_at_mask_pixels"]}')
    report = {
        "mode": "read-only audit",
        "vehicles": rows,
        "dimension_mismatches": sum(x["resized_for_comparison"] for x in rows),
        "alpha_mismatches": sum(x["pixels_outside_opaque_body"] > 0 for x in rows),
        "warning": "No source assets modified. Review before any automatic resize or alpha clipping.",
    }
    path = args.report if args.report.is_absolute() else ROOT / args.report
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
