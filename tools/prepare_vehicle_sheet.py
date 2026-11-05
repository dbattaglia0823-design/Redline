"""Key original side-elevation sheets and propose axle coordinates for review.

Usage: python tools/prepare_vehicle_sheet.py sheet.png top_to_bottom_model_ids...
The model IDs are supplied in top-to-bottom row order. Check the printed axle
coordinates against the cutouts before merging entries into authoring.json.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets/vehicles/source_premium"


def runs(values):
    indices = np.flatnonzero(values)
    return np.split(indices, np.where(np.diff(indices) > 1)[0] + 1) if len(indices) else []


def key_sheet(image):
    pixels = np.asarray(image.convert("RGB")).astype(np.float32)
    r, g, b = pixels.transpose(2, 0, 1)
    spill = np.minimum(r, b) - g
    alpha = np.clip((122 - spill) / 85, 0, 1)
    # Unmix edge pixels against magenta; avoid a colored fringe on dark tires.
    foreground = (pixels - (1 - alpha[..., None]) * [255, 0, 255]) / np.maximum(.05, alpha[..., None])
    edge = (alpha > 0) & (alpha < .94)
    foreground[edge] = (g[edge] / alpha[edge])[:, None]
    return np.dstack([np.clip(foreground, 0, 255), alpha * 255]).astype(np.uint8)


def axle(alpha, start, end):
    mask = alpha[:, start:end] > 230
    bottom = np.max(np.where(mask, np.arange(len(alpha))[:, None], -1), axis=0)
    groups = runs(bottom >= bottom.max() - len(alpha) * .065)
    edge = max(groups, key=len)
    x = edge.astype(float) + start
    y = bottom[edge].astype(float)
    origin = np.array([x.mean(), y.max()])
    x, y = x - origin[0], y - origin[1]
    cx, cy, constant = np.linalg.lstsq(np.column_stack([2*x, 2*y, np.ones_like(x)]), x*x+y*y, rcond=None)[0]
    radius = np.sqrt(cx*cx+cy*cy+constant)
    error = np.mean(np.abs(np.hypot(x-cx, y-cy)-radius))
    if not len(alpha)*.12 < radius < len(alpha)*.48 or error > 4:
        raise ValueError(f"Poor tire fit radius={radius:.1f}, residual={error:.1f}")
    return [round(cx+origin[0]), round(cy+origin[1])], round(radius)


def prepare(path, models):
    pixels = key_sheet(Image.open(path))
    rows = runs(np.count_nonzero(pixels[:, :, 3] > 230, axis=1) > pixels.shape[1] * .012)
    rows = [row for row in rows if len(row) > 38]
    if len(rows) != len(models):
        raise ValueError(f"Expected {len(models)} separated rows, found {len(rows)}")
    entries = {}
    for model, row in zip(models, rows):
        car = pixels[max(0, row[0]-3):row[-1]+4]
        x = np.flatnonzero(np.count_nonzero(car[:, :, 3] > 230, axis=0) > 2)
        car = car[:, max(0, x[0]-4):x[-1]+5]
        target = SOURCES / f"{model}_studio.png"
        Image.fromarray(car).save(target)
        try:
            rear, rear_radius = axle(car[:, :, 3], 0, car.shape[1]//2)
            front, front_radius = axle(car[:, :, 3], car.shape[1]//2, car.shape[1])
        except ValueError as error:
            print(f"{model}: {error}; measure the cutout manually.")
            continue
        entries[model] = {
            "source": target.relative_to(ROOT).as_posix(),
            "rear": rear, "front": front, "radius": round((rear_radius+front_radius)/2),
            "resolution": 2 if car.shape[1] >= 1250 else 1,
        }
    return entries


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path)
    parser.add_argument("models", nargs="+")
    args = parser.parse_args()
    print(json.dumps(prepare(args.sheet, args.models), indent=2))
