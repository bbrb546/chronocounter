"""
main.py

Runs the full pipeline end-to-end:

  1. Send the input image to Roboflow to get raw detections
     (roboflow_runner).
  2. OCR-read the measure counts printed on long-rest glyphs (algorithm2).
  3. Group detections into staff lines and number the measures
     (algorithm1).
  4. Draw the resulting measure numbers onto the image  -> output.png
  5. Save per-line, JSON-ready detections               -> predictions.json
  6. Draw a per-detection debug view (box, confidence,
     measure number, rest length)                       -> test_debug.png
     (see test.py)

output.png and predictions.json are the pipeline's real outputs;
test_debug.png is only for sanity-checking a run during development.
"""

import argparse
import json

import cv2

import algorithm1
import algorithm2
import roboflow_runner
import test

IMAGE_PATH = "test/test.png"
OUTPUT_IMAGE_PATH = "output.png"
OUTPUT_JSON_PATH = "predictions.json"
DEBUG_IMAGE_PATH = "test_debug.png"


def parse_args():
    """Parse command-line arguments for the input image and output paths.
    Each output path falls back to its module-level default (output.png,
    predictions.json, test_debug.png) if not supplied."""
    parser = argparse.ArgumentParser(
        description="Run the measure-numbering pipeline on a sheet-music image."
    )
    parser.add_argument(
        "image_path",
        nargs="?",
        default=IMAGE_PATH,
        help=f"Path to the input image (default: {IMAGE_PATH})",
    )
    parser.add_argument(
        "-a", "--api-key",
        dest="api_key",
        help="Roboflow API key",
    )
    parser.add_argument(
        "-o", "--output-image",
        dest="output_image_path",
        default=OUTPUT_IMAGE_PATH,
        help=f"Path to write the annotated output image (default: {OUTPUT_IMAGE_PATH})",
    )
    parser.add_argument(
        "-j", "--output-json",
        dest="output_json_path",
        default=OUTPUT_JSON_PATH,
        help=f"Path to write the predictions JSON (default: {OUTPUT_JSON_PATH})",
    )
    parser.add_argument(
        "-d", "--debug-image",
        dest="debug_image_path",
        default=DEBUG_IMAGE_PATH,
        help=f"Path to write the per-detection debug image (default: {DEBUG_IMAGE_PATH})",
    )
    parser.add_argument(
        "--initial-measure-number",
        type=int,
        default=1,
        help="Measure number of the first bar or long rest on this page (default: 1)",
    )

    return parser.parse_args()


def _annotate_image(image_path, api_key, initial_measure_number=1):
    """Process an image and return internal annotations for rendering/export."""
    preds = roboflow_runner.get_predictions(image_path, api_key)

    other_preds = [p for p in preds if p["class"] != "ending"]  # ignore endings for now

    lines = algorithm1.group_into_lines(other_preds)
    lines = algorithm1.merge_close_lines(lines)
    lines = algorithm1.remove_doubled_long_rests(lines)

    # Read long-rest durations after split detections have been merged.
    algorithm2.ocr_annotate_long_rests(
        [pred for line in lines for pred in line], image_path, api_key
    )

    return algorithm1.annotate_measure_numbers(
        lines, algorithm2.duration_from_ocr, initial_measure_number
    )


def serialize_detections(annotated_lines):
    """Convert internal annotations to JSON-compatible staff lines.

    Each detection has a class, pixel-space bounding box (x/y are the
    center; width/height are its size), and measure_number. Long rests
    additionally have measures_spanned as an integer, including OCR fallback.
    """
    return [
        [
            {
                "class": entry["class"],
                "x": entry["detection"]["x"],
                "y": entry["detection"]["y"],
                "width": entry["detection"]["width"],
                "height": entry["detection"]["height"],
                "measure_number": entry["measure_number"],
                **({"measures_spanned": entry["measures_spanned"]}
                   if "measures_spanned" in entry else {}),
            }
            for entry in line
        ]
        for line in annotated_lines
    ]


def run_pipeline(image_path, api_key, initial_measure_number=1):
    """Return top-to-bottom staff lines of left-to-right JSON-ready detections.

    initial_measure_number labels the first bar or long rest, so a new
    page can start at the same measure number where the previous page ended.
    This function has no output-file side effects; a future API handler can
    return its result directly as JSON. image_path is a local image file.
    """
    return serialize_detections(
        _annotate_image(image_path, api_key, initial_measure_number)
    )


if __name__ == "__main__":
    args = parse_args()

    annotated = _annotate_image(
        args.image_path, args.api_key, args.initial_measure_number
    )

    image = cv2.imread(args.image_path)
    algorithm1.draw_measure_numbers(image, annotated)
    cv2.imwrite(args.output_image_path, image)

    with open(args.output_json_path, "w", encoding="utf-8") as f:
        json.dump(serialize_detections(annotated), f, indent=2, ensure_ascii=False)

    # Debug view: every individual detection's box, confidence, measure
    # number, and (for long rests) measure length -- for sanity-checking
    # a run beyond what output.png / predictions.json show.
    test.save_debug_image(args.image_path, annotated, args.debug_image_path)