# Mobile Batch Overall Report — 2026-04-16

## 1) Mục tiêu

Tổng hợp kết quả test full-flow cho demo nhận diện bệnh cây với các mốc batch:

- 10 ảnh
- 15 ảnh
- 25 ảnh
- 40 ảnh
- 65 ảnh

Flow đánh giá dùng cùng tinh thần kiểm thử đã chốt:

- lấy ảnh từ pool mẫu PlantVillage đã đưa vào app/mobile assets
- random subset theo batch size
- crop ngẫu nhiên
- rotate ngẫu nhiên
- upload lên backend `/predict`
- so sánh nhãn dự đoán với ground truth

## 2) Bối cảnh chạy test

### 2.1. Pool dữ liệu

- Pool mẫu đã được nâng lên **200 ảnh** trong `mobile/assets/batch_samples/`
- Manifest nguồn: `mobile/assets/batch_samples/manifest.csv`
- Seed dùng trong batch logic: `20260416`

### 2.2. Môi trường chạy

Do thiết bị Pixel 4a không còn sẵn ở cuối phiên, kết quả 5 mốc được ghép từ **2 môi trường khác nhau**:

#### A. Trên thiết bị thật Pixel 4a
- 10 ảnh
- 15 ảnh
- 25 ảnh

#### B. Trên web-side equivalent runner
- 40 ảnh
- 65 ảnh

Web-side equivalent runner được viết để bám sát logic batch của app:

- dùng cùng pool 200 ảnh
- cùng cách chọn subset theo batch size
- cùng crop ratio ngẫu nhiên `30% → 80%`
- cùng rotate ngẫu nhiên trái/phải
- cùng upload multipart `image/jpeg` tới backend local

File hỗ trợ:
- `tester/run_mobile_batch_equivalent.py`
- `tester/mobile_batch_equivalent_40.json`
- `tester/mobile_batch_equivalent_65.json`

## 3) Kết quả tổng hợp

| Batch size | Môi trường | Đúng | Sai | Accuracy |
|---|---|---:|---:|---:|
| 10 | Pixel 4a | 7 | 3 | 70.00% |
| 15 | Pixel 4a | 13 | 2 | 86.67% |
| 25 | Pixel 4a | 22 | 3 | 88.00% |
| 40 | Web-side equivalent | 30 | 10 | 75.00% |
| 65 | Web-side equivalent | 50 | 15 | 76.92% |

### 3.1. Tổng cộng

- Tổng ảnh: **155**
- Đúng: **122**
- Sai: **33**
- Accuracy gộp: **78.71%**

## 4) Nhận xét nhanh về xu hướng

### 4.1. Sample nhỏ biến động khá mạnh

- Batch 10 chỉ đạt **70%**
- Batch 15 và 25 tăng lên **86.67%** và **88.00%**

Điều này cho thấy sample nhỏ dễ dao động mạnh theo tập ảnh được chọn ngẫu nhiên.

### 4.2. Khi sample lớn hơn, accuracy ổn định ở mức thấp hơn

- Batch 40: **75.00%**
- Batch 65: **76.92%**

Khi số mẫu tăng lên, kết quả bắt đầu phản ánh rõ hơn độ khó thực của full-flow có crop/rotate ngẫu nhiên. Mức này thấp hơn rõ rệt so với benchmark full-image trước đó.

### 4.3. So với benchmark trước

Tham chiếu các mốc đã có trước đây:

- Full image / PlantVillage random 1000 ảnh: **95.8%**
- Random crop 30–80% / 2000 ảnh: **86.0%**
- Full mobile flow 50 ảnh trên thiết bị thật trước đây: **86.0%**

Kết quả batch lần này thấp hơn các mốc trên, hợp lý vì:

- pool 200 ảnh mới khác sample cũ
- subset được random lại theo batch size
- crop + rotate ngẫu nhiên có thể tạo ra nhiều ca khó hơn
- kết quả hiện tại ghép từ 2 môi trường chạy, không phải 1 run đồng nhất end-to-end trên cùng device

## 5) Phân tích lỗi tổng quan

### 5.1. Các lỗi đã xác nhận ở batch 10 / 15 / 25

#### Batch 10 — 3 lỗi
1. `Tomato Yellow Leaf Curl Virus` → `Orange with Citrus Greening`
2. `Tomato with Target Spot` → `Tomato with Spider Mites or Two-spotted Spider Mite`
3. `Peach with Bacterial Spot` → `Tomato with Septoria Leaf Spot`

#### Batch 15 — 2 lỗi
1. `Tomato with Early Blight` → `Corn (Maize) with Northern Leaf Blight`
2. `Tomato with Bacterial Spot` → `Apple Scab`

#### Batch 25 — 3 lỗi
1. `Tomato with Spider Mites or Two-spotted Spider Mite` → `Healthy Potato Plant`
2. `Tomato with Bacterial Spot` → `Tomato Yellow Leaf Curl Virus`
3. `Tomato with Late Blight` → `Potato with Late Blight`

### 5.2. Confusion nổi bật ở batch 40

Từ `tester/mobile_batch_equivalent_40.json`, các cặp nhầm nổi bật:

- `Corn (Maize) with Northern Leaf Blight` → `Corn (Maize) with Cercospora and Gray Leaf Spot` (**2 lần**)
- `Peach with Bacterial Spot` → `Corn (Maize) with Northern Leaf Blight`
- `Healthy Bell Pepper Plant` → `Healthy Soybean Plant`
- `Tomato with Late Blight` → `Tomato with Target Spot`
- `Bell Pepper with Bacterial Spot` → `Healthy Bell Pepper Plant`
- `Tomato Yellow Leaf Curl Virus` → `Healthy Bell Pepper Plant`
- `Tomato with Septoria Leaf Spot` → `Tomato with Bacterial Spot`
- `Corn (Maize) with Common Rust` → `Corn (Maize) with Cercospora and Gray Leaf Spot`
- `Cedar Apple Rust` → `Apple with Black Rot`

### 5.3. Confusion nổi bật ở batch 65

Từ `tester/mobile_batch_equivalent_65.json`, các cặp nhầm nổi bật:

- `Corn (Maize) with Northern Leaf Blight` → `Corn (Maize) with Cercospora and Gray Leaf Spot` (**2 lần**)
- `Tomato with Spider Mites or Two-spotted Spider Mite` → `Healthy Potato Plant` (**2 lần**)
- `Apple with Black Rot` → `Healthy Peach Plant` (**2 lần**)
- `Healthy Tomato Plant` → `Tomato with Target Spot`
- `Grape with Esca (Black Measles)` → `Grape with Black Rot`
- `Healthy Apple` → `Healthy Peach Plant`
- `Healthy Soybean Plant` → `Healthy Bell Pepper Plant`
- `Grape with Isariopsis Leaf Spot` → `Potato with Late Blight`
- `Tomato with Target Spot` → `Healthy Potato Plant`
- `Orange with Citrus Greening` → `Healthy Blueberry Plant`

## 6) Nhóm lỗi chính

### Nhóm A — Nhầm trong cùng họ bệnh / cùng cây
Đây là nhóm dễ hiểu nhất và cũng lặp lại nhiều nhất:

- `Tomato with Late Blight` ↔ `Tomato with Target Spot`
- `Tomato with Septoria Leaf Spot` ↔ `Tomato with Bacterial Spot`
- `Tomato with Target Spot` ↔ `Tomato with Spider Mites...`
- `Corn (Maize) with Northern Leaf Blight` ↔ `Corn (Maize) with Cercospora and Gray Leaf Spot`
- `Grape with Esca (Black Measles)` ↔ `Grape with Black Rot`
- `Cedar Apple Rust` ↔ `Apple with Black Rot`

**Ý nghĩa:** crop/rotate ngẫu nhiên làm mất bối cảnh hình thái tổng thể, khiến model chỉ còn nhìn các texture cục bộ nên dễ nhầm giữa các bệnh có pattern lá tương tự.

### Nhóm B — Nhầm giữa bệnh và healthy của cùng hoặc gần domain
Ví dụ:

- `Bell Pepper with Bacterial Spot` → `Healthy Bell Pepper Plant`
- `Healthy Tomato Plant` → `Tomato with Target Spot`

**Ý nghĩa:** crop có thể cắt mất vùng tổn thương chính, khiến ảnh còn lại trông gần như healthy; hoặc ngược lại crop vào vùng nhiễu làm healthy trông giống bệnh.

### Nhóm C — Nhầm chéo giữa các loại cây khác nhau
Ví dụ:

- `Tomato Yellow Leaf Curl Virus` → `Orange with Citrus Greening`
- `Tomato with Spider Mites...` → `Healthy Potato Plant`
- `Healthy Soybean Plant` → `Healthy Bell Pepper Plant`
- `Peach with Bacterial Spot` → `Corn (Maize) with Northern Leaf Blight`
- `Apple with Black Rot` → `Healthy Peach Plant`

**Ý nghĩa:** đây là nhóm lỗi “nặng” hơn. Thường xuất hiện khi crop quá hẹp hoặc góc nhìn sau rotate làm mất gần hết tín hiệu đặc trưng của loại cây gốc.

## 7) Kết luận

### 7.1. Điều đã được xác nhận

- Pipeline batch full-flow hiện **chạy được** với pool 200 ảnh.
- Cách ghi log nội bộ / runner equivalent đã giúp lấy số ổn định hơn so với scrape UI.
- Khi áp dụng crop + rotate ngẫu nhiên, accuracy thực tế giảm đáng kể so với benchmark full-image.

### 7.2. Kết luận sản phẩm/demo

Model vẫn **ổn trong bối cảnh demo**, nhưng kết quả cho thấy:

- độ chính xác rất nhạy với tiền xử lý crop/rotate ngẫu nhiên
- không nên kỳ vọng full-flow kiểu “crop bừa + rotate bừa” sẽ giữ được accuracy cao như benchmark full-image
- nếu muốn trải nghiệm demo tốt hơn, nên định hướng người dùng:
  - giữ lá chiếm phần lớn ảnh
  - tránh crop quá sát
  - hạn chế rotate không cần thiết

## 8) Đề xuất bước tiếp theo

### Option 1 — Cải thiện chất lượng report
- xuất thêm confusion matrix gọn theo top lỗi
- tính per-class accuracy cho pool 200 ảnh đã chọn
- so sánh trực tiếp 3 mode:
  - full image
  - random crop only
  - random crop + rotate

### Option 2 — Cải thiện demo app
- giới hạn crop tối thiểu lớn hơn (ví dụ `50% → 90%` thay vì `30% → 80%`)
- chỉ rotate khi user chủ động, không random trong batch demo
- thêm hướng dẫn chụp ảnh để giảm cross-class confusion

### Option 3 — Dọn repo trước khi push/review
Hiện repo còn nhiều file phát sinh local cần dọn/chuẩn hóa trước khi push sạch:

- ảnh asset batch 200 file mới
- script automation tạm cho device test
- các file ảnh test local trong `backend/tests/`
- các result JSON local

---

## 9) File liên quan

- `mobile/assets/batch_samples/manifest.csv`
- `tester/mobile_batch_equivalent_40.json`
- `tester/mobile_batch_equivalent_65.json`
- `tester/run_mobile_batch_equivalent.py`
- `tester/mobile-batch-overall-report-2026-04-16.md`
