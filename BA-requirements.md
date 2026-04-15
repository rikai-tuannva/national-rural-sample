# BA Analysis - National Rural Sample Demo

## 1. Mục tiêu

Tạo một ứng dụng demo có khả năng:
- chụp hoặc upload ảnh đối tượng cần xác định
- gửi ảnh lên backend
- backend chạy model local để phân loại bệnh cây từ ảnh
- trả về kết quả cho app mobile để hiển thị tên bệnh và độ tin cậy

Đây là **app demo**, nên ưu tiên:
- chạy được end-to-end
- đơn giản, dễ test
- ít tính năng phụ

---

## 2. Thành phần hệ thống

### 2.1 Backend
Backend có nhiệm vụ:
- nhận ảnh từ mobile app qua API
- tiền xử lý ảnh theo yêu cầu model
- chạy model local
- trả về kết quả phân loại

Model tham chiếu:
- https://huggingface.co/linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification

### 2.2 App mobile
App mobile có nhiệm vụ:
- chụp ảnh bằng camera hoặc chọn ảnh từ thư viện
- preview ảnh trước khi gửi
- gửi ảnh lên backend
- chờ kết quả
- hiển thị:
  - tên bệnh / loại được nhận diện
  - phần trăm độ tin cậy
  - trạng thái loading / lỗi nếu có

---

## 3. Phạm vi MVP

## Bao gồm
- 1 backend API inference local
- 1 mobile app demo
- 2 cách lấy ảnh:
  - camera
  - upload từ thư viện
- 1 màn hình chính để:
  - chọn/chụp ảnh
  - gửi ảnh
  - xem kết quả
- trả về top prediction và confidence score

## Không bao gồm
- tài khoản / đăng nhập
- lịch sử ảnh đã nhận diện
- lưu trữ cloud
- nhiều loại phân tích nâng cao
- dashboard admin
- đa ngôn ngữ
- offline inference trên mobile

---

## 4. User flow chính

### Luồng 1: chụp ảnh
1. Người dùng mở app
2. Chọn chức năng chụp ảnh
3. Chụp đối tượng cần xác định
4. App hiển thị preview ảnh
5. Người dùng bấm gửi phân tích
6. Backend xử lý ảnh và trả kết quả
7. App hiển thị kết quả phân loại + độ tin cậy

### Luồng 2: upload ảnh
1. Người dùng mở app
2. Chọn ảnh từ thư viện
3. App hiển thị preview ảnh
4. Người dùng bấm gửi phân tích
5. Backend xử lý ảnh và trả kết quả
6. App hiển thị kết quả phân loại + độ tin cậy

---

## 5. Yêu cầu chức năng

### FR-01: Chọn nguồn ảnh
Hệ thống phải cho phép người dùng:
- chụp ảnh bằng camera
- hoặc chọn ảnh từ thư viện

### FR-02: Preview ảnh
Hệ thống phải hiển thị ảnh đã chọn/chụp trước khi gửi lên backend

### FR-03: Gửi ảnh lên backend
App phải gửi ảnh tới backend API bằng request HTTP phù hợp

### FR-04: Xử lý model local
Backend phải nhận ảnh, chạy model local và tạo ra kết quả dự đoán

### FR-05: Trả kết quả phân loại
Backend phải trả tối thiểu:
- label kết quả tốt nhất
- confidence score

### FR-06: Hiển thị kết quả
App mobile phải hiển thị tối thiểu:
- tên bệnh / loại nhận diện
- phần trăm độ tin cậy

### FR-07: Trạng thái xử lý
App phải hiển thị trạng thái đang xử lý khi request chưa hoàn thành

### FR-08: Xử lý lỗi cơ bản
Hệ thống phải báo lỗi nếu:
- không chọn được ảnh
- API lỗi
- backend không suy luận được

---

## 6. Yêu cầu API mức BA

## Endpoint đề xuất
### `POST /predict`

### Input
- `multipart/form-data`
- field ảnh: `image`

### Output JSON đề xuất
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

### Lỗi đề xuất
```json
{
  "success": false,
  "error": "Invalid image input"
}
```

---

## 7. Acceptance Criteria

### AC-01
Người dùng có thể chọn ảnh từ thư viện

### AC-02
Người dùng có thể chụp ảnh từ camera

### AC-03
Sau khi chọn/chụp ảnh, app hiển thị preview ảnh

### AC-04
Khi bấm phân tích, app gửi ảnh thành công tới backend

### AC-05
Backend nhận ảnh và trả về ít nhất 1 kết quả phân loại hợp lệ

### AC-06
App hiển thị được:
- tên kết quả
- phần trăm độ tin cậy

### AC-07
Trong lúc chờ kết quả, app hiển thị trạng thái loading

### AC-08
Nếu API lỗi hoặc ảnh lỗi, app hiển thị thông báo lỗi dễ hiểu

---

## 8. Giả định hiện tại

- Model Hugging Face có thể được tải/chạy local trên backend host
- Backend được phép dùng Python nếu cần để inference model
- App mobile chỉ cần demo, chưa cần tối ưu production
- Kết quả chính hiển thị top-1 là đủ cho demo; top-k là tùy chọn nhưng nên có

---

## 9. Rủi ro / điểm cần Tech Lead xác nhận

### R1. Cách chạy model local
Cần chốt:
- dùng Python service riêng cho inference
- hay gắn trực tiếp vào backend chính

### R2. Format output của model
Cần xác minh:
- danh sách label chính xác
- cách map confidence score
- cách preprocess ảnh theo input size model

### R3. Chọn stack mobile
Cần chốt framework:
- Flutter
- React Native
- native

### R4. Chọn stack backend
Cần chốt:
- FastAPI / Flask / Node wrapper
- cách expose inference endpoint

---

## 10. Khuyến nghị BA bàn giao cho bước tiếp theo

Role phù hợp tiếp theo là `1_tl`.

### Nhiệm vụ cho `1_tl`
- đề xuất kiến trúc demo end-to-end
- chốt stack backend + mobile
- chốt cách chạy model local từ Hugging Face
- định nghĩa contract API chi tiết
- chia task cho dev backend và dev mobile

---

## 11. Đề xuất scope implementation nhanh nhất

Để demo nhanh, BA đề xuất:
- **Backend:** Python FastAPI + model inference local
- **Mobile:** Flutter
- **API:** 1 endpoint `/predict`
- **UI mobile:** 1 màn hình duy nhất
  - chọn/chụp ảnh
  - preview
  - nút phân tích
  - vùng hiển thị kết quả

Đây là đường ngắn nhất để đạt mục tiêu demo chạy được.
