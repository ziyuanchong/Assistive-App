import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';

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

  String lastWords = "Press mic and speak";
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    initTts();
  }

  Future initTts() async {
    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
  }

  Future speak(String text) async {
    await tts.speak(text);
  }

  Future listen() async {
    if (!isListening) {
      bool available = await speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (available) {
        setState(() => isListening = true);
        
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
          listenFor: Duration(seconds: 10),
          pauseFor: Duration(seconds: 3),
        );
      }
    } else {
      setState(() => isListening = false);
      speech.stop();
    }
  }

  void processCommand(String words) async {
    String command = words.toLowerCase();

    // Time queries
    if (command.contains("time")) {
      String time = DateFormat.jm().format(DateTime.now());
      await speak("The time is $time");
    }
    // Date queries
    else if (command.contains("date") || command.contains("today")) {
      String date = DateFormat.yMMMMd().format(DateTime.now());
      await speak("Today is $date");
    }
    // Greetings
    else if (command.contains("hello") || command.contains("hi")) {
      await speak("Hello! How can I help you today?");
    }
    // Help
    else if (command.contains("help")) {
      await speak("You can ask me for the time, date, or just speak to me. I'm here to assist you.");
    }
    // Read back text
    else if (command.contains("read")) {
      await speak("Reading mode activated. Say something and I'll read it back to you.");
    }
    // Default - just repeat
    else {
      await speak("You said: $command");
    }
  }

  // Text input for accessibility
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
        title: const Text("Assistive App"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status display
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
                      isListening ? "Listening..." : lastWords,
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

              const SizedBox(height: 30),

              // Voice input button
              ElevatedButton.icon(
                onPressed: listen,
                icon: Icon(isListening ? Icons.stop : Icons.mic),
                label: Text(
                  isListening ? "Stop Listening" : "🎤 Voice Command",
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
                  labelText: "Type text to speak",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: speakTextInput,
                  ),
                ),
                onSubmitted: (value) => speakTextInput(),
              ),

              const SizedBox(height: 30),

              // Demo features section
              const Text(
                "Demo Features:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 15),

              ElevatedButton.icon(
                onPressed: () {
                  speak("Obstacle detected 3 meters ahead on your left. Please move right.");
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text("📷 Demo: Obstacle Detection"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  speak("Warning: This product contains milk and tree nuts. Not suitable for people with dairy or nut allergies.");
                },
                icon: const Icon(Icons.local_drink),
                label: const Text("🥤 Demo: Allergen Detection"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  speak("This is a can of Coca Cola. 330 milliliters.");
                },
                icon: const Icon(Icons.image_search),
                label: const Text("🔍 Demo: Object Recognition"),
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
                  children: const [
                    Text(
                      "Try saying:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text("• What time is it?"),
                    Text("• What's the date today?"),
                    Text("• Hello"),
                    Text("• Help"),
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
    super.dispose();
  }
}