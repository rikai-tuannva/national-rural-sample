# Backend - National Rural Sample

## Scope hiện tại
- FastAPI skeleton
- `GET /health`
- `POST /predict`
- service load model local từ Hugging Face
- contract response cho mobile

## Chạy local
Yêu cầu máy có Python + pip.

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Test
```bash
pytest
```

## Ghi chú
Lần chạy đầu tiên sẽ tải model:
- `linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification`

Endpoint chính:
- `GET /health`
- `POST /predict`
