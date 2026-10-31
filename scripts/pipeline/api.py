"""HTTP adapter for Godot: POST raw PNG/JPEG/WebP bytes to /count."""

import os
import tempfile

import cv2
from fastapi import FastAPI, HTTPException, Query, Request
from starlette.concurrency import run_in_threadpool

from main import run_pipeline

app = FastAPI(title="Chronocounter")

MAX_IMAGE_BYTES = 10 * 1024 * 1024
IMAGE_SUFFIXES = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/webp": ".webp",
}


def _process_image(image_bytes, suffix, api_key, initial_measure_number):
    """Run the path-based pipeline on an isolated, temporary uploaded image."""
    path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as image_file:
            path = image_file.name
            image_file.write(image_bytes)

        # Reject corrupt/non-image data before sending it to Roboflow.
        if cv2.imread(path) is None:
            raise HTTPException(status_code=400, detail="Invalid image")
        return run_pipeline(path, api_key, initial_measure_number)
    finally:
        if path is not None:
            os.unlink(path)


@app.post("/count")
async def count_measures(request: Request, initial_measure_number: int = Query(1, ge=1)):
    """Return JSON staff lines of detections; coordinates are input-image pixels."""
    api_key = os.environ.get("ROBOFLOW_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="Roboflow API key is not configured")

    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    suffix = IMAGE_SUFFIXES.get(content_type)
    if suffix is None:
        raise HTTPException(status_code=415, detail="Expected image/png, image/jpeg or image/webp")

    data = bytearray()
    async for chunk in request.stream():
        data.extend(chunk)
        if len(data) > MAX_IMAGE_BYTES:
            raise HTTPException(status_code=413, detail="Image exceeds 10 MB")
    if not data:
        raise HTTPException(status_code=400, detail="Empty image")

    # Roboflow and OpenCV calls are synchronous; do not block the event loop.
    return await run_in_threadpool(
        _process_image, data, suffix, api_key, initial_measure_number
    )
