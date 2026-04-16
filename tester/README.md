# Tester - PlantVillage benchmark

## Dataset source
- https://github.com/spMohanty/PlantVillage-Dataset/tree/master/data_distribution_for_SVM/test

## Benchmark scripts
- `tester/run_plantvillage_benchmark.py`
- `tester/run_plantvillage_random_crop_benchmark.py`

## Expected flow
1. Backend chạy ở `http://127.0.0.1:8000`
2. Script đi qua toàn bộ thư mục test `0..37`
3. Gọi `POST /predict` cho từng ảnh
4. So sánh nhãn dự đoán với nhãn kỳ vọng theo id thư mục
5. Ghi kết quả vào `tester/plantvillage_benchmark_result.json`

## Random crop benchmark
- Sinh crop ngẫu nhiên cho từng ảnh
- Kích thước crop = `1/3` ảnh gốc
- Gửi crop đó vào `/predict`
- Dùng để kiểm tra model nhạy thế nào khi chỉ nhìn một vùng con của ảnh
