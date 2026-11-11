import 'package:flutter/services.dart';

class VideoEditorService {
  static const MethodChannel _channel = MethodChannel('com.alldown.app/downloader');

  /// High-speed lossless or re-encoded video trimming
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

  /// Hardware-accelerated Video Crop, Zoom, Pan & Trim using Jetpack Media3 Transformer
  /// Supported [cropRatio]: "original", "1:1", "9:16", "16:9", "4:5"
  /// [zoom]: 1.0 to 3.0+
  /// [panX], [panY]: -1.0 to 1.0 (0.0 is center)
  static Future<bool> cropVideo({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required String cropRatio,
    double zoom = 1.0,
    double panX = 0.0,
    double panY = 0.0,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('cropVideo', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
        'cropRatio': cropRatio,
        'zoom': zoom,
        'panX': panX,
        'panY': panY,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Converts a video segment into an animated GIF (.gif) with optional crop, zoom & pan
  static Future<bool> createGif({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required String cropRatio,
    double zoom = 1.0,
    double panX = 0.0,
    double panY = 0.0,
    int fps = 10,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('createGif', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
        'cropRatio': cropRatio,
        'zoom': zoom,
        'panX': panX,
        'panY': panY,
        'fps': fps,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Extracts and trims pure audio from video with zero video overhead using Media3 Transformer
  static Future<bool> extractAudio({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('extractAudio', {
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

  /// Registers newly saved media with Android MediaStore so it appears instantly in the Samsung Gallery
  static Future<bool> scanMediaFile({
    required String path,
    required String mimeType,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('scanMediaFile', {
        'path': path,
        'mimeType': mimeType,
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
