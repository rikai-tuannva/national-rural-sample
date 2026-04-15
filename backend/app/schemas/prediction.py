from pydantic import BaseModel


class PredictionItem(BaseModel):
    label: str
    confidence: float


class PredictionResponse(BaseModel):
    success: bool
    prediction: PredictionItem
    top_k: list[PredictionItem]


class ErrorResponse(BaseModel):
    success: bool = False
    error: str
