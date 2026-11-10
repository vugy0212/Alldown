enum DownloadStatus {
  active,
  queued,
  converting,
  completed,
  paused,
  failed,
}

class DownloadTask {
  final String id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String duration;
  final String format;
  final String resolution;
  final String sizeFormatted;
  final double progress; // 0.0 to 1.0
  final String speed; // e.g. "14.6 MB/s"
  final String eta; // e.g. "00:24 remaining"
  final String downloadedBytes;
  final String totalBytes;
  final DownloadStatus status;
  final bool isAudio;
  final String platform; // "YouTube", "TikTok", "Instagram", etc.
  final String subtitleInfo;
  final int priority; // 0 = normal, 1 = boosted

  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.duration,
    required this.format,
    required this.resolution,
    required this.sizeFormatted,
    this.progress = 0.0,
    this.speed = "0.0 MB/s",
    this.eta = "--:--",
    this.downloadedBytes = "0 MB",
    this.totalBytes = "0 MB",
    this.status = DownloadStatus.queued,
    this.isAudio = false,
    this.platform = "YouTube",
    this.subtitleInfo = "CC En",
    this.priority = 0,
  });

  DownloadTask copyWith({
    String? id,
    String? title,
    String? url,
    String? thumbnailUrl,
    String? duration,
    String? format,
    String? resolution,
    String? sizeFormatted,
    double? progress,
    String? speed,
    String? eta,
    String? downloadedBytes,
    String? totalBytes,
    DownloadStatus? status,
    bool? isAudio,
    String? platform,
    String? subtitleInfo,
    int? priority,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      sizeFormatted: sizeFormatted ?? this.sizeFormatted,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      isAudio: isAudio ?? this.isAudio,
      platform: platform ?? this.platform,
      subtitleInfo: subtitleInfo ?? this.subtitleInfo,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'format': format,
    'resolution': resolution,
    'sizeFormatted': sizeFormatted,
    'progress': progress,
    'speed': speed,
    'eta': eta,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'status': status.name,
    'isAudio': isAudio,
    'platform': platform,
    'subtitleInfo': subtitleInfo,
    'priority': priority,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      duration: json['duration'] as String,
      format: json['format'] as String,
      resolution: json['resolution'] as String,
      sizeFormatted: json['sizeFormatted'] as String,
      progress: (json['progress'] as num).toDouble(),
      speed: json['speed'] as String? ?? "0.0 MB/s",
      eta: json['eta'] as String? ?? "--:--",
      downloadedBytes: json['downloadedBytes'] as String? ?? "0 MB",
      totalBytes: json['totalBytes'] as String? ?? "0 MB",
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      isAudio: json['isAudio'] as bool? ?? false,
      platform: json['platform'] as String? ?? "YouTube",
      subtitleInfo: json['subtitleInfo'] as String? ?? "CC En",
      priority: json['priority'] as int? ?? 0,
    );
  }
}

