enum AudioCodec {
  mp3,
  aac,
  opus,
}

enum MaxResolution {
  noLimit,
  res4k,
  res1440p,
  res1080p,
  res720p,
}

class AppSettings {
  final String downloadDirectory;
  final bool cookiesActive;
  final int cookiesCount;
  final int maxConcurrentDownloads;
  final bool wifiOnly;
  final bool autoRetry;
  final bool autoRemuxToMp4;
  final AudioCodec audioCodec;
  final MaxResolution maxResolution;
  final bool sponsorBlockEnabled;
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
    this.maxConcurrentDownloads = 3,
    this.wifiOnly = true,
    this.autoRetry = true,
    this.autoRemuxToMp4 = true,
    this.audioCodec = AudioCodec.mp3,
    this.maxResolution = MaxResolution.res1080p,
    this.sponsorBlockEnabled = true,
    this.ytDlpVersion = "v2025.01.26-nightly",
    this.ffmpegVersion = "v7.1 Android-ARM64",
    this.audioBitrate = "320 kbps",
    this.videoContainer = "MP4",
    this.userAgent = "Android Chrome",
    this.connectionTimeout = 15,
    this.notifyOnComplete = true,
    this.isDarkMode = true,
  });

  AppSettings copyWith({
    String? downloadDirectory,
    bool? cookiesActive,
    int? cookiesCount,
    int? maxConcurrentDownloads,
    bool? wifiOnly,
    bool? autoRetry,
    bool? autoRemuxToMp4,
    AudioCodec? audioCodec,
    MaxResolution? maxResolution,
    bool? sponsorBlockEnabled,
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
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoRetry: autoRetry ?? this.autoRetry,
      autoRemuxToMp4: autoRemuxToMp4 ?? this.autoRemuxToMp4,
      audioCodec: audioCodec ?? this.audioCodec,
      maxResolution: maxResolution ?? this.maxResolution,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
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
    'maxConcurrentDownloads': maxConcurrentDownloads,
    'wifiOnly': wifiOnly,
    'autoRetry': autoRetry,
    'autoRemuxToMp4': autoRemuxToMp4,
    'audioCodec': audioCodec.name,
    'maxResolution': maxResolution.name,
    'sponsorBlockEnabled': sponsorBlockEnabled,
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
      downloadDirectory: json['downloadDirectory'] as String? ?? "/storage/emulated/0/Download/AllDown",
      cookiesActive: json['cookiesActive'] as bool? ?? true,
      cookiesCount: json['cookiesCount'] as int? ?? 42,
      maxConcurrentDownloads: json['maxConcurrentDownloads'] as int? ?? 3,
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      autoRetry: json['autoRetry'] as bool? ?? true,
      autoRemuxToMp4: json['autoRemuxToMp4'] as bool? ?? true,
      audioCodec: AudioCodec.values.firstWhere(
        (e) => e.name == json['audioCodec'],
        orElse: () => AudioCodec.mp3,
      ),
      maxResolution: MaxResolution.values.firstWhere(
        (e) => e.name == json['maxResolution'],
        orElse: () => MaxResolution.res1080p,
      ),
      sponsorBlockEnabled: json['sponsorBlockEnabled'] as bool? ?? true,
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

