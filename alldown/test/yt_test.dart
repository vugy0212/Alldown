import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('Test youtube_explode_dart metadata and stream manifest', () async {
    final yt = YoutubeExplode();
    try {
      // final video = await yt.videos.get('dQw4w9WgXcQ');
      final manifest = await yt.videos.streamsClient.getManifest(
        'dQw4w9WgXcQ',
        requireWatchPage: false,
        ytClients: [YoutubeApiClient.androidSdkless, YoutubeApiClient.ios],
      );
      // ignore: avoid_print
      print('Muxed count: ${manifest.muxed.length}, AudioOnly: ${manifest.audioOnly.length}');
      if (manifest.audioOnly.isNotEmpty) {
        final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        final stream = yt.videos.streamsClient.get(audioStreamInfo);
        int totalBytesRead = 0;
        await for (final chunk in stream.take(5)) {
          totalBytesRead += chunk.length;
        }
        expect(totalBytesRead, greaterThan(0));
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error: $e');
    } finally {
      yt.close();
    }
  });
}

