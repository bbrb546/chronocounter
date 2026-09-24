"""
main.py

Runs the full pipeline end-to-end:

  1. Send the input image to Roboflow to get raw detections
     (roboflow_runner).
  2. OCR-read the measure counts printed on long-rest glyphs (algorithm2).
  3. Group detections into staff lines and number the measures
     (algorithm1).
  4. Draw the resulting measure numbers onto the image  -> output.png
  5. Save the per-line label strings                    -> predictions.json
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
    
    return parser.parse_args()


def run_pipeline(image_path, api_key):
    """Run the full detection -> line-grouping -> measure-numbering
    pipeline on `image_path`.

    Returns (labels, annotated):
      - labels: list of lines, each a list of class-name strings (long
        rests tagged as "long rest:<n_measures>")
      - annotated: same shape, each element a dict of
        {"class", "measure_number", "detection", ...}
    """
    preds = roboflow_runner.get_predictions(image_path, api_key)

    ending_preds = [p for p in preds if p["class"] == "ending"]
    other_preds = [p for p in preds if p["class"] != "ending"]

    lines = algorithm1.group_into_lines(other_preds)
    lines = algorithm1.merge_close_lines(lines)
    lines = algorithm1.remove_doubled_long_rests(lines)
    #lines = algorithm1.insert_endings(lines, ending_preds) # ignoring endings for now

    # Read long-rest durations after split detections have been merged.
    algorithm2.ocr_annotate_long_rests(
        [pred for line in lines for pred in line], image_path, api_key
    )

    labels = algorithm1.to_label_strings(lines, algorithm2.duration_from_ocr)
    annotated = algorithm1.annotate_measure_numbers(lines, algorithm2.duration_from_ocr)

    return labels, annotated


if __name__ == "__main__":
    args = parse_args()

    labels, annotated = run_pipeline(args.image_path, args.api_key)

    image = cv2.imread(args.image_path)
    algorithm1.draw_measure_numbers(image, annotated)
    cv2.imwrite(args.output_image_path, image)

    with open(args.output_json_path, "w", encoding="utf-8") as f:
        json.dump(labels, f, indent=2, ensure_ascii=False)

    # Debug view: every individual detection's box, confidence, measure
    # number, and (for long rests) measure length -- for sanity-checking
    # a run beyond what output.png / predictions.json show.
    test.save_debug_image(args.image_path, annotated, args.debug_image_path)