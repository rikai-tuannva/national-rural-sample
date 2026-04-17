# Report Field Explanation

File này giải thích các field chính xuất hiện trong các file report/JSON benchmark của dự án `national-rural-sample`.

## 1) `file`

Ví dụ:

```json
"file": "data_distribution_for_SVM/test/8/11b127a0-337d-443d-8b0d-b05f11cc6dd5.JPG"
```

Ý nghĩa:
- đây là đường dẫn tương đối tới ảnh gốc trong dataset benchmark
- số thư mục ở giữa (ví dụ `8`) là **class id** của ảnh trong dataset

---

## 2) `expected_label`

Ví dụ:

```json
"expected_label": "Corn (Maize) with Common Rust"
```

Ý nghĩa:
- đây là **nhãn ground truth** của ảnh
- **không phải** nhãn do model sinh ra

### `expected_label` được lấy từ đâu?

Có 2 trường hợp chính:

### A. Benchmark PlantVillage trực tiếp
Ví dụ file:
- `tester/plantvillage_random_crop_benchmark_result_15.json`

Script lấy `expected_label` từ **folder class chứa ảnh**.

Ví dụ:
- ảnh nằm trong `.../test/8/...`
- folder cha là `8`
- script map `8` qua bảng `ID_TO_LABEL`
- kết quả là:
  - `8 -> Corn (Maize) with Common Rust`

Code hiện tại trong `tester/run_plantvillage_random_crop_benchmark.py`:

```python
expected_label = ID_TO_LABEL[int(image_path.parent.name)]
```

### B. Batch mobile assets
Ví dụ các file batch trên app/mobile.

Lúc này `expected_label` được lấy từ:
- `mobile/assets/batch_samples/manifest.csv`

Manifest có cấu trúc kiểu:

```csv
asset_name,class_id,source_name
sample_001.jpg,16,c91758a1-ff3f-476f-92b5-6924f072b718.JPG
```

Sau đó script/app map:
- `class_id`
- qua bảng `ID_TO_LABEL`
- để ra `expected_label`

Ví dụ:
- `16 -> Peach with Bacterial Spot`

---

## 3) `predicted_label`

Ví dụ:

```json
"predicted_label": "Corn (Maize) with Northern Leaf Blight"
```

Ý nghĩa:
- đây là nhãn model dự đoán sau khi ảnh được gửi vào endpoint `/predict`
- field này đến từ output thật của model

---

## 4) `confidence`

Ví dụ:

```json
"confidence": 0.8194
```

Ý nghĩa:
- độ tin cậy của dự đoán `predicted_label`
- thường hiểu là xác suất hoặc score chuẩn hóa của top-1 class

Ví dụ:
- `0.8194` tương đương khoảng **81.94%**

---

## 5) `ok`

Ví dụ:

```json
"ok": false
```

Ý nghĩa:
- kết quả so sánh giữa:
  - `predicted_label`
  - `expected_label`

Rule hiện tại:

```python
ok = predicted_label == expected_label
```

Nên:
- `true` = model đoán đúng nhãn ground truth
- `false` = model đoán sai nhãn ground truth

---

## 6) `crop_box`

Ví dụ:

```json
"crop_box": [35, 86, 228, 170]
```

Ý nghĩa:
- vùng crop được lấy từ ảnh gốc
- format thường là:
  - `[left, top, right, bottom]`

---

## 7) `crop_ratio_width` và `crop_ratio_height`

Ví dụ:

```json
"crop_ratio_width": 0.7542,
"crop_ratio_height": 0.3305
```

Ý nghĩa:
- tỷ lệ chiều rộng và chiều cao của vùng crop so với ảnh gốc
- ví dụ trên nghĩa là:
  - crop rộng khoảng **75.42%** chiều rộng ảnh gốc
  - crop cao khoảng **33.05%** chiều cao ảnh gốc

---

## 8) `crop_index`

Ví dụ:

```json
"crop_index": 0
```

Ý nghĩa:
- chỉ số lần crop nếu một ảnh được crop/test nhiều lần
- hiện nhiều benchmark đang chạy `crops_per_image = 1`, nên thường sẽ là `0`

---

## 9) Tóm tắt ngắn

- `expected_label` = **nhãn chuẩn của dataset**
- `predicted_label` = **nhãn model đoán ra**
- `ok` = so sánh đúng/sai giữa 2 nhãn trên
- benchmark hiện tại dùng ground truth từ:
  - **folder class của dataset**, hoặc
  - **`manifest.csv` của mobile assets**

---

## 10) Ví dụ cụ thể

Record:

```json
{
  "file": "data_distribution_for_SVM/test/8/11b127a0-337d-443d-8b0d-b05f11cc6dd5.JPG",
  "crop_index": 0,
  "crop_box": [35, 86, 228, 170],
  "crop_ratio_width": 0.7542,
  "crop_ratio_height": 0.3305,
  "expected_label": "Corn (Maize) with Common Rust",
  "predicted_label": "Corn (Maize) with Northern Leaf Blight",
  "confidence": 0.8194,
  "ok": false
}
```

Diễn giải:
- ảnh gốc thuộc class folder `8`
- class `8` map ra:
  - `Corn (Maize) with Common Rust`
- model lại đoán:
  - `Corn (Maize) with Northern Leaf Blight`
- nên:
  - `ok = false`
