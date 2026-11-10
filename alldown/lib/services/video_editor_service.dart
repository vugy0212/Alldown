import 'package:flutter/services.dart';

class VideoEditorService {
  static const MethodChannel _channel = MethodChannel('com.alldown.app/downloader');

  /// High-speed lossless trimming (MediaExtractor + MediaMuxer)
  static Future<bool> trimVideo({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('trimVideo', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hardware-accelerated Video Crop & Trim using Jetpack Media3 Transformer
  /// Supported [cropRatio]: "original", "1:1", "9:16", "16:9", "4:5"
  static Future<bool> cropVideo({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required String cropRatio,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('cropVideo', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
        'cropRatio': cropRatio,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Converts a video segment into an animated GIF (.gif) with optional crop
  static Future<bool> createGif({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required String cropRatio,
    int fps = 10,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('createGif', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
        'cropRatio': cropRatio,
        'fps': fps,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Formats milliseconds into mm:ss display
  static String formatMs(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
