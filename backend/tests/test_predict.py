from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image

from app.api.routes import get_inference_service
from app.main import app


class FakeInferenceService:
    def predict_from_bytes(self, image_bytes: bytes) -> dict:
        if not image_bytes:
            raise ValueError("Image payload is empty")

        return {
            "success": True,
            "prediction": {
                "label": "Healthy Tomato Plant",
                "confidence": 0.9876,
            },
            "top_k": [
                {
                    "label": "Healthy Tomato Plant",
                    "confidence": 0.9876,
                },
                {
                    "label": "Tomato with Early Blight",
                    "confidence": 0.0124,
                },
            ],
        }


def _build_test_image_bytes() -> bytes:
    image = Image.new("RGB", (32, 32), color=(0, 180, 0))
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def test_predict_returns_prediction_response():
    app.dependency_overrides[get_inference_service] = lambda: FakeInferenceService()
    client = TestClient(app)

    response = client.post(
        "/predict",
        files={"image": ("leaf.png", _build_test_image_bytes(), "image/png")},
    )

    app.dependency_overrides.clear()

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["prediction"]["label"] == "Healthy Tomato Plant"
    assert len(body["top_k"]) == 2


def test_predict_rejects_non_image_payload():
    client = TestClient(app)

    response = client.post(
        "/predict",
        files={"image": ("note.txt", b"hello", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json() == {"success": False, "error": "Invalid image input"}


def test_predict_requires_image_field():
    client = TestClient(app)

    response = client.post("/predict")

    assert response.status_code == 422
    assert response.json()["success"] is False
    assert isinstance(response.json()["error"], str)
