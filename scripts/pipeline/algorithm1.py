"""
algorithm1.py

All detection post-processing EXCEPT long-rest duration reading:

  - group_into_lines / merge_close_lines: turn a flat list of detections
    into left-to-right, top-to-bottom staff lines (robust to page skew).
    THIS VERSION uses deterministic line-intersection grouping instead of
    RANSAC: see group_into_lines.
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

import cv2


LONG_REST_CLASSES = ('long rest', 'long rest bottom')


DEFAULT_MAX_SLOPE = math.tan(math.radians(15))  # steepest line we will believe


def _boxes_hit_by_line(boxes, anchor, slope, tolerance=0.0):
    """Return every box in `boxes` that the non-vertical line through the
    centre of `anchor` with the given slope (dy/dx) passes through.

    A box is hit when the line's y-range across the box's left..right edges
    overlaps the box's top..bottom edges. `tolerance` grows each box by that
    many pixels on every side."""
    ax, ay = anchor["x"], anchor["y"]
    hits = []
    for p in boxes:
        left = p["x"] - p["width"] / 2 - tolerance
        right = p["x"] + p["width"] / 2 + tolerance
        top = p["y"] - p["height"] / 2 - tolerance
        bottom = p["y"] + p["height"] / 2 + tolerance
        y_left = ay + slope * (left - ax)
        y_right = ay + slope * (right - ax)
        if min(y_left, y_right) <= bottom and max(y_left, y_right) >= top:
            hits.append(p)
    return hits


def group_into_lines(preds, y_window=None, max_slope=DEFAULT_MAX_SLOPE,
                      tolerance=0.0, min_dx=1.0):
    """Group detections into staff lines by repeatedly drawing a line
    through a pair of boxes and claiming every box that line crosses.

    Each round:
      1. Take the topmost remaining box as the seed.
      2. Collect the remaining boxes whose centre y is within `y_window` of
         the seed's (default: the median box height) -- the candidates.
      3. For every pair of candidates, draw a line through their centres.
         Skip pairs that are nearly vertically stacked (|dx| < min_dx) or
         whose line is steeper than `max_slope` (default 15 degrees).
      4. Count how many REMAINING boxes (not just candidates, so a skewed
         line is followed across the whole page) each line passes through.
      5. The line crossing the most boxes wins (ties go to the flatter
         line). Every box it crosses becomes one staff line and is removed.
    Rounds repeat until nothing remains. A seed with no valid pair becomes
    a one-box line.

    Fully deterministic: no random sampling. Returns a list of lines, each
    a list of pred dicts sorted left-to-right, ordered top-to-bottom.
    """
    if not preds:
        return []
    if y_window is None:
        heights = sorted(p["height"] for p in preds)
        y_window = heights[len(heights) // 2]  # median box height

    remaining = list(preds)
    lines = []

    while remaining:
        remaining.sort(key=lambda p: p["y"])
        seed = remaining[0]
        window = [p for p in remaining if abs(p["y"] - seed["y"]) <= y_window]

        best_hits, best_key = None, None
        for i in range(len(window)):
            for j in range(i + 1, len(window)):
                a, b = window[i], window[j]
                dx = b["x"] - a["x"]
                if abs(dx) < min_dx:
                    continue
                slope = (b["y"] - a["y"]) / dx
                if abs(slope) > max_slope:
                    continue
                hits = _boxes_hit_by_line(remaining, a, slope, tolerance)
                key = (len(hits), -abs(slope))
                if best_key is None or key > best_key:
                    best_hits, best_key = hits, key

        if not best_hits:
            best_hits = [seed]

        lines.append(best_hits)
        used = {id(p) for p in best_hits}
        remaining = [p for p in remaining if id(p) not in used]

    result = []
    for line in lines:
        line_sorted = sorted(line, key=lambda p: p["x"])
        mean_y = sum(p["y"] for p in line) / len(line)
        result.append((mean_y, line_sorted))
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


def remove_doubled_long_rests(lines):
    """Merge consecutive same-type long-rest detections within each staff
    line when no bar separates them.

    A very wide rest can occasionally be detected as two boxes.  Because
    lines are ordered left-to-right, consecutive matching long-rest classes
    represent such a split unless a bar-like detection occurs between them.
    The replacement box is the union of the two boxes, allowing downstream
    OCR to read the duration from the complete glyph.
    """
    long_rest_classes = ("long rest", "long rest bottom")
    bar_classes = ("bar", "repeat bar", "double bar")

    for line in lines:
        merged_line = []
        for pred in line:
            if (
                merged_line
                and pred["class"] in long_rest_classes
                and merged_line[-1]["class"] == pred["class"]
                and merged_line[-1]["class"] not in bar_classes
            ):
                previous = merged_line[-1]
                x1 = min(previous["x"] - previous["width"] / 2,
                         pred["x"] - pred["width"] / 2)
                y1 = min(previous["y"] - previous["height"] / 2,
                         pred["y"] - pred["height"] / 2)
                x2 = max(previous["x"] + previous["width"] / 2,
                         pred["x"] + pred["width"] / 2)
                y2 = max(previous["y"] + previous["height"] / 2,
                         pred["y"] + pred["height"] / 2)
                previous["x"] = (x1 + x2) / 2
                previous["y"] = (y1 + y2) / 2
                previous["width"] = x2 - x1
                previous["height"] = y2 - y1
            else:
                merged_line.append(pred)
        line[:] = merged_line

    return lines


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


def annotate_measure_numbers(lines, rest_duration_fn, initial_measure_number=1):
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

    `initial_measure_number` is the number given to the page's first bar, or
    the number a leading long rest starts at. The caller chooses it; the
    Chronocounter app sends a provisional value and renumbers locally (see
    its SPEC section 4).

    Returns the same array-of-arrays shape, with each pred dict replaced by
    {"class": ..., "measure_number": ..., "detection": pred_dict}.
    """
    measure_num = initial_measure_number
    first_counted_detection = True
    annotated = []
    pcls = "fpbar" # pretend a "fake previous bar" was seen before the first line
    for line in lines:
        line_out = []
        for p in line:
            cls = p["class"]
            entry = {"class": cls, "measure_number": measure_num, "detection": p}
            if cls in ("long rest", "long rest bottom"):
                first_counted_detection = False
                n = rest_duration_fn(p)
                entry["measures_spanned"] = n
                measure_num += n
            elif cls in ("bar", "repeat bar", "double bar"):
                if not first_counted_detection and pcls in (
                    "bar", "repeat bar", "double bar", "pbar", "fpbar"
                ):
                    measure_num += 1
                entry["measure_number"] = measure_num
                first_counted_detection = False

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


