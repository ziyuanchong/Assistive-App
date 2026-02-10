import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

class AllergenScanner extends StatefulWidget {
  final String language;
  
  const AllergenScanner({super.key, required this.language});

  @override
  State<AllergenScanner> createState() => _AllergenScannerState();
}

class _AllergenScannerState extends State<AllergenScanner> {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  final FlutterTts _tts = FlutterTts();
  
  XFile? _capturedImage;
  bool _isProcessing = false;
  String _detectedText = "";
  List<String> _foundAllergens = [];
  
  final Map<String, List<String>> _allergensList = {
    'en': [
      'milk', 'dairy', 'lactose', 'whey', 'casein', 'cream', 'butter', 'skim milk',
      'peanut', 'peanuts', 'tree nuts', 'almond', 'walnut', 'cashew', 
      'hazelnut', 'pecan', 'pistachio', 'nuts',
      'soy', 'soya', 'soybean', 'soybeans',
      'wheat', 'gluten',
      'egg', 'eggs', 'egg white', 'egg yolk',
      'fish', 'shellfish', 'crustacean', 'shrimp', 'crab', 'lobster',
      'sesame', 'sulfite', 'sulphite'
    ],
    'zh': [
      '牛奶', '乳', '奶', '乳糖', '乳清', '酪蛋白', '奶粉',
      '花生', '坚果', '果仁', '杏仁', '核桃', '腰果', '榛子',
      '大豆', '黄豆', '豆', '黄豆粉',
      '小麦', '麸质', '面筋', '麦',
      '鸡蛋', '蛋', '蛋白', '蛋黄', '蛋白粉',
      '鱼', '贝类', '甲壳类', '虾', '蟹', '龙虾',
      '芝麻', '麻', '亚硫酸盐'
    ],
  };

  Map<String, String> get _t => widget.language == 'zh' ? {
    'title': 'OCR 扫描',
    'retake': '重拍',
    'crop': '裁剪',
    'use_photo': '使用照片',
    'allergens_found': '发现过敏原',
    'no_allergens': '未发现过敏原',
    'detected_text': '识别的文字',
    'processing': '处理中...',
  } : {
    'title': 'OCR Scanner',
    'retake': 'Retake',
    'crop': 'Crop',
    'use_photo': 'Use Photo',
    'allergens_found': 'Allergens Found',
    'no_allergens': 'No Allergens',
    'detected_text': 'Detected Text',
    'processing': 'Processing...',
  };

  @override
  void initState() {
    super.initState();
    _initializeTextRecognizer();
    _initializeCamera();
    _initTts();
  }

  void _initializeTextRecognizer() {
    _textRecognizer = widget.language == 'zh'
        ? TextRecognizer(script: TextRecognitionScript.chinese)
        : TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<void> _initTts() async {
    try {
      await _tts.stop();
      String lang = widget.language == 'zh' ? 'zh-CN' : 'en-US';
      await _tts.setLanguage(lang);
      if (widget.language == 'zh') {
        await _tts.setVoice({"name": "Ting-Ting", "locale": "zh-CN"});
      }
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
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

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print("Capture error: $e");
    }
  }

  Future<void> _cropImage() async {
    if (_capturedImage == null) return;

    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: _capturedImage!.path,
        uiSettings: [
          IOSUiSettings(
            title: _t['crop']!,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            aspectRatioLockEnabled: false,
            minimumAspectRatio: 0.5,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _capturedImage = XFile(croppedFile.path);
        });
      }
    } catch (e) {
      print("Crop error: $e");
    }
  }

  Future<void> _processImage() async {
    if (_capturedImage == null) return;

    setState(() {
      _isProcessing = true;
      _detectedText = "";
      _foundAllergens = [];
    });

    try {
      final InputImage inputImage = InputImage.fromFilePath(_capturedImage!.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      print("📝 OCR Text (${recognizedText.text.length} chars):");
      print(recognizedText.text);
      
      String fullText = recognizedText.text;
      
      setState(() {
        _detectedText = fullText;
      });

      // Auto-detect allergens
      if (fullText.isNotEmpty) {
        List<String> allergens = _allergensList[widget.language]!;
        List<String> found = [];
        
        for (String allergen in allergens) {
          bool match = widget.language == 'zh'
              ? fullText.contains(allergen)
              : fullText.toLowerCase().contains(allergen.toLowerCase());
          
          if (match && !found.contains(allergen)) {
            found.add(allergen);
          }
        }

        setState(() {
          _foundAllergens = found;
        });

        // Speak results
        if (found.isNotEmpty) {
          String list = found.join(widget.language == 'zh' ? '，' : ', ');
          String msg = (widget.language == 'zh' ? '检测到过敏原：' : 'Allergens detected: ') + list;
          await _tts.speak(msg);
        }
      }

    } catch (e) {
      print("OCR error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _detectedText = "";
      _foundAllergens = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera or captured image (FULLSCREEN)
          if (_capturedImage == null) ...[
            // Live camera view
            if (_cameraController != null && _cameraController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Center(child: CircularProgressIndicator(color: Colors.white)),
          ] else ...[
            // Captured image preview
            SizedBox.expand(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
          ],

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _t['title']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Bottom controls (iOS style)
          if (_capturedImage == null) ...[
            // Camera mode - capture button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Preview mode - retake, crop, and use buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Retake button
                    TextButton.icon(
                      onPressed: _retake,
                      icon: Icon(Icons.refresh, color: Colors.white, size: 24),
                      label: Text(
                        _t['retake']!,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    
                    // Crop button
                    TextButton.icon(
                      onPressed: _cropImage,
                      icon: Icon(Icons.crop, color: Colors.white, size: 24),
                      label: Text(
                        _t['crop']!,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    
                    // Use photo button
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processImage,
                      icon: _isProcessing 
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.check, size: 24),
                      label: Text(
                        _isProcessing ? _t['processing']! : _t['use_photo']!,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Results overlay (when processing complete)
          if (_detectedText.isNotEmpty && !_isProcessing) ...[
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 15,
              right: 15,
              child: Container(
                constraints: BoxConstraints(maxHeight: size.height * 0.7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Allergen warnings
                    if (_foundAllergens.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.white, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  _t['allergens_found']!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _foundAllergens.map((a) => Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  a.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Detected text
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.text_fields, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  _t['detected_text']!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              _detectedText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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