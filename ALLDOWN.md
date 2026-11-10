Act as a Senior Flutter & Android Engineer.

 

We are building a production-grade Android media downloader app named "AllDown", using Flutter, based on the architecture of the open-source "Seal" project (which integrates yt-dlp, FFmpeg, and Python runtime via Chaquopy / Flutter-native bindings), customized with our modern Material 3 design created in Google Stitch.

 

\#\#\# Technical Stack & Architecture:

\- Framework: Flutter (latest stable, Dart 3\)

\- Design System: Material 3 (Material You dynamic theming, custom dark theme default)

\- State Management: Riverpod (or BLoC)

\- Downloader Core: yt-dlp engine integrated with FFmpeg for auto-remuxing to MP4 / MP3 extraction

\- Storage & Persistence: Hive / Isar / SharedPreferences for local settings and download history; Scoped Storage (SAF) for Android 11+

\- Concurrency & Services: Android Foreground Service with permanent notification for background downloading

 

\#\#\# Visual Design Guidelines (Reflecting Google Stitch Screens):

1\. Color Palette:

   \- Background: Dark Charcoal (\#121218)

   \- Surface / Card: \#1E1E28 with 1px border (\#2A2A3C)

   \- Primary Accent: Electric Indigo (\#6366F1)

   \- Secondary Accent: Cyan (\#06B6D4)

   \- Success / Done: Emerald (\#10B981)

   \- Error / Alert: Rose (\#F43F5E)

2\. Typography & Shape:

   \- Modern Sans-serif (Google Fonts 'Plus Jakarta Sans' or 'Inter')

   \- Card border radius: 18px \- 22px

   \- Pill-shaped chips and buttons (radius: 28px)

   \- Bottom Navigation Bar: Floating or frosted glassmorphism with subtle elevation

 

\#\#\# Screen Implementations Required:

 

1\. Main Home Screen (HomeScreen):

   \- Header with "AllDown" typography branding and quick status pill.

   \- Smart URL Input Box with single-tap "Paste from Clipboard" and "Clear" buttons.

   \- Dynamic Preview Card (triggered on URL validation):

     \* Fetches metadata flatly: Thumbnail, Title, Channel/Creator, Duration.

   \- Format Selection Section:

     \* Mode Selector (SegmentedButton): \[Video (MP4)\] \| \[Audio (MP3)\] \| \[Custom\].

     \* Quality Chips: 2160p (4K), 1080p Full HD, 720p HD, 480p, Audio 320kbps.

   \- Toggles & Options (SwitchListTile):

     \* "Create subfolder with video title" (Default: ON).

     \* "Auto-remux to MP4" (Default: ON for Jellyfin Direct Play).

     \* "Embed subtitles" (langs: hr, sr, bs, en).

     \* "Save thumbnail (.jpg)".

   \- Full-width Gradient Action Button: "Start Download".

 

2\. Downloads & Queue Screen (QueueScreen):

   \- TabBar: Active (with badge count), Completed, Paused.

   \- Live Download Item Card:

     \* Thumbnail on the left.

     \* Title with single-line ellipsis.

     \* Animated LinearProgressIndicator.

     \* Real-time metadata row: Speed (MB/s), ETA, Downloaded/Total size, Percentage.

     \* Inline Controls: Pause, Resume, Cancel.

   \- Bottom floating action bar for "Pause All" and "Clear Finished".

 

3\. Media Library & Player Screen (LibraryScreen):

   \- Grid and List view modes.

   \- Quick search and filter chips (All, Videos, Music).

   \- Tap to play with native Android video/audio intent or in-app media player.

   \- Context Menu: "Share", "Open in Files", "Show Path", "Delete".

 

4\. Settings & Authentication Screen (SettingsScreen):

   \- Download Directory Selector via Android SAF (Storage Access Framework).

   \- "Cookies / 18+ Gate Bypass" Section:

     \* Status indicator: \[Active / Not configured\].

     \* Option to import \`cookies.txt\` with file picker and format validator (checks for LOGIN\_INFO).

     \* Guide / Tooltip explaining how to export cookies safely for age-restricted videos.

   \- Network options: Download only on Wi-Fi, Max concurrent downloads slider (1-5).

   \- yt-dlp & FFmpeg update checker and version card.

 

\#\#\# Key Functional Requirements:

\- Deep Linking & Share Sheet: Register an Android Intent filter (\`ACTION\_SEND\`) so users can tap "Share" inside the YouTube / TikTok / Instagram app and select "AllDown" to immediately open the app with the URL parsed.

\- Foreground Service: Downloads must not stop when the app is minimized or the screen is turned off.

\- Error Handling: Graceful handling of network timeouts, private/age-gated videos with informative user-friendly dialogues.

 

Generate the project structure, main widgets, models, and state controllers with clean, modular, and documented Flutter code.

