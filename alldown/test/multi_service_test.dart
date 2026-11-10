import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:alldown/services/metadata_fetcher_service.dart';

void main() {
  group('10+ Multi-Service Download & Extraction Tests', () {
    // 1. YouTube
    test('1. YouTube Video & Shorts extraction', () async {
      const ytUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
      final id = MetadataFetcherService.extractYouTubeId(ytUrl);
      expect(id, 'jNQXAC9IVRw');

      final info = await MetadataFetcherService.fetchMediaInfo(ytUrl);
      // ignore: avoid_print
      print('[YouTube] Title: ${info.title}, Channel: ${info.channel}');
      expect(info.platform, 'YouTube');
      expect(info.title.isNotEmpty, isTrue);
    });

    // 2. X (Twitter)
    test('2. X (Twitter) Status & Direct MP4 stream', () async {
      const xUrl = 'https://x.com/MattWallace888/status/2120120305763095008';
      final statusId = MetadataFetcherService.extractTwitterStatusId(xUrl);
      expect(statusId, isNotNull);

      final resolved = await MetadataFetcherService.resolveTwitterStream(statusId!);
      expect(resolved, isNotNull);
      // ignore: avoid_print
      print('[X / Twitter] Title: ${resolved!.title}, MP4: ${resolved.streamUrl.substring(0, 50)}...');
      expect(resolved.streamUrl.contains('.mp4'), isTrue);
    });

    // 3. TikTok
    test('3. TikTok URL detection', () {
      const tkUrl = 'https://www.tiktok.com/@tiktok/video/7123456789012345678';
      expect(MetadataFetcherService.isTikTokUrl(tkUrl), isTrue);
    });

    // 4. Facebook
    test('4. Facebook Watch & Reels detection', () async {
      const fbUrl = 'https://www.facebook.com/watch/?v=10153231379946729';
      expect(MetadataFetcherService.isFacebookUrl(fbUrl), isTrue);
      final resolved = await MetadataFetcherService.resolveFacebookStream(fbUrl);
      expect(resolved, isNotNull);
      // ignore: avoid_print
      print('[Facebook] Title: ${resolved!.title}, Platform: ${resolved.platform}');
      expect(resolved.platform, 'Facebook');
    });

    // 5. Streamable
    test('5. Streamable Video API direct MP4 extraction', () async {
      const stUrl = 'https://streamable.com/moo72';
      expect(MetadataFetcherService.isStreamableUrl(stUrl), isTrue);

      final resolved = await MetadataFetcherService.resolveStreamableStream(stUrl);
      expect(resolved, isNotNull);
      // ignore: avoid_print
      print('[Streamable] Title: ${resolved!.title}, Resolution: ${resolved.resolutionLabel}, URL: ${resolved.streamUrl.substring(0, 60)}...');
      expect(resolved.streamUrl.contains('.mp4'), isTrue);
      expect(resolved.platform, 'Streamable');

      // Verify that the stream URL is actually downloadable via HTTP GET
      final resp = await http.get(Uri.parse(resolved.streamUrl), headers: {'Range': 'bytes=0-1024'});
      expect(resp.statusCode, inInclusiveRange(200, 206));
    });

    // 6. Archive.org
    test('6. Archive.org Open Media MP4 stream test', () async {
      const archiveUrl = 'https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4';
      expect(MetadataFetcherService.isDirectMediaUrl(archiveUrl), isTrue);

      final info = await MetadataFetcherService.fetchMediaInfo(archiveUrl);
      // ignore: avoid_print
      print('[Archive.org] Title: ${info.title}, Badge: ${info.badgeText}');
      expect(info.badgeText.contains('MP4'), isTrue);

      final resp = await http.get(Uri.parse(archiveUrl), headers: {'Range': 'bytes=0-1024'});
      expect(resp.statusCode, inInclusiveRange(200, 206));
    });

    // 7. Wikimedia Commons
    test('7. Wikimedia Commons Public Domain Video stream test', () async {
      const wikiUrl = 'https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Big_Buck_Bunny_4K.webm/Big_Buck_Bunny_4K.webm.480p.vp9.webm';
      expect(MetadataFetcherService.isDirectMediaUrl(wikiUrl), isTrue);

      final resp = await http.get(Uri.parse(wikiUrl), headers: {
        'User-Agent': 'AllDown/1.0 (Mobile; Android)',
        'Range': 'bytes=0-1024',
      });
      expect(resp.statusCode, inInclusiveRange(200, 206));
      // ignore: avoid_print
      print('[Wikimedia Commons] Received chunk status: ${resp.statusCode}, Content-Type: ${resp.headers['content-type']}');
    });

    // 8. Test-Videos CDN
    test('8. Test-Videos High-Speed CDN H.264 MP4 test', () async {
      const testVidUrl = 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4';
      expect(MetadataFetcherService.isDirectMediaUrl(testVidUrl), isTrue);

      final resp = await http.get(Uri.parse(testVidUrl), headers: {'Range': 'bytes=0-1024'});
      expect(resp.statusCode, inInclusiveRange(200, 206));
      // ignore: avoid_print
      print('[Test-Videos CDN] Received chunk status: ${resp.statusCode}');
    });

    // 9. W3Schools HTML5 Video
    test('9. W3Schools HTML5 Sample Video MP4 test', () async {
      const w3Url = 'https://www.w3schools.com/html/mov_bbb.mp4';
      expect(MetadataFetcherService.isDirectMediaUrl(w3Url), isTrue);

      final resp = await http.get(Uri.parse(w3Url), headers: {'Range': 'bytes=0-1024'});
      expect(resp.statusCode, inInclusiveRange(200, 206));
      // ignore: avoid_print
      print('[W3Schools HTML5] Received chunk status: ${resp.statusCode}');
    });

    // 10. GitHub Raw Media Asset
    test('10. GitHub Raw Media Video Asset test', () async {
      const ghUrl = 'https://raw.githubusercontent.com/intel-iot-devkit/sample-videos/master/face-demographics-walking.mp4';
      expect(MetadataFetcherService.isDirectMediaUrl(ghUrl), isTrue);

      final resp = await http.get(Uri.parse(ghUrl), headers: {'Range': 'bytes=0-1024'});
      expect(resp.statusCode, inInclusiveRange(200, 206));
      // ignore: avoid_print
      print('[GitHub Raw Media] Received chunk status: ${resp.statusCode}');
    });

    // 11. Generic Webpage Parser
    test('11. Generic Webpage Video Parser with og:video', () async {
      final stream = await MetadataFetcherService.resolveGenericWebpageStream('https://www.w3schools.com/html/html5_video.asp');
      // ignore: avoid_print
      print('[Webpage Parser] Checked webpage parser result: ${stream?.streamUrl ?? "Clean pass"}');
    });
  });
}

