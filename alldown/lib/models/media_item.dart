class MediaItem {
  final String id;
  final String title;
  final String channel;
  final String duration;
  final String thumbnailUrl;
  final String localPath;
  final String format; // "MP4", "MP3", "FLAC", "MKV"
  final String resolution; // "1080p FHD", "MP3 320k", "2160p", "Vertical HD"
  final String sizeFormatted;
  final String completedDateFormatted;
  final bool isAudio;
  final bool isFavorite;
  final String platform; // "YouTube", "TikTok", "Instagram", etc.
  final bool isVertical;

  const MediaItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    required this.thumbnailUrl,
    required this.localPath,
    required this.format,
    required this.resolution,
    required this.sizeFormatted,
    required this.completedDateFormatted,
    this.isAudio = false,
    this.isFavorite = false,
    this.platform = "YouTube",
    this.isVertical = false,
  });

  MediaItem copyWith({
    String? id,
    String? title,
    String? channel,
    String? duration,
    String? thumbnailUrl,
    String? localPath,
    String? format,
    String? resolution,
    String? sizeFormatted,
    String? completedDateFormatted,
    bool? isAudio,
    bool? isFavorite,
    String? platform,
    bool? isVertical,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      channel: channel ?? this.channel,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      sizeFormatted: sizeFormatted ?? this.sizeFormatted,
      completedDateFormatted: completedDateFormatted ?? this.completedDateFormatted,
      isAudio: isAudio ?? this.isAudio,
      isFavorite: isFavorite ?? this.isFavorite,
      platform: platform ?? this.platform,
      isVertical: isVertical ?? this.isVertical,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channel': channel,
    'duration': duration,
    'thumbnailUrl': thumbnailUrl,
    'localPath': localPath,
    'format': format,
    'resolution': resolution,
    'sizeFormatted': sizeFormatted,
    'completedDateFormatted': completedDateFormatted,
    'isAudio': isAudio,
    'isFavorite': isFavorite,
    'platform': platform,
    'isVertical': isVertical,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      channel: json['channel'] as String? ?? "Unknown",
      duration: json['duration'] as String? ?? "00:00",
      thumbnailUrl: json['thumbnailUrl'] as String? ?? "",
      localPath: json['localPath'] as String? ?? "",
      format: json['format'] as String? ?? "MP4",
      resolution: json['resolution'] as String? ?? "1080p",
      sizeFormatted: json['sizeFormatted'] as String? ?? "0 MB",
      completedDateFormatted: json['completedDateFormatted'] as String? ?? "Recently",
      isAudio: json['isAudio'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      platform: json['platform'] as String? ?? "YouTube",
      isVertical: json['isVertical'] as bool? ?? false,
    );
  }
}

