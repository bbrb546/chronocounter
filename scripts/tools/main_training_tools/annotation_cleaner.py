import json
from pathlib import Path

"""
annotation_cleaner.py

This script cleans up a COCO-format dataset by removing unannotated images
from the JSON file and deleting any image files that are either unannotated
or not referenced in the JSON.
"""

# ==========================================================
# Configuration
# ==========================================================

DATASET_ROOT = Path("dataset v1.0")

IMAGE_DIR = DATASET_ROOT / "images" / "train"
ANNOTATION_FILE = DATASET_ROOT / "annotations" / "instances_default.json"

# ==========================================================
# Load COCO annotations
# ==========================================================

with open(ANNOTATION_FILE, "r", encoding="utf-8") as f:
    coco = json.load(f)

images = coco["images"]
annotations = coco["annotations"]

# ==========================================================
# Find images that contain at least one annotation
# ==========================================================

annotated_image_ids = {
    ann["image_id"]
    for ann in annotations
}

# ==========================================================
# Separate annotated and unannotated images
# ==========================================================

kept_images = []
removed_images = []

for img in images:
    if img["id"] in annotated_image_ids:
        kept_images.append(img)
    else:
        removed_images.append(img)

# ==========================================================
# Delete image files listed in JSON that have no annotations
# ==========================================================

deleted_count = 0

for img in removed_images:
    image_path = IMAGE_DIR / img["file_name"]

    if image_path.exists():
        image_path.unlink()
        deleted_count += 1
        print(f"Deleted unannotated image: {image_path}")
    else:
        print(f"Warning: File not found: {image_path}")

# ==========================================================
# Find image files that are NOT referenced in the COCO JSON
# ==========================================================

# Get the filenames of all images referenced by the COCO JSON
referenced_filenames = {
    Path(img["file_name"]).name
    for img in images
}

# Find all PNG files physically present in the image directory
unreferenced_files = [
    path
    for path in IMAGE_DIR.glob("*.png")
    if path.name not in referenced_filenames
]

# ==========================================================
# Delete unreferenced PNG files
# ==========================================================

for image_path in unreferenced_files:
    image_path.unlink()
    deleted_count += 1
    print(f"Deleted unreferenced image: {image_path}")

# ==========================================================
# Update COCO JSON
# ==========================================================

coco["images"] = kept_images

with open(ANNOTATION_FILE, "w", encoding="utf-8") as f:
    json.dump(coco, f, indent=2)

# ==========================================================
# Summary
# ==========================================================

print("\nDone.")
print(f"Images kept:             {len(kept_images)}")
print(f"Unannotated JSON images: {len(removed_images)}")
print(f"Unreferenced PNG files:  {len(unreferenced_files)}")
print(f"Total files deleted:     {deleted_count}")