import 'package:flutter_test/flutter_test.dart';
import 'package:alldown/services/metadata_fetcher_service.dart';

void main() {
  test('extract YouTube ID from different formats', () {
    expect(
      MetadataFetcherService.extractYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      MetadataFetcherService.extractYouTubeId('https://youtu.be/dQw4w9WgXcQ?si=7vB3y'),
      'dQw4w9WgXcQ',
    );
  });

  test('extract X (Twitter) status ID and resolve 480p MP4 stream', () async {
    const xUrl = 'https://x.com/MattWallace888/status/2120120305763095008?a=gF-TAk0T9MEkYNcqBys&s=19';
    final statusId = MetadataFetcherService.extractTwitterStatusId(xUrl);
    expect(statusId, '2120120305763095008');

    final info = await MetadataFetcherService.fetchMediaInfo(xUrl);
    // ignore: avoid_print
    print('X Title: ${info.title}, Channel: ${info.channel}, Thumb: ${info.thumbnailUrl}');
    expect(info.platform, 'X (Twitter)');

    final resolved480 = await MetadataFetcherService.resolveTwitterStream(
      statusId!,
      preferredResolution: '480p SD',
    );
    expect(resolved480, isNotNull);
    // ignore: avoid_print
    print('Resolved 480p stream URL: ${resolved480!.streamUrl}');
    expect(resolved480.streamUrl.contains('video.twimg.com'), isTrue);
    expect(resolved480.streamUrl.contains('.mp4'), isTrue);
    expect(resolved480.resolutionLabel, '480p SD');
  });

  test('extract Facebook video and resolve direct MP4 stream', () async {
    const fbUrl = 'https://www.facebook.com/watch/?v=10153231379946729';
    expect(MetadataFetcherService.isFacebookUrl(fbUrl), isTrue);

    final resolved = await MetadataFetcherService.resolveFacebookStream(fbUrl);
    expect(resolved, isNotNull);
    // ignore: avoid_print
    print('FB Title: ${resolved!.title}, Thumb: ${resolved.thumbnailUrl}');
    // ignore: avoid_print
    print('FB Stream URL: ${resolved.streamUrl.substring(0, 80)}...');
    expect(resolved.streamUrl.contains('fbcdn.net'), isTrue);
    expect(resolved.streamUrl.contains('.mp4'), isTrue);
    expect(resolved.platform, 'Facebook');
  });
}
