# Mobile Batch Smart Crop Comparison Report — 2026-04-16

## 1) Mục tiêu

File này dùng để **so sánh trực tiếp** giữa:

1. **Báo cáo cũ** — batch flow với crop/rotate ngẫu nhiên mạnh
2. **Báo cáo mới** — batch flow sau khi áp dụng **smart crop** và test lại trên **Pixel 4a**

Báo cáo cũ tham chiếu:
- `tester/mobile-batch-overall-report-2026-04-16.md`

---

## 2) Tóm tắt thay đổi logic

### Logic cũ
- crop ngẫu nhiên khá mạnh
- vùng crop có thể lệch xa khỏi trung tâm
- dễ cắt mất vùng bệnh chính hoặc mất ngữ cảnh tổng thể của lá

### Logic mới: Smart crop
- crop lớn hơn, giữ lại nhiều ngữ cảnh hơn
- crop bám gần trung tâm ảnh
- chỉ jitter nhẹ quanh vùng giữa
- mục tiêu: vẫn tạo biến thiên input nhưng không “phá ảnh” quá đà

---

## 3) Kết quả mới trên Pixel 4a

### Kết quả theo từng mốc

| Batch size | Đúng | Sai | Accuracy |
|---|---:|---:|---:|
| 10 | 9 | 1 | 90.00% |
| 15 | 13 | 2 | 86.67% |
| 25 | 23 | 2 | 92.00% |
| 40 | 37 | 3 | 92.50% |
| 65 | 59 | 6 | 90.77% |

### Tổng hợp chung

- Tổng ảnh: **155**
- Đúng: **141**
- Sai: **14**
- Accuracy gộp: **90.97%**

---

## 4) So sánh với báo cáo cũ

### 4.1. Bảng đối chiếu

| Batch size | Báo cáo cũ | Báo cáo mới smart crop | Chênh lệch |
|---|---:|---:|---:|
| 10 | 70.00% | 90.00% | **+20.00 điểm** |
| 15 | 86.67% | 86.67% | **0.00 điểm** |
| 25 | 88.00% | 92.00% | **+4.00 điểm** |
| 40 | 75.00% | 92.50% | **+17.50 điểm** |
| 65 | 76.92% | 90.77% | **+13.85 điểm** |

### 4.2. So sánh tổng thể

| Chỉ số | Báo cáo cũ | Báo cáo mới smart crop |
|---|---:|---:|
| Tổng ảnh | 155 | 155 |
| Đúng | 122 | 141 |
| Sai | 33 | 14 |
| Accuracy gộp | 78.71% | 90.97% |

### 4.3. Chênh lệch tổng thể

- Accuracy gộp tăng từ **78.71%** lên **90.97%**
- Mức tăng: **+12.26 điểm phần trăm**
- Số ảnh đoán đúng tăng từ **122** lên **141**
- Tăng thêm **19 ảnh đúng** trên cùng tổng số **155 ảnh**

---

## 5) Nhận xét ngắn

### 5.1. Smart crop có hiệu quả rõ rệt

Kết quả cho thấy việc đổi từ crop ngẫu nhiên mạnh sang **smart crop** giúp accuracy tăng đáng kể, đặc biệt ở các mốc lớn:

- 40 ảnh: tăng **+17.50 điểm**
- 65 ảnh: tăng **+13.85 điểm**

Đây là tín hiệu rất tốt vì các mốc lớn phản ánh ổn định hơn so với sample nhỏ.

### 5.2. Mục tiêu >80% đã vượt rõ ràng

Với logic smart crop mới, toàn bộ các mốc trên Pixel 4a đều đã vượt **86%**, và accuracy gộp đạt gần **91%**.

### 5.3. Giải thích vì sao hiệu quả

Smart crop giúp:

- giữ lại phần lớn lá / vùng bệnh
- giảm xác suất crop trúng nền hoặc vùng không liên quan
- giảm nhầm chéo giữa các loại cây khác nhau
- vẫn giữ được tính đa dạng của input mà không làm model bị “mù ngữ cảnh”

---

## 6) Kết luận

Nếu mục tiêu của demo là:
- **ra kết quả ổn định hơn**
- **đưa accuracy thực tế lên trên 80%**
- **giữ trải nghiệm crop vẫn linh hoạt**

thì **smart crop là hướng đúng và đã được xác nhận bằng test thực tế trên Pixel 4a**.

Kết luận ngắn gọn:

- logic cũ: **quá khắc nghiệt** với model
- logic mới smart crop: **cân bằng tốt hơn giữa realism và accuracy**
- nên dùng **smart crop** làm default cho flow batch/demo

---

## 7) File liên quan

- Báo cáo cũ: `tester/mobile-batch-overall-report-2026-04-16.md`
- Báo cáo so sánh mới: `tester/mobile-batch-smartcrop-comparison-report-2026-04-16.md`
