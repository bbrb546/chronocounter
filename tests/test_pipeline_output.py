"""Offline checks for the JSON-ready pipeline result (no Roboflow calls)."""

import json
import sys
import unittest
from unittest.mock import MagicMock, patch

# The processing tests mock network and image I/O, so native/API packages
# are not required to run them locally.
with patch.dict(sys.modules, {"cv2": MagicMock(), "inference_sdk": MagicMock()}):
    import main


def detection(cls, x):
    return {"class": cls, "x": x, "y": 50, "width": 10, "height": 20,
            "confidence": 0.9}


class PipelineOutputTests(unittest.TestCase):
    def test_empty_page(self):
        with patch.object(main.roboflow_runner, "get_predictions", return_value=[]), \
             patch.object(main.algorithm2, "ocr_annotate_long_rests") as ocr:
            result = main.run_pipeline("image.png", "key")
        self.assertEqual(result, [])
        ocr.assert_called_once()

    def test_initial_number_continues_across_pages(self):
        previous_page = [detection("bar", 10), detection("bar", 30)]
        next_page = [detection("other", 5), detection("bar", 10),
                     detection("bar", 30)]
        with patch.object(main.roboflow_runner, "get_predictions",
                          side_effect=[previous_page, next_page]), \
             patch.object(main.algorithm2, "ocr_annotate_long_rests"):
            last_page = main.run_pipeline("previous.png", "key", 31)
            next_page = main.run_pipeline("next.png", "key", 32)
        self.assertEqual([p["measure_number"] for p in last_page[0]], [31, 32])
        self.assertEqual([p["measure_number"] for p in next_page[0]], [32, 32, 33])

    def test_initial_long_rest_and_cli_option(self):
        lines = [[detection("long rest bottom", 10), detection("bar", 30)]]
        lines[0][0]["measure_count"] = "3"
        annotated = main.algorithm1.annotate_measure_numbers(
            lines, main.algorithm2.duration_from_ocr, initial_measure_number=47
        )
        self.assertEqual([p["measure_number"] for p in annotated[0]], [47, 50])
        with patch.object(sys, "argv", ["main.py", "page.png",
                                        "--initial-measure-number", "47"]):
            self.assertEqual(main.parse_args().initial_measure_number, 47)

    def test_json_detections_and_rest_fallback(self):
        preds = [detection("bar", 10), detection("long rest", 30),
                 detection("bar", 50), detection("other", 70)]

        def fake_ocr(lines, image_path, api_key):
            self.assertEqual((image_path, api_key), ("image.png", "key"))
            lines[1]["measure_count"] = "4"

        with patch.object(main.roboflow_runner, "get_predictions", return_value=preds), \
             patch.object(main.algorithm2, "ocr_annotate_long_rests", side_effect=fake_ocr):
            result = main.run_pipeline("image.png", "key")

        self.assertEqual([p["class"] for p in result[0]],
                         ["bar", "long rest", "bar", "other"])
        self.assertEqual([p["measure_number"] for p in result[0]], [1, 1, 5, 5])
        self.assertEqual(result[0][1]["measures_spanned"], 4)
        self.assertEqual(result[0][1]["x"], 30)
        self.assertEqual(result[0][1]["width"], 10)
        self.assertNotIn("measures_spanned", result[0][0])
        self.assertNotIn("confidence", result[0][0])
        self.assertNotIn("detection", result[0][0])
        self.assertEqual(json.loads(json.dumps(result)), result)

        # Failed digit detection still yields an integer duration.
        self.assertEqual(main.serialize_detections(
            main.algorithm1.annotate_measure_numbers(
                [[detection("long rest bottom", 10)]],
                main.algorithm2.duration_from_ocr
            )
        )[0][0]["measures_spanned"], 1)


if __name__ == "__main__":
    unittest.main()
