enum AudioCodec {
  aac,
  opus,
}

enum MaxResolution {
  res4k,
  res1080p,
  res720p,
  res480p,
}

class AppSettings {
  final String downloadDirectory;
  final bool cookiesActive;
  final int cookiesCount;
  final String cookiesHeader;
  final int maxConcurrentDownloads;
  final bool wifiOnly;
  final bool autoRetry;
  final bool autoRemuxToMp4;
  final AudioCodec audioCodec;
  final MaxResolution maxResolution;
  final bool organizeByPlatform;
  final String ytDlpVersion;
  final String ffmpegVersion;
  final String audioBitrate;
  final String videoContainer;
  final String userAgent;
  final int connectionTimeout;
  final bool notifyOnComplete;
  final bool isDarkMode;

  const AppSettings({
    this.downloadDirectory = "/storage/emulated/0/Download/AllDown",
    this.cookiesActive = false,
    this.cookiesCount = 0,
    this.cookiesHeader = "",
    this.maxConcurrentDownloads = 3,
    this.wifiOnly = true,
    this.autoRetry = true,
    this.autoRemuxToMp4 = true,
    this.audioCodec = AudioCodec.aac,
    this.maxResolution = MaxResolution.res1080p,
    this.organizeByPlatform = false,
    this.ytDlpVersion = "v2025.01.26-nightly",
    this.ffmpegVersion = "v7.1 Android-ARM64",
    this.audioBitrate = "320 kbps",
    this.videoContainer = "MP4",
    this.userAgent = "Android Chrome",
    this.connectionTimeout = 15,
    this.notifyOnComplete = true,
    this.isDarkMode = true,
  });

  /// Converts Android SAF tree URIs (e.g. content://.../primary%3ADownload...) into standard POSIX paths.
  static String normalizeDirectoryPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return "/storage/emulated/0/Download/AllDown";
    }
    if (trimmed.startsWith('content://')) {
      final decoded = Uri.decodeFull(trimmed);
      final primaryIdx = decoded.indexOf('primary:');
      if (primaryIdx != -1) {
        final subPath = decoded.substring(primaryIdx + 'primary:'.length).trim();
        if (subPath.isEmpty) {
          return "/storage/emulated/0";
        }
        return "/storage/emulated/0/$subPath";
      }
      return "/storage/emulated/0/Download/AllDown";
    }
    return trimmed;
  }

  /// Resolves the friendly User-Agent preset name into a full HTTP User-Agent string.
  String get resolvedUserAgent {
    switch (userAgent) {
      case 'Desktop Firefox':
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0';
      case 'Safari iOS':
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
      case 'Googlebot':
        return 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
      case 'Android Chrome':
      default:
        return 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
    }
  }

  static MaxResolution _parseMaxResolution(String? raw) {
    if (raw == 'noLimit' || raw == 'res4k') return MaxResolution.res4k;
    if (raw == 'res1440p' || raw == 'res1080p') return MaxResolution.res1080p;
    if (raw == 'res720p') return MaxResolution.res720p;
    if (raw == 'res480p') return MaxResolution.res480p;
    return MaxResolution.res1080p;
  }

  AppSettings copyWith({
    String? downloadDirectory,
    bool? cookiesActive,
    int? cookiesCount,
    String? cookiesHeader,
    int? maxConcurrentDownloads,
    bool? wifiOnly,
    bool? autoRetry,
    bool? autoRemuxToMp4,
    AudioCodec? audioCodec,
    MaxResolution? maxResolution,
    bool? organizeByPlatform,
    String? ytDlpVersion,
    String? ffmpegVersion,
    String? audioBitrate,
    String? videoContainer,
    String? userAgent,
    int? connectionTimeout,
    bool? notifyOnComplete,
    bool? isDarkMode,
  }) {
    return AppSettings(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      cookiesActive: cookiesActive ?? this.cookiesActive,
      cookiesCount: cookiesCount ?? this.cookiesCount,
      cookiesHeader: cookiesHeader ?? this.cookiesHeader,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoRetry: autoRetry ?? this.autoRetry,
      autoRemuxToMp4: autoRemuxToMp4 ?? this.autoRemuxToMp4,
      audioCodec: audioCodec ?? this.audioCodec,
      maxResolution: maxResolution ?? this.maxResolution,
      organizeByPlatform: organizeByPlatform ?? this.organizeByPlatform,
      ytDlpVersion: ytDlpVersion ?? this.ytDlpVersion,
      ffmpegVersion: ffmpegVersion ?? this.ffmpegVersion,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      videoContainer: videoContainer ?? this.videoContainer,
      userAgent: userAgent ?? this.userAgent,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      notifyOnComplete: notifyOnComplete ?? this.notifyOnComplete,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'downloadDirectory': downloadDirectory,
    'cookiesActive': cookiesActive,
    'cookiesCount': cookiesCount,
    'cookiesHeader': cookiesHeader,
    'maxConcurrentDownloads': maxConcurrentDownloads,
    'wifiOnly': wifiOnly,
    'autoRetry': autoRetry,
    'autoRemuxToMp4': autoRemuxToMp4,
    'audioCodec': audioCodec.name,
    'maxResolution': maxResolution.name,
    'organizeByPlatform': organizeByPlatform,
    'ytDlpVersion': ytDlpVersion,
    'ffmpegVersion': ffmpegVersion,
    'audioBitrate': audioBitrate,
    'videoContainer': videoContainer,
    'userAgent': userAgent,
    'connectionTimeout': connectionTimeout,
    'notifyOnComplete': notifyOnComplete,
    'isDarkMode': isDarkMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      downloadDirectory: normalizeDirectoryPath(
        json['downloadDirectory'] as String? ?? "/storage/emulated/0/Download/AllDown",
      ),
      cookiesActive: json['cookiesActive'] as bool? ?? false,
      cookiesCount: json['cookiesCount'] as int? ?? 0,
      cookiesHeader: json['cookiesHeader'] as String? ?? "",
      maxConcurrentDownloads: json['maxConcurrentDownloads'] as int? ?? 3,
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      autoRetry: json['autoRetry'] as bool? ?? true,
      autoRemuxToMp4: json['autoRemuxToMp4'] as bool? ?? true,
      audioCodec: AudioCodec.values.firstWhere(
        (e) => e.name == json['audioCodec'],
        orElse: () => AudioCodec.aac,
      ),
      maxResolution: _parseMaxResolution(json['maxResolution'] as String?),
      organizeByPlatform: json['organizeByPlatform'] as bool? ?? false,
      ytDlpVersion: json['ytDlpVersion'] as String? ?? "v2025.01.26-nightly",
      ffmpegVersion: json['ffmpegVersion'] as String? ?? "v7.1 Android-ARM64",
      audioBitrate: json['audioBitrate'] as String? ?? "320 kbps",
      videoContainer: json['videoContainer'] as String? ?? "MP4",
      userAgent: json['userAgent'] as String? ?? "Android Chrome",
      connectionTimeout: json['connectionTimeout'] as int? ?? 15,
      notifyOnComplete: json['notifyOnComplete'] as bool? ?? true,
      isDarkMode: json['isDarkMode'] as bool? ?? true,
    );
  }
}

