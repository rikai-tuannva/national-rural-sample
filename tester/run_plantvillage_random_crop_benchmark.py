from __future__ import annotations

import argparse
import json
import random
from dataclasses import asdict, dataclass
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image

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
class CropResult:
    file: str
    crop_index: int
    crop_box: list[int]
    crop_ratio_width: float
    crop_ratio_height: float
    expected_label: str
    predicted_label: str
    confidence: float
    ok: bool


def build_random_crop(
    image_path: Path,
    rng: random.Random,
    min_crop_ratio: float,
    max_crop_ratio: float,
) -> tuple[bytes, list[int], float, float]:
    image = Image.open(image_path).convert("RGB")
    width, height = image.size

    ratio_width = rng.uniform(min_crop_ratio, max_crop_ratio)
    ratio_height = rng.uniform(min_crop_ratio, max_crop_ratio)

    crop_width = max(1, int(width * ratio_width))
    crop_height = max(1, int(height * ratio_height))

    max_left = max(0, width - crop_width)
    max_top = max(0, height - crop_height)

    left = rng.randint(0, max_left) if max_left > 0 else 0
    top = rng.randint(0, max_top) if max_top > 0 else 0
    right = left + crop_width
    bottom = top + crop_height

    cropped = image.crop((left, top, right, bottom))
    buffer = BytesIO()
    cropped.save(buffer, format="JPEG", quality=95)
    return buffer.getvalue(), [left, top, right, bottom], round(ratio_width, 4), round(ratio_height, 4)


def predict_crop(image_name: str, image_bytes: bytes, retries: int = 3) -> dict:
    last_error: Exception | None = None
    for _ in range(retries):
        try:
            response = requests.post(
                API_URL,
                files={"image": (image_name, image_bytes, "image/jpeg")},
                timeout=TIMEOUT,
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as exc:
            last_error = exc
    if last_error is not None:
        raise last_error
    raise RuntimeError("Prediction request failed without explicit error")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-size", type=int, default=30)
    parser.add_argument("--crops-per-image", type=int, default=1)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--min-crop-ratio", type=float, default=0.3)
    parser.add_argument("--max-crop-ratio", type=float, default=0.8)
    args = parser.parse_args()

    if not BASE_DIR.exists():
        raise SystemExit(f"Missing dataset directory: {BASE_DIR}")
    if not (0 < args.min_crop_ratio <= args.max_crop_ratio <= 1):
        raise SystemExit("Crop ratio must satisfy 0 < min <= max <= 1")

    rng = random.Random(args.seed)
    all_files = sorted([p for p in BASE_DIR.rglob('*') if p.is_file()])
    sample_size = min(args.sample_size, len(all_files))
    sampled_files = rng.sample(all_files, sample_size)

    results: list[CropResult] = []

    for image_path in sampled_files:
        expected_label = ID_TO_LABEL[int(image_path.parent.name)]
        for crop_index in range(args.crops_per_image):
            crop_bytes, crop_box, crop_ratio_width, crop_ratio_height = build_random_crop(
                image_path,
                rng,
                args.min_crop_ratio,
                args.max_crop_ratio,
            )
            payload = predict_crop(image_path.name, crop_bytes)
            predicted_label = payload['prediction']['label']
            confidence = float(payload['prediction']['confidence'])
            ok = predicted_label == expected_label
            results.append(
                CropResult(
                    file=str(image_path.relative_to(BASE_DIR.parent.parent)),
                    crop_index=crop_index,
                    crop_box=crop_box,
                    crop_ratio_width=crop_ratio_width,
                    crop_ratio_height=crop_ratio_height,
                    expected_label=expected_label,
                    predicted_label=predicted_label,
                    confidence=confidence,
                    ok=ok,
                )
            )

    total = len(results)
    correct = sum(int(item.ok) for item in results)
    accuracy = round(correct / total, 4) if total else 0.0
    failures = [asdict(item) for item in results if not item.ok]

    output = {
        'seed': args.seed,
        'sample_size': sample_size,
        'crops_per_image': args.crops_per_image,
        'crop_ratio_range': [args.min_crop_ratio, args.max_crop_ratio],
        'total_crops': total,
        'correct': correct,
        'accuracy': accuracy,
        'first_20_failures': failures[:20],
        'results': [asdict(item) for item in results],
    }

    output_path = Path(__file__).resolve().parent / 'plantvillage_random_crop_benchmark_result.json'
    output_path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({
        'seed': output['seed'],
        'sample_size': output['sample_size'],
        'crops_per_image': output['crops_per_image'],
        'crop_ratio_range': output['crop_ratio_range'],
        'total_crops': output['total_crops'],
        'correct': output['correct'],
        'accuracy': output['accuracy'],
        'output_path': str(output_path),
    }, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
