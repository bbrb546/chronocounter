"""
algorithm2.py

All long-rest-specific processing: reading the "how many measures" number
printed on/near each detected "long rest" (digits on top) or "long rest
bottom" (digits on bottom) glyph, and turning that reading into a
measure-duration for algorithm1's measure counter.

The digits are read by cropping out the relevant half of each glyph and
running it through a dedicated Roboflow digit-detection workflow (via
roboflow_runner.get_digit_predictions), which returns one detection per
digit. Those per-digit detections are sorted left-to-right and
concatenated into the final number.
"""

import cv2

import roboflow_runner


def crop_box(image, pred, top, pad_frac=0.15):
    """Crop a prediction's bounding box out of `image`, padded slightly
    (digits sometimes sit right at the box edge), then cut down to just
    the top or bottom half -- that's where the measure-count digits sit,
    depending on whether the glyph is a "long rest" (digits on top, so
    top=True) or a "long rest bottom" (digits on bottom, top=False)."""
    h_img, w_img = image.shape[:2]
    x, y, w, h = pred["x"], pred["y"], pred["width"], pred["height"]

    pad_x = w * pad_frac
    pad_y = h * pad_frac

    x1 = int(max(0, x - w / 2 - pad_x))
    y1 = int(max(0, y - h / 2 - pad_y))
    x2 = int(min(w_img - 1, x + w / 2 + pad_x))
    y2 = int(min(h_img - 1, y + h / 2 + pad_y))

    mid_y = (y1 + y2) // 2
    if top:
        y2 = mid_y
    else:
        y1 = mid_y

    # trim the left/right fifths -- the rest bar spans the full box width,
    # but the digits are printed nearer the middle
    x_trim = (x2 - x1) // 5
    return image[y1:y2, x1 + x_trim:x2 - x_trim]


def preprocess_for_digit_detection(crop, scale=4):
    """Upscale a small crop so the digit-detection model has a better
    chance at finding and separating individual digits."""
    return cv2.resize(crop, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)


def digits_from_predictions(digit_preds, conf_threshold=0.3):
    """Combine a set of single-digit detections into the actual
    multi-digit number they represent: keep only confident-enough
    detections, sort them left-to-right by x, and concatenate each one's
    predicted digit class.

    Returns (digit_string, mean_confidence), or (None, 0.0) if nothing
    usable came back.
    """
    usable = [p for p in digit_preds if p.get("confidence", 0) >= conf_threshold]
    if not usable:
        return None, 0.0

    usable.sort(key=lambda p: p["x"])
    digits = "".join(str(p["class"]) for p in usable)

    if not digits.isdigit() or len(digits) > 3:
        return None, 0.0

    mean_conf = sum(p["confidence"] for p in usable) / len(usable)
    return digits, mean_conf


def read_number(crop, api_key):
    """Run the digit-detection workflow on a preprocessed crop and return
    the resulting (digit_string, confidence), or (None, 0.0) if nothing
    usable was found."""
    if crop.size == 0:
        return None, 0.0

    processed = preprocess_for_digit_detection(crop)
    digit_preds = roboflow_runner.get_digit_predictions(processed, api_key)
    return digits_from_predictions(digit_preds)


def ocr_annotate_long_rests(preds, image_path, api_key):
    """Mutate every "long rest" / "long rest bottom" prediction in `preds`
    IN PLACE, adding "measure_count" (digit string or None) and
    "measure_count_confidence".

    (Named "ocr_annotate..." for backwards compatibility with the rest of
    the pipeline; the actual digit-reading is now done via the Roboflow
    digit-detection workflow rather than OCR -- see read_number() above.)

    Operating in place keeps these dicts as the same objects that
    algorithm1's line-grouping will later sort into lines, so the digit
    reading travels with each detection automatically -- no re-matching
    by detection_id needed."""
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    for pred in preds:
        if pred["class"] not in ("long rest", "long rest bottom"):
            continue
        crop = crop_box(image, pred, top=(pred["class"] == "long rest"))
        digits, conf = read_number(crop, api_key)
        pred["measure_count"] = digits
        pred["measure_count_confidence"] = conf

    return preds


def duration_from_ocr(pred, default=1):
    """rest_duration_fn for algorithm1.annotate_measure_numbers() /
    to_label_strings(). Reads the digit-detection result stashed by
    ocr_annotate_long_rests(), falling back to `default` if nothing
    confident came back -- this keeps a single bad reading from crashing
    the whole measure count, at the cost of that rest's count possibly
    being wrong."""
    digits = pred.get("measure_count")
    if not digits:
        return default
    return int(digits)