# API Contract

## GET /health

Response:
```json
{
  "status": "ok"
}
```

## POST /predict

### Request
- Content-Type: `multipart/form-data`
- field name: `image`

### Response success
```json
{
  "success": true,
  "prediction": {
    "label": "Tomato with Early Blight",
    "confidence": 0.9421
  },
  "top_k": [
    {
      "label": "Tomato with Early Blight",
      "confidence": 0.9421
    },
    {
      "label": "Tomato with Late Blight",
      "confidence": 0.0312
    }
  ]
}
```

### Response error
```json
{
  "success": false,
  "error": "Invalid image input"
}
```
