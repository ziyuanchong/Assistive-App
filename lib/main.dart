import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'allergen_scanner.dart';
import 'disability_selection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visual Audio Buddy',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialRoute(),
        '/disability-selection': (context) => const DisabilitySelectionScreen(),
        '/home': (context) => const HomePage(),
        '/ocr-scanner-blind': (context) {
          // Get language preference
          return FutureBuilder<String>(
            future: _getLanguage(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return AllergenScanner(
                  language: snapshot.data!,
                  autoStartLiveScan: true,
                );
              }
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        },
      },
    );
  }

  static Future<String> _getLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('language') ?? 'en';
  }
}

/// Initial route that checks for saved disability preference
class InitialRoute extends StatefulWidget {
  const InitialRoute({super.key});

  @override
  State<InitialRoute> createState() => _InitialRouteState();
}

class _InitialRouteState extends State<InitialRoute> {
  @override
  void initState() {
    super.initState();
    _checkDisabilityPreference();
  }

  Future<void> _checkDisabilityPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? disability = prefs.getString('disability');
    
    if (!mounted) return;
    
    if (disability == null) {
      // No preference saved - show selection screen
      Navigator.of(context).pushReplacementNamed('/disability-selection');
    } else {
      // Preference exists - route accordingly
      String language = prefs.getString('language') ?? 'en';
      
      if (disability == 'blind') {
        // Blind users go directly to OCR scanner with live scan
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

  @override
  Widget build(BuildContext context) {
    // Show loading while checking preference
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts tts = FlutterTts();
  final SpeechToText speech = SpeechToText();

  String lastWords = "";
  bool isListening = false;
  String currentLanguage = 'en';
  double fontSize = 18.0;
  String? disability; // 'deaf', 'mute', 'blind'

  Map<String, String> get _t => currentLanguage == 'zh' ? {
    'title': '视觉音频伙伴 (VAB)',
    'press_mic': '按麦克风并说话',
    'listening': '正在聆听...',
    'stop_listening': '停止聆听',
    'voice_command': '🎤 语音命令',
    'type_to_speak': '输入文字朗读',
    'demo_features': '演示功能:',
    'obstacle_detection': '📷 演示:障碍物检测',
    'ocr_scanner': '📄 OCR 扫描器',
    'object_recognition': '🔍 演示:物体识别',
    'hello': '• 你好',
    'help': '• 帮助',
    'switch_language': '切换语言',
    'reselect_disability': '重新选择障碍类型',
    'hide_keyboard': '收起键盘',
  } : {
    'title': 'Visual Audio Buddy (VAB)',
    'press_mic': 'Press mic and speak',
    'listening': 'Listening...',
    'stop_listening': 'Stop Listening',
    'voice_command': '🎤 Voice Command',
    'type_to_speak': 'Type text to speak',
    'demo_features': 'Demo Features:',
    'obstacle_detection': '📷 Demo: Obstacle Detection',
    'ocr_scanner': '📄 OCR Scanner',
    'object_recognition': '🔍 Demo: Object Recognition',
    'hello': '• Hello',
    'help': '• Help',
    'switch_language': 'Switch Language',
    'reselect_disability': 'Reselect disability',
    'hide_keyboard': 'Hide keyboard',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLanguage = prefs.getString('language') ?? 'en';
      disability = prefs.getString('disability');
      lastWords = _t['press_mic']!;
    });
    await initTts();
  }

  Future<void> _reselectDisability() async {
    // Allow deaf/mute users to reselect at any time
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('disability');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/disability-selection');
  }

  Future<void> _saveLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
  }

