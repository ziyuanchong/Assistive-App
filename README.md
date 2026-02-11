# Visual Audio Buddy (VAB)

## Multimodal Accessibility for Real-World Independence

Visual Audio Buddy (VAB) is a Flutter-based assistive mobile application designed to reduce communication and environmental barriers for individuals with sensory impairments.

Our solution integrates **visual, audio, and haptic modalities** into a simple, adaptive interface that supports independent interaction in public environments.

---

## 🎯 Problem

Many assistive technologies rely on a single sensory modality (speech, text, or vision).  
This creates friction in:

- Public communication  
- Product identification  
- Environmental awareness  
- Everyday independence  

VAB addresses this through **mode-based, multimodal accessibility**.

---

## 💡 MVP Features

### 👁 Visual Assist Mode
- Live OCR scanning
- AI-guided camera alignment
- Auto-capture when text is readable
- Text-to-Speech output
- Haptic confirmation

**Use case:** Independently identify products and read ingredient labels.

---

### 👂 Hearing Assist Mode
- Speech-to-Text (STT) transcription
- Controlled conversation recording
- Clear, high-contrast transcript display
- Text-to-Speech reply support

**Use case:** Reduce conversational lag in public interactions.

---

## 🧠 Design Principles

- **Multimodal by necessity** – Redundant audio, visual, and haptic outputs.
- **Low cognitive load** – Large buttons, simplified workflows.
- **Mode-based simplification** – Interface adapts to user profile.
- **Dignity-preserving** – Designed for discreet public use.
- **Elderly-friendly** – High contrast, large fonts, bilingual (English & Chinese).

---

## 🏗 Tech Stack

- Flutter (Dart)
- Camera plugin
- Speech-to-Text
- Text-to-Speech
- OCR engine
- Real-time AI alignment feedback

---

## 🚀 Setup


### Prerequisites

- Flutter SDK (latest stable)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code (Flutter plugins installed)

---

### macOS (iOS Development)

Xcode is required to run the app on iOS.

Install from the Mac App Store, then run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license```

### Install CocoaPods:

```sudo gem install cocoapods

###Verify Environment
```flutter doctor``
Resolve any reported issues.

### Running the App
Clone the repository:
```git clone <repository-url>
cd visual-audio-buddy```

### Install dependencies:
```flutter pub get```

### Run:
```flutter run```
