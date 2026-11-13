import 'package:flutter_test/flutter_test.dart';
import 'package:alldown/models/local_playlist.dart';
import 'package:alldown/models/media_item.dart';
import 'package:alldown/providers/player_provider.dart';

void main() {
  group('LocalPlaylist & PlayerState Playlist Tests', () {
    final track1 = MediaItem(
      id: 't1',
      title: 'Song One',
      channel: 'Artist A',
      duration: '03:45',
      thumbnailUrl: 'https://example.com/1.jpg',
      localPath: 'C:/fake/path1.m4a',
      format: 'M4A',
      resolution: 'Audio 320 kbps',
      sizeFormatted: '8.5 MB',
      completedDateFormatted: 'Just Now',
      isAudio: true,
    );

    final track2 = MediaItem(
      id: 't2',
      title: 'Song Two',
      channel: 'Artist B',
      duration: '04:12',
      thumbnailUrl: 'https://example.com/2.jpg',
      localPath: 'C:/fake/path2.m4a',
      format: 'M4A',
      resolution: 'Audio 320 kbps',
      sizeFormatted: '9.8 MB',
      completedDateFormatted: 'Just Now',
      isAudio: true,
    );

    final track3 = MediaItem(
      id: 't3',
      title: 'Song Three',
      channel: 'Artist C',
      duration: '02:50',
      thumbnailUrl: 'https://example.com/3.jpg',
      localPath: 'C:/fake/path3.m4a',
      format: 'M4A',
      resolution: 'Audio 320 kbps',
      sizeFormatted: '6.4 MB',
      completedDateFormatted: 'Just Now',
      isAudio: true,
    );

    test('LocalPlaylist JSON serialization round-trip', () {
      final now = DateTime.now();
      final pl = LocalPlaylist(
        id: 'pl_100',
        title: 'My Rock Hits',
        createdAt: now,
        trackIds: ['t1', 't2', 't3'],
      );

      final json = pl.toJson();
      expect(json['id'], 'pl_100');
      expect(json['title'], 'My Rock Hits');
      expect(json['trackIds'], ['t1', 't2', 't3']);

      final restored = LocalPlaylist.fromJson(json);
      expect(restored.id, pl.id);
      expect(restored.title, pl.title);
      expect(restored.trackIds.length, 3);
      expect(restored.trackIds[1], 't2');
    });

    test('PlayerState playlist navigation logic (hasNext, hasPrevious, repeat, shuffle)', () {
      final state = PlayerState(
        playlist: [track1, track2, track3],
        currentIndex: 0,
        currentItem: track1,
        repeatMode: AudioRepeatMode.off,
      );

      expect(state.hasPlaylist, isTrue);
      expect(state.playlistCount, 3);
      expect(state.hasPrevious, isFalse);
      expect(state.hasNext, isTrue);

      final middleState = state.copyWith(currentIndex: 1, currentItem: track2);
      expect(middleState.hasPrevious, isTrue);
      expect(middleState.hasNext, isTrue);

      final endState = state.copyWith(currentIndex: 2, currentItem: track3);
      expect(endState.hasPrevious, isTrue);
      expect(endState.hasNext, isFalse);

      final repeatAllState = endState.copyWith(repeatMode: AudioRepeatMode.all);
      expect(repeatAllState.hasNext, isTrue);

      final repeatOneState = endState.copyWith(repeatMode: AudioRepeatMode.one);
      expect(repeatOneState.hasNext, isTrue);
    });
  });
}