  Future<void> _showLanguageDialog() async {
    String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_t['switch_language']!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language, color: Colors.blue),
                title: const Text('English', style: TextStyle(fontSize: 18)),
                trailing: currentLanguage == 'en' 
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
                onTap: () => Navigator.pop(context, 'en'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.blue),
                title: const Text('中文', style: TextStyle(fontSize: 18)),
                trailing: currentLanguage == 'zh' 
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
                onTap: () => Navigator.pop(context, 'zh'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentLanguage) {
      setState(() {
        currentLanguage = selected;
        lastWords = _t['press_mic']!;
      });
      await _saveLanguage(selected);
      await initTts();
      
      String message = currentLanguage == 'zh' ? '已切换到中文' : 'Switched to English';
      await speak(message);
    }
  }

  Future<void> initTts() async {
    try {
      // Stop any ongoing speech
      await tts.stop();
      
      // Set language first
      String ttsLanguage = currentLanguage == 'zh' ? 'zh-CN' : 'en-US';
      var langResult = await tts.setLanguage(ttsLanguage);
      print("TTS Language set: $langResult for $ttsLanguage");
      
      // Set volume to maximum (very important!)
      await tts.setVolume(1.0);
      print("TTS Volume set to 1.0");
      
      // Set speech rate (not too fast, not too slow)
      await tts.setSpeechRate(0.5);
      
      // Set pitch to normal
      await tts.setPitch(1.0);
      
      // iOS-specific voice settings for better quality
      try {
        if (currentLanguage == 'zh') {
          await tts.setVoice({"name": "Ting-Ting", "locale": "zh-CN"});
        } else {
          await tts.setVoice({"name": "Samantha", "locale": "en-US"});
        }
      } catch (e) {
        print("Voice setting warning: $e");
      }
      
      // Enable shared instance for iOS
      try {
        await tts.setSharedInstance(true);
      } catch (e) {
        print("Shared instance warning: $e");
      }
      
      // Add handlers for debugging
      tts.setStartHandler(() {
        print("▶️ TTS started speaking");
      });
      
      tts.setCompletionHandler(() {
        print("✅ TTS completed speaking");
      });
      
      tts.setErrorHandler((msg) {
        print("❌ TTS error: $msg");
      });
      
      print("✅ TTS initialized successfully");
      
    } catch (e) {
      print("❌ TTS initialization error: $e");
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    print("🔊 Attempting to speak: '$text'");
    
    try {
      // Stop any ongoing speech first
      await tts.stop();
      
      // Re-initialize to ensure settings are correct
      await initTts();
      
      // Small delay
      await Future.delayed(Duration(milliseconds: 50));
      
      // Ensure volume is maximum
      await tts.setVolume(1.0);
      
      // Speak the text
      var result = await tts.speak(text);
      
      print("🔊 TTS speak result: $result");
      
      if (result == 0) {
        print("⚠️ WARNING: TTS returned 0");
        print("⚠️ Check: 1) Phone volume is up");
        print("⚠️        2) Silent mode is OFF");
        print("⚠️        3) Phone is not muted");
      }
      
    } catch (e) {
      print("❌ TTS speak error: $e");
    }
  }

  Future<void> listen() async {
    if (!isListening) {
      bool available = await speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (available) {
        setState(() => isListening = true);
        
        String locale = currentLanguage == 'zh' ? 'zh_CN' : 'en_US';
        
        speech.listen(
          onResult: (result) {
            setState(() {
              lastWords = result.recognizedWords;
            });

            if (result.finalResult) {
              processCommand(result.recognizedWords);
              setState(() => isListening = false);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          localeId: locale,
        );
      }
    } else {
      setState(() => isListening = false);
      speech.stop();
    }
  }

  void processCommand(String words) async {
    String command = words.toLowerCase();

    if (currentLanguage == 'zh') {
      if (command.contains('你好') || command.contains('您好')) {
        await speak("你好!我能帮您什么?");
      }
      else if (command.contains('帮助')) {
        await speak("您可以直接跟我说话，或用下方输入框让手机朗读。我在这里协助您。");
      }
      else {
        await speak("您说:$command");
      }
    } else {
      if (command.contains("hello") || command.contains("hi")) {
        await speak("Hello! How can I help you today?");
      }
      else if (command.contains("help")) {
        await speak("You can speak to me, or type in the box to have your phone read it out loud.");
      }
      else {
        await speak("You said: $command");
      }
    }
  }

  final TextEditingController textController = TextEditingController();

  void speakTextInput() {
    if (textController.text.isNotEmpty) {
      speak(textController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['title']!),
        backgroundColor: Colors.blue,
        actions: [
          // Deaf/Mute users: show a reselect button on main page
          if (disability == 'deaf' || disability == 'mute')
            IconButton(
              icon: const Icon(Icons.accessibility_new, size: 28),
              onPressed: _reselectDisability,
              tooltip: _t['reselect_disability'],
            ),
          IconButton(
            icon: const Icon(Icons.language, size: 28),
            onPressed: _showLanguageDialog,
            tooltip: _t['switch_language'],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Language indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      currentLanguage == 'zh' ? '中文' : 'English',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // Status display with dynamic height - smaller by default
              Container(
                constraints: BoxConstraints(
                  minHeight: 80,  // Smaller default height
                  maxHeight: 300,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isListening ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isListening ? Colors.red : Colors.blue,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Only take needed space
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          size: 40,
                          color: isListening ? Colors.red : Colors.blue,
                        ),
                        // Font size controls
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.text_decrease, size: 24),
                              onPressed: () {
                                setState(() {
                                  if (fontSize > 12) fontSize -= 2;
                                });
                              },
                              tooltip: 'Decrease font size',
                            ),
                            Text(
                              '${fontSize.toInt()}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: Icon(Icons.text_increase, size: 24),
                              onPressed: () {
                                setState(() {
                                  if (fontSize < 48) fontSize += 2;
                                });
                              },
                              tooltip: 'Increase font size',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Flexible instead of Expanded - only takes needed space
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          isListening ? _t['listening']! : lastWords.isEmpty ? _t['press_mic']! : lastWords,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            color: isListening ? Colors.red.shade700 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Voice input button
              ElevatedButton.icon(
                onPressed: listen,
                icon: Icon(isListening ? Icons.stop : Icons.mic, size: 28),
                label: Text(
                  isListening ? _t['stop_listening']! : _t['voice_command']!,
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: isListening ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // Text input for non-verbal users - expandable
              Container(
                constraints: BoxConstraints(
                  minHeight: 60,
                  maxHeight: 200,
                ),
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _t['type_to_speak']!,
                    labelStyle: const TextStyle(fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.keyboard_hide, size: 28),
                      tooltip: _t['hide_keyboard'],
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                    alignLabelWithHint: true,
                  ),
                  style: TextStyle(fontSize: fontSize),
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  onSubmitted: (value) => speakTextInput(),
                ),
              ),

              const SizedBox(height: 10),

              // Speak typed text button (keeps keyboard dismiss separate)
              ElevatedButton.icon(
                onPressed: speakTextInput,
                icon: const Icon(Icons.volume_up, size: 24),
                label: Text(
                  currentLanguage == 'zh' ? '朗读输入内容' : 'Speak typed text',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),

              const SizedBox(height: 30),

              // Demo features section
              Text(
                _t['demo_features']!,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 15),

              ElevatedButton.icon(
                onPressed: () {
                  speak(currentLanguage == 'zh' 
                    ? "检测到前方3米处有障碍物。请向右移动。"
                    : "Obstacle detected 3 meters ahead on your left. Please move right.");
                },
                icon: const Icon(Icons.camera_alt, size: 24),
                label: Text(
                  _t['obstacle_detection']!,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllergenScanner(language: currentLanguage),
                    ),
                  );
                },
                icon: const Icon(Icons.document_scanner, size: 24),
                label: Text(
                  _t['ocr_scanner']!,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  speak(currentLanguage == 'zh'
                    ? "这是一罐可口可乐。330毫升。"
                    : "This is a can of Coca Cola. 330 milliliters.");
                },
                icon: const Icon(Icons.image_search, size: 24),
                label: Text(
                  _t['object_recognition']!,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
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
    textController.dispose();
    tts.stop();
    speech.stop();
    super.dispose();
  }
}