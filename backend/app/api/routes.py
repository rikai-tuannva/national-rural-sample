from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.schemas.prediction import ErrorResponse, PredictionResponse
from app.services.inference_service import InferenceService

router = APIRouter()


def get_inference_service() -> InferenceService:
    from app.main import inference_service

    return inference_service


@router.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post(
    "/predict",
    response_model=PredictionResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def predict(
    image: UploadFile = File(...),
    service: InferenceService = Depends(get_inference_service),
) -> PredictionResponse:
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image input",
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image payload is empty",
        )

    try:
        result = service.predict_from_bytes(image_bytes)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc

    return PredictionResponse.model_validate(result)
