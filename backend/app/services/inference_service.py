from __future__ import annotations

from io import BytesIO
from threading import Lock

from PIL import Image

LABEL_JA_MAP = {
    "Apple Scab": "リンゴ黒星病",
    "Apple with Black Rot": "リンゴ黒腐病",
    "Cedar Apple Rust": "リンゴ赤さび病",
    "Healthy Apple": "健全なリンゴ",
    "Healthy Blueberry Plant": "健全なブルーベリー",
    "Cherry with Powdery Mildew": "サクランボうどんこ病",
    "Healthy Cherry Plant": "健全なサクランボ",
    "Corn (Maize) with Cercospora and Gray Leaf Spot": "トウモロコシ 灰色斑点病",
    "Corn (Maize) with Common Rust": "トウモロコシ さび病",
    "Corn (Maize) with Northern Leaf Blight": "トウモロコシ 北部葉枯病",
    "Healthy Corn (Maize) Plant": "健全なトウモロコシ",
    "Grape with Black Rot": "ブドウ黒腐病",
    "Grape with Esca (Black Measles)": "ブドウ エスカ病",
    "Grape with Isariopsis Leaf Spot": "ブドウ 葉斑病",
    "Healthy Grape Plant": "健全なブドウ",
    "Orange with Citrus Greening": "オレンジ 柑橘グリーニング病",
    "Peach with Bacterial Spot": "モモ斑点細菌病",
    "Healthy Peach Plant": "健全なモモ",
    "Bell Pepper with Bacterial Spot": "ピーマン斑点細菌病",
    "Healthy Bell Pepper Plant": "健全なピーマン",
    "Potato with Early Blight": "ジャガイモ 早疫病",
    "Potato with Late Blight": "ジャガイモ 疫病",
    "Healthy Potato Plant": "健全なジャガイモ",
    "Healthy Raspberry Plant": "健全なラズベリー",
    "Healthy Soybean Plant": "健全なダイズ",
    "Squash with Powdery Mildew": "カボチャ うどんこ病",
    "Strawberry with Leaf Scorch": "イチゴ 葉焼け病",
    "Healthy Strawberry Plant": "健全なイチゴ",
    "Tomato with Bacterial Spot": "トマト斑点細菌病",
    "Tomato with Early Blight": "トマト 早疫病",
    "Tomato with Late Blight": "トマト 疫病",
    "Tomato with Leaf Mold": "トマト 葉かび病",
    "Tomato with Septoria Leaf Spot": "トマト セプトリア葉斑病",
    "Tomato with Spider Mites or Two-spotted Spider Mite": "トマト ハダニ被害",
    "Tomato with Target Spot": "トマト ターゲットスポット病",
    "Tomato Yellow Leaf Curl Virus": "トマト 黄化葉巻病",
    "Tomato Mosaic Virus": "トマト モザイク病",
    "Healthy Tomato Plant": "健全なトマト",
}

try:
    import torch
    from transformers import AutoImageProcessor, AutoModelForImageClassification
except ImportError:  # pragma: no cover
    torch = None
    AutoImageProcessor = None
    AutoModelForImageClassification = None


class InferenceService:
    def __init__(
        self,
        model_id: str = "linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification",
        top_k: int = 3,
    ) -> None:
        self.model_id = model_id
        self.top_k = top_k
        self._lock = Lock()
        self._model = None
        self._processor = None
        self._id2label: dict[int, str] = {}

    @property
    def is_ready(self) -> bool:
        return self._model is not None and self._processor is not None

    def load(self) -> None:
        if self.is_ready:
            return

        if AutoImageProcessor is None or AutoModelForImageClassification is None or torch is None:
            raise RuntimeError(
                "Missing inference dependencies. Install requirements before running backend."
            )

        with self._lock:
            if self.is_ready:
                return

            self._processor = AutoImageProcessor.from_pretrained(self.model_id)
            self._model = AutoModelForImageClassification.from_pretrained(self.model_id)
            self._model.eval()
            self._id2label = {
                int(key): value for key, value in self._model.config.id2label.items()
            }

    def _localize_label(self, english_label: str) -> dict[str, str]:
        return {
            "label": LABEL_JA_MAP.get(english_label, english_label),
            "label_en": english_label,
        }

    def predict_from_bytes(self, image_bytes: bytes) -> dict:
        self.load()

        try:
            image = Image.open(BytesIO(image_bytes)).convert("RGB")
        except Exception as exc:  # pragma: no cover
            raise ValueError("Invalid image input") from exc

        inputs = self._processor(images=image, return_tensors="pt")

        with torch.no_grad():
            outputs = self._model(**inputs)
            probabilities = outputs.logits.softmax(dim=-1)[0]

        k = min(self.top_k, probabilities.shape[0])
        scores, indices = torch.topk(probabilities, k=k)

        top_k = [
            {
                **self._localize_label(self._id2label.get(int(index), str(int(index)))),
                "confidence": round(float(score), 4),
            }
            for score, index in zip(scores.tolist(), indices.tolist(), strict=False)
        ]

        return {
            "success": True,
            "prediction": top_k[0],
            "top_k": top_k,
        }
