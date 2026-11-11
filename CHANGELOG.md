# Changelog

All notable changes to **AllDown** are documented in this file.

## [1.0.2] - 2026-11-11

### Improved & Fixed
- **Updater UX Streamlining:** The download button is now cleanly hidden when the app is already up to date, showing only a concise status card with an 'OK' button.
- **Direct APK Resolution:** The updater directly resolves and targets the optimal device-specific `arm64-v8a` APK from GitHub Releases for fast downloads.
- **Scrollable Modal:** Release notes are now fully contained in a smooth scroll view, keeping action buttons permanently anchored and accessible.

## [1.0.1] - 2026-11-11

### Added & Improved
- **Audio Codec Synchronization:** Home screen format selector and quality cards now dynamically reflect the audio codec chosen in Settings (`M4A / AAC`, `MP3`, or `Opus`).
- **GPL-3.0 License Compliance:** Added explicit attribution and acknowledgment for the upstream [Seal](https://github.com/JunkFood02/Seal) project and author [JunkFood02](https://github.com/JunkFood02).
- **In-App Update Engine:** Live verification against GitHub Releases API (`v1.0.1`).

## [1.0.0] - 2026-11-10

### Added
- **Universal Media Extraction Engine:** Support for YouTube, X (Twitter), TikTok, Facebook, Streamable, Wikimedia Commons, Archive.org, Dailymotion, Vimeo, and direct HTML5/CDN media streams.
- **Built-in Video Studio & HD GIF Generator:**
  - Hardware-accelerated video trimming, aspect-ratio cropping (`16:9`, `9:16`, `1:1`, `4:5`), interactive pan & zoom (`1.0x`–`3.0x`) via Jetpack Media3 Transformer.
  - True 256-color Median-Cut palette & Floyd-Steinberg dithering HD GIF encoder with instant Android Gallery (`MediaStore`) indexing.
- **Dynamic Dark & Light Theme Switcher:** Instant one-tap theme switching in the top header bar with persistent preference storage.
- **Background Download Queue & Foreground Service:** Concurrent download management, real-time speed/ETA telemetry, Wi-Fi-only enforcement, auto-retry, Netscape `cookies.txt` import, and completion notifications.
- **Interactive Settings & User Guide:** Expandable accordions for Download Directory, Video/Audio Defaults, Network & Concurrency, Supported Services, and Help Guide.
