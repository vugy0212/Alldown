# AllDown Architecture & Module Reference

AllDown is located in the [`alldown/`](alldown/) directory and uses a modular Flutter + Native Android Kotlin architecture:

- **`alldown/lib/screens/`**:
  - `home_screen.dart` — Quick URL input, clipboard paste, live metadata preview, format/quality selector, and instant download trigger.
  - `queue_screen.dart` — Real-time active, queued, paused, and completed download pipeline with priority ordering.
  - `library_screen.dart` — Media vault with built-in video/audio playback and Video/GIF Studio integration.
  - `video_editor_screen.dart` — Interactive video trim, aspect-ratio crop, zoom/pan framing, and HD GIF creation studio.
  - `settings_screen.dart` — Storage analytics, Netscape `cookies.txt` import, collapsible configuration drawers, user guide, and About section.
- **`alldown/lib/providers/`**:
  - `download_queue_provider.dart` — Multi-service stream download engine enforcing concurrency, Wi-Fi-only mode, auto-retry, custom User-Agent, and completion notifications.
  - `settings_provider.dart` — Persistent `AppSettings` state management with SAF path normalization and `cookies.txt` parsing.
- **`alldown/android/app/src/main/kotlin/com/alldown/app/alldown/`**:
  - `MainActivity.kt` — Flutter `MethodChannel` bridge (`com.alldown.app/downloader`), `FileProvider` external intents, network transport check, and share intent receiver.
  - `service/DownloadForegroundService.kt` — Ongoing progress notification service and completion notifications.
  - `video/VideoEditorHelper.kt` & `video/AnimatedGifEncoder.kt` — Hardware-accelerated Jetpack Media3 Transformer video cropper/trimmer and Median-Cut + Floyd-Steinberg HD GIF generator.
