import 'package:flutter_test/flutter_test.dart';
import 'package:alldown/models/playlist_info.dart';
import 'package:alldown/services/metadata_fetcher_service.dart';

void main() {
  group('Playlist extraction & parsing tests', () {
    test('extractPlaylistId detects various playlist URLs correctly', () {
      expect(
        MetadataFetcherService.extractPlaylistId('https://www.youtube.com/playlist?list=PLWwAypAcFRgKFlxtLbn_u14zddtDJj3mk'),
        equals('PLWwAypAcFRgKFlxtLbn_u14zddtDJj3mk'),
      );
      expect(
        MetadataFetcherService.extractPlaylistId('https://www.youtube.com/watch?v=u4FG-iB8NFc&list=PLWwAypAcFRgKFlxtLbn_u14zddtDJj3mk&index=1'),
        equals('PLWwAypAcFRgKFlxtLbn_u14zddtDJj3mk'),
      );
      expect(
        MetadataFetcherService.extractPlaylistId('https://m.youtube.com/playlist?list=OLAK5uy_k123456789'),
        equals('OLAK5uy_k123456789'),
      );
      expect(
        MetadataFetcherService.extractPlaylistId('https://www.youtube.com/watch?v=u4FG-iB8NFc&list=WL'),
        isNull,
      );
      expect(
        MetadataFetcherService.extractPlaylistId('https://www.youtube.com/watch?v=u4FG-iB8NFc'),
        isNull,
      );
      expect(
        MetadataFetcherService.extractPlaylistId('not a url'),
        isNull,
      );
    });

    test('PlaylistInfo and PlaylistItem calculations work properly', () {
      const item1 = PlaylistItem(
        id: 'vid1',
        title: 'Song 1',
        author: 'Artist 1',
        duration: '3:30',
        durationSeconds: 210,
        thumbnailUrl: 'https://thumb1',
        isSelected: true,
      );
      const item2 = PlaylistItem(
        id: 'vid2',
        title: 'Song 2',
        author: 'Artist 2',
        duration: '4:00',
        durationSeconds: 240,
        thumbnailUrl: 'https://thumb2',
        isSelected: false,
      );

      final playlist = PlaylistInfo(
        id: 'test_pl',
        title: 'Test Playlist',
        author: 'Channel',
        thumbnailUrl: 'https://thumb',
        totalTracks: 2,
        items: [item1, item2],
      );

      expect(playlist.selectedCount, equals(1));
      expect(playlist.totalDurationSeconds, equals(210));
      expect(playlist.estimateTotalAudioSize().contains('MB'), isTrue);

      final updatedItem2 = item2.copyWith(isSelected: true);
      final updatedPlaylist = playlist.copyWith(items: [item1, updatedItem2]);
      expect(updatedPlaylist.selectedCount, equals(2));
      expect(updatedPlaylist.totalDurationSeconds, equals(450));
    });

    test('Live fetchPlaylistInfo returns real track metadata', () async {
      const playlistId = 'PLWwAypAcFRgKFlxtLbn_u14zddtDJj3mk';
      final playlist = await MetadataFetcherService.fetchPlaylistInfo(playlistId);

      expect(playlist, isNotNull);
      expect(playlist!.title.isNotEmpty, isTrue);
      expect(playlist.items.isNotEmpty, isTrue);
      expect(playlist.items.first.id.isNotEmpty, isTrue);
      expect(playlist.items.first.title.isNotEmpty, isTrue);
      expect(playlist.items.first.duration.isNotEmpty, isTrue);
    });
  });
}
