import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'disability_selection.dart';
import 'dart:async';
import 'dart:io';

class AllergenScanner extends StatefulWidget {
  final String language;
  final bool autoStartLiveScan; // For blind users: auto-start live scan on open
  
  const AllergenScanner({
    super.key,
    required this.language,
    this.autoStartLiveScan = false,
  });

  @override
  State<AllergenScanner> createState() => _AllergenScannerState();
}

class _AllergenScannerState extends State<AllergenScanner> {
  CameraController? _cameraController;
  late TextRecognizer _autoTextRecognizer;
  late TextRecognizer _latinTextRecognizer;
  late TextRecognizer _chineseTextRecognizer;
  final FlutterTts _tts = FlutterTts();
  
  XFile? _capturedImage;
  bool _isProcessing = false;
  String _detectedText = "";
  List<String> _foundAllergens = [];

  // Live scan mode: point camera at ingredients, get real-time allergen alerts (for blind users)
  bool _liveScanEnabled = false;
  Timer? _liveScanTimer;
  Set<String> _lastAnnouncedAllergens = {};
  static const Duration _liveScanInterval = Duration(seconds: 2);
  static const Duration _allergenAnnounceDebounce = Duration(seconds: 8);
  DateTime? _lastAllergenAnnounceTime;
  
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
    'detected_text': '识别的文字',
    'processing': '处理中...',
    'live_scan': '实时扫描',
    'live_scan_off': '关闭实时扫描',
    'live_scan_hint': '将摄像头对准成分表，无需拍照即可听到过敏原提示',
  } : {
    'title': 'OCR Scanner',
    'retake': 'Retake',
    'crop': 'Crop',
    'use_photo': 'Use Photo',
    'allergens_found': 'Allergens Found',
    'detected_text': 'Detected Text',
    'processing': 'Processing...',
    'live_scan': 'Live scan',
    'live_scan_off': 'Stop live scan',
    'live_scan_hint': 'Point camera at ingredients — no need to take a photo',
  };

  @override
  void initState() {
    super.initState();
    _initializeTextRecognizers();
    _initializeCamera();
    _initTts();
    
    // Auto-start live scan for blind users with audio guidance
    if (widget.autoStartLiveScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait a bit to ensure camera is ready and previous TTS has finished
        await Future.delayed(Duration(milliseconds: 800));
        
        // Announce live scan is starting
        final msg = widget.language == 'zh'
            ? '实时扫描已启动。请将摄像头对准成分标签。'
            : 'Live scan started. Point the camera at the ingredient label.';
        
        // Set up completion handler
        bool speechCompleted = false;
        _tts.setCompletionHandler(() {
          speechCompleted = true;
        });
        
        await _tts.speak(msg);
        
        // Wait for speech to complete
        int waitCount = 0;
        while (!speechCompleted && waitCount < 80) {
          await Future.delayed(Duration(milliseconds: 100));
          waitCount++;
        }
        
        // Small buffer
        await Future.delayed(Duration(milliseconds: 300));
        
        // Now start live scan
        _startLiveScan();
        setState(() => _liveScanEnabled = true);
      });
    }
  }

  void _initializeTextRecognizers() {
    // Many ingredient labels are mixed-language.
    // Using an auto recognizer often works better than script-locked mode for Chinese.
    _autoTextRecognizer = TextRecognizer();
    _latinTextRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _chineseTextRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  }

  String _normalizeForMatch(String text) {
    // Remove whitespace/punctuation to make matching resilient to OCR line breaks.
    // Keep CJK characters and ASCII letters/numbers.
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '');
  }

  List<String> _allAllergensToCheck() {
    // In Chinese UI mode, still detect English allergens (many imported products).
    // In English mode, still detect Chinese allergens if present.
    return [
      ...?_allergensList['en'],
      ...?_allergensList['zh'],
    ];
  }

  Future<String> _extractTextFromPath(String path) async {
    final inputImage = InputImage.fromFilePath(path);

    // 1) Try auto-detect first (best for mixed Chinese/English labels)
    final autoText = (await _autoTextRecognizer.processImage(inputImage)).text;

    // 2) Also try explicit scripts and merge (helps when auto misses)
    final latinText = (await _latinTextRecognizer.processImage(inputImage)).text;
    final chineseText = (await _chineseTextRecognizer.processImage(inputImage)).text;

    final parts = <String>[
      autoText,
      latinText,
      chineseText,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return parts.join('\n');
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
      final String fullText = await _extractTextFromPath(_capturedImage!.path);
      print("📝 OCR Text (${fullText.length} chars):");
      print(fullText);
      
      setState(() {
        _detectedText = fullText;
      });

      // Auto-detect allergens
      if (fullText.isNotEmpty) {
        final normalized = _normalizeForMatch(fullText);
        List<String> allergens = _allAllergensToCheck();
        List<String> found = [];
        
        for (String allergen in allergens) {
          final a = _normalizeForMatch(allergen);
          final match = normalized.contains(a);
          
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

  /// Live scan: for blind users — point at ingredients, get vibration + TTS when allergens are detected.
  void _toggleLiveScan() {
    if (_liveScanEnabled) {
      _stopLiveScan();
      setState(() => _liveScanEnabled = false);
    } else {
      _startLiveScan();
      setState(() => _liveScanEnabled = true);
    }
  }

  void _startLiveScan() {
    _lastAnnouncedAllergens = {};
    _lastAllergenAnnounceTime = null;
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer.periodic(_liveScanInterval, (_) => _runLiveScanCycle());
    // Initial hint for blind users
    _tts.speak(widget.language == 'zh'
        ? '摄像头正在进行实时扫描，请将手机对准成分表。'
        : 'The camera is now doing live scanning. Point your phone at the ingredient list.');
  }

  void _stopLiveScan() {
    _liveScanTimer?.cancel();
    _liveScanTimer = null;
  }

  Future<void> _runLiveScanCycle() async {
    if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return; // skip if previous run still in progress

    try {
      _isProcessing = true;
      final XFile image = await _cameraController!.takePicture();
      final String path = image.path;

      final String fullText = await _extractTextFromPath(path);
      try { File(path).deleteSync(); } catch (_) {}

      final normalized = _normalizeForMatch(fullText);
      List<String> allergens = _allAllergensToCheck();
      List<String> found = [];
      for (String allergen in allergens) {
        final a = _normalizeForMatch(allergen);
        bool match = normalized.contains(a);
        if (match && !found.contains(allergen)) found.add(allergen);
      }

      Set<String> currentSet = found.toSet();
      bool shouldAnnounce = currentSet.isNotEmpty &&
          (currentSet != _lastAnnouncedAllergens ||
              (_lastAllergenAnnounceTime != null &&
                  DateTime.now().difference(_lastAllergenAnnounceTime!) > _allergenAnnounceDebounce));

      if (shouldAnnounce && mounted) {
        _lastAnnouncedAllergens = currentSet;
        _lastAllergenAnnounceTime = DateTime.now();
        // Strong tactile feedback for blind users: pattern = double buzz
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(pattern: [0, 200, 100, 200]); // double buzz
        } else {
          HapticFeedback.heavyImpact();
        }
        String list = found.join(widget.language == 'zh' ? '，' : ', ');
        String msg = widget.language == 'zh'
            ? '检测到过敏原：$list'
            : 'Allergens detected: $list';
        await _tts.speak(msg);
      }
    } catch (e) {
      print("Live scan cycle error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera or captured image (FULLSCREEN with proper aspect ratio)
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
            // Captured image preview - CONTAIN instead of COVER to prevent stretching
            Center(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain, // Changed from cover to contain - adds black bars
                width: size.width,
                height: size.height,
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
                    onPressed: () async {
                      // Stop live scan if running
                      _stopLiveScan();
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      final disability = prefs.getString('disability');

                      // Blind users: exiting OCR should return to disability selection (reselect flow)
                      if (disability == 'blind') {
                        await prefs.remove('disability');
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const DisabilitySelectionScreen(),
                            ),
                          );
                        }
                        return;
                      }

                      // Deaf/Mute users: exiting OCR should return to main page (pop back)
                      if (mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/home');
                      }
                    },
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

          // Bottom controls
          if (_capturedImage == null) ...[
            // Live scan toggle (for blind users: point at label, get spoken + haptic alerts)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Center(
                child: Material(
                  color: _liveScanEnabled
                      ? Colors.orange.withOpacity(0.9)
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: _toggleLiveScan,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _liveScanEnabled ? Icons.stop_rounded : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            _liveScanEnabled ? _t['live_scan_off']! : _t['live_scan']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Camera mode - capture button (one-shot photo)
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
                // Wrap prevents RenderFlex overflow on smaller widths (esp. English labels)
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Retake button
                    TextButton.icon(
                      onPressed: _retake,
                      icon: Icon(Icons.refresh, color: Colors.white, size: 22),
                      label: Text(
                        _t['retake']!,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    // Crop button
                    TextButton.icon(
                      onPressed: _cropImage,
                      icon: Icon(Icons.crop, color: Colors.white, size: 22),
                      label: Text(
                        _t['crop']!,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          : Icon(Icons.check, size: 22),
                      label: Text(
                        _isProcessing ? _t['processing']! : _t['use_photo']!,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // Results overlay
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
    _stopLiveScan();
    _cameraController?.dispose();
    _autoTextRecognizer.close();
    _latinTextRecognizer.close();
    _chineseTextRecognizer.close();
    _tts.stop();
    super.dispose();
  }
}