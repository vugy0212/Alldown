import 'dart:async';
import 'package:flutter/services.dart';

class NativeDownloaderService {
  static final NativeDownloaderService _instance = NativeDownloaderService._internal();
  factory NativeDownloaderService() => _instance;

  static const MethodChannel _channel = MethodChannel('com.alldown.app/downloader');

  final StreamController<String> _sharedUrlController = StreamController<String>.broadcast();
  Stream<String> get onUrlShared => _sharedUrlController.stream;

  // Media Player Callbacks
  void Function()? onMediaPlay;
  void Function()? onMediaPause;
  void Function()? onMediaPlayPause;
  void Function()? onMediaSkipNext;
  void Function()? onMediaSkipPrevious;
  void Function(int posMs)? onMediaSeekTo;
  void Function()? onMediaStop;

  NativeDownloaderService._internal() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onUrlShared':
          final url = call.arguments as String?;
          if (url != null && url.isNotEmpty) {
            _sharedUrlController.add(url);
          }
          break;
        case 'onMediaPlay':
          onMediaPlay?.call();
          break;
        case 'onMediaPause':
          onMediaPause?.call();
          break;
        case 'onMediaPlayPause':
          onMediaPlayPause?.call();
          break;
        case 'onMediaSkipNext':
          onMediaSkipNext?.call();
          break;
        case 'onMediaSkipPrevious':
          onMediaSkipPrevious?.call();
          break;
        case 'onMediaSeekTo':
          final pos = (call.arguments as num?)?.toInt() ?? 0;
          onMediaSeekTo?.call(pos);
          break;
        case 'onMediaStop':
          onMediaStop?.call();
          break;
      }
    });
  }

  /// Checks if the app was launched by tapping "Share" in YouTube/TikTok/etc.
  Future<String?> getInitialSharedUrl() async {
    try {
      final url = await _channel.invokeMethod<String>('getSharedUrl');
      return url;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Starts the Android Foreground Service with ongoing notification
  Future<void> startForegroundService({required String title}) async {
    try {
      await _channel.invokeMethod('startForegroundService', {'title': title});
    } catch (_) {}
  }

  /// Updates ongoing foreground notification with progress and speed
  Future<void> updateNotificationProgress({
    required String title,
    required int progress,
    required String speed,
    required String eta,
  }) async {
    try {
      await _channel.invokeMethod('updateNotificationProgress', {
        'title': title,
        'progress': progress,
        'speed': speed,
        'eta': eta,
      });
    } catch (_) {}
  }

  /// Stops foreground service when all tasks complete
  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  /// Shows a system notification when a download finishes (if enabled in settings)
  Future<void> showCompletionNotification({required String title}) async {
    try {
      await _channel.invokeMethod('showCompletionNotification', {'title': title});
    } catch (_) {}
  }

  /// Updates Lock Screen & Android System Media Notification
  Future<void> updateMediaNotification({
    required String title,
    required String artist,
    required bool isPlaying,
    required int positionMs,
    required int durationMs,
    required bool hasNext,
    required bool hasPrev,
  }) async {
    try {
      await _channel.invokeMethod('updateMediaNotification', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'hasNext': hasNext,
        'hasPrev': hasPrev,
      });
    } catch (_) {}
  }

  /// Stops Lock Screen & Android System Media Notification
  Future<void> stopMediaNotification() async {
    try {
      await _channel.invokeMethod('stopMediaNotification');
    } catch (_) {}
  }

  /// Equalizer & Audio FX
  Future<Map<String, dynamic>?> getEqualizerParams() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getEqualizerParams');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setEqualizerEnabled(bool enabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('setEqualizerEnabled', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setEqualizerBandLevel(int band, int level) async {
    try {
      final res = await _channel.invokeMethod<bool>('setEqualizerBandLevel', {'band': band, 'level': level});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> useEqualizerPreset(int presetIndex) async {
    try {
      final res = await _channel.invokeMethod<bool>('useEqualizerPreset', {'presetIndex': presetIndex});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBassBoost(bool enabled, int strength) async {
    try {
      final res = await _channel.invokeMethod<bool>('setBassBoost', {'enabled': enabled, 'strength': strength});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setLoudness(bool enabled, int gainMb) async {
    try {
      final res = await _channel.invokeMethod<bool>('setLoudness', {'enabled': enabled, 'gainMb': gainMb});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trims or extracts audio segment lossless to M4A/AAC
  Future<bool> extractAndTrimAudio({
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

  /// Checks whether the device is connected via Wi-Fi or Ethernet
  Future<bool> isWifiConnected() async {
    try {
      final res = await _channel.invokeMethod<bool>('isWifiConnected');
      return res ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Triggers Android MediaScanner for a newly saved file
  Future<void> scanMediaFile({required String path, String mimeType = '*/*'}) async {
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'path': path,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }

  /// Opens a video/audio file with external player intent
  Future<void> openFile(String path) async {
    try {
      await _channel.invokeMethod('openFile', {'path': path});
    } catch (_) {}
  }

  /// Opens target download folder
  Future<void> openFolder(String path) async {
    try {
      await _channel.invokeMethod('openFolder', {'path': path});
    } catch (_) {}
  }

  /// Triggers standard Android system package installer for downloaded APK
  Future<bool> installApk(String path) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs an HTTP GET request using Android's native HttpURLConnection (bypasses TLS/CDN fingerprinting)
  Future<Map<String, dynamic>?> nativeHttpGet({
    required String url,
    Map<String, String>? headers,
  }) async {
    try {
      final res = await _channel.invokeMethod<dynamic>('nativeHttpGet', {
        'url': url,
        'headers': headers ?? {},
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a URL (such as an anti-bot protected HLS manifest) using headless Chromium WebView
  Future<Map<String, dynamic>?> webViewFetch({required String url}) async {
    try {
      final res = await _channel.invokeMethod<dynamic>('webViewFetch', {'url': url});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Streams a remote file or HLS segment directly to disk using Android's native connection
  Future<bool> nativeDownloadFile({
    required String url,
    required String outputPath,
    Map<String, String>? headers,
    bool append = false,
  }) async {
    try {
      final res = await _channel.invokeMethod<dynamic>('nativeDownloadFile', {
        'url': url,
        'outputPath': outputPath,
        'headers': headers ?? {},
        'append': append,
      });
      if (res is Map) {
        final code = (res['statusCode'] as num?)?.toInt() ?? 0;
        return code >= 200 && code < 300;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Remuxes an MPEG-TS or concatenated HLS file into a cleanly indexed, universally playable MP4 container
  Future<bool> remuxTsToMp4({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('remuxTsToMp4', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return res ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('remuxTsToMp4 error: $e');
      return false;
    }
  }
}
