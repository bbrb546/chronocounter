"""
algorithm1.py

All detection post-processing EXCEPT long-rest duration reading:

  - group_into_lines / merge_close_lines: turn a flat list of detections
    into left-to-right, top-to-bottom staff lines (robust to page skew).
  - insert_endings: reattach "ending" bracket detections -- poor anchors
    for line-fitting -- back into the correct line.
  - annotate_measure_numbers / to_label_strings: walk the lines in reading
    order and tag each detection with its measure number.
  - draw_measure_numbers: render each line's starting measure number onto
    the source image, just to the left of the staff.

annotate_measure_numbers() and to_label_strings() both take a
rest_duration_fn callback (how many measures a "long rest" glyph spans),
so this file has no dependency on how that number is actually determined
-- see algorithm2.py for the OCR-based implementation.
"""

import math
import random

import cv2


def perp_distance(pt, p1, p2):
    """Perpendicular distance from `pt` to the infinite line through p1, p2."""
    (x0, y0), (x1, y1), (x2, y2) = pt, p1, p2
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x0 - x1, y0 - y1)
    t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)
    projx, projy = x1 + t * dx, y1 + t * dy
    return math.hypot(x0 - projx, y0 - projy)


def group_into_lines(preds, y_window=60, dist_thresh=None, ransac_iters=200,
                      min_line_size=2, seed=0):
    """Group detections into staff lines using RANSAC line-fitting within
    small y-windows, so the result stays robust to slight page skew.
    Returns a list of lines, each a list of pred dicts sorted left-to-right,
    with the lines themselves ordered top-to-bottom.
    """
    rng = random.Random(seed)
    pts = [(p["x"], p["y"], p) for p in preds]
    heights = [p["height"] for p in preds]
    if dist_thresh is None:
        heights_sorted = sorted(heights)
        dist_thresh = heights_sorted[len(heights_sorted) // 2] * 0.5  # half of median box height

    remaining = pts[:]
    lines = []

    while remaining:
        remaining.sort(key=lambda t: t[1])  # sort by y
        seedpt = remaining[0]
        window = [t for t in remaining if abs(t[1] - seedpt[1]) <= y_window]
        if len(window) < 2:
            lines.append([seedpt])
            remaining.remove(seedpt)
            continue

        best_inliers = None
        for _ in range(ransac_iters):
            a, b = rng.sample(window, 2)
            if a[0] == b[0]:
                continue
            (ax, ay, _), (bx, by, _) = a, b
            inliers = [t for t in window if perp_distance((t[0], t[1]), (ax, ay), (bx, by)) <= dist_thresh]
            if best_inliers is None or len(inliers) > len(best_inliers):
                best_inliers = inliers

        if best_inliers is None or len(best_inliers) < min_line_size:
            best_inliers = [seedpt]

        lines.append(best_inliers)
        used_ids = set(id(t) for t in best_inliers)
        remaining = [t for t in remaining if id(t) not in used_ids]

    result = []
    for line in lines:
        line_sorted = sorted(line, key=lambda t: t[0])
        mean_y = sum(t[1] for t in line) / len(line)
        result.append((mean_y, [t[2] for t in line_sorted]))
    result.sort(key=lambda r: r[0])
    return [r[1] for r in result]


def merge_close_lines(lines, merge_frac=0.5):
    """Merge line-groups whose mean-y is closer together than merge_frac *
    the median spacing between consecutive lines -- fixes over-segmentation
    at line boundaries (stray/ambiguous points forming tiny "lines")."""
    if len(lines) < 3:
        return lines
    means = [sum(p["y"] for p in line) / len(line) for line in lines]
    gaps = sorted(means[i + 1] - means[i] for i in range(len(means) - 1))
    threshold = gaps[len(gaps) // 2] * merge_frac

    merged = [lines[0]]
    merged_means = [means[0]]
    for line, m in zip(lines[1:], means[1:]):
        if m - merged_means[-1] < threshold:
            merged[-1] = merged[-1] + line
            merged[-1].sort(key=lambda p: p["x"])
            merged_means[-1] = sum(p["y"] for p in merged[-1]) / len(merged[-1])
        else:
            merged.append(line)
            merged_means.append(m)
    return merged


def insert_endings(lines, ending_preds):
    """Assign each "ending" detection to the line containing the closest
    detection that lies below it, then insert it into that line in
    left-to-right order.

    "ending" boxes sit above their staff line and are unusually wide/short,
    which makes them poor anchors for line-fitting -- they're excluded from
    group_into_lines and reattached here instead."""
    id_to_line = {}
    for i, line in enumerate(lines):
        for p in line:
            id_to_line[id(p)] = i

    for ending in ending_preds:
        ex, ey = ending["x"], ending["y"]

        candidates = [p for line in lines for p in line if p["y"] > ey]
        if not candidates:
            # fallback: nothing below it anywhere (e.g. ending on the very
            # last line) -- use the closest detection overall
            candidates = [p for line in lines for p in line]
        if not candidates:
            continue  # no other detections at all; nothing to attach to

        closest = min(candidates, key=lambda p: math.hypot(p["x"] - ex, p["y"] - ey))
        target_idx = id_to_line[id(closest)]

        lines[target_idx].append(ending)
        lines[target_idx].sort(key=lambda p: p["x"])
        id_to_line[id(ending)] = target_idx

    return lines


def annotate_measure_numbers(lines, rest_duration_fn):
    """Walk the line-grouped detections in reading order, tagging each with
    its measure number.

    Convention:
      - "bar" / "repeat bar" / "double bar" mark the END of a measure, so
        the running counter increments by 1 right after one is seen.
      - "long rest" / "long rest bottom" represent a multi-measure rest: it
        is stamped with the measure number it STARTS at, and the counter
        jumps forward by rest_duration_fn(pred) instead of by 1.
      - anything else is tagged with the current measure number but does
        not advance the counter.

    Returns the same array-of-arrays shape, with each pred dict replaced by
    {"class": ..., "measure_number": ..., "detection": pred_dict}.
    """
    measure_num = 0
    annotated = []
    pcls = "fpbar" # pretend a "fake previous bar" was seen before the first line
    for line in lines:
        line_out = []
        for p in line:
            
            cls = p["class"]
            if cls in ("long rest", "long rest bottom"):
                if pcls == "fpbar":
                    measure_num += 1
                entry = {"class": cls, "measure_number": measure_num, "detection": p}
                n = rest_duration_fn(p)
                entry["measures_spanned"] = n
                measure_num += n
            elif cls in ("bar", "repeat bar", "double bar") and pcls in ("bar", "repeat bar", "double bar", "pbar", "fpbar"):
                measure_num += 1
                entry = {"class": cls, "measure_number": measure_num, "detection": p}
            elif cls in ("bar", "repeat bar", "double bar"):
                entry = {"class": cls, "measure_number": measure_num, "detection": p}
            
            line_out.append(entry)

            pcls = cls

        pcls = "pbar"
        annotated.append(line_out)
    return annotated


def to_label_strings(lines, rest_duration_fn):
    """Simplified string-based view: same array-of-arrays shape, each
    element replaced by its class name, with long rests tagged as
    "long rest:<n_measures>"."""
    output = []
    for line in lines:
        line_out = []
        for p in line:
            if p["class"] in ("long rest", "long rest bottom"):
                n = rest_duration_fn(p)
                line_out.append(f"{p['class']}:{n}")
            else:
                line_out.append(p["class"])
        output.append(line_out)
    return output


def draw_measure_numbers(image, annotated_lines, font=cv2.FONT_HERSHEY_SIMPLEX,
                          font_scale=0.8, color=(0, 0, 0), thickness=2, gap=15):
    """Draw each staff line's starting measure number onto `image`, just to
    the left of that line, vertically centered on its detections. Mutates
    `image` in place and also returns it."""
    for line in annotated_lines:
        if not line:
            continue
        measure_num = line[0]["measure_number"]
        detections = [entry["detection"] for entry in line]
        text_y = int(sum(d["y"] for d in detections) / len(detections))
        leftmost_x = int(min(d["x"] - d["width"] / 2 for d in detections))

        text = str(measure_num)
        (text_w, text_h), _ = cv2.getTextSize(text, font, font_scale, thickness)
        text_x = max(0, leftmost_x - text_w - gap)

        cv2.putText(image, text, (text_x, text_y + text_h // 2),
                    font, font_scale, color, thickness, cv2.LINE_AA)

    return image
