from __future__ import annotations

import argparse
import csv
import json
import random
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image

API_URL = 'http://127.0.0.1:8000/predict'
TIMEOUT = 120
BATCH_SEED = 20260416
MOBILE_ASSET_DIR = Path('/home/tuannguyen/.openclaw/workspace/national-rural-sample/mobile/assets/batch_samples')
MANIFEST_PATH = MOBILE_ASSET_DIR / 'manifest.csv'

ID_TO_LABEL = {
    0: 'Apple Scab',
    1: 'Apple with Black Rot',
    2: 'Cedar Apple Rust',
    3: 'Healthy Apple',
    4: 'Healthy Blueberry Plant',
    5: 'Cherry with Powdery Mildew',
    6: 'Healthy Cherry Plant',
    7: 'Corn (Maize) with Cercospora and Gray Leaf Spot',
    8: 'Corn (Maize) with Common Rust',
    9: 'Corn (Maize) with Northern Leaf Blight',
    10: 'Healthy Corn (Maize) Plant',
    11: 'Grape with Black Rot',
    12: 'Grape with Esca (Black Measles)',
    13: 'Grape with Isariopsis Leaf Spot',
    14: 'Healthy Grape Plant',
    15: 'Orange with Citrus Greening',
    16: 'Peach with Bacterial Spot',
    17: 'Healthy Peach Plant',
    18: 'Bell Pepper with Bacterial Spot',
    19: 'Healthy Bell Pepper Plant',
    20: 'Potato with Early Blight',
    21: 'Potato with Late Blight',
    22: 'Healthy Potato Plant',
    23: 'Healthy Raspberry Plant',
    24: 'Healthy Soybean Plant',
    25: 'Squash with Powdery Mildew',
    26: 'Strawberry with Leaf Scorch',
    27: 'Healthy Strawberry Plant',
    28: 'Tomato with Bacterial Spot',
    29: 'Tomato with Early Blight',
    30: 'Tomato with Late Blight',
    31: 'Tomato with Leaf Mold',
    32: 'Tomato with Septoria Leaf Spot',
    33: 'Tomato with Spider Mites or Two-spotted Spider Mite',
    34: 'Tomato with Target Spot',
    35: 'Tomato Yellow Leaf Curl Virus',
    36: 'Tomato Mosaic Virus',
    37: 'Healthy Tomato Plant',
}


def pick_batch_rows(rows: list[dict[str, str]], size: int) -> list[dict[str, str]]:
    if len(rows) <= size:
        return list(rows)
    shuffled = list(rows)
    random.Random(BATCH_SEED + size).shuffle(shuffled)
    return shuffled[:size]


def crop_smart_jpeg(image_bytes: bytes, rng: random.Random) -> bytes:
    image = Image.open(BytesIO(image_bytes)).convert('RGB')
    width, height = image.size
    ratio_width = rng.random() * 0.2 + 0.65
    ratio_height = rng.random() * 0.2 + 0.65
    crop_width = max(1, int(width * ratio_width))
    crop_height = max(1, int(height * ratio_height))
    max_left = max(0, width - crop_width)
    max_top = max(0, height - crop_height)
    center_left = max_left // 2
    center_top = max_top // 2
    jitter_x = max(1, round(max_left * 0.2))
    jitter_y = max(1, round(max_top * 0.2))
    left = 0 if max_left == 0 else max(0, min(max_left, center_left + rng.randint(-jitter_x, jitter_x)))
    top = 0 if max_top == 0 else max(0, min(max_top, center_top + rng.randint(-jitter_y, jitter_y)))
    cropped = image.crop((left, top, left + crop_width, top + crop_height))
    out = BytesIO()
    cropped.save(out, format='JPEG', quality=95)
    return out.getvalue()


def rotate_jpeg(image_bytes: bytes, clockwise: bool) -> bytes:
    image = Image.open(BytesIO(image_bytes)).convert('RGB')
    rotated = image.rotate(-90 if clockwise else 90, expand=True)
    out = BytesIO()
    rotated.save(out, format='JPEG', quality=95)
    return out.getvalue()


def predict(image_name: str, image_bytes: bytes) -> dict:
    response = requests.post(
        API_URL,
        files={'image': (image_name, image_bytes, 'image/jpeg')},
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def run(size: int) -> dict:
    rows = list(csv.DictReader(MANIFEST_PATH.read_text(encoding='utf-8').splitlines()))
    selected_rows = pick_batch_rows(rows, size)
    rng = random.Random(BATCH_SEED)

    results = []
    correct = 0
    for row in selected_rows:
        asset_name = row['asset_name']
        class_id = int(row['class_id'])
        expected_label = ID_TO_LABEL[class_id]
        source_name = row['source_name']
        original_bytes = (MOBILE_ASSET_DIR / asset_name).read_bytes()
        cropped = crop_smart_jpeg(original_bytes, rng)
        clockwise = rng.choice([True, False])
        rotated = rotate_jpeg(cropped, clockwise)
        payload = predict(asset_name, rotated)
        predicted_label = payload['prediction']['label']
        confidence = float(payload['prediction']['confidence'])
        ok = predicted_label == expected_label
        correct += int(ok)
        results.append({
            'asset_name': asset_name,
            'source_name': source_name,
            'expected_label': expected_label,
            'predicted_label': predicted_label,
            'confidence': confidence,
            'ok': ok,
            'rotated_clockwise': clockwise,
        })

    total = len(results)
    failures = [item for item in results if not item['ok']]
    output = {
        'seed': BATCH_SEED,
        'selected_batch_size': size,
        'total': total,
        'correct': correct,
        'wrong': total - correct,
        'accuracy': 0 if total == 0 else correct / total,
        'results': results,
        'failures': failures,
    }
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--size', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()

    output = run(args.size)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({
        'size': output['selected_batch_size'],
        'total': output['total'],
        'correct': output['correct'],
        'wrong': output['wrong'],
        'accuracy': round(output['accuracy'], 4),
        'output': str(args.output),
    }, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
