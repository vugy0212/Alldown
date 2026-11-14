# Changelog

All notable changes to **AllDown** are documented in this file.

## [1.6.4] - 2026-11-14

### Added
- **Native Haptic Feedback UX (`HapticService`):**
  - Integrated subtle, tactile haptic feedback using Flutter's built-in `package:flutter/services.dart` (`HapticFeedback` class) without external dependencies.
  - Centralized `HapticService` helper with granular interaction tiers:
    - **Light Impact (`HapticFeedback.lightImpact()`):** Standard button taps (Paste, Clear, Search, Play/Pause, Next/Prev, Favorites), format and quality chips, menus, and bottom sheets.
    - **Medium Impact (`HapticFeedback.mediumImpact()`):** Download starts (single & batch playlists), video/audio clipping saves, and GIF exports.
    - **Selection Click (`HapticFeedback.selectionClick()`):** Slider touch start/end (Audio scrubber, Equalizer 5-band sliders, Bass Booster, Volume Booster, Video Trim/Zoom/Pan), bottom navigation tab switches, and Settings toggles.
    - **Warning / Error (`HapticFeedback.heavyImpact()`):** Failed downloads, invalid URL inputs, queue task removal, and library item / playlist deletion.
  - Added user toggle in **Settings -> Notifications & Background Service** to enable or disable haptic feedback at will, stored persistently via `SharedPreferences`.
  - Added Android permission `<uses-permission android:name="android.permission.VIBRATE"/>` in `AndroidManifest.xml`.

## [1.6.3] - 2026-11-14

### Fixed
- **Screen Lock Lifecycle Auto-Pause Prevention (Samsung Galaxy S25 Ultra & Android):**
  - Configured `VideoPlayerOptions(allowBackgroundPlayback: true)` in `PlayerNotifier`.
  - In Flutter's `video_player` plugin, omitting `allowBackgroundPlayback: true` causes the framework's internal `_VideoAppLifeCycleObserver` to intercept `AppLifecycleState.paused` when the phone screen is locked or turned off, immediately pausing playback, and resuming on `AppLifecycleState.resumed` when the phone is unlocked.
  - Setting `allowBackgroundPlayback: true` completely detaches the lifecycle observer, allowing continuous, uninterrupted playback in the background with the screen locked.

## [1.6.2] - 2026-11-14

### Fixed
- **Screen Lock Background Audio Playback & Battery Optimization (MIUI/HyperOS & Android 12-14):**
  - Implemented dedicated `AudioPlaybackService` foreground service bound with `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK` to prevent Android's process cgroup freezer from suspending audio decoding threads when the screen is locked or display turns off.
  - Added CPU `PARTIAL_WAKE_LOCK` held continuously during active playback (`isPlaying == true`), guaranteeing zero stutter, pauses, or audio dropouts when device enters deep sleep. WakeLock is automatically released on pause or stop to conserve battery.
  - Configured Flutter `VideoPlayerController.file` with `VideoPlayerOptions(mixWithOthers: true)` to avoid audio interruptions on surface destruction or lockscreen status bar transitions.
  - Seamless lockscreen notification transport controls (`Previous`, `Play/Pause`, `Next`, `Close`) dynamically synchronized with the foreground service.

## [1.6.1] - 2026-11-14

### Fixed
- **Audio Playback Activation & Audio Focus Conflict Fix:**
  - Resolved an issue where pressing the Play button resulted in immediate pause / silence due to a race condition between Android's native `AudioManager.requestAudioFocus` and ExoPlayer's internal audio focus manager. ExoPlayer now manages audio focus without OS interference.
  - Fixed `togglePlayPause` to automatically re-load and start playback if the player controller was in an uninitialized state when pressing Play.
  - Immediate `VideoPlayerModal.show(context)` opening with non-null `currentItem` initialization, eliminating delays and blank player states.
  - Safe, protected status-bar icon fallback for `MediaStyle` notification and added `MODIFY_AUDIO_SETTINGS` permission in AndroidManifest.


## [1.6.0] - 2026-11-14

