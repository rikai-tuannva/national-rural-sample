from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import requests

BASE_DIR = Path(__file__).resolve().parent / "PlantVillage-Dataset" / "data_distribution_for_SVM" / "test"
API_URL = "http://127.0.0.1:8000/predict"
TIMEOUT = 120

ID_TO_LABEL = {
    0: "Apple Scab",
    1: "Apple with Black Rot",
    2: "Cedar Apple Rust",
    3: "Healthy Apple",
    4: "Healthy Blueberry Plant",
    5: "Cherry with Powdery Mildew",
    6: "Healthy Cherry Plant",
    7: "Corn (Maize) with Cercospora and Gray Leaf Spot",
    8: "Corn (Maize) with Common Rust",
    9: "Corn (Maize) with Northern Leaf Blight",
    10: "Healthy Corn (Maize) Plant",
    11: "Grape with Black Rot",
    12: "Grape with Esca (Black Measles)",
    13: "Grape with Isariopsis Leaf Spot",
    14: "Healthy Grape Plant",
    15: "Orange with Citrus Greening",
    16: "Peach with Bacterial Spot",
    17: "Healthy Peach Plant",
    18: "Bell Pepper with Bacterial Spot",
    19: "Healthy Bell Pepper Plant",
    20: "Potato with Early Blight",
    21: "Potato with Late Blight",
    22: "Healthy Potato Plant",
    23: "Healthy Raspberry Plant",
    24: "Healthy Soybean Plant",
    25: "Squash with Powdery Mildew",
    26: "Strawberry with Leaf Scorch",
    27: "Healthy Strawberry Plant",
    28: "Tomato with Bacterial Spot",
    29: "Tomato with Early Blight",
    30: "Tomato with Late Blight",
    31: "Tomato with Leaf Mold",
    32: "Tomato with Septoria Leaf Spot",
    33: "Tomato with Spider Mites or Two-spotted Spider Mite",
    34: "Tomato with Target Spot",
    35: "Tomato Yellow Leaf Curl Virus",
    36: "Tomato Mosaic Virus",
    37: "Healthy Tomato Plant",
}


@dataclass
class SampleResult:
    path: str
    expected_label: str
    predicted_label: str
    confidence: float
    ok: bool


def predict_image(image_path: Path) -> dict:
    with image_path.open("rb") as file_obj:
        response = requests.post(
            API_URL,
            files={"image": (image_path.name, file_obj, "image/jpeg")},
            timeout=TIMEOUT,
        )
    response.raise_for_status()
    return response.json()


def main() -> None:
    if not BASE_DIR.exists():
        raise SystemExit(f"Missing dataset directory: {BASE_DIR}")

    started_at = time.time()
    sample_results: list[SampleResult] = []
    per_class: dict[str, dict[str, int]] = {}

    class_dirs = sorted([path for path in BASE_DIR.iterdir() if path.is_dir()], key=lambda p: int(p.name))

    for class_dir in class_dirs:
        class_id = int(class_dir.name)
        expected_label = ID_TO_LABEL[class_id]
        per_class.setdefault(expected_label, {"total": 0, "correct": 0})

        image_paths = sorted([p for p in class_dir.iterdir() if p.is_file()])
        for image_path in image_paths:
            payload = predict_image(image_path)
            predicted_label = payload["prediction"]["label"]
            confidence = float(payload["prediction"]["confidence"])
            ok = predicted_label == expected_label

            per_class[expected_label]["total"] += 1
            per_class[expected_label]["correct"] += int(ok)
            sample_results.append(
                SampleResult(
                    path=str(image_path.relative_to(BASE_DIR.parent.parent)),
                    expected_label=expected_label,
                    predicted_label=predicted_label,
                    confidence=confidence,
                    ok=ok,
                )
            )

    total = len(sample_results)
    correct = sum(int(item.ok) for item in sample_results)
    accuracy = (correct / total) if total else 0.0
    elapsed = time.time() - started_at

    output = {
        "dataset_root": str(BASE_DIR),
        "api_url": API_URL,
        "total_samples": total,
        "correct_predictions": correct,
        "accuracy": round(accuracy, 4),
        "elapsed_seconds": round(elapsed, 2),
        "per_class": {
            label: {
                "total": values["total"],
                "correct": values["correct"],
                "accuracy": round(values["correct"] / values["total"], 4) if values["total"] else 0.0,
            }
            for label, values in per_class.items()
        },
        "samples": [asdict(item) for item in sample_results],
    }

    output_path = Path(__file__).resolve().parent / "plantvillage_benchmark_result.json"
    output_path.write_text(json.dumps(output, indent=2), encoding="utf-8")

    print(json.dumps({
        "total_samples": output["total_samples"],
        "correct_predictions": output["correct_predictions"],
        "accuracy": output["accuracy"],
        "elapsed_seconds": output["elapsed_seconds"],
        "output_path": str(output_path),
    }, indent=2))


if __name__ == "__main__":
    main()
