enum TargetFormat {
  videoMp4,
  audioMp3,
  customRaw,
}

enum VideoQuality {
  res4k,
  res1080p,
  res720p,
  res480p,
}

enum AudioQuality {
  kbps320,
  kbps256,
  kbps192,
  kbps128,
}

class DownloadOptions {
  final TargetFormat format;
  final VideoQuality quality;
  final AudioQuality audioQuality;
  final bool createSubfolder;
  final bool embedSubtitles;
  final bool saveMetadata;
  final List<String> subtitleLanguages;
  final String customYtDlpArgs;

  const DownloadOptions({
    this.format = TargetFormat.videoMp4,
    this.quality = VideoQuality.res1080p,
    this.audioQuality = AudioQuality.kbps320,
    this.createSubfolder = true,
    this.embedSubtitles = true,
    this.saveMetadata = true,
    this.subtitleLanguages = const ['hr', 'sr', 'bs', 'en'],
    this.customYtDlpArgs = '',
  });

  DownloadOptions copyWith({
    TargetFormat? format,
    VideoQuality? quality,
    AudioQuality? audioQuality,
    bool? createSubfolder,
    bool? embedSubtitles,
    bool? saveMetadata,
    List<String>? subtitleLanguages,
    String? customYtDlpArgs,
  }) {
    return DownloadOptions(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      audioQuality: audioQuality ?? this.audioQuality,
      createSubfolder: createSubfolder ?? this.createSubfolder,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      saveMetadata: saveMetadata ?? this.saveMetadata,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      customYtDlpArgs: customYtDlpArgs ?? this.customYtDlpArgs,
    );
  }
}