def end_measure(entry):
    """Measure number in force immediately AFTER this detection.
    A long rest is stamped with the measure it STARTS at, so add the
    measures it spans; anything else already carries the right number."""
    n = entry.get('measures_spanned')
    if entry['class'] in LONG_REST_CLASSES and n:
        return entry['measure_number'] + n
    return entry['measure_number']


def draw_measure_numbers(image, annotated_lines, font=cv2.FONT_HERSHEY_SIMPLEX,
                          font_scale=0.8, color=(0, 0, 0), thickness=2, gap=15):
    """Draw each line's starting measure number near the image's left
    edge, vertically aligned with that line. On the first line the
    number is the first detection's number minus 1, unless that
    detection is a long rest (then its own number). On every later
    line it is end_measure() of the rightmost detection of the
    preceding line (start + span if that detection is a long rest).
    Mutates `image` in place and also returns it."""
    previous_end_measure_num = None
    for line in annotated_lines:
        if not line:
            continue

        detections = [entry["detection"] for entry in line]
        text_y = int(sum(d["y"] for d in detections) / len(detections))
        first = line[0]
        if previous_end_measure_num is not None:
            measure_num = previous_end_measure_num
        elif first['class'] in LONG_REST_CLASSES:
            measure_num = first['measure_number']
        else:
            measure_num = first['measure_number'] - 1

        text = str(measure_num)
        (_, text_h), _ = cv2.getTextSize(text, font, font_scale, thickness)
        text_x = gap

        cv2.putText(image, text, (text_x, text_y + text_h // 2),
                    font, font_scale, color, thickness, cv2.LINE_AA)

        previous_end_measure_num = end_measure(
            max(line, key=lambda entry: entry["detection"]["x"])
        )

    return image