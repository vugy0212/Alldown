# Changelog

All notable changes to **AllDown** are documented in this file.

## [1.3.6] - 2026-11-12

### Fixed
- **Single Instance & Task Management (`singleTask`):** Fixed an issue where opening or sharing links from external apps (YouTube, Reddit, Instagram, browser) spawned multiple duplicate window instances in Android's Recents screen. Removed empty `taskAffinity` and switched to `android:launchMode="singleTask"` so AllDown always maintains a single unified application instance, routing shared links cleanly to the foreground window via `onNewIntent`.

## [1.3.5] - 2026-11-12

### Added & Improved
- **Reddit Video & Audio Downloader:**
  - Added full support for downloading Reddit-hosted videos (`reddit.com/r/...`, `redd.it/...`, `v.redd.it/...`, `/s/...`).
  - Automated edge resolution of Reddit's separated video/audio streams into a high-speed, single-file merged MP4 with pristine sound.
  - Integration with Cloudflare DLR edge resolver and client-side fallback parsing.
  - Master HLS playlist (`HLSPlaylist.m3u8`) fallback support using Android Media3 Transformer.
  - Automated extraction of post titles, subreddit origin, author `@username`, and HD stream badge.
  - Rule Definitions: Updated `rules.json` and `RemoteRulesService` with Reddit pattern matching.

## [1.3.4] - 2026-11-12

### Added & Improved
- **Instagram Video & Reels Downloader:**
  - Added full support for downloading Instagram Reels, Videos, and Posts (`instagram.com/reel/`, `/p/`, `/tv/`, `instagr.am/`).
  - Implemented zero-auth direct progressive MP4 stream extractor via inline `data-sjs` and `xig_polaris_media` payload parsing.
  - Automatic detection of highest available resolution (HD 1080p / 720p), post caption/title, uploader `@username`, duration, and cover art.
  - Seamless support for authenticated sessions: imports cookies from "Browser Cookies & Auth" settings drawer to download private or restricted posts.
  - Added background headless WebView fallback mechanism to bypass login redirect walls on Android.
  - Rule Definitions: Updated `rules.json` and `RemoteRulesService` with Instagram pattern matching and URL shortcode extraction.

## [1.3.3] - 2026-11-12

### Fixed & Improved
- **fMP4 / CMAF HLS Support (`#EXT-X-MAP`):** Fixed playback failure for Dailymotion and Vimeo video downloads by downloading the required initialization segment (`init.mp4` / `init.m4s`) with `ftyp` and `moov` track headers.
- **In-App Video Player Fix:** Fixed `Playback error: Source error` in ExoPlayer when playing downloaded HLS video files.
- **Smart Remuxing:** Enhanced `VideoEditorHelper.kt` to dynamically differentiate MPEG-TS (`0x47`) and fMP4 streams for clean Jetpack Media3 container remuxing.
- **About Versioning:** Updated in-app version indicator in Settings > About to accurately reflect `v1.3.3`.

## [1.3.0] - 2026-11-12

### Added & Improved
- **Cloudflare Dynamic Link Resolver (DLR) & Remote Rules Engine:**
  - Integrated zero-downtime remote extraction engine running on Cloudflare Workers + KV (`alldown-dlr`).
  - Real-time dynamic URL resolution for streaming platforms without requiring APK updates when web structures change.
  - Offline-first cache architecture with local rules fallback.
- **Vimeo & Dailymotion Video Downloading Support:**
  - Implemented native HLS (`.m3u8`) segment parsing and sequential chunk downloading in `DownloadQueueProvider`.
  - Live percentage progress tracking during segment retrieval with direct lossless muxing into playable `.mp4`.
  - Added session cookie warmup and header spoofing (`Referer`, `User-Agent`) to prevent stream 403 errors.

## [1.2.0] - 2026-11-11

### Added & Improved
- **Video Studio GIF Quality Presets & Live Size Estimation:**
  - Added an intuitive quality selector bottom sheet for GIF generation with 3 presets: Low (320p, 8 FPS), Standard (420p, 10 FPS - Recommended), and High (540p, 12 FPS).
  - Dynamic real-time MB size estimation badge for each preset calculated directly from the active trim range.
  - Native hardware-scaled frame processing in `VideoEditorHelper.kt`.
- **Audio Extraction Quality Presets & Live Size Estimation:**
  - Added a quality selector modal for video-to-audio extraction with 3 presets: Standard (128 kbps M4A - Speech & Podcasts), High Quality (192 kbps M4A - Music & Balanced), and Master (Original Stream / 320 kbps M4A - Studio Fidelity).
  - Dynamic real-time MB size estimation badge calculated directly from the trimmed duration.
- **Video Player CapCut-style Edit Button:**
  - Added a prominent vertical action button with a small "Edit" label below the scissors icon in the Video Player header for direct access to Video Studio.
- **Settings & UI Reorganization:**
  - Moved the "Supported Services & Extractors" drawer into "Help & User Guide" for cleaner settings structure.
  - Added a "Buy Me a Coffee" creator support banner placeholder in "About AllDown".

## [1.1.0] - 2026-11-11

### Added & Improved
- **Video to Audio Extraction & Trimming:** Directly extract high-fidelity audio (`M4A/AAC`) from any downloaded video with custom start/end time trimming via Jetpack Media3 Transformer. Saved immediately to `Music/AllDown` and indexed in Android MediaStore & in-app library.
- **CapCut-style Multi-Touch Canvas:** Full two-finger pinch-to-zoom (`1.0x` - `3.0x`) and single/multi-finger pan directly on the live video preview canvas with instantaneous aspect-ratio clipping.
- **Library Quick Action:** Added instant "Extract & Trim Audio" shortcut in the video card context menu.

## [1.0.3] - 2026-11-11

### Improved & Added
- **Collapsible Cookies & Auth Drawer:** Converted the standalone Cookies & 18+ Access card in Settings into a sleek, expandable drawer matching all other settings modules.
- **In-App Direct Updater:** Enhanced native APK downloading with live progress indicator and automatic Android Package Installer intent.

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