### Added
- **Pro Audio Player Studio & Background MediaSession:**
  - **Native Lock Screen & Notification Transport Controls**: Seamless integration with Android `MediaSession` and `Notification.MediaStyle`. Displays interactive playback controls (Play, Pause, Skip Previous, Skip Next, Stop) with live track metadata and scrubber directly on the lock screen and notification shade.
  - **Headphone Unplug Detection**: Automatically pauses audio playback when headphones, Bluetooth earbuds, or AUX cables are disconnected (`ACTION_AUDIO_BECOMING_NOISY`), preventing accidental audio blasting.
  - **Audio Focus Management**: Automatically handles audio focus changes, pausing playback during incoming phone calls or other apps requesting audio focus.
  - **Android 14+ Foreground Service**: Added `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission and configured `foregroundServiceType="dataSync|mediaPlayback"` to ensure smooth background audio without OS interruption.

- **Native 5-Band Equalizer, Bass Boost & Volume Booster:**
  - Hardware-accelerated audio effects using Android's native `android.media.audiofx` engine (`Equalizer`, `BassBoost`, `LoudnessEnhancer`).
  - Interactive **5-Band Graphic Equalizer** modal with 5 vertical frequency sliders (60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz) and pre-configured sound presets (Rock, Pop, Jazz, Classical, Flat, etc.).
  - **Bass Boost** effect with dedicated strength slider (0–100%) and hardware bass virtualization.
  - **Loudness / Volume Booster** slider providing up to **+30 dB** clean gain boost for quiet tracks and outdoor listening.

- **Playback Speed, A-B Repeat Loop & Countdown Sleep Timer:**
  - **Variable Playback Speed**: Quick selector chip for `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x` speeds with pitch preservation.
  - **A-B Segment Looping**: Set custom Start point (A) and End point (B) to endlessly loop any segment of a song or podcast.
  - **Countdown Sleep Timer**: Choose from presets (15m, 30m, 45m, 60m) or "End of track", featuring an automatic 5-second smooth volume fadeout before stopping playback.

- **Interactive Queue Drag-and-Drop & Smart Playlists:**
  - **Drag-and-Drop Queue Reordering**: Reorder songs in the active playback queue on the fly via `ReorderableListView`.
  - **Queue Context Actions**: Added "Play Next in Queue" and "Add to Queue End" directly in the Library context menu.
  - **Lossless Audio Trimmer Modal**: Extract and save any audio segment with dual start/end trim handles directly into `Music/` and index it in the Library.
  - **Auto-Curated Smart Playlists**: 3 dynamic playlists available at the top of the Playlists tab:
    - 🕒 *Recently Added / Nedavno preuzeto*: Plays audio tracks sorted by latest download.
    - ❤️ *Favorites / Omiljene pjesme*: Instant playback of all favorite songs.
    - 🔥 *Most Played / Najčešće slušano*: Top audio collection sorted by track length and popularity.


## [1.5.3] - 2026-11-14

### Added
- **Full In-App Audio Playlist Playback & Queue System:**
  - Upgraded the media player to support seamless playlist playback across all downloaded audio tracks.
  - Automatic continuous playback: tracks now seamlessly auto-advance to the next song when finished.
  - Dedicated **Audio Transport Controls**:
    - **Shuffle Mode**: Randomize playback order with smart permutation preserving the current track.
    - **Repeat Modes**: Cycle between Repeat Off, Repeat All, and Repeat One.
    - **Previous / Next Track**: Instant track navigation via `Icons.skip_previous_rounded` and `Icons.skip_next_rounded`.
  - **Interactive In-Player Queue Drawer ("Up Next / Red izvođenja"):**
    - View active queue of songs with real-time playing indicators and song counts.
    - Tap any song in the queue to jump directly to it.
    - Remove individual songs from the active queue with a single tap.
    - "Save Queue as Playlist" button directly within the player.

### Added
- **Library Multi-Selection & Custom Playlist Creator:**
  - **Selective Playback Mode**: Tap "Select" in Library to enter selection mode with checkboxes on each audio card. Choose any subset of downloaded tracks and tap "Play as Playlist" to start listening immediately.
  - **Instant "Play All"**: One-tap button on the Audio category tab to queue and play all downloaded songs sequentially.
  - **Persistent Local Playlists**:
    - Create, name, and manage custom playlists (e.g. "Favorites", "Gym Workout", "Rock Hits") stored locally via `StorageService`.
    - Dedicated "Playlists" category chip in the Library toolbar.
    - One-tap playback of entire saved playlists.
  - **Enhanced MiniPlayer Bar**:
    - Added Previous and Next buttons when a playlist is active.
    - Real-time track progress indicator (e.g. "Playing (3/12) • M4A").
  - Bilingual Croatian & English localization across all new playlist modals, queue drawers, and player controls.

## [1.5.2] - 2026-11-13

### Fixed
- **YouTube Audio Download 1MB Buffer Hang & 403 Forbidden:**
  - Resolved an issue where YouTube audio downloads stalled indefinitely at "Connecting..." or failed with HTTP 403 after downloading 1 MB. YouTube recently enforced strict 1 MB buffer limits on adaptive audio-only streams (`audioOnly`) for mobile clients when playback authorization tokens are missing.
  - Implemented automatic fallback to high-speed muxed streams (`itag 18`, 360p MP4 with AAC stereo audio) containing `ratebypass=yes`. This bypasses YouTube's adaptive audio throttling entirely, downloading at full network speed (15-20+ MB/s) without bot checks or rate limits.
  - Preserved lossless audio playback: saved files are extracted directly into the `Music/` folder as `.m4a` containers, fully recognized and indexed as native audio tracks by Android MediaStore, ExoPlayer, and third-party media players.
  - Added an 8-second manifest timeout to prevent background downloads from hanging indefinitely in silent retry loops.
  - Switched InnerTube client discovery to pure `YoutubeApiClient.androidSdkless` with `requireWatchPage: false` for instant stream metadata extraction.

## [1.5.1] - 2026-11-13

### Fixed & Improved
- **YouTube Playlist Stream Extraction & Queue Concurrency:**
  - Resolved `RequestLimitExceededException` by switching to pure InnerTube clients (`androidSdkless`, `ios`, `androidMusic`) with `requireWatchPage: false`, eliminating YouTube botguard blocks and rate limiting.
  - Eliminated redundant watch page network calls during download when track metadata is already present from the playlist intake.
  - Fixed download queue promotion logic: resolved an issue where downloads stopped promoting queued items when active tasks completed, ensuring continuous processing.
  - Enforced `maxConcurrentDownloads` limit when queuing multiple playlist items, preventing simultaneous stream extraction overload.


### Added
- **YouTube Playlist Audio Download Engine:**
  - Full support for detecting, parsing, and extracting YouTube playlists (`/playlist?list=...` and `&list=...`).
  - High-speed YouTube InnerTube API integration (`youtubei/v1/browse`) parsing complete playlist tracklists (100+ songs, titles, artists, thumbnails, durations) in under 200 ms with robust HTML fallback.
  - Dedicated **Playlist Intake Card** on the Home screen showing playlist thumbnail banner, track count badge, audio-only format constraint badge (`Audio (M4A) • 320 kbps`), and dual action buttons: **Download All** and **Select Songs**.
  - **Selective Track Picker Bottom Sheet (`PlaylistSelectionModal`):**
    - Instant live search and filtering through all playlist songs.
    - Global "Select All / Deselect All" toggle.
    - Individual rounded checkboxes with track numbers, artwork thumbnails, duration tags, and estimated audio file size.
    - Sticky bottom control bar showing live selected count and total download size calculation in megabytes.
  - One-tap batch queuing of all or selected songs directly into the background download queue with lossless M4A / AAC 320 kbps audio settings.
  - Bilingual Croatian & English localization across all playlist intake banners, modals, and notifications.

### Changed & Improved
- Auto-constrained playlist downloads to high-fidelity audio mode to ensure minimal bandwidth usage, instant queuing, and clean separation from single video downloads.
- Clean Home Screen layout: hides video resolution accordions and single-video format selectors whenever a playlist is detected.


### Added
- **Višejezična podrška (Croatian & English Multilingual Architecture):**
  - Dodana potpuna podrška za hrvatski (`hr`) i engleski (`en`) jezik kroz cjelokupnu aplikaciju (`L10n`).
  - Dinamički prekidač jezika s emoji zastavicama (`🇭🇷 HR` / `🇬🇧 EN`) integriran izravno u gornji `CustomHeader` pored prekidača za tamnu/svijetlu temu.
  - Trenutna (reaktivna) promjena jezika bez potrebe za ponovnim pokretanjem aplikacije, uz perzistenciju postavke jezika u `AppSettings` i `StorageService`.
  - Potpuno lokalizirani svi ekrani:
    - **Početni zaslon (Preuzmi):** unos poveznica, status analize toka, odabir formata (`Video (MP4)`, `Audio (M4A)`, `Izvorni Tok`), rezolucija i gumb preuzimanja.
    - **Red Čekanja:** filtarske kartice (`Aktivno`, `Dovršeno`, `Pauzirano`), telemetrija brzine, kontrolne tipke (`Pauziraj sve`, `Očisti`) i limit istovremenih zadataka.
    - **Biblioteka:** tražilica, kategorije (`Sve`, `Videozapisi`, `Zvuk`, `Favoriti`), mjerač zauzeća memorije, padajući izbornik sortiranja (`Najnovije`, `Najstarije`, `Najveće`, `Naziv A-Z`) te kontekstualni izbornik datoteka.
    - **Postavke:** sve sekcije, padajući izbornici, dijalozi za uvoz kolačića, odabir mapa, korisnički vodič i prozor s informacijama o aplikaciji.


### Fixed & Improved
- **Reactive Light & Dark Theme Transitions:**
  - Resolved theme state synchronization across `LibraryScreen`, `MainScaffold`, and `MiniPlayerBar` by binding them directly to Riverpod's `settingsProvider`.
  - Fixed remaining dark surfaces in the upper 1/3 of the Library screen (search input container, category filter chips, local storage meter, sort controls, and view toggles) to dynamically switch to high-contrast `#FFFFFF` and `#F8F9FC` with subtle ambient elevations and borders.
  - Enhanced Bottom Navigation Bar styling in light mode with high-contrast active icons and background blur.
  - Improved codec selector tab contrast in Settings using `onPrimaryContainer` typography.

