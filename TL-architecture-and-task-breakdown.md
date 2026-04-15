# Tech Lead - Architecture & Task Breakdown

## 1. Mục tiêu kỹ thuật

Xây một demo end-to-end có thể:
- mobile chụp/chọn ảnh
- gửi ảnh sang backend
- backend chạy model local để phân loại bệnh cây
- trả về kết quả để mobile hiển thị

Ưu tiên:
- chạy được nhanh
- ít thành phần thừa
- dễ debug
- dễ demo nội bộ

---

## 2. Tech stack chốt

## Backend
- **Python 3.11+**
- **FastAPI** để expose API
- **Uvicorn** để chạy local server
- **Transformers / timm / PyTorch** tùy theo yêu cầu thực tế của model trên Hugging Face
- **Pillow** để đọc và preprocess ảnh

## Mobile
- **Flutter stable mới nhất**
- package dự kiến:
  - `image_picker` để chụp/chọn ảnh
  - `http` hoặc `dio` để upload ảnh

## Giao tiếp
- **HTTP REST API**
- upload ảnh bằng `multipart/form-data`

---

## 3. Kiến trúc tổng thể

```text
[Flutter Mobile App]
   -> chụp/chọn ảnh
   -> POST /predict

[FastAPI Backend]
   -> nhận file ảnh
   -> preprocess ảnh
   -> chạy model local
   -> map kết quả
   -> trả JSON response

[Local Model Runtime]
   -> load model từ Hugging Face / local weights
   -> infer top-1 hoặc top-k
```

---

## 4. Quyết định kỹ thuật chính

## 4.1 Backend tách riêng inference
Chọn hướng:
- **FastAPI backend đồng thời là inference service**

Lý do:
- demo scope nhỏ
- ít thành phần hơn
- dễ chạy local
- dễ đóng gói và test

Không cần tách thành 2 service ở giai đoạn này.

## 4.2 Mobile framework
Chọn:
- **Flutter**

Lý do:
- phù hợp với luồng demo nhanh
- dễ chạy Android/web nếu cần test nhanh UI
- trước đó workspace đã có flow làm Flutter

## 4.3 API contract
Chốt endpoint chính:
- `POST /predict`

Có thể thêm:
- `GET /health` để check service sống

## 4.4 Output cho mobile
Mobile cần tối thiểu:
- label tốt nhất
- confidence
- top_k nếu backend có trả
- message lỗi nếu request fail

---

## 5. Cấu trúc thư mục đề xuất

```text
national-rural-sample/
  backend/
    app/
      main.py
      api/
      services/
      models/
      schemas/
      utils/
    requirements.txt

  mobile/
    lib/
    pubspec.yaml

  docs/
    api-contract.md
```

---

## 6. Backend design

## 6.1 Endpoint
### `GET /health`
Response ví dụ:
```json
{
  "status": "ok"
}
```

### `POST /predict`
Input:
- multipart field: `image`

Response success:
```json
{
  "success": true,
  "prediction": {
    "label": "Tomato Early Blight",
    "confidence": 0.9421
  },
  "top_k": [
    {
      "label": "Tomato Early Blight",
      "confidence": 0.9421
    },
    {
      "label": "Tomato Late Blight",
      "confidence": 0.0312
    }
  ]
}
```

Response error:
```json
{
  "success": false,
  "error": "Invalid image input"
}
```

## 6.2 Các thành phần backend
- `main.py`: bootstrap FastAPI app
- `api/predict.py`: route handlers
- `services/inference_service.py`: load model + predict
- `utils/image_preprocess.py`: resize / normalize / tensor conversion
- `schemas/response.py`: response models

## 6.3 Lifecycle backend
- load model **một lần khi app khởi động**
- request đến thì tái sử dụng model đã load

Điều này rất quan trọng để demo không bị chậm vì reload model mỗi request.

---

## 7. Mobile design

## 7.1 Màn hình chính
Một màn hình duy nhất gồm:
- nút chụp ảnh
- nút chọn ảnh từ thư viện
- vùng preview ảnh
- nút `Phân tích`
- vùng kết quả:
  - label
  - confidence
  - top_k (nếu có)
- loading indicator
- error message

## 7.2 Mobile states
- idle
- image_selected
- uploading
- success
- error

## 7.3 Hành vi chính
- nếu chưa có ảnh thì disable nút phân tích
- sau khi chọn ảnh thì cho preview
- khi đang gọi API thì hiện loading
- khi có kết quả thì render kết quả

---

## 8. Luồng triển khai được chốt

### Phase 1 - Backend chạy được local
- dựng FastAPI skeleton
- dựng `/health`
- dựng `/predict`
- tích hợp model local
- trả response JSON chuẩn

### Phase 2 - Mobile chạy được flow demo
- dựng app Flutter 1 màn hình
- chọn/chụp ảnh
- preview ảnh
- upload ảnh
- render kết quả

### Phase 3 - End-to-end integration
- cấu hình base URL backend
- test flow từ app -> backend -> kết quả
- sửa lỗi contract nếu có

---

## 9. Rủi ro kỹ thuật cần lưu ý

## R1. Model Hugging Face không theo đúng API chuẩn image-classification
Cần kiểm tra thực tế:
- model card
- loại artifact tải về
- cách load model đúng

Nếu model không load trực tiếp qua transformers pipeline, cần fallback sang:
- custom PyTorch load
- hoặc script infer riêng

## R2. Preprocess ảnh sai kích thước / normalize
Tên model có gợi ý input:
- `mobilenet_v2_1.0_224`

Suy ra nhiều khả năng input cần về **224x224**.
Nhưng vẫn phải xác minh exact preprocess.

## R3. Mobile camera/gallery permissions
Cần xử lý permission tối thiểu cho demo.

## R4. Base URL khi test mobile
Nếu chạy trên máy thật/emulator, cần chốt URL backend theo môi trường:
- localhost
- LAN IP
- Android emulator special host nếu cần

---

## 10. Task breakdown

## Task A — Dev Backend
**Owner:** `1_dev_be`

### Mục tiêu
Dựng backend inference local và expose API.

### Deliverables
- `backend/` project structure
- `GET /health`
- `POST /predict`
- model loader
- image preprocess
- response JSON đúng contract
- README chạy local ngắn gọn

### Checklist
- tạo FastAPI app
- tạo endpoint health
- tạo endpoint predict nhận multipart image
- load model local 1 lần khi startup
- infer top-1 / top-k
- trả label + confidence
- xử lý lỗi input không hợp lệ

---

## Task B — Dev Mobile
**Owner:** `1_dev_mb`

### Mục tiêu
Dựng app Flutter demo 1 màn hình để gửi ảnh và xem kết quả.

### Deliverables
- `mobile/` Flutter app
- pick image từ camera/gallery
- preview ảnh
- gọi API `/predict`
- render kết quả
- loading + error state

### Checklist
- tạo Flutter app
- chọn/chụp ảnh
- preview ảnh
- disable nút phân tích nếu chưa có ảnh
- upload multipart request
- parse response
- hiển thị label + confidence + top_k nếu có

---

## Task C — Integration / QA
**Owner:** `1_tester` hoặc run chung sau dev

### Mục tiêu
Xác minh demo chạy end-to-end.

### Checklist
- backend health ok
- backend predict nhận ảnh hợp lệ
- app upload thành công
- app hiển thị kết quả đúng format
- app hiển thị lỗi khi backend fail
- test camera path
- test gallery path

---

## 11. Thứ tự thực hiện tối ưu

1. `1_dev_be` dựng backend trước
2. `1_dev_mb` dựng UI + integration song song
3. `1_dev_be` chốt contract response thật
4. `1_dev_mb` map UI theo contract thật
5. `1_tester` test end-to-end

---

## 12. Kết luận TL

Tech stack chốt cho demo:
- **Backend:** Python FastAPI + local model inference
- **Mobile:** Flutter
- **API:** REST multipart upload

Đây là hướng ngắn nhất để đạt mục tiêu demo hoạt động được.
