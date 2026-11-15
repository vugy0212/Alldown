import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class ExternalFolder {
  final String uri;
  final String name;
  final int trackCount;
  final DateTime addedAt;

  const ExternalFolder({
    required this.uri,
    required this.name,
    required this.trackCount,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'uri': uri,
        'name': name,
        'trackCount': trackCount,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ExternalFolder.fromMap(Map<String, dynamic> map) {
    return ExternalFolder(
      uri: map['uri'] as String? ?? '',
      name: map['name'] as String? ?? 'Glazba',
      trackCount: (map['trackCount'] as num?)?.toInt() ?? 0,
      addedAt: map['addedAt'] != null
          ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ExternalFolder.fromJson(Map<String, dynamic> json) =>
      ExternalFolder.fromMap(json);

  ExternalFolder copyWith({
    String? uri,
    String? name,
    int? trackCount,
    DateTime? addedAt,
  }) {
    return ExternalFolder(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      trackCount: trackCount ?? this.trackCount,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExternalFolder && uri == other.uri;
  }

  @override
  int get hashCode => uri.hashCode;
}

class ExternalMusicService {
  static const MethodChannel _channel = MethodChannel('com.alldown.app/downloader');
  static const String _prefKey = 'external_music_folders_v1';

  static final ExternalMusicService _instance = ExternalMusicService._internal();
  factory ExternalMusicService() => _instance;
  ExternalMusicService._internal();

  /// Prompts user to select a folder via Android SAF and saves it.
  Future<ExternalFolder?> pickAndAddFolder() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickExternalFolder');
      if (res == null) return null;

      final uri = res['uri'] as String?;
      final name = res['name'] as String? ?? 'Glazba';
      if (uri == null || uri.isEmpty) return null;

      // Scan initial track count
      final tracks = await scanFolder(uri);
      final folder = ExternalFolder(
        uri: uri,
        name: name,
        trackCount: tracks.length,
        addedAt: DateTime.now(),
      );

      final current = await getSavedFolders();
      // Remove any duplicate with the same URI
      current.removeWhere((f) => f.uri == uri);
      current.insert(0, folder);
      await _saveFolders(current);

      return folder;
    } catch (e) {
      return null;
    }
  }

  /// Retrieves list of saved external music folders from SharedPreferences.
  Future<List<ExternalFolder>> getSavedFolders() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ExternalFolder.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveFolders(List<ExternalFolder> folders) async {
    final sp = await SharedPreferences.getInstance();
    final data = jsonEncode(folders.map((f) => f.toMap()).toList());
    await sp.setString(_prefKey, data);
  }

  /// Removes folder from saved list and releases Android persistable URI permission.
  Future<void> removeFolder(String uri) async {
    try {
      final folders = await getSavedFolders();
      folders.removeWhere((f) => f.uri == uri);
      await _saveFolders(folders);

      await _channel.invokeMethod('releaseExternalFolder', {'uri': uri});
    } catch (_) {}
  }

  /// Scans audio files inside a specific tree URI.
  Future<List<MediaItem>> scanFolder(String treeUri) async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'scanExternalFolder',
        {'uri': treeUri},
      );
      if (rawList == null || rawList.isEmpty) return [];

      final items = <MediaItem>[];
      for (final raw in rawList) {
        if (raw is Map) {
          items.add(_mapNativeToMediaItem(raw));
        }
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Scans all saved folders and aggregates unique audio items.
  Future<List<MediaItem>> scanAllFolders() async {
    final folders = await getSavedFolders();
    final allTracks = <MediaItem>[];
    final seenPaths = <String>{};

    for (final folder in folders) {
      final tracks = await scanFolder(folder.uri);
      for (final track in tracks) {
        if (!seenPaths.contains(track.localPath)) {
          seenPaths.add(track.localPath);
          allTracks.add(track);
        }
      }
    }
    return allTracks;
  }

  MediaItem _mapNativeToMediaItem(Map<dynamic, dynamic> raw) {
    final id = raw['id']?.toString() ?? 'ext_${DateTime.now().microsecondsSinceEpoch}';
    final title = raw['title']?.toString() ?? 'Nepoznato';
    final artist = raw['artist']?.toString() ?? '';
    final channel = artist.isNotEmpty ? artist : 'Lokalno';
    final durationMs = (raw['durationMs'] as num?)?.toInt() ?? 0;
    final uri = raw['uri']?.toString() ?? '';
    final sizeBytes = (raw['sizeBytes'] as num?)?.toInt() ?? 0;
    final format = raw['format']?.toString() ?? 'AUDIO';

    return MediaItem(
      id: id,
      title: title,
      channel: channel,
      duration: _formatDuration(durationMs),
      thumbnailUrl: '',
      localPath: uri,
      format: format,
      resolution: 'Lokalni Audio',
      sizeFormatted: _formatBytes(sizeBytes),
      completedDateFormatted: 'Lokalno',
      isAudio: true,
      platform: 'Local',
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final totalSec = ms ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    final hr = min ~/ 60;
    final remMin = min % 60;

    if (hr > 0) {
      return '$hr:${remMin.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
