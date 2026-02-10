import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'allergen_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistive App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
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
  String responseOutput = ""; // NEW: Visual output for responses
  bool isListening = false;
  String currentLanguage = 'en'; // 'en' or 'zh'

  // UI text translations
  Map<String, String> get _t => currentLanguage == 'zh' ? {
    'title': '辅助应用',
    'press_mic': '按麦克风并说话',
    'listening': '正在聆听...',
    'stop_listening': '停止聆听',
    'voice_command': '🎤 语音命令',
    'type_to_speak': '输入文字朗读',
    'demo_features': '演示功能:',
    'obstacle_detection': '📷 演示:障碍物检测',
    'allergen_scanner': '🥤 过敏原扫描(OCR)',
    'object_recognition': '🔍 演示:物体识别',
    'try_saying': '试着说:',
    'what_time': '• 现在几点?',
    'what_date': '• 今天几号?',
    'hello': '• 你好',
    'help': '• 帮助',
    'switch_language': '切换语言',
    'response': '回应:',
  } : {
    'title': 'Assistive App',
    'press_mic': 'Press mic and speak',
    'listening': 'Listening...',
    'stop_listening': 'Stop Listening',
    'voice_command': '🎤 Voice Command',
    'type_to_speak': 'Type text to speak',
    'demo_features': 'Demo Features:',
    'obstacle_detection': '📷 Demo: Obstacle Detection',
    'allergen_scanner': '🥤 Allergen Scanner (OCR)',
    'object_recognition': '🔍 Demo: Object Recognition',
    'try_saying': 'Try saying:',
    'what_time': '• What time is it?',
    'what_date': '• What\'s the date today?',
    'hello': '• Hello',
    'help': '• Help',
    'switch_language': 'Switch Language',
    'response': 'Response:',
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
      lastWords = _t['press_mic']!;
    });
    await initTts();
  }

  Future<void> _saveLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
  }

  // NEW: Show language selection dialog
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
        responseOutput = "";
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
      
      // Set language
      String ttsLanguage = currentLanguage == 'zh' ? 'zh-CN' : 'en-US';
      var result = await tts.setLanguage(ttsLanguage);
      print("TTS Language set result: $result for $ttsLanguage");
      
      // iOS-specific voice settings for better compatibility
      if (currentLanguage == 'zh') {
        await tts.setVoice({"name": "Ting-Ting", "locale": "zh-CN"});
      } else {
        await tts.setVoice({"name": "Samantha", "locale": "en-US"});
      }
      
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      
      // Add handlers for debugging
      tts.setCompletionHandler(() {
        print("TTS completed");
      });
      
      tts.setErrorHandler((msg) {
        print("TTS error: $msg");
      });
      
      print("TTS initialized successfully for language: $currentLanguage");
      
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  Future<void> speak(String text) async {
    print("Speaking: $text");
    
    // Update visual output
    setState(() {
      responseOutput = text;
    });
    
    try {
      await tts.stop(); // Stop any ongoing speech
      var result = await tts.speak(text);
      print("TTS speak result: $result");
    } catch (e) {
      print("TTS speak error: $e");
    }
  }

  Future<void> listen() async {
    if (!isListening) {
      bool available = await speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (available) {
        setState(() {
          isListening = true;
          responseOutput = ""; // Clear previous response
        });
        
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
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
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
      // Chinese commands
      if (command.contains('时间') || command.contains('几点')) {
        DateTime now = DateTime.now();
        int hour = now.hour;
        int minute = now.minute;
        
        // Format time in 12-hour format with AM/PM
        String period = hour >= 12 ? '下午' : '上午';
        int hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        
        String timeText = "$period$hour12点${minute}分";
        String displayTime = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        
        setState(() {
          responseOutput = "现在是 $displayTime";
        });
        
        await speak("现在是$timeText");
      }
      else if (command.contains('日期') || command.contains('几号') || command.contains('今天')) {
        DateTime now = DateTime.now();
        String dateText = "${now.year}年${now.month}月${now.day}日";
        
        setState(() {
          responseOutput = "今天是 $dateText";
        });
        
        await speak("今天是$dateText");
      }
      else if (command.contains('你好') || command.contains('您好')) {
        await speak("你好!我能帮您什么?");
      }
      else if (command.contains('帮助')) {
        await speak("您可以问我时间、日期,或者直接跟我说话。我在这里协助您。");
      }
      else {
        await speak("您说:$command");
      }
    } else {
      // English commands
      if (command.contains("time")) {
        DateTime now = DateTime.now();
        int hour = now.hour;
        int minute = now.minute;
        
        // Format in 12-hour format with AM/PM
        String period = hour >= 12 ? 'PM' : 'AM';
        int hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        
        String timeText = "$hour12:${minute.toString().padLeft(2, '0')} $period";
        
        setState(() {
          responseOutput = "The time is $timeText";
        });
        
        await speak("The time is $hour12 ${minute.toString().padLeft(2, '0')} $period");
      }
      else if (command.contains("date") || command.contains("today")) {
        DateTime now = DateTime.now();
        List<String> months = ['January', 'February', 'March', 'April', 'May', 'June',
                               'July', 'August', 'September', 'October', 'November', 'December'];
        
        String dateText = "${months[now.month - 1]} ${now.day}, ${now.year}";
        
        setState(() {
          responseOutput = "Today is $dateText";
        });
        
        await speak("Today is $dateText");
      }
      else if (command.contains("hello") || command.contains("hi")) {
        await speak("Hello! How can I help you today?");
      }
      else if (command.contains("help")) {
        await speak("You can ask me for the time, date, or just speak to me. I'm here to assist you.");
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
          // Language dropdown button
          IconButton(
            icon: const Icon(Icons.language, size: 28),
            onPressed: _showLanguageDialog,
            tooltip: _t['switch_language'],
          ),
        ],
      ),
      body: SingleChildScrollView(
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

              // Status display - what you said
              Container(
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
                  children: [
                    Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: isListening ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isListening ? _t['listening']! : lastWords.isEmpty ? _t['press_mic']! : lastWords,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isListening ? Colors.red.shade700 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // NEW: Response Output Display
              if (responseOutput.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.green, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            _t['response']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        responseOutput,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

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

              // Text input for non-verbal users
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: _t['type_to_speak']!,
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.volume_up, size: 28),
                    onPressed: speakTextInput,
                  ),
                ),
                style: const TextStyle(fontSize: 18),
                onSubmitted: (value) => speakTextInput(),
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
                icon: const Icon(Icons.local_drink, size: 24),
                label: Text(
                  _t['allergen_scanner']!,
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

              const SizedBox(height: 30),

              // Quick commands help
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t['try_saying']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(_t['what_time']!, style: const TextStyle(fontSize: 15)),
                    Text(_t['what_date']!, style: const TextStyle(fontSize: 15)),
                    Text(_t['hello']!, style: const TextStyle(fontSize: 15)),
                    Text(_t['help']!, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
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