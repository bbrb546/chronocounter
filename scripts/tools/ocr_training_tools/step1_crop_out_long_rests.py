"""
step1_crop_out_long_rests.py

Crops every 'long rest' / 'long rest bottom' bounding box out of a YOLOv8-
format dataset (images + YOLO .txt labels) and saves each crop as its own
image file, ready for you to annotate independently (e.g. with the printed
measure-count number).

Path handling note: Roboflow-exported data.yaml files are inconsistent
about what train/val paths are relative to -- sometimes the dataset's
'path' field, sometimes the yaml file's own folder, sometimes that folder's
parent (e.g. a 'train: ../train/images' entry). Rather than guess wrong,
this script tries several plausible base directories for each split and
uses whichever one actually contains images.

Usage:
    python step1_crop_out_long_rests.py --data data.yaml --out long_rest_crops
    python step1_crop_out_long_rests.py --data data.yaml --out crops --splits train val \
        --classes "long rest" "long rest bottom" --pad 0.15

Install:
    pip install opencv-python pyyaml --break-system-packages
"""

import argparse
import os
from pathlib import Path

import cv2
import yaml

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp"}


def load_class_names(yaml_path):
    with open(yaml_path, "r") as f:
        cfg = yaml.safe_load(f)
    names = cfg["names"]
    if isinstance(names, dict):  # some data.yaml files write {0: 'bar', 1: ...}
        names = [names[i] for i in sorted(names)]
    return names, cfg


def strip_updirs(rel_path):
    """Drop any leading '..'/'.' components, e.g. '../train/images' ->
    'train/images'. Used to build a base-independent suffix we can join
    onto several candidate roots."""
    parts = [p for p in Path(rel_path).parts]
    while parts and parts[0] in ("..", "."):
        parts = parts[1:]
    return Path(*parts) if parts else Path(".")


def count_images(d):
    if not d.is_dir():
        return 0
    return sum(1 for f in d.rglob("*") if f.suffix.lower() in IMAGE_EXTS)


def resolve_split_images_dir(yaml_path, cfg, split_rel):
    """Try several candidate base directories for this split's relative
    path and return the first one that actually contains images."""
    yaml_dir = Path(yaml_path).resolve().parent
    cfg_path = cfg.get("path")
    cfg_path_dir = Path(cfg_path) if cfg_path else None

    suffix = strip_updirs(split_rel)
    bases = [b for b in [cfg_path_dir, yaml_dir, yaml_dir.parent,
                          cfg_path_dir.parent if cfg_path_dir else None] if b]

    candidates = []
    for base in bases:
        candidates.append((base / suffix).resolve())          # base + stripped suffix
        candidates.append((base / split_rel).resolve())        # base + literal (with ../) path

    # de-duplicate while preserving order
    seen = set()
    unique_candidates = []
    for c in candidates:
        if c not in seen:
            seen.add(c)
            unique_candidates.append(c)

    for c in unique_candidates:
        if count_images(c) > 0:
            return c

    return None, unique_candidates


def images_dir_to_labels_dir(images_dir: Path):
    """Mirror an images directory onto its labels directory by swapping the
    'images' path component for 'labels' (last occurrence)."""
    parts = list(images_dir.parts)
    for i in range(len(parts) - 1, -1, -1):
        if parts[i].lower() == "images":
            parts[i] = "labels"
            return Path(*parts)
    # no 'images' component found -- fall back to a sibling 'labels' folder
    return images_dir.parent / "labels"


def yolo_box_to_pixels(cx, cy, w, h, img_w, img_h, pad_frac):
    box_w, box_h = w * img_w, h * img_h
    box_cx, box_cy = cx * img_w, cy * img_h
    pad_x, pad_y = box_w * pad_frac, box_h * pad_frac
    x1 = int(max(0, box_cx - box_w / 2 - pad_x))
    y1 = int(max(0, box_cy - box_h / 2 - pad_y))
    x2 = int(min(img_w - 1, box_cx + box_w / 2 + pad_x))
    y2 = int(min(img_h - 1, box_cy + box_h / 2 + pad_y))
    return x1, y1, x2, y2


