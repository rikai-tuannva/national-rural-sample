#!/usr/bin/env bash
set -euo pipefail

cd /home/tuannguyen/.openclaw/workspace/national-rural-sample
curl -fsS http://127.0.0.1:8000/health >/dev/null

for n in 10 15 25 40 65; do
  echo "=== SAMPLE_SIZE:${n} ==="
  python3 tester/run_plantvillage_random_crop_benchmark.py \
    --sample-size "$n" \
    --crops-per-image 1 \
    --seed 4242 \
    --min-crop-ratio 0.3 \
    --max-crop-ratio 0.8
  cp tester/plantvillage_random_crop_benchmark_result.json "tester/plantvillage_random_crop_benchmark_result_${n}.json"
  echo
 done
