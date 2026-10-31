#!/usr/bin/env python3
"""
step2_focus_crop.py

Two-stage crop pipeline for a YOLO(v8)-format object detection dataset.

Supports any of these common input layouts, auto-detected:

    1. Flat (plain Ultralytics):
         <input_dir>/images/**            <input_dir>/labels/**

    2. Split-based (Roboflow YOLOv8 export style):
         <input_dir>/train/images/**      <input_dir>/train/labels/**
         <input_dir>/valid/images/**      <input_dir>/valid/labels/**
         <input_dir>/test/images/**       <input_dir>/test/labels/**
         (any split name works -- it's any folder containing a sibling
         "images"/"labels" pair, found at any depth under input_dir)

    3. Side-by-side (image and .txt label in the same folder, no
       separate images/ and labels/ subfolders at all)

    Label files are YOLO format: "class xc yc w h", all four floats
    normalized to 0-1, one box per line.

    Output datasets are always written in the flat layout
    (<output_root>/images/... + <output_root>/labels/...), with any
    split/subfolder structure from the input preserved as a prefix
    (e.g. input "train/images/img1.jpg" -> output "images/train/img1.jpg").

For every image/label pair:

  STAGE 1 -- top/bottom half crop
  --------------------------------
  - If every annotation's box lies *entirely* within the top half of the
    image  -> crop the image down to just the top half.
  - If every annotation's box lies *entirely* within the bottom half
    -> crop the image down to just the bottom half.
  - Otherwise (annotations span both halves, straddle the midline, or
    there are no annotations at all) -> the ORIGINAL image+label pair is
    copied, unchanged, into the "edge_cases" output dataset, and stage 2
    is skipped for this image.

  Annotation coordinates are rescaled (not just re-normalized) to match
  the new, shorter image height. No boxes are dropped in this stage,
  since by construction every box already fits inside the kept half.

  STAGE 2 -- middle 3/5 horizontal crop
  --------------------------------------
  Applied to the stage-1 output (the half-height image).
  - Remove the leftmost 1/5 and rightmost 1/5 of the image width, keeping
    the middle 3/5.
  - Any annotation box that is not *entirely* contained within that
    middle 3/5 (i.e. it overlaps either removed edge strip at all) is
    dropped entirely -- boxes are never clipped/resized, only kept or
    removed.
  - If this leaves zero annotations, the image is considered unusable:
    the PRE-stage-2 image (i.e. the stage-1 top/bottom-cropped image,
    NOT the original full image) and its stage-1 label are moved into
    "edge_cases" instead.
  - Otherwise, the stage-2 cropped image and its filtered/rescaled
    labels are written to the main output dataset.

Usage:
    python step2_focus_crop.py \\
        --input_dir /path/to/dataset \\
        --output_dir /path/to/dataset_processed \\
        --edge_dir /path/to/dataset_edge_cases

All three of images/ and labels/ mirrored subfolder structure is
preserved in both output datasets.
"""

import argparse
import shutil
from pathlib import Path

import cv2

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"}

# Small tolerance for floating point noise when comparing box edges to the
# midline / crop boundaries.
EPS = 1e-6


# --------------------------------------------------------------------------
# YOLO label I/O
# --------------------------------------------------------------------------