def normalize_name(s):
    return s.strip().lower().replace("_", " ")


def crop_dataset(data_yaml, out_dir, splits, target_classes, pad_frac=0.15):
    names, cfg = load_class_names(data_yaml)

    target_norm = {normalize_name(c) for c in target_classes}
    idx_to_name = {i: n for i, n in enumerate(names)}
    matched_idxs = {i for i, n in idx_to_name.items() if normalize_name(n) in target_norm}

    if not matched_idxs:
        raise SystemExit(
            f"None of {target_classes} matched class names in {data_yaml}.\n"
            f"Available classes: {', '.join(names)}\n"
            f"(Pass --classes with the exact names from this dataset's own data.yaml.)"
        )

    print("Target classes:", {idx_to_name[i] for i in matched_idxs})

    os.makedirs(out_dir, exist_ok=True)
    total_crops = 0
    seen_split = False

    for split in splits:
        split_rel = cfg.get(split)
        if not split_rel:
            print(f"  [skip] '{split}' not defined in {data_yaml}")
            continue

        images_dir = resolve_split_images_dir(data_yaml, cfg, split_rel)
        if isinstance(images_dir, tuple):  # resolution failed; unpack debug info
            _, tried = images_dir
            print(f"  [skip] no images found for split '{split}' (declared as '{split_rel}')")
            print("         tried:")
            for t in tried:
                print(f"           {t}")
            continue

        labels_dir = images_dir_to_labels_dir(images_dir)
        image_paths = sorted(
            p for p in images_dir.rglob("*") if p.suffix.lower() in IMAGE_EXTS
        )
        seen_split = True
        print(f"  {split}: {len(image_paths)} images  (images: {images_dir}, labels: {labels_dir})")

        for img_path in image_paths:
            rel = img_path.relative_to(images_dir).with_suffix(".txt")
            label_path = labels_dir / rel
            if not label_path.is_file():
                continue

            with open(label_path, "r") as f:
                lines = [ln.strip() for ln in f if ln.strip()]
            if not lines:
                continue

            image = None  # lazy-load only if this file has a matching box
            stem = img_path.stem

            for i, line in enumerate(lines):
                parts = line.split()
                if len(parts) < 5:
                    continue
                cls_idx = int(float(parts[0]))
                if cls_idx not in matched_idxs:
                    continue

                if image is None:
                    image = cv2.imread(str(img_path))
                    if image is None:
                        print(f"  [warn] could not read image {img_path}")
                        break
                img_h, img_w = image.shape[:2]

                cx, cy, w, h = map(float, parts[1:5])
                x1, y1, x2, y2 = yolo_box_to_pixels(cx, cy, w, h, img_w, img_h, pad_frac)
                if x2 <= x1 or y2 <= y1:
                    continue

                crop = image[y1:y2, x1:x2]
                cls_name = idx_to_name[cls_idx].replace(" ", "_")
                out_name = f"{stem}_{cls_name}_{i}.png"
                cv2.imwrite(os.path.join(out_dir, out_name), crop)
                total_crops += 1

    if not seen_split:
        raise SystemExit(
            "No splits produced any images. Double-check --splits matches keys "
            "in data.yaml, and that the dataset actually exists on this machine."
        )

    print(f"\nSaved {total_crops} crops to {out_dir}")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--data", default="data.yaml", help="Path to the dataset's data.yaml")
    parser.add_argument("--out", default="long_rest_crops", help="Output folder for cropped images")
    parser.add_argument(
        "--splits", nargs="+", default=["train", "val"],
        help="Which data.yaml split keys to process (e.g. train val test)",
    )
    parser.add_argument(
        "--classes", nargs="+", default=["long rest", "long rest bottom"],
        help="Class names to crop, matched case/underscore-insensitively "
             "against data.yaml's 'names' list",
    )
    parser.add_argument(
        "--pad", type=float, default=0.15,
        help="Padding around each box as a fraction of box size (default 0.15)",
    )
    args = parser.parse_args()

    crop_dataset(args.data, args.out, args.splits, args.classes, args.pad)


if __name__ == "__main__":
    main()