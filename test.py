"""
test.py

Debug visualization for the pipeline: draws EVERY raw detection's
bounding box, with its class + confidence labeled above the box and its
assigned measure number -- plus, for long rests, the measure length read
off the glyph -- labeled below the box.

This is deliberately separate from algorithm1.draw_measure_numbers(),
which only draws one number per staff line for the real output.png; this
script is for sanity-checking that every individual detection was found,
classified, and numbered correctly.

Meant to be called from main.py (see the __main__ block there) so a
debug image gets produced alongside the normal output on every run.
"""

import cv2


def draw_debug_boxes(image, annotated_lines, box_color=(0, 255, 0),
                      text_color=(0, 0, 255), bg_color=(255, 255, 255),
                      font=cv2.FONT_HERSHEY_SIMPLEX, font_scale=0.45,
                      thickness=1):
    """Draw every detection's bounding box plus a label onto `image`.

    `annotated_lines` is the array-of-arrays produced by
    algorithm1.annotate_measure_numbers(): each element is a dict with
    keys "class", "measure_number", "detection", and (for long rests)
    "measures_spanned".

    Two labels are drawn per box, split for legibility:
      - top, just above the box:   "<class> <confidence>"
      - bottom, just below the box: "m<measure_number>", with
        " | len:<n>" appended for "long rest" / "long rest bottom"
        detections.
    Keeping the class/confidence at the top and the measure info at the
    bottom means the two never overlap each other, even when a box is
    short.

    Mutates `image` in place and also returns it.
    """
    img_h = image.shape[0]

    def draw_label(text, x1, y_anchor, above):
        """Draw `text` with its baseline at `y_anchor`, either just above
        it (above=True) or just below it (above=False), with a filled
        rect behind the text so it stays legible over packed boxes."""
        (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, thickness)
        if above:
            text_y = max(text_h + baseline, y_anchor - 4)
        else:
            text_y = min(img_h - baseline - 1, y_anchor + text_h + 4)

        cv2.rectangle(image,
                      (x1, text_y - text_h - baseline),
                      (x1 + text_w, text_y + baseline),
                      bg_color, -1)
        cv2.putText(image, text, (x1, text_y), font, font_scale,
                    text_color, thickness, cv2.LINE_AA)

    for line in annotated_lines:
        for entry in line:
            pred = entry["detection"]
            cls = entry["class"]
            measure_num = entry["measure_number"]
            conf = pred.get("confidence", 0.0)

            x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)

            cv2.rectangle(image, (x1, y1), (x2, y2), box_color, thickness)

            top_label = f"{cls} {conf:.2f}"
            bottom_label = f"m{measure_num}"
            if cls in ("long rest", "long rest bottom"):
                n = entry.get("measures_spanned")
                bottom_label += f" | len:{n if n is not None else '?'}"

            draw_label(top_label, x1, y1, above=True)
            draw_label(bottom_label, x1, y2, above=False)

    return image


def save_debug_image(image_path, annotated_lines, output_path="test_debug.png"):
    """Load `image_path` fresh, draw debug boxes for every detection in
    `annotated_lines` onto it, and save the result to `output_path`.

    Loading a fresh copy (rather than reusing main.py's already-annotated
    image) keeps the two outputs independent, so this debug view isn't
    cluttered by, or dependent on, the real measure-number drawing.
    """
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    draw_debug_boxes(image, annotated_lines)
    cv2.imwrite(output_path, image)
    return output_path