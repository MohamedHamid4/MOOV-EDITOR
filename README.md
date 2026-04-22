# 🎬 Moov Editor

A production-ready video editor built entirely in Flutter — featuring a multi-track timeline, real-time preview, and FFmpeg-powered MP4 export.

> **Comparable to CapCut in capabilities. Built from scratch in Dart.**

---

## ✨ Features

- 🎞️ **Multi-track timeline** — 3 tracks: Video/Image, Audio, Text
- ▶️ **Sequential preview** — seamless playback across multiple clips
- ✂️ **Full editing tools** — cut, trim, split, duplicate, delete
- 🎨 **Keyframe animations** — animate text overlays with position, scale, rotation
- 📤 **Real MP4 export** — FFmpeg-powered with auto-save to gallery
- 🎤 **Voiceover recording** — record audio directly in the app
- 🔐 **Firebase Auth** — Email/Password + Google Sign-In
- ☁️ **Cloud sync** — Firestore for project metadata
- 🌓 **Dark/Light themes** — with system default support
- 🌍 **Bilingual** — English + Arabic (with RTL support)

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter + Dart |
| **Architecture** | Clean MVVM |
| **State Management** | Provider |
| **Backend** | Firebase (Auth + Firestore) |
| **Video Processing** | FFmpeg-kit |
| **Audio** | just_audio + record |
| **UI** | Lucide Icons + Google Fonts |

---

## 📐 Architecture

```
lib/
├── core/              → Theme, constants, utilities
├── domain/            → Entities (Project, Clip, Keyframe)
├── data/              → Repositories (local + Firestore)
├── services/          → Firebase, FFmpeg, Thumbnail generation
└── presentation/
    ├── viewmodels/    → Business logic (Provider)
    ├── screens/       → UI screens
    └── widgets/       → Reusable components
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.x or later)
- Android Studio / VS Code
- Firebase project (for cloud features)

### Installation

```bash
# Clone the repo
git clone https://github.com/MohamedHamid4/MOOV-EDITOR.git
cd MOOV-EDITOR

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run the app
flutter run --release
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password + Google)
3. Enable **Firestore Database**
4. Run `flutterfire configure` to generate `firebase_options.dart`

---

## 📱 Screenshots
<img width="1080" height="1080" alt="editor" src="https://github.com/user-attachments/assets/b8a18190-d2b1-4da6-b87d-b6df3acf4f03" />
<img width="1080" height="1080" alt="home" src="https://github.com/user-attachments/assets/88d8c12d-2dc1-4adc-8cbf-0d2ac5ff2ea2" />
<img width="1080" height="1080" alt="splash" src="https://github.com/user-attachments/assets/a5b56c0d-5b09-4e00-8cbd-680a5b261752" />
<img width="1080" height="1080" alt="login" src="https://github.com/user-attachments/assets/d59cf864-b56f-4ab7-8973-bb6454b60e6b" />
<img width="1080" height="1080" alt="signup" src="https://github.com/user-attachments/assets/29bd27c0-0ca3-4860-95d5-5804e6d7e3b3" />
<img width="1080" height="1080" alt="profile" src="https://github.com/user-attachments/assets/811f864f-211f-44d4-bfa5-70ee9fa978fc" />
<img width="1080" height="1080" alt="settings" src="https://github.com/user-attachments/assets/0f78d517-baf6-46a6-8287-9d6c7a077e4e" />

---

## 🎥 Demo

Watch the full demo on [LinkedIn]([https://www.linkedin.com/in/your-profile](https://www.linkedin.com/posts/mohamed-hamid-3bb3aa243_flutter-flutterdev-firebase-ugcPost-7452667986353590272-uO0a?utm_source=share&utm_medium=member_desktop&rcm=ACoAADxkg78Bft2_-NKlGEyuFfxDJCnX2tIstwg))

---

## 🧠 Technical Highlights

### Multi-controller video synchronization
Managing multiple `VideoPlayerController` instances that transition seamlessly as the playhead moves across clips on the timeline.

### FFmpeg filter_complex pipeline
Trim, pad, concat, and overlay filters chained together for production-quality MP4 output.

### Background thumbnail generation
Filmstrip thumbnails rendered with `Uint8List` caching for smooth scrolling.

### Graceful Firestore degradation
Authentication never fails due to Firestore issues — every cloud call wrapped with try/catch.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!  
Feel free to open an [issue](https://github.com/MohamedHamid4/MOOV-EDITOR/issues).

---

## 📄 License

This project is licensed under the MIT License.

---

## 👨‍💻 Author

**Mohamed Hamid**

- GitHub: [@MohamedHamid4](https://github.com/MohamedHamid4)
- LinkedIn: [https://www.linkedin.com/in/mohamed-hamid-3bb3aa243/]
- Email: [mohamedhamidofficial4@gmail.com]

---

## ⭐ Show Your Support

If you like this project, give it a ⭐ on GitHub!

---

**Built with ❤️ using Flutter**
