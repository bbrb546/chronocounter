# roboflow_runner.py
import base64
import cv2
from inference_sdk import InferenceHTTPClient

WORKSPACE_NAME = "test-workspace-yhesc"
WORKFLOW_ID = "main-predictor"

DIGIT_WORKSPACE_NAME = "test-workspace-yhesc"
DIGIT_WORKFLOW_ID = "digit-detector"

API_URL = "https://serverless.roboflow.com"


def _file_to_b64(image_path):
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def _numpy_to_b64(image):
    ok, buf = cv2.imencode(".jpg", image)
    if not ok:
        raise ValueError("Could not encode image for upload")
    return base64.b64encode(buf).decode("utf-8")


def get_predictions(image_path, api_key):
    client = InferenceHTTPClient(api_url=API_URL, api_key=api_key)
    result = client.run_workflow(
        workspace_name=WORKSPACE_NAME,
        workflow_id=WORKFLOW_ID,
        images={"image": _file_to_b64(image_path)},
        use_cache=False,
    )
    return result[0]["predictions"]["predictions"]


def get_digit_predictions(image, api_key):
    client = InferenceHTTPClient(api_url=API_URL, api_key=api_key)
    result = client.run_workflow(
        workspace_name=DIGIT_WORKSPACE_NAME,
        workflow_id=DIGIT_WORKFLOW_ID,
        images={"image": _numpy_to_b64(image)},
        use_cache=False,
    )
    return result[0]["predictions"]["predictions"]