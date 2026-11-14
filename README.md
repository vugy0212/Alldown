<div align="center">
  <img src="assets/app_logo.png" width="160" alt="AllDown Logo" style="border-radius: 32px;" />
  <h1>AllDown</h1>
  <p><b>Universal Media Downloader, Pro Audio Studio & HD Video/GIF Editor for Android</b></p>

  <p>
    <a href="https://github.com/vugy0212/Alldown/releases"><img src="https://img.shields.io/badge/Version-1.6.3-6366F1?style=for-the-badge&logo=android&logoColor=white" alt="Version 1.6.3" /></a>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-06B6D4?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Platform-Android%208.0%2B-10B981?style=for-the-badge&logo=android&logoColor=white" alt="Platform Android" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-F59E0B?style=for-the-badge" alt="License GPLv3" /></a>
  </p>

  <p>
    <b>Author:</b> Allen &nbsp;•&nbsp;
    <a href="#-key-features">Key Features</a> &nbsp;•&nbsp;
    <a href="#-pro-audio-player-studio">Pro Audio Studio</a> &nbsp;•&nbsp;
    <a href="#%EF%B8%8F-video-studio--hd-gif-generator">Video & GIF Studio</a> &nbsp;•&nbsp;
    <a href="#-supported-platforms--services">Platforms</a> &nbsp;•&nbsp;
    <a href="#-getting-started">Getting Started</a>
  </p>
</div>

---

## 📖 Overview

**AllDown** is a powerful, modern, and privacy-focused Android application designed for downloading high-definition video and audio content from virtually any platform, equipped with an advanced **Pro Audio Player Studio**, intelligent **Playlist Management**, and a built-in **Video Crop, Zoom, Trim & HD GIF Studio**.

Built with Flutter 3.x and native Android hardware-accelerated Kotlin engines (Media3, AudioFX, MediaSession, Foreground Services), AllDown delivers zero-latency playback, smooth lockscreen media controls, and full background execution even while your phone is locked or in deep sleep.

---

## ✨ Key Features

### 🎧 Pro Audio Player Studio & Background Engine
- **Screen-Lock Background Audio Playback**: Continuous background playback powered by an Android `ForegroundService` (`mediaPlayback`) and CPU `PARTIAL_WAKE_LOCK`. The player continues playing smoothly when the screen locks or display turns off, with zero battery waste when paused.
- **Lockscreen & Notification Transport Controls**: Native `MediaSession` & `Notification.MediaStyle` integration providing interactive controls (**Previous**, **Play/Pause**, **Next**, **Stop**, and scrubber seeking) directly on the lockscreen and status bar.
- **Headphone Unplug Protection**: Detects `ACTION_AUDIO_BECOMING_NOISY` and automatically pauses audio when wired headphones, Bluetooth earbuds, or external speakers are disconnected.
- **Hardware-Accelerated 5-Band Equalizer**: Real-time sound frequency shaping (60 Hz, 230 Hz, 910 Hz, 3.6 kHz, 14 kHz) with built-in presets (*Rock*, *Pop*, *Jazz*, *Classical*, *Flat*, etc.).
- **Hardware Bass Boost & Volume Booster (+30 dB)**: Dedicated bass enhancement slider and a high-gain loudness booster for quiet tracks and outdoor listening.
- **Variable Playback Speed (`0.25x` – `2.0x`)**: Adjust speed on the fly with pitch correction.
- **A-B Segment Repeat Loop**: Set custom start (A) and end (B) loop points to effortlessly loop specific musical passages, language lessons, or podcast segments.
- **Countdown Sleep Timer**: Set a timer (`15m`, `30m`, `45m`, `60m`, or custom) that smoothly fades out audio and stops playback.
- **Audio Trimmer Modal**: Lossless audio trimming tool to cut and save specific audio snippets directly into your library.

### 📂 Smart Playlists & Queue Management
- **Smart Auto-Playlists**: Automatically curated smart playlists for **Recently Added**, **Favorites**, and **Most Played** tracks.
- **Custom User Playlists**: Create, rename, and manage custom playlists; easily add and remove tracks.
- **Interactive Queue Reordering**: Drag-and-drop playlist reordering, "Play Next", Shuffle mode, and Repeat options (*Off*, *Repeat All*, *Repeat One*).
- **Auto-Advance & Resume**: Seamlessly plays through entire playlists, with track position memory for long recordings (> 10 minutes).

### 🎬 Built-in Video Crop, Zoom & Trim Studio
- **Frame-Accurate Video Trimmer**: Cut videos with real-time frame preview.
- **Social Media Aspect Ratios**: One-tap aspect ratio presets (`Original`, `16:9`, `9:16`, `1:1`, `4:5`, `21:9`) optimized for TikTok, Instagram Reels, YouTube Shorts, and X (Twitter).
- **Interactive Pan & Zoom**: Smoothly zoom in (`1.0x` – `3.0x`) and pan (X / Y) across the live video canvas before exporting.
- **Hardware-Accelerated MP4 Export**: High-speed video rendering powered by **Android Jetpack Media3 Transformer**.

### 🖼️ HD Animated GIF Studio (True 256-Color Palette)
- **High-Quality GIF Creation**: Convert any video clip into an animated GIF at `10 FPS` and crisp 480p resolution.
- **Median-Cut Quantizer & Floyd-Steinberg Dithering**: Produces smooth color gradients and eliminates color banding.
- **Instant Gallery Indexing**: Automatically indexed into Android and Samsung Gallery via `MediaScannerConnection`.

### 🌐 Universal Multi-Platform Downloader & YouTube Playlist Extractor
- **Full YouTube Playlist Support**: Paste any YouTube playlist link to batch-fetch all track metadata and download all videos or audio files in one tap.
- **12+ Platforms Supported**: YouTube, YouTube Shorts, TikTok, Instagram Reels, Facebook Watch, X (Twitter), Streamable, Vimeo, Wikimedia Commons, Archive.org, and universal direct media streams.
- **Automatic Format Remuxing**: Detects unremuxed MPEG-TS streams and automatically converts them to clean, instantly playable MP4 files.
- **Network Customization**: Wi-Fi Only download protection, parallel downloads (`1` – `5` simultaneous streams), auto-retry on network dropouts, custom User-Agent headers, and Netscape `cookies.txt` import.

### 🔄 In-App Auto-Updater
- **One-Tap Updates**: Integrated `AppUpdateService` checks GitHub Releases for new versions, shows detailed changelogs, and downloads/installs the latest APK directly within the app.

---

## 🎧 Pro Audio Player Studio

```
┌────────────────────────────────────────────────────────┐
│                  ALLDOWN AUDIO STUDIO                  │
├────────────────────────────────────────────────────────┤
│  [Now Playing]  Song Title - Artist                    │
│  01:24 ──────────●────────────────────── 03:45         │
│                                                        │
│  [Controls]   [🔀 Shuffle]  [⏮ Prev]  [▶ Play/Pause]   │
│               [⏭ Next]     [🔁 Repeat] [⏱ Sleep Timer] │
│                                                        │
│  [Pro Audio Tools]                                     │
│  🎚️ 5-Band Equalizer: [Rock] [Pop] [Jazz] [Custom]     │
│  🔊 Bass Boost Slider: ───────[ 70% ]───────           │
│  📢 Volume Gain Booster: ─────[ +18 dB ]────           │
│  ⚡ Playback Speed: [0.75x] [1.0x] [1.25x] [1.5x]      │
│  🔄 A-B Loop: Set [Point A] ─── Set [Point B]          │
│  ✂️ Audio Trimmer: Extract clip to Library             │
│                                                        │
│  [Queue & Playlists]                                   │
│  ≡≡ Drag & Drop Reorder  •  Smart Collections          │
└────────────────────────────────────────────────────────┘
```

---

## ✂️ Video Studio & HD GIF Generator

```
┌────────────────────────────────────────────────────────┐
│                  ALLDOWN VIDEO STUDIO                  │
├────────────────────────────────────────────────────────┤
│  [ Trim Slider ]  ──[==================]──  00:15 / 00:30│
│                                                        │
│  [ Aspect Ratios ]                                     │
│  (•) Original   ( ) 16:9    ( ) 9:16    ( ) 1:1   4:5  │
│                                                        │
│  [ Zoom & Pan Framing ]                                │
│  (-) ──────────[ 1.4x ]────────── (+)                  │
│  Pan X: [-1.0 ... 0.0 ... +1.0]                        │
│  Pan Y: [-1.0 ... 0.0 ... +1.0]                        │
│  (Supports interactive drag directly on video canvas)  │
│                                                        │
│  [ SAVE VIDEO (MP4) ]           [ CREATE GIF (HD) ]    │
└────────────────────────────────────────────────────────┘
```

---

## 🌍 Supported Platforms & Services

AllDown resolves and downloads media across **12+ categories and platforms**:

| Platform / Service | Extraction Method & Capabilities | Status |
| :--- | :--- | :---: |
| **YouTube Videos & Shorts** | Native stream manifest via `youtube_explode_dart` (Muxed MP4 & Audio-only M4A/WebM) | ✅ **Active** |
| **YouTube Playlists** | Batch playlist discovery, metadata parsing, and bulk downloading | ✅ **Active** |
| **X (Twitter)** | Direct MP4 resolution (`1080p` / `720p` / `480p`) via `api.fxtwitter.com` | ✅ **Active** |
| **TikTok** | Watermark-free HD MP4 & metadata resolution via `tikwm.com` API | ✅ **Active** |
| **Facebook Watch & Reels** | Direct HD/SD stream scraping (`hd_src` / `sd_src` / OpenGraph) | ✅ **Active** |
| **Instagram Reels & Posts** | Direct progressive MP4 video stream discovery | ✅ **Active** |
| **Streamable** | Direct API JSON extraction (`api.streamable.com/videos`) | ✅ **Active** |
| **Wikimedia Commons** | Open-source HD video & audio archives | ✅ **Active** |
| **Internet Archive (`archive.org`)** | Public domain films, documentaries & audio collections | ✅ **Active** |
| **Blender Open Movies CDN** | High-bitrate cinema test streams (Sintel, Big Buck Bunny, Tears of Steel) | ✅ **Active** |
| **Dailymotion & Vimeo** | OpenGraph `og:video` & embedded HTML5 media extractor | ✅ **Active** |
| **HTML5 `<video>` Portals** | Automatic `<video>` and `<source>` tag stream discovery | ✅ **Active** |
| **Universal Direct Links** | Any direct `.mp4`, `.webm`, `.mkv`, `.m4a`, `.mp3`, `.wav`, `.ogg` URL | ✅ **Active** |

> **Privacy & Security Note:** AllDown runs locally on your device. There is zero telemetry, tracking, or user data collection.

---

## 🛠️ Tech Stack & Architecture

- **Framework:** [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management:** [Riverpod](https://riverpod.dev) 2.x (`StateNotifierProvider`)
- **Native Android AudioFX Engine:** `android.media.audiofx.Equalizer`, `BassBoost`, `LoudnessEnhancer`
- **Native Android Media Control:** Android `MediaSession` & `Notification.MediaStyle`
- **Background Execution:** `AudioPlaybackService` (`foregroundServiceType="mediaPlayback"`), `DownloadForegroundService` (`dataSync`), and CPU `PARTIAL_WAKE_LOCK`
- **Native Video Processing:** Android Jetpack Media3 (`media3-transformer`, `media3-effect`, `media3-common` 1.4.1)
- **Custom Native GIF Encoder:** Kotlin `AnimatedGifEncoder` with Median-Cut 256-color quantizer & Floyd-Steinberg dithering
- **Storage & Gallery Sync:** Android Scoped Storage, `SharedPreferences`, and `MediaScannerConnection`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+ / Dart 3.x)
- Android SDK (API 26+ / Android 8.0 Oreo or newer)
- Java 17 (OpenJDK)

### 1. Clone the Repository
```bash
git clone https://github.com/vugy0212/Alldown.git
cd Alldown/alldown
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

### 4. Build Release APKs
```bash
# Build lightweight ABI-specific APKs (Recommended for installation)
flutter build apk --release --split-per-abi

# Build universal APK compatible with all architectures
flutter build apk --release
```

Compiled APKs will be located in: `alldown/build/app/outputs/flutter-apk/`.

---

## 👤 About

- **Project:** AllDown
- **Current Version:** 1.6.3 (`v1.6.3+25`)
- **Author:** **Allen**
- **Repository:** [https://github.com/vugy0212/Alldown](https://github.com/vugy0212/Alldown)

---

## 🙏 Credits & Acknowledgements

AllDown is developed as an independent, modernized Flutter media application built upon the architectural foundations, concepts, and heritage of [Seal](https://github.com/JunkFood02/Seal) by [JunkFood02](https://github.com/JunkFood02). We express our sincere gratitude to JunkFood02 and the open-source multimedia community (`yt-dlp`, FFmpeg, Media3) for their invaluable pioneer work and inspiration.

---

## 📄 License

This project is open-source software licensed under the [GNU General Public License v3.0 (GPLv3)](LICENSE).
