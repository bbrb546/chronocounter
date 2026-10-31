"""
test.py

Debug visualization for the pipeline: creates a main test_debug.png
image with every detection's bounding box, class, confidence, duration
(if applicable), and measure number; a test_lines.png image showing
detections grouped by staff line by color; and a test_long_rests.png image showing 
only long rests with their durations.

Meant to be called from main.py (see the __main__ block there) so a
debug image gets produced alongside the normal output on every run.
"""

import cv2

import algorithm1

# BGR colors, one per class (same convention as roboflow_workflow_json_add.py)
CLASS_COLORS = {
    "bar": (0, 255, 0),                 # Green
    "long rest": (255, 0, 0),           # Blue
    "long rest bottom": (255, 255, 0),  # Cyan
    "repeat bar": (0, 0, 255),          # Red
    "double bar": (255, 0, 255),        # Magenta
}
DEFAULT_COLOR = (0, 255, 255)           # Yellow, for any unknown class


def draw_debug_boxes(image, annotated_lines, colors=None,
                      text_color=(0, 0, 0),
                      font=cv2.FONT_HERSHEY_SIMPLEX, font_scale=0.55,
                      box_thickness=2, text_thickness=2,
                      draw_line_numbers=True):
    """Draw every detection's bounding box plus labels onto `image`, and
    (unless draw_line_numbers is False) each staff line's starting measure
    number at the left edge.

    `annotated_lines` is the array-of-arrays produced by
    algorithm1.annotate_measure_numbers(): each element is a dict with
    keys "class", "measure_number", "detection", and (for long rests)
    "measures_spanned".

    Each box is drawn in its class color (see CLASS_COLORS; pass `colors`
    to override). Two labels are drawn per box, each on a filled strip of
    the same color with black text:
      - top, just above the box:   "<class> <confidence>"
      - bottom, just below the box: "m<measure_number>", with
        " | len:<n>" appended for "long rest" / "long rest bottom"
        detections.

    The line-start numbers come from algorithm1.draw_measure_numbers, so
    they match output.png exactly. They are drawn last so the boxes and
    label strips never cover them.

    Mutates `image` in place and also returns it.
    """
    colors = CLASS_COLORS if colors is None else colors
    img_h, img_w = image.shape[:2]

    def draw_label(text, x1, y_edge, above, color):
        """Draw `text` on a filled strip of `color`, attached to the box
        edge at `y_edge` -- just above it (above=True) or just below it
        (above=False). The strip is nudged to stay inside the image."""
        (tw, th), baseline = cv2.getTextSize(text, font, font_scale, text_thickness)
        strip_w = tw + 6
        strip_h = th + baseline + 6

        left = max(0, min(x1, img_w - strip_w))
        if above:
            top = max(0, y_edge - strip_h)
        else:
            top = min(y_edge, img_h - strip_h)
        top = max(0, top)

        cv2.rectangle(image, (left, top), (left + strip_w, top + strip_h),
                      color, -1)
        cv2.putText(image, text, (left + 3, top + 3 + th), font, font_scale,
                    text_color, text_thickness, cv2.LINE_AA)

    for line in annotated_lines:
        for entry in line:
            pred = entry["detection"]
            cls = entry["class"]
            measure_num = entry["measure_number"]
            conf = pred.get("confidence", 0.0)
            color = colors.get(cls, DEFAULT_COLOR)

            x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)

            # Clamp to image bounds
            x1 = max(0, min(x1, img_w - 1))
            y1 = max(0, min(y1, img_h - 1))
            x2 = max(0, min(x2, img_w - 1))
            y2 = max(0, min(y2, img_h - 1))

            cv2.rectangle(image, (x1, y1), (x2, y2), color, box_thickness)

            top_label = f"{cls} {conf:.2f}"
            bottom_label = f"m{measure_num}"
            if cls in ("long rest", "long rest bottom"):
                n = entry.get("measures_spanned")
                bottom_label += f" | len:{n if n is not None else '?'}"

            draw_label(top_label, x1, y1, above=True, color=color)
            draw_label(bottom_label, x1, y2, above=False, color=color)

    if draw_line_numbers:
        # Same call main.py makes for output.png: one number per staff
        # line, at the left edge, vertically centred on the line.
        algorithm1.draw_measure_numbers(image, annotated_lines)

    return image


def save_debug_image(image_path, annotated_lines, output_path="test_debug.png",
                     draw_line_numbers=True):
    """Load `image_path` fresh, draw debug boxes (and, by default, the
    line-start measure numbers) for every detection in `annotated_lines`
    onto it, and save the result to `output_path`.

    Loading a fresh copy (rather than reusing main.py's already-annotated
    image) keeps this image independent of output.png: the line numbers
    are drawn here by the same function, not carried over from it.
    """
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    draw_debug_boxes(image, annotated_lines, draw_line_numbers=draw_line_numbers)
    cv2.imwrite(output_path, image)
    return output_path

# Distinct BGR colors, chosen to stay clearly different from their
# neighbours in the palette so adjacent lines never look alike. Lines
# beyond len(LINE_COLORS) wrap around and reuse colors in order.
LINE_COLORS = [
    (0, 0, 230),      # red
    (230, 120, 0),    # blue
    (0, 170, 0),      # green
    (0, 140, 255),    # orange
    (200, 0, 200),    # magenta
    (200, 200, 0),    # cyan
    (0, 200, 220),    # yellow
    (130, 0, 80),     # purple
]