def read_yolo_labels(label_path):
    """Read a YOLO-format label file.

    Returns a list of [class_id (int), xc, yc, w, h] with the four floats
    normalized to [0, 1]. Blank lines are skipped. Returns [] if the file
    doesn't exist or is empty.
    """
    boxes = []
    if not label_path.exists():
        return boxes
    with open(label_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            # Tolerate extra trailing fields (e.g. some exporters add a
            # confidence or extra id column) by only reading the first 5.
            cls_id = int(float(parts[0]))
            xc, yc, w, h = (float(v) for v in parts[1:5])
            boxes.append([cls_id, xc, yc, w, h])
    return boxes


def write_yolo_labels(label_path, boxes):
    """Write boxes (list of [class_id, xc, yc, w, h]) to `label_path`
    in YOLO format. Creates parent directories as needed. Writes an
    empty file if `boxes` is empty (matches Ultralytics convention of
    having a label file with no lines for background images)."""
    label_path.parent.mkdir(parents=True, exist_ok=True)
    with open(label_path, "w", encoding="utf-8") as f:
        for cls_id, xc, yc, w, h in boxes:
            f.write(f"{cls_id} {xc:.6f} {yc:.6f} {w:.6f} {h:.6f}\n")


# --------------------------------------------------------------------------
# Stage 1: top/bottom half crop
# --------------------------------------------------------------------------

def classify_vertical_half(boxes):
    """Decide whether every box lies fully in the top half, fully in the
    bottom half, or neither (mixed / straddling / no boxes at all).

    Returns "top", "bottom", or None.
    """
    if not boxes:
        # No annotations -> undefined; treat as a mixed/edge case.
        return None

    all_top = True
    all_bottom = True
    for _cls, _xc, yc, _w, h in boxes:
        top_edge = yc - h / 2.0
        bottom_edge = yc + h / 2.0
        if bottom_edge > 0.5 + EPS:
            all_top = False
        if top_edge < 0.5 - EPS:
            all_bottom = False

    if all_top and not all_bottom:
        return "top"
    if all_bottom and not all_top:
        return "bottom"
    # Either mixed (neither all_top nor all_bottom), or degenerate
    # (both true, e.g. every box has zero height sitting exactly on the
    # midline) -- treat degenerate case as mixed too, to be safe.
    if all_top and all_bottom:
        return None
    return None


def crop_top_bottom(image, boxes, half):
    """Crop `image` to its top or bottom half and rescale `boxes`
    (already known to fit entirely within that half) into the new
    image's normalized coordinate space.

    Returns (new_image, new_boxes).
    """
    h_img, w_img = image.shape[:2]
    crop_y = h_img // 2

    if half == "top":
        new_image = image[0:crop_y, :].copy()
        new_h = crop_y
        y_offset_px = 0
    else:  # "bottom"
        new_image = image[crop_y:h_img, :].copy()
        new_h = h_img - crop_y
        y_offset_px = crop_y

    new_boxes = []
    for cls_id, xc, yc, w, h in boxes:
        # Convert to absolute pixels in the ORIGINAL image, shift into the
        # cropped image's frame, then re-normalize by the new height.
        yc_px = yc * h_img - y_offset_px
        h_px = h * h_img
        new_yc = yc_px / new_h
        new_h_norm = h_px / new_h
        # x and width are untouched by a purely-vertical crop.
        new_boxes.append([cls_id, xc, new_yc, w, new_h_norm])

    return new_image, new_boxes


# --------------------------------------------------------------------------
# Stage 2: middle 3/5 horizontal crop
# --------------------------------------------------------------------------

def crop_middle_three_fifths(image, boxes):
    """Crop `image` down to its middle 3/5 by width (dropping the
    leftmost and rightmost 1/5 strips), and keep only boxes that lie
    *entirely* within the kept region, rescaled into the new image's
    normalized coordinate space.

    Returns (new_image, new_boxes).
    """
    h_img, w_img = image.shape[:2]
    left_cut = round(w_img * 0.2)
    right_cut = round(w_img * 0.8)
    # Guard against degenerate rounding on very narrow images.
    right_cut = max(right_cut, left_cut + 1)

    new_image = image[:, left_cut:right_cut].copy()
    new_w = right_cut - left_cut

    new_boxes = []
    for cls_id, xc, yc, w, h in boxes:
        left_edge_px = (xc - w / 2.0) * w_img
        right_edge_px = (xc + w / 2.0) * w_img

        # Drop the box entirely if any part of it falls outside the kept
        # middle region.
        if left_edge_px < left_cut - EPS * w_img or right_edge_px > right_cut + EPS * w_img:
            continue

        xc_px = xc * w_img - left_cut
        w_px = w * w_img
        new_xc = xc_px / new_w
        new_w_norm = w_px / new_w
        # y and height are untouched by a purely-horizontal crop.
        new_boxes.append([cls_id, new_xc, yc, new_w_norm, h])

    return new_image, new_boxes


# --------------------------------------------------------------------------
# Dataset walking / pipeline
# --------------------------------------------------------------------------

def find_image_label_pairs(input_dir: Path):
    """Yield (image_path, label_path, relative_path) for every image found
    under `input_dir`, matched to its YOLO label file.

    Handles three common dataset shapes, tried in order:

      1. Flat:            <input_dir>/images/**            <input_dir>/labels/**
      2. Split-based       <input_dir>/<split>/images/**    <input_dir>/<split>/labels/**
         (Roboflow-style: train/images, train/labels, valid/images, ... at
         any depth -- not just directly under input_dir)
      3. Side-by-side:     <input_dir>/**/*.jpg + *.txt in the SAME folder,
         no separate images/labels split at all.

    `relative_path` is a *normalized* relative path (split/subfolder +
    filename, with any literal "images"/"labels" segment stripped out) that
    save_pair()/copy_original_pair() re-attach under "images/" or "labels/"
    in the destination dataset. This means output layout is always
    standardized to <output_root>/images/... + <output_root>/labels/...
    regardless of which input shape was detected, while still preserving
    any split (train/valid/test) or other subfolder structure.
    """
    # --- Shape 1 & 2: look for any directory literally named "images"
    # (case-insensitive) that has a sibling directory named "labels". This
    # covers both input_dir/images+labels directly, and
    # input_dir/<split>/images+labels at any depth. ---
    images_dirs = []
    for d in input_dir.rglob("*"):
        if d.is_dir() and d.name.lower() == "images":
            sibling_labels = d.parent / "labels"
            if not sibling_labels.is_dir():
                # try case-insensitive sibling lookup
                candidates = [c for c in d.parent.iterdir() if c.is_dir() and c.name.lower() == "labels"]
                sibling_labels = candidates[0] if candidates else None
            if sibling_labels is not None and sibling_labels.is_dir():
                images_dirs.append((d, sibling_labels))

    found_any = False
    if images_dirs:
        for images_root, labels_root in images_dirs:
            # e.g. "train" if images_root == input_dir/train/images,
            # "." if images_root == input_dir/images directly.
            split_prefix = images_root.parent.relative_to(input_dir)
            for img_path in sorted(images_root.rglob("*")):
                if not img_path.is_file() or img_path.suffix.lower() not in IMAGE_EXTS:
                    continue
                rel_within_images = img_path.relative_to(images_root)
                label_path = labels_root / rel_within_images.with_suffix(".txt")
                rel_path = (split_prefix / rel_within_images) if str(split_prefix) != "." else rel_within_images
                found_any = True
                yield img_path, label_path, rel_path
        if found_any:
            return

    # --- Shape 3: fallback -- images and .txt labels living side by side
    # in the same folder anywhere under input_dir. ---
    for img_path in sorted(input_dir.rglob("*")):
        if not img_path.is_file() or img_path.suffix.lower() not in IMAGE_EXTS:
            continue
        label_path = img_path.with_suffix(".txt")
        rel_path = img_path.relative_to(input_dir)
        found_any = True
        yield img_path, label_path, rel_path

    if not found_any:
        # Nothing matched any known shape -- surface a diagnostic instead
        # of silently processing zero files.
        sample_dirs = sorted({p.relative_to(input_dir) for p in input_dir.rglob("*") if p.is_dir()})[:15]
        sample_images = [p for p in input_dir.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTS][:5]
        print(f"[error] No images found under {input_dir} in any recognized layout.")
        print(f"        Recognized image extensions: {sorted(IMAGE_EXTS)}")
        print(f"        First subdirectories found: {sample_dirs if sample_dirs else '(none)'}")
        print(f"        First image files found anywhere: {sample_images if sample_images else '(none)'}")
        print("        Expected one of:")
        print("          <input_dir>/images/... + <input_dir>/labels/...")
        print("          <input_dir>/<split>/images/... + <input_dir>/<split>/labels/...")
        print("          <input_dir>/**/<name>.jpg + <name>.txt side by side")


def save_pair(image, boxes, images_root: Path, labels_root: Path, rel_path: Path):
    """Write `image` and `boxes` into the images/labels tree rooted at
    `images_root`/`labels_root`, at the mirrored relative location
    `rel_path` (image extension preserved, label forced to .txt)."""
    out_img_path = images_root / rel_path
    out_img_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_img_path), image)

    out_label_path = labels_root / rel_path.with_suffix(".txt")
    write_yolo_labels(out_label_path, boxes)


