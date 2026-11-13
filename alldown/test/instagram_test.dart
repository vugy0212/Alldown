// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:alldown/services/metadata_fetcher_service.dart';

void main() {
  test('Instagram URL detection and extraction', () async {
    const url = 'https://www.instagram.com/reel/Chunk8-jurw/';
    expect(MetadataFetcherService.isInstagramUrl(url), isTrue);
    expect(MetadataFetcherService.extractInstagramShortcode(url), 'Chunk8-jurw');

    final res = await MetadataFetcherService.resolveInstagramStream(url);
    print('IG Resolved stream: ${res?.streamUrl}');
    print('IG Title: ${res?.title}');
    print('IG Author: ${res?.author}');
    print('IG Resolution: ${res?.resolutionLabel}');
    expect(res, isNotNull);
    expect(res!.streamUrl, contains('fbcdn.net'));
  });
}

