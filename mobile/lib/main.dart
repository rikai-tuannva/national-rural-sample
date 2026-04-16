import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const NationalRuralSampleApp());
}

class NationalRuralSampleApp extends StatelessWidget {
  const NationalRuralSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'National Rural Sample',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F855A)),
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
        useMaterial3: true,
      ),
      home: const ImageClassifierPage(),
    );
  }
}

class ImageClassifierPage extends StatefulWidget {
  const ImageClassifierPage({super.key});

  @override
  State<ImageClassifierPage> createState() => _ImageClassifierPageState();
}

class _ImageClassifierPageState extends State<ImageClassifierPage> {
  static const String _defaultApiBaseUrl = 'http://127.0.0.1:8000';

  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _apiController =
      TextEditingController(text: _defaultApiBaseUrl);
  final Random _random = Random(20260416);

  File? _selectedImage;
  PredictionResponse? _prediction;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isBatchRunning = false;
  BatchRunSummary? _batchSummary;

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Disease Demo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend API',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'API base URL',
                        hintText: 'http://192.168.10.97:8000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '1. Chọn nguồn ảnh',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ảnh là tình trạng bệnh của một loại cây nông nghiệp bất kỳ. Có thể chụp ảnh mới hoặc chọn từ thư viện, rồi crop / rotate trước khi submit.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Chụp ảnh'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Chọn từ thư viện'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildImagePreview(),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _selectedImage == null || _isBusy
                              ? null
                              : _cropSelectedImage,
                          icon: const Icon(Icons.crop),
                          label: const Text('Crop'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _selectedImage == null || _isBusy
                              ? null
                              : () => _rotateSelectedImage(clockwise: false),
                          icon: const Icon(Icons.rotate_left),
                          label: const Text('Rotate trái'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _selectedImage == null || _isBusy
                              ? null
                              : () => _rotateSelectedImage(clockwise: true),
                          icon: const Icon(Icons.rotate_right),
                          label: const Text('Rotate phải'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _selectedImage == null || _isBusy
                          ? null
                          : _submitPrediction,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_isSubmitting ? 'Đang phân tích...' : 'Submit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '2. Batch test trên app mobile',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chạy tự động 50 ảnh mẫu ngay trong app: mỗi ảnh sẽ crop ngẫu nhiên, rotate ngẫu nhiên rồi submit lên backend để lấy kết quả tổng hợp.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isBusy ? null : _runBatchFlow,
                      icon: _isBatchRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_motion_outlined),
                      label: Text(
                        _isBatchRunning
                            ? 'Đang chạy batch 50 ảnh...'
                            : 'Chạy batch 50 ảnh',
                      ),
                    ),
                    if (_batchSummary != null) ...[
                      const SizedBox(height: 16),
                      _buildBatchSummary(theme, _batchSummary!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                _SectionCard(
                  backgroundColor: const Color(0xFFFFF1F2),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),
              _SectionCard(
                child: _prediction == null
                    ? const Text(
                        'Chưa có kết quả. Hãy chọn ảnh, crop/rotate nếu cần rồi submit.',
                      )
                    : _buildPredictionView(theme, _prediction!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isBusy => _isSubmitting || _isBatchRunning;

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0D5DD)),
          color: Colors.white,
        ),
        child: const Center(
          child: Text('Chưa có ảnh nào được chọn'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: kIsWeb
            ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
            : Image.file(_selectedImage!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPredictionView(ThemeData theme, PredictionResponse prediction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kết quả tốt nhất',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF0FDF4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prediction.prediction.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${_formatConfidence(prediction.prediction.confidence)}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Top kết quả',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...prediction.topK.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.white,
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(item.label),
                subtitle: Text(_formatConfidence(item.confidence)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBatchSummary(ThemeData theme, BatchRunSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Batch result',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text('Tổng ảnh: ${summary.total}'),
          Text('Đúng: ${summary.correct}'),
          Text('Sai: ${summary.total - summary.correct}'),
          Text('Accuracy: ${(summary.accuracy * 100).toStringAsFixed(2)}%'),
          const SizedBox(height: 12),
          if (summary.failures.isNotEmpty)
            ...summary.failures.take(10).map(
              (failure) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${failure.assetName}: ${failure.expectedLabel} → ${failure.predictedLabel} (${_formatConfidence(failure.confidence)})',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else
            const Text('Không có case sai trong batch này.'),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _prediction = null;
    });

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 95,
    );

    if (pickedFile == null) {
      return;
    }

    setState(() {
      _selectedImage = File(pickedFile.path);
    });
  }

  Future<void> _cropSelectedImage() async {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop ảnh',
          toolbarColor: const Color(0xFF2F855A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop ảnh'),
      ],
    );

    if (croppedFile == null) {
      return;
    }

    setState(() {
      _selectedImage = File(croppedFile.path);
      _prediction = null;
      _errorMessage = null;
    });
  }

  Future<void> _rotateSelectedImage({required bool clockwise}) async {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    final rotatedBytes = _rotateBytes(
      bytes,
      clockwise: clockwise,
    );
    if (rotatedBytes == null) {
      setState(() {
        _errorMessage = 'Không thể xử lý ảnh để rotate.';
      });
      return;
    }

    await image.writeAsBytes(rotatedBytes, flush: true);

    setState(() {
      _selectedImage = image;
      _prediction = null;
      _errorMessage = null;
    });
  }

  Future<void> _submitPrediction() async {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    final baseUrl = _apiController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Hãy nhập API base URL.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _prediction = null;
    });

    try {
      final response = await _predictFromFile(image);
      setState(() {
        _prediction = response;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Không thể kết nối API: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _runBatchFlow() async {
    setState(() {
      _isBatchRunning = true;
      _errorMessage = null;
      _batchSummary = null;
      _prediction = null;
    });

    try {
      final manifest = await rootBundle.loadString('assets/batch_samples/manifest.csv');
      final lines = manifest
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .skip(1)
          .toList();

      final tempDir = await getTemporaryDirectory();
      final failures = <BatchFailure>[];
      var correct = 0;

      for (final line in lines) {
        final parts = line.split(',');
        if (parts.length < 3) {
          continue;
        }

        final assetName = parts[0];
        final classId = int.parse(parts[1]);
        final expectedLabel = idToLabel[classId] ?? 'Unknown';
        final data = await rootBundle.load('assets/batch_samples/$assetName');
        final originalBytes = data.buffer.asUint8List();
        final croppedBytes = _cropBytesRandom(originalBytes) ?? originalBytes;
        final rotatedBytes = _rotateBytes(
              croppedBytes,
              clockwise: _random.nextBool(),
            ) ??
            croppedBytes;

        final tempFile = File('${tempDir.path}/$assetName')
          ..writeAsBytesSync(rotatedBytes, flush: true);

        final prediction = await _predictFromFile(tempFile);
        final ok = prediction.prediction.label == expectedLabel;
        correct += ok ? 1 : 0;
        if (!ok) {
          failures.add(
            BatchFailure(
              assetName: assetName,
              expectedLabel: expectedLabel,
              predictedLabel: prediction.prediction.label,
              confidence: prediction.prediction.confidence,
            ),
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _batchSummary = BatchRunSummary(
          total: lines.length,
          correct: correct,
          failures: failures,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Batch test thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBatchRunning = false;
        });
      }
    }
  }

  Future<PredictionResponse> _predictFromFile(File image) async {
    final baseUrl = _apiController.text.trim();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final jsonBody = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return PredictionResponse.fromJson(jsonBody);
    }

    throw Exception((jsonBody['error'] ?? 'Gọi API thất bại').toString());
  }

  Uint8List? _cropBytesRandom(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final cropWidth = max(1, ((decoded.width * (_random.nextDouble() * 0.5 + 0.3))).floor());
    final cropHeight = max(1, ((decoded.height * (_random.nextDouble() * 0.5 + 0.3))).floor());
    final maxX = max(0, decoded.width - cropWidth);
    final maxY = max(0, decoded.height - cropHeight);
    final x = maxX == 0 ? 0 : _random.nextInt(maxX + 1);
    final y = maxY == 0 ? 0 : _random.nextInt(maxY + 1);
    final cropped = img.copyCrop(decoded, x: x, y: y, width: cropWidth, height: cropHeight);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Uint8List? _rotateBytes(Uint8List bytes, {required bool clockwise}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final rotated = clockwise
        ? img.copyRotate(decoded, angle: 90)
        : img.copyRotate(decoded, angle: -90);
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
  }

  String _formatConfidence(double value) => '${(value * 100).toStringAsFixed(2)}%';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.backgroundColor});

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PredictionResponse {
  PredictionResponse({
    required this.success,
    required this.prediction,
    required this.topK,
  });

  final bool success;
  final PredictionItem prediction;
  final List<PredictionItem> topK;

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    return PredictionResponse(
      success: json['success'] as bool? ?? false,
      prediction: PredictionItem.fromJson(
        json['prediction'] as Map<String, dynamic>? ?? const {},
      ),
      topK: (json['top_k'] as List<dynamic>? ?? const [])
          .map((item) => PredictionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PredictionItem {
  PredictionItem({required this.label, required this.confidence});

  final String label;
  final double confidence;

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      label: (json['label'] ?? 'Unknown').toString(),
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
    );
  }
}

class BatchRunSummary {
  BatchRunSummary({
    required this.total,
    required this.correct,
    required this.failures,
  });

  final int total;
  final int correct;
  final List<BatchFailure> failures;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class BatchFailure {
  BatchFailure({
    required this.assetName,
    required this.expectedLabel,
    required this.predictedLabel,
    required this.confidence,
  });

  final String assetName;
  final String expectedLabel;
  final String predictedLabel;
  final double confidence;
}

const Map<int, String> idToLabel = {
  0: 'Apple Scab',
  1: 'Apple with Black Rot',
  2: 'Cedar Apple Rust',
  3: 'Healthy Apple',
  4: 'Healthy Blueberry Plant',
  5: 'Cherry with Powdery Mildew',
  6: 'Healthy Cherry Plant',
  7: 'Corn (Maize) with Cercospora and Gray Leaf Spot',
  8: 'Corn (Maize) with Common Rust',
  9: 'Corn (Maize) with Northern Leaf Blight',
  10: 'Healthy Corn (Maize) Plant',
  11: 'Grape with Black Rot',
  12: 'Grape with Esca (Black Measles)',
  13: 'Grape with Isariopsis Leaf Spot',
  14: 'Healthy Grape Plant',
  15: 'Orange with Citrus Greening',
  16: 'Peach with Bacterial Spot',
  17: 'Healthy Peach Plant',
  18: 'Bell Pepper with Bacterial Spot',
  19: 'Healthy Bell Pepper Plant',
  20: 'Potato with Early Blight',
  21: 'Potato with Late Blight',
  22: 'Healthy Potato Plant',
  23: 'Healthy Raspberry Plant',
  24: 'Healthy Soybean Plant',
  25: 'Squash with Powdery Mildew',
  26: 'Strawberry with Leaf Scorch',
  27: 'Healthy Strawberry Plant',
  28: 'Tomato with Bacterial Spot',
  29: 'Tomato with Early Blight',
  30: 'Tomato with Late Blight',
  31: 'Tomato with Leaf Mold',
  32: 'Tomato with Septoria Leaf Spot',
  33: 'Tomato with Spider Mites or Two-spotted Spider Mite',
  34: 'Tomato with Target Spot',
  35: 'Tomato Yellow Leaf Curl Virus',
  36: 'Tomato Mosaic Virus',
  37: 'Healthy Tomato Plant',
};