def draw_line_group_boxes(image, lines, colors=LINE_COLORS, thickness=3):
    """Draw only each detection's bounding box, colored by its line.

    `lines` is either the output of algorithm1.annotate_measure_numbers()
    (entries are dicts with a "detection" key) or the raw output of
    algorithm1.group_into_lines() (entries are the detection dicts
    themselves), so the grouping can be inspected at either stage.

    All boxes in one line share a color; line i uses colors[i % len(colors)],
    so colors repeat in order for pages with more lines than colors. No
    text of any kind is drawn.

    Mutates `image` in place and also returns it.
    """
    for line_idx, line in enumerate(lines):
        color = colors[line_idx % len(colors)]
        for entry in line:
            pred = entry["detection"] if "detection" in entry else entry

            x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)

            cv2.rectangle(image, (x1, y1), (x2, y2), color, thickness)

    return image


def save_line_group_image(image_path, lines, output_path="test_lines.png"):
    """Load `image_path` fresh, draw the line-grouping boxes for `lines`
    onto it (see draw_line_group_boxes), and save to `output_path`."""
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    draw_line_group_boxes(image, lines)
    cv2.imwrite(output_path, image)
    return output_path


LONG_REST_COLORS = {
    "long rest": (0, 168, 0),          # green  (digits on top)
    "long rest bottom": (200, 120, 0), # blue   (digits on bottom)
}


def draw_long_rest_boxes(image, lines, colors=LONG_REST_COLORS, thickness=3):
    """Draw ONLY the long-rest detections' bounding boxes, with no text and
    no other detection types.

    Bars, repeat bars, double bars and anything else are skipped entirely.
    "long rest" and "long rest bottom" get different colors (see
    LONG_REST_COLORS) so you can tell which glyph variant was detected and
    therefore which half of the box the digit reader crops.

    `lines` can be annotated output (entries have a "detection" key) or raw
    group_into_lines() output (entries are the detection dicts).

    Mutates `image` in place and also returns it.
    """
    for line in lines:
        for entry in line:
            pred = entry["detection"] if "detection" in entry else entry
            color = colors.get(pred["class"])
            if color is None:
                continue

            x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)

            cv2.rectangle(image, (x1, y1), (x2, y2), color, thickness)

    return image


def save_long_rest_image(image_path, lines, output_path="test_long_rests.png"):
    """Load `image_path` fresh, draw only the long-rest boxes for `lines`
    onto it (see draw_long_rest_boxes), and save to `output_path`."""
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    draw_long_rest_boxes(image, lines)
    cv2.imwrite(output_path, image)
    return output_path


LONG_REST_CLASSES = ("long rest", "long rest bottom")


def draw_long_rest_boxes(image, lines, box_color=(0, 170, 0),
                         text_color=(255, 255, 255), bg_color=(0, 110, 0),
                         font=cv2.FONT_HERSHEY_SIMPLEX, font_scale=1.0,
                         thickness=3, text_thickness=2):
    """Draw ONLY long-rest detections: a box plus its duration in measures.

    Bars, repeat bars, double bars and everything else are skipped, and
    no class, confidence or measure-number text is drawn. Each long
    rest's duration is shown as "x<n>" on a filled tag just above its box
    (moved inside the box if it would run off the top of the image).

    `lines` is the annotated output of algorithm1.annotate_measure_numbers(),
    which carries "measures_spanned" (the value actually used for
    numbering, including the fallback). For raw, un-annotated lines the
    duration falls back to the detection's "measure_count" digit string,
    and shows "?" if neither is available.

    Mutates `image` in place and also returns it.
    """
    for line in lines:
        for entry in line:
            is_annotated = "detection" in entry
            pred = entry["detection"] if is_annotated else entry
            cls = entry["class"] if is_annotated else pred["class"]
            if cls not in LONG_REST_CLASSES:
                continue

            n = entry.get("measures_spanned") if is_annotated else None
            if n is None:
                n = pred.get("measure_count")
            label = f"{n if n is not None else '?'}"

            x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)
            cv2.rectangle(image, (x1, y1), (x2, y2), box_color, thickness)

            (tw, th), baseline = cv2.getTextSize(label, font, font_scale, text_thickness)
            tag_top = y1 - th - baseline - 6
            if tag_top < 0:
                tag_top = y1 + 2  # no room above: put the tag inside the box
            tag_bottom = tag_top + th + baseline + 6
            cv2.rectangle(image, (x1, tag_top), (x1 + tw + 8, tag_bottom),
                          bg_color, -1)
            cv2.putText(image, label, (x1 + 4, tag_bottom - baseline - 3),
                        font, font_scale, text_color, text_thickness, cv2.LINE_AA)

    return image


def save_long_rest_image(image_path, lines, output_path="test_long_rests.png"):
    """Load `image_path` fresh, draw only the long rests and their
    durations (see draw_long_rest_boxes), and save to `output_path`."""
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    draw_long_rest_boxes(image, lines)
    cv2.imwrite(output_path, image)
    return output_path

