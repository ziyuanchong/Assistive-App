import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AllergenScanner extends StatefulWidget {
  final String language; // 'en' or 'zh'
  
  const AllergenScanner({super.key, required this.language});

  @override
  State<AllergenScanner> createState() => _AllergenScannerState();
}

class _AllergenScannerState extends State<AllergenScanner> {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  final FlutterTts _tts = FlutterTts();
  
  bool _isProcessing = false;
  String _detectedText = "";
  List<String> _foundAllergens = [];
  
  // Enhanced allergen list based on the image - includes variations
  final Map<String, List<String>> _allergensList = {
    'en': [
      'milk', 'dairy', 'lactose', 'whey', 'casein', 'cream', 'butter', 'skim milk',
      'peanut', 'peanuts', 'tree nuts', 'tree nut', 'almond', 'walnut', 'cashew', 
      'hazelnut', 'pecan', 'pistachio', 'nuts',
      'soy', 'soya', 'soybean', 'soy bean', 'soybeans',
      'wheat', 'gluten',
      'egg', 'eggs', 'egg white', 'egg yolk',
      'fish', 'shellfish', 'crustacean', 'shrimp', 'crab', 'lobster', 'prawn',
      'sesame',
      'sulfite', 'sulphite', 'sulfur dioxide'
    ],
    'zh': [
      '牛奶', '乳制品', '乳', '奶', '乳糖', '乳清', '酪蛋白', '奶油', '黄油', '脱脂奶', '奶粉',
      '花生', '坚果', '果仁', '杏仁', '核桃', '腰果', '榛子', '胡桃', '开心果',
      '大豆', '黄豆', '豆类', '豆制品', '豆', '黄豆粉',
      '小麦', '麸质', '面筋', '麦',
      '鸡蛋', '蛋', '蛋白', '蛋黄', '蛋白粉', '鸡蛋粉',
      '鱼', '鱼类', '贝类', '甲壳类', '虾', '蟹', '龙虾', '海鲜',
      '芝麻', '麻',
      '亚硫酸盐', '二氧化硫'
    ],
  };

  // UI text translations
  Map<String, String> get _t => widget.language == 'zh' ? {
    'title': '过敏原扫描',
    'camera_ready': '相机准备就绪',
    'camera_not_ready': '相机未准备好',
    'capturing': '正在拍照',
    'analyzing': '分析中...',
    'guide_text': '对准成分列表',
    'allergens_detected': '检测到过敏原',
    'no_allergens': '未检测到常见过敏原',
    'verify_label': '注意：请务必核对实际标签',
    'point_camera': '对准标签并点击扫描',
    'detected_text': '检测到的文字',
    'scan_label': '扫描标签',
    'processing': '处理中...',
    'no_camera': '没有相机',
    'camera_failed': '相机失败',
    'no_allergens_audio': '未检测到常见过敏原',
    'allergens_found_audio': '警告！此产品含有：',
    'ocr_failed': '无法读取标签',
    'no_text_detected': '未检测到文字',
  } : {
    'title': 'Allergen Scanner',
    'camera_ready': 'Camera ready',
    'camera_not_ready': 'Camera not ready',
    'capturing': 'Capturing',
    'analyzing': 'Analyzing...',
    'guide_text': 'Align ingredients',
    'allergens_detected': 'Allergens Detected',
    'no_allergens': 'No allergens detected',
    'verify_label': 'Always verify label',
    'point_camera': 'Point at label and scan',
    'detected_text': 'Detected Text',
    'scan_label': 'Scan Label',
    'processing': 'Processing...',
    'no_camera': 'No camera',
    'camera_failed': 'Camera failed',
    'no_allergens_audio': 'No common allergens detected',
    'allergens_found_audio': 'Warning! Contains: ',
    'ocr_failed': 'Failed to read label',
    'no_text_detected': 'No text detected',
  };

  @override
  void initState() {
    super.initState();
    _initializeTextRecognizer();
    _initializeCamera();
    _initTts();
  }

  void _initializeTextRecognizer() {
    if (widget.language == 'zh') {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    } else {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.stop();
      String ttsLanguage = widget.language == 'zh' ? 'zh-CN' : 'en-US';
      await _tts.setLanguage(ttsLanguage);
      if (widget.language == 'zh') {
        await _tts.setVoice({"name": "Ting-Ting", "locale": "zh-CN"});
      } else {
        await _tts.setVoice({"name": "Samantha", "locale": "en-US"});
      }
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      print("TTS error: $e");
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Camera error: $e");
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      print("TTS error: $e");
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectedText = _t['analyzing']!;
      _foundAllergens = [];
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      print("📸 Captured: ${image.path}");
      
      final InputImage inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      print("📝 OCR Text (${recognizedText.text.length} chars):");
      print(recognizedText.text);
      
      if (recognizedText.text.isEmpty) {
        setState(() {
          _detectedText = _t['no_text_detected']!;
          _isProcessing = false;
        });
        await _speak(_t['no_text_detected']!);
        return;
      }
      
      String fullText = recognizedText.text;
      setState(() => _detectedText = fullText);

      // Find allergens
      List<String> allergens = _allergensList[widget.language]!;
      List<String> found = [];
      
      for (String allergen in allergens) {
        bool match = widget.language == 'zh'
            ? fullText.contains(allergen)
            : fullText.toLowerCase().contains(allergen.toLowerCase());
        
        if (match && !found.contains(allergen)) {
          found.add(allergen);
          print("✓ Found: $allergen");
        }
      }

      setState(() => _foundAllergens = found);

      if (found.isEmpty) {
        await _speak(_t['no_allergens_audio']!);
      } else {
        String list = found.join(widget.language == 'zh' ? '，' : ', ');
        await _speak(_t['allergens_found_audio']! + list);
      }

    } catch (e) {
      print("Error: $e");
      await _speak(_t['ocr_failed']!);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['title']!),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // Camera with fixed aspect ratio
          Expanded(
            flex: 3,
            child: _cameraController != null && _cameraController!.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 40),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _t['guide_text']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: CircularProgressIndicator()),
          ),

          // Results
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              color: _foundAllergens.isEmpty ? Colors.grey.shade100 : Colors.red.shade50,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isProcessing)
                      Center(child: CircularProgressIndicator())
                    else if (_foundAllergens.isNotEmpty) ...[
                      Text(
                        _t['allergens_detected']!,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      SizedBox(height: 10),
                      ..._foundAllergens.map((a) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 24),
                                SizedBox(width: 10),
                                Text(a.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                    ] else if (_detectedText.isNotEmpty) ...[
                      Text(
                        _t['no_allergens']!,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      SizedBox(height: 10),
                      Text(_t['verify_label']!, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                    ] else ...[
                      Center(child: Text(_t['point_camera']!, textAlign: TextAlign.center)),
                    ],
                    
                    if (_detectedText.isNotEmpty && !_isProcessing) ...[
                      SizedBox(height: 15),
                      Divider(),
                      Text(_t['detected_text']!, style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Container(
                        constraints: BoxConstraints(maxHeight: 100),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SingleChildScrollView(child: Text(_detectedText, style: TextStyle(fontSize: 12))),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _captureAndAnalyze,
        backgroundColor: _isProcessing ? Colors.grey : Colors.orange,
        icon: Icon(_isProcessing ? Icons.hourglass_bottom : Icons.camera, size: 28),
        label: Text(_isProcessing ? _t['processing']! : _t['scan_label']!, style: TextStyle(fontSize: 18)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _tts.stop();
    super.dispose();
  }
}