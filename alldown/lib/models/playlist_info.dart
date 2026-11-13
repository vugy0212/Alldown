import 'download_options.dart';

class PlaylistItem {
  final String id;
  final String title;
  final String author;
  final String duration;
  final int durationSeconds;
  final String thumbnailUrl;
  final bool isSelected;

  const PlaylistItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.durationSeconds = 210,
    required this.thumbnailUrl,
    this.isSelected = true,
  });

  PlaylistItem copyWith({
    String? id,
    String? title,
    String? author,
    String? duration,
    int? durationSeconds,
    String? thumbnailUrl,
    bool? isSelected,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  String estimateSize([AudioQuality audioQuality = AudioQuality.kbps320]) {
    final mins = (durationSeconds / 60.0).clamp(0.5, 300.0);
    double rate = 2.4; // 320 kbps M4A (~2.4 MB/min)
    switch (audioQuality) {
      case AudioQuality.kbps320:
        rate = 2.4;
        break;
      case AudioQuality.kbps256:
        rate = 1.9;
        break;
      case AudioQuality.kbps192:
        rate = 1.4;
        break;
      case AudioQuality.kbps128:
        rate = 1.0;
        break;
    }
    final mb = (mins * rate).clamp(0.8, 500.0);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class PlaylistInfo {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int totalTracks;
  final List<PlaylistItem> items;

  const PlaylistInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.totalTracks,
    required this.items,
  });

  int get selectedCount => items.where((i) => i.isSelected).length;

  int get totalDurationSeconds {
    return items
        .where((i) => i.isSelected)
        .fold(0, (sum, i) => sum + i.durationSeconds);
  }

  String get totalDurationFormatted {
    final totalSec = totalDurationSeconds;
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes > 0 ? minutes : 1} min';
  }

  String estimateTotalAudioSize([AudioQuality audioQuality = AudioQuality.kbps320]) {
    double totalMb = 0;
    for (final item in items.where((i) => i.isSelected)) {
      final mins = (item.durationSeconds / 60.0).clamp(0.5, 300.0);
      double rate = 2.4;
      switch (audioQuality) {
        case AudioQuality.kbps320:
          rate = 2.4;
          break;
        case AudioQuality.kbps256:
          rate = 1.9;
          break;
        case AudioQuality.kbps192:
          rate = 1.4;
          break;
        case AudioQuality.kbps128:
          rate = 1.0;
          break;
      }
      totalMb += (mins * rate);
    }
    if (totalMb >= 1024) {
      return '${(totalMb / 1024).toStringAsFixed(1)} GB';
    }
    return '${totalMb.toStringAsFixed(0)} MB';
  }

  PlaylistInfo copyWith({
    String? id,
    String? title,
    String? author,
    String? thumbnailUrl,
    int? totalTracks,
    List<PlaylistItem>? items,
  }) {
    return PlaylistInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      totalTracks: totalTracks ?? this.totalTracks,
      items: items ?? this.items,
    );
  }
}

