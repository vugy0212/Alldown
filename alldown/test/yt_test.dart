import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('Test youtube_explode_dart metadata and stream manifest', () async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get('dQw4w9WgXcQ');
      // ignore: avoid_print
      print('Title: ${video.title}, Duration: ${video.duration}, Author: ${video.author}');
      final manifest = await yt.videos.streamsClient.getManifest('dQw4w9WgXcQ');
      // ignore: avoid_print
      print('Muxed count: ${manifest.muxed.length}, AudioOnly: ${manifest.audioOnly.length}');
      if (manifest.muxed.isNotEmpty) {
        final best = manifest.muxed.withHighestBitrate();
        // ignore: avoid_print
        print('Best muxed: ${best.qualityLabel}, size: ${best.size.totalMegaBytes.toStringAsFixed(1)} MB');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error: $e');
    } finally {
      yt.close();
    }
  });
}

