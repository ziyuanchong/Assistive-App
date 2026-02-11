import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'allergen_scanner.dart';
import 'dart:async';

/// Disability types
enum DisabilityType {
  deaf,
  mute,
  blind,
}

class DisabilitySelectionScreen extends StatefulWidget {
  const DisabilitySelectionScreen({super.key});

  @override
  State<DisabilitySelectionScreen> createState() => _DisabilitySelectionScreenState();
}

class _DisabilitySelectionScreenState extends State<DisabilitySelectionScreen> {
  final FlutterTts _tts = FlutterTts();
  int _tapCount = 0;
  Timer? _tapResetTimer;
  static const Duration _tapTimeout = Duration(seconds: 2);
  static const Duration _holdToResetDuration = Duration(seconds: 3);
  String _currentLanguage = 'en';

  DisabilityType? _pendingDisability;
  Timer? _holdToResetTimer;

  Map<String, String> get _t => _currentLanguage == 'zh' ? {
    'instructions': '按一次按钮表示您是聋人，按两次表示您是哑人，按三次表示您是盲人',
    'selected_deaf': '已选择：聋人',
    'selected_mute': '已选择：哑人',
    'selected_blind': '已选择：盲人',
    'confirm': '请再次使用相同的点击次数确认。长按3秒可重新选择。',
    'confirm_deaf': '您选择了：聋人。请再次按一次确认。长按3秒可重新选择。',
    'confirm_mute': '您选择了：哑人。请再次按两次确认。长按3秒可重新选择。',
    'confirm_blind': '您选择了：盲人。请再次按三次确认。长按3秒可重新选择。',
    'reset_done': '已重置，请重新选择。',
    'loading': '正在加载...',
  } : {
    'instructions': 'Press the button once if you are deaf, press the button twice if you are mute, press the button thrice if you are blind',
    'selected_deaf': 'Selected: Deaf',
    'selected_mute': 'Selected: Mute',
    'selected_blind': 'Selected: Blind',
    'confirm': 'Tap again with the same count to confirm. Hold for 3 seconds to reselect.',
    'confirm_deaf': 'You selected Deaf. Tap once again to confirm. Hold 3 seconds to reselect.',
    'confirm_mute': 'You selected Mute. Tap twice again to confirm. Hold 3 seconds to reselect.',
    'confirm_blind': 'You selected Blind. Tap three times again to confirm. Hold 3 seconds to reselect.',
    'reset_done': 'Reset done. Please select again.',
    'loading': 'Loading...',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _initTts();
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguage = prefs.getString('language') ?? 'en';
    });
    await _initTts();
    // Speak instructions after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      _speakInstructions();
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.stop();
      String lang = _currentLanguage == 'zh' ? 'zh-CN' : 'en-US';
      await _tts.setLanguage(lang);
      if (_currentLanguage == 'zh') {
        await _tts.setVoice({"name": "Ting-Ting", "locale": "zh-CN"});
      }
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      print("TTS error: $e");
    }
  }

  Future<void> _speakInstructions() async {
    await _tts.speak(_t['instructions']!);
  }

  void _handleTap() {
    // Cancel previous reset timer
    _tapResetTimer?.cancel();
    
    setState(() {
      _tapCount++;
    });
    
    // Haptic feedback for each tap
    HapticFeedback.mediumImpact();
    
    // Reset tap count after timeout
    _tapResetTimer = Timer(_tapTimeout, () {
      final DisabilityType selected;
      if (_tapCount == 1) {
        selected = DisabilityType.deaf;
      } else if (_tapCount == 2) {
        selected = DisabilityType.mute;
      } else {
        selected = DisabilityType.blind;
      }
      
      setState(() {
        _tapCount = 0;
      });

      _handleSelectionOrConfirm(selected);
    });
  }

  Future<void> _handleSelectionOrConfirm(DisabilityType disability) async {
    _tapResetTimer?.cancel();

    // First step: set pending and ask for confirmation
    if (_pendingDisability == null) {
      setState(() {
        _pendingDisability = disability;
      });

      final confirmMsg = disability == DisabilityType.deaf
          ? _t['confirm_deaf']!
          : disability == DisabilityType.mute
              ? _t['confirm_mute']!
              : _t['confirm_blind']!;

      // Speak confirmation prompt (deaf users won't rely on TTS anyway, but it's harmless)
      await _tts.speak(confirmMsg);
      return;
    }

    // Second step: must match pending to confirm
    if (_pendingDisability != disability) {
      // Mismatch: treat this as a new pending selection
      setState(() {
        _pendingDisability = disability;
      });
      final confirmMsg = disability == DisabilityType.deaf
          ? _t['confirm_deaf']!
          : disability == DisabilityType.mute
              ? _t['confirm_mute']!
              : _t['confirm_blind']!;
      await _tts.speak(confirmMsg);
      return;
    }

    // Confirmed: proceed to save + navigate
    final confirmed = disability;
    setState(() {
      _pendingDisability = null;
    });
    
    // Save preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String disabilityKey = confirmed.name; // 'deaf', 'mute', or 'blind'
    await prefs.setString('disability', disabilityKey);
    
    // Visual feedback
    String message = '';
    if (confirmed == DisabilityType.deaf) {
      message = _t['selected_deaf']!;
    } else if (confirmed == DisabilityType.mute) {
      message = _t['selected_mute']!;
    } else if (confirmed == DisabilityType.blind) {
      message = _t['selected_blind']!;
    }
    
    // Speak confirmation (except for deaf users)
    if (confirmed != DisabilityType.deaf) {
      await _tts.speak(message);
    }
    
    // Vibrate for confirmation
    HapticFeedback.heavyImpact();
    
    // Show loading briefly, then navigate
    if (mounted) {
      setState(() {});
      await Future.delayed(Duration(milliseconds: 1500));
      
      // Navigate based on disability
      if (mounted) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String language = prefs.getString('language') ?? 'en';
        
        if (confirmed == DisabilityType.blind) {
          // Blind users go directly to OCR scanner with live scan enabled
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AllergenScanner(
                language: language,
                autoStartLiveScan: true,
              ),
            ),
          );
        } else {
          // Deaf/Mute users go to main page
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  void _onHoldStart() {
    _holdToResetTimer?.cancel();
    _holdToResetTimer = Timer(_holdToResetDuration, () async {
      // Clear saved preference + reset pending state so user can reselect
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('disability');
      if (!mounted) return;
      setState(() {
        _pendingDisability = null;
        _tapCount = 0;
      });
      HapticFeedback.heavyImpact();
      await _tts.speak(_t['reset_done']!);
    });
  }

  void _onHoldEnd() {
    _holdToResetTimer?.cancel();
    _holdToResetTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Instructions text at top
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _t['instructions']!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Large tap button
                GestureDetector(
                  onTap: _handleTap,
                  onLongPressStart: (_) => _onHoldStart(),
                  onLongPressEnd: (_) => _onHoldEnd(),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_tapCount',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Tap count indicator
                if (_tapCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tapCount == 1
                          ? (_currentLanguage == 'zh' ? '一次' : 'Once')
                          : _tapCount == 2
                              ? (_currentLanguage == 'zh' ? '两次' : 'Twice')
                              : (_currentLanguage == 'zh' ? '三次' : 'Thrice'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                if (_pendingDisability != null)
                  Text(
                    _t['confirm']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _holdToResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }
}
