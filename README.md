# National Rural Sample

Demo end-to-end nhận diện bệnh cây trồng từ ảnh.

Hệ thống gồm 2 phần chính:

- `backend/`: FastAPI API chạy model local để dự đoán nhãn bệnh cây
- `mobile/`: Flutter app để chụp/chọn ảnh, crop, rotate, submit lên backend và xem kết quả

---

## 1. Cấu trúc thư mục

```text
national-rural-sample/
  backend/   # FastAPI + local inference
  mobile/    # Flutter app demo
  tester/    # benchmark scripts, report, note giải thích field
  docs/      # tài liệu bổ sung
```

---

## 2. Yêu cầu môi trường

## 2.1. Backend

Cần:
- Python 3.11+
- `venv`
- `pip`

Khuyến nghị:
- Linux/macOS
- model chạy bằng **CPU-only torch** để setup gọn

## 2.2. Mobile

Cần:
- Flutter stable
- Android SDK
- `adb`
- thiết bị Android thật hoặc emulator

Nếu chạy trên Android thật:
- bật **USB debugging**
- authorize thiết bị với `adb`

---

## 3. Cài môi trường backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install --index-url https://download.pytorch.org/whl/cpu torch
```

### Kiểm tra nhanh

```bash
pytest
```

---

## 4. Chạy backend local

Từ thư mục `backend/`:

```bash
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Health check

```bash
curl http://127.0.0.1:8000/health
```

Kỳ vọng:

```json
{"status":"ok"}
```

### Lưu ý

- lần chạy đầu tiên có thể tải model từ Hugging Face
- model hiện dùng:
  - `linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification`

---

## 5. Cài môi trường mobile

Từ thư mục `mobile/`:

```bash
flutter pub get
```

### Kiểm tra nhanh

```bash
flutter analyze
flutter test
```

---

## 6. Chạy app trong môi trường test/dev

## 6.1. Chạy web để review nhanh UI

Từ thư mục `mobile/`:

```bash
flutter run -d chrome
```

Hoặc nếu muốn bind host/port rõ ràng:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3001
```

### Khi chạy web
- phù hợp để review UI nhanh
- phù hợp để test flow submit ảnh cơ bản
- camera/crop native sẽ không giống hoàn toàn Android thật

---

## 6.2. Chạy trên Android thật

### Bước 1: kiểm tra thiết bị

```bash
adb devices
flutter devices
```

### Bước 2: nếu backend chạy trên máy local, nối cổng cho điện thoại

```bash
adb reverse tcp:8000 tcp:8000
```

### Bước 3: chạy app

```bash
flutter run -d <device_id>
```

Ví dụ:

```bash
flutter run -d 08191JEC207319
```

### Bước 4: API base URL trong app

Dùng:

```text
http://127.0.0.1:8000
```

Khi đã có `adb reverse`, điện thoại sẽ gọi về backend local qua địa chỉ trên.

---

## 6.3. Nếu muốn chạy qua LAN thay vì `adb reverse`

Backend có thể chạy trên LAN, ví dụ:

```text
http://192.168.x.x:8000
```

Trong trường hợp đó:
- điện thoại và máy chạy backend phải cùng mạng
- app cần nhập đúng IP LAN của máy host

Khuyến nghị:
- với test ổn định trên Android thật, nên ưu tiên `adb reverse + 127.0.0.1:8000`

---

## 7. Luồng test thủ công cơ bản

1. chạy backend local
2. chạy app Flutter
3. nhập `API base URL`
4. chọn một trong hai cách lấy ảnh:
   - **Chụp ảnh**
   - **Chọn từ thư viện**
5. preview ảnh
6. nếu cần thì:
   - **Crop**
   - **Rotate trái/phải**
7. bấm **Submit**
8. xem:
   - top prediction
   - confidence
   - top-k

---

## 8. Batch test trong app

App có batch mode để test nhiều ảnh mẫu liên tiếp.

Batch mode hiện hỗ trợ:
- pool ảnh mẫu nằm trong `mobile/assets/batch_samples/`
- chọn batch size trong app
- chạy crop/rotate theo logic app
- gọi backend `/predict`
- tổng hợp kết quả

### Ghi chú

- kết quả batch được dùng cho mục đích test/demo
- các file report/giải thích field nằm trong `tester/`

Các file đáng xem:
- `tester/mobile-batch-smartcrop-comparison-report-2026-04-16.md`
- `tester/report-field-explanation.md`

---

## 9. Smart crop hiện tại

Batch/test flow đã được cải thiện bằng **smart crop** để giữ nhiều ngữ cảnh lá hơn:

- crop lớn hơn
- crop gần trung tâm hơn
- jitter nhẹ thay vì crop ngẫu nhiên quá mạnh

Mục tiêu:
- tăng accuracy thực tế
- giảm các lỗi do crop làm mất vùng bệnh chính

---

## 10. API contract ngắn

### `GET /health`

Response:

```json
{
  "status": "ok"
}
```

### `POST /predict`

- content-type: `multipart/form-data`
- field ảnh: `image`

Response success ví dụ:

```json
{
  "success": true,
  "prediction": {
    "label": "Tomato with Early Blight",
    "confidence": 0.94
  },
  "top_k": [
    {
      "label": "Tomato with Early Blight",
      "confidence": 0.94
    }
  ]
}
```

Response error ví dụ:

```json
{
  "success": false,
  "error": "Invalid image input"
}
```

---

## 11. Một số lỗi hay gặp

### 11.1. App Android gọi backend bị timeout

Nguyên nhân thường gặp:
- chưa `adb reverse`
- nhập sai API URL

Cách xử lý:

```bash
adb reverse tcp:8000 tcp:8000
```

và dùng:

```text
http://127.0.0.1:8000
```

### 11.2. Crop làm app crash

Nếu gặp lỗi crop trên Android, kiểm tra:
- `UCropActivity` đã được khai báo trong `AndroidManifest.xml` chưa

Hiện repo đã có fix này trong:
- `mobile/android/app/src/main/AndroidManifest.xml`

### 11.3. Backend không lên

Kiểm tra:
- đã activate `.venv`
- đã cài `torch` CPU chưa
- port `8000` có bị chiếm không

---

## 12. Gợi ý chạy lại demo từ đầu

### Terminal 1

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Terminal 2

```bash
cd mobile
flutter pub get
flutter run -d 08191JEC207319
```

### Terminal 3 (nếu test Android thật)

```bash
adb reverse tcp:8000 tcp:8000
```

Sau đó trên app:
- nhập `http://127.0.0.1:8000`
- chọn ảnh / crop / submit
- xem kết quả

---

## 13. Ghi chú cuối

Repo này đang phục vụ mục tiêu **demo + test**.

Nếu muốn dùng lâu dài hơn, nên làm thêm:
- dọn repo sạch file benchmark/result tạm
- chuẩn hóa README theo production/dev/test
- thêm script bootstrap môi trường tự động
- tách batch harness/test utility khỏi UI demo chính
