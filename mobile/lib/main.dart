import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const NationalRuralSampleApp());
}

class NationalRuralSampleApp extends StatelessWidget {
  const NationalRuralSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '植物病害診断デモ',
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

  File? _selectedImage;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  bool get _isBusy => _isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('植物病害診断デモ'),
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
                      'バックエンド API',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'API ベース URL',
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
                      '1. 画像を選択',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '作物の病害が写っている画像を選択してください。カメラ撮影またはギャラリー選択後、必要に応じて切り抜き・回転してから送信できます。',
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
                            label: const Text('写真を撮る'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('ギャラリーから選ぶ'),
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
                          label: const Text('切り抜き'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _selectedImage == null || _isBusy
                              ? null
                              : () => _rotateSelectedImage(clockwise: false),
                          icon: const Icon(Icons.rotate_left),
                          label: const Text('左回転'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _selectedImage == null || _isBusy
                              ? null
                              : () => _rotateSelectedImage(clockwise: true),
                          icon: const Icon(Icons.rotate_right),
                          label: const Text('右回転'),
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
                      label: Text(_isSubmitting ? '診断中...' : '診断する'),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

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
          child: Text('まだ画像が選択されていません'),
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

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
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
          toolbarTitle: '画像を切り抜く',
          toolbarColor: const Color(0xFF2F855A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: '画像を切り抜く'),
      ],
    );

    if (croppedFile == null) {
      return;
    }

    setState(() {
      _selectedImage = File(croppedFile.path);
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
        _errorMessage = '画像を回転できませんでした。';
      });
      return;
    }

    await image.writeAsBytes(rotatedBytes, flush: true);

    setState(() {
      _selectedImage = image;
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
        _errorMessage = 'API ベース URL を入力してください。';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await _predictFromFile(image);
      if (!mounted) {
        return;
      }
      await _showPredictionDialog(response);
    } catch (error) {
      setState(() {
        _errorMessage = 'API に接続できません: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showPredictionDialog(PredictionResponse prediction) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('診断結果'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '最も可能性が高い結果',
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
                          '信頼度: ${_formatConfidence(prediction.prediction.confidence)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '候補一覧',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...prediction.topK.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(item.label),
                        subtitle: Text('信頼度: ${_formatConfidence(item.confidence)}'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
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

    throw Exception((jsonBody['error'] ?? 'API 呼び出しに失敗しました').toString());
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
  PredictionItem({
    required this.label,
    required this.labelEn,
    required this.confidence,
  });

  final String label;
  final String labelEn;
  final double confidence;

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      label: (json['label'] ?? 'Unknown').toString(),
      labelEn: (json['label_en'] ?? json['label'] ?? 'Unknown').toString(),
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
    );
  }
}