def copy_original_pair(img_path: Path, label_path: Path, images_root: Path,
                        labels_root: Path, rel_path: Path):
    """Copy an original (unmodified) image + label pair into an output
    dataset tree, e.g. for edge cases detected before any cropping."""
    out_img_path = images_root / rel_path
    out_img_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(img_path, out_img_path)

    out_label_path = labels_root / rel_path.with_suffix(".txt")
    out_label_path.parent.mkdir(parents=True, exist_ok=True)
    if label_path.exists():
        shutil.copy2(label_path, out_label_path)
    else:
        # No label file existed for this image -- create an empty one so
        # the edge_cases dataset still has a matching label file.
        out_label_path.touch()


def process_dataset(input_dir: str, output_dir: str, edge_dir: str, verbose: bool = True):
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)
    edge_dir = Path(edge_dir)

    out_images_root = output_dir / "images"
    out_labels_root = output_dir / "labels"
    edge_images_root = edge_dir / "images"
    edge_labels_root = edge_dir / "labels"

    counts = {"processed": 0, "edge_stage1": 0, "edge_stage2": 0, "skipped_unreadable": 0}

    for img_path, label_path, rel_path in find_image_label_pairs(input_dir):
        image = cv2.imread(str(img_path))
        if image is None:
            print(f"[warn] could not read image, skipping: {img_path}")
            counts["skipped_unreadable"] += 1
            continue

        boxes = read_yolo_labels(label_path)

        # ---- Stage 1 ----
        half = classify_vertical_half(boxes)
        if half is None:
            # Mixed / straddling / no annotations -> original pair to edge_cases.
            copy_original_pair(img_path, label_path, edge_images_root, edge_labels_root, rel_path)
            counts["edge_stage1"] += 1
            if verbose:
                print(f"[edge:stage1] {rel_path} -> annotations not confined to one half")
            continue

        stage1_image, stage1_boxes = crop_top_bottom(image, boxes, half)

        # ---- Stage 2 ----
        stage2_image, stage2_boxes = crop_middle_three_fifths(stage1_image, stage1_boxes)

        if not stage2_boxes:
            # No annotations survive the 3/5 crop -> fall back to the
            # STAGE-1 image/labels (post top/bottom crop, pre 3/5 crop).
            save_pair(stage1_image, stage1_boxes, edge_images_root, edge_labels_root, rel_path)
            counts["edge_stage2"] += 1
            if verbose:
                print(f"[edge:stage2] {rel_path} -> no annotations survived the 3/5 crop")
            continue

        save_pair(stage2_image, stage2_boxes, out_images_root, out_labels_root, rel_path)
        counts["processed"] += 1
        if verbose:
            print(f"[ok] {rel_path} -> kept {len(stage2_boxes)}/{len(boxes)} annotations ({half} half)")

    print("\n--- Summary ---")
    print(f"Processed successfully : {counts['processed']}")
    print(f"Edge cases (stage 1)   : {counts['edge_stage1']}  (annotations spanned both halves / none present)")
    print(f"Edge cases (stage 2)   : {counts['edge_stage2']}  (all annotations removed by the 3/5 crop)")
    print(f"Skipped (unreadable)   : {counts['skipped_unreadable']}")
    print(f"Total edge cases       : {counts['edge_stage1'] + counts['edge_stage2']}")

    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input_dir", required=True, help="Root of the source YOLO dataset (flat images/+labels/, or Roboflow-style <split>/images/+<split>/labels/)")
    parser.add_argument("--output_dir", required=True, help="Root for the main processed output dataset")
    parser.add_argument("--edge_dir", required=True, help="Root for the 'edge_cases' output dataset")
    parser.add_argument("--quiet", action="store_true", help="Suppress per-file logging")
    args = parser.parse_args()

    process_dataset(args.input_dir, args.output_dir, args.edge_dir, verbose=not args.quiet)


if __name__ == "__main__":
    main()