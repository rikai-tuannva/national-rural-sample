from __future__ import annotations

from io import BytesIO
from threading import Lock

from PIL import Image

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
                "label": self._id2label.get(int(index), str(int(index))),
                "confidence": round(float(score), 4),
            }
            for score, index in zip(scores.tolist(), indices.tolist(), strict=False)
        ]

        return {
            "success": True,
            "prediction": top_k[0],
            "top_k": top_k,
        }
