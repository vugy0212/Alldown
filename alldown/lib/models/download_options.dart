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

class DownloadOptions {
  final TargetFormat format;
  final VideoQuality quality;
  final bool createSubfolder;
  final bool embedSubtitles;
  final bool saveMetadata;
  final List<String> subtitleLanguages;
  final String customYtDlpArgs;

  const DownloadOptions({
    this.format = TargetFormat.videoMp4,
    this.quality = VideoQuality.res1080p,
    this.createSubfolder = true,
    this.embedSubtitles = true,
    this.saveMetadata = true,
    this.subtitleLanguages = const ['hr', 'sr', 'bs', 'en'],
    this.customYtDlpArgs = '',
  });

  DownloadOptions copyWith({
    TargetFormat? format,
    VideoQuality? quality,
    bool? createSubfolder,
    bool? embedSubtitles,
    bool? saveMetadata,
    List<String>? subtitleLanguages,
    String? customYtDlpArgs,
  }) {
    return DownloadOptions(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      createSubfolder: createSubfolder ?? this.createSubfolder,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      saveMetadata: saveMetadata ?? this.saveMetadata,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      customYtDlpArgs: customYtDlpArgs ?? this.customYtDlpArgs,
    );
  }
}

