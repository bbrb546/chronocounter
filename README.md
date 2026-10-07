# chronocounter
A computer-vision based pipeline to automatically count measures for music.

## Pipeline output

`main.run_pipeline(image_path, api_key, initial_measure_number=1)` accepts a
local image path and a Roboflow API key and returns a JSON-serializable array
of staff lines (top to bottom). Each line is an array of detections (left to
right). `initial_measure_number` labels the first bar or long rest on the
page; use the previous page's final bar number if that measure continues onto
the next page. It defaults to 1. The function does not
write output files, so an API endpoint can return the result directly. An
HTTP upload handler will need to save the image to a temporary file before
calling it; no API handler is included yet.

Each detection has `class`, `x`, `y`, `width`, `height`, and `measure_number`.
Coordinates are in **pixels relative to the input image**: `x` and `y` are
the center of the bounding box; `width` and `height` are its size. Long rests
also have an integer `measures_spanned` (1 if the duration could not be read).
Endings are currently ignored.

Example:

```json
[[{"class": "bar", "x": 100, "y": 50, "width": 8, "height": 40, "measure_number": 1},
  {"class": "long rest", "x": 150, "y": 50, "width": 24, "height": 20,
   "measure_number": 1, "measures_spanned": 4}]]
```

Running `python main.py <image-path> --api-key <key> --initial-measure-number 32`
saves this same structure as `predictions.json` and still creates `output.png`
and `test_debug.png`. The CLI also defaults the initial number to 1.