## [1.3.8] - 2026-11-13

### Fixed & Improved
- **Library Screen Full Light Theme Support:**
  - Fixed dark elements remaining in Light Mode by updating header, status bar, search inputs, filter category chips, and media cards to crisp, high-contrast light surfaces (`#FFFFFF` cards with subtle ambient elevation).
- **Settings UI Decluttering:**
  - Removed "Visit GitHub Repository" button from the About section to keep the UI clean, distraction-free, and end-user friendly.
- **Audio Extraction Streamlining (M4A / AAC Standard):**
  - Unified audio options into lossless stream **M4A / AAC** (the modern standard supported across 100% of Android, iOS, Windows, and car infotainment systems) and high-efficiency **Opus**.
  - Eliminated redundant and lossy re-encoded MP3 toggles since online media platforms stream in native AAC.

## [1.3.7] - 2026-11-13

### Fixed & Improved
- **Settings & Home Screen Full Synchronization:**
  - **Unified Video Resolutions:** Aligned `Default / Max Video Resolution` in Settings (`4K Ultra HD (2160p)`, `1080p Full HD`, `720p HD`, `480p SD`) with the Home Screen quality selector so changing the default resolution in Settings immediately updates the Home Screen selection and caps stream resolution during extraction.
  - **Synced Audio Bitrate & Codec:** Changing `Audio Quality (Bitrate)` (`320 kbps`, `256 kbps`, `192 kbps`, `128 kbps`) and `Audio Format (Codec)` (`MP3`, `M4A / AAC`, `Opus`) in Settings dynamically updates the Home Screen audio options and ensures `DownloadQueueProvider` respects per-download audio quality and codec selection.
  - **Dynamic Video Container & Auto-Remux:** Connected `Default Video Container` (`MP4`, `MKV`, `WebM`) to the Home Screen format tab (`Video (MP4/MKV/WebM)`) and wired `Auto-remux to MP4` in the HLS segment muxer (`_downloadHlsSegments`).
  - **Replaced Dead SponsorBlock Toggle with Organize by Platform:** Removed the unimplemented `SponsorBlock Filter` toggle and replaced it with a functional `Organize by Platform` setting that saves downloaded media into platform-specific subfolders (`/Download/AllDown/Videos/YouTube/`, `/TikTok/`, `/Reddit/`, etc.) when enabled.
  - **Interactive Advanced Config & Updated Supported Services:** Connected the `Advanced Config` button on the Home Screen to open the Settings tab directly, and updated the `Supported Services & Extractors` list in Help to include Instagram Reels/Posts, Reddit (`v.redd.it`), and Dailymotion device-token HLS.

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
