import 'dart:async';
import 'package:flutter/services.dart';

class NativeDownloaderService {
  static const MethodChannel _channel = MethodChannel('com.alldown.app/downloader');

  final StreamController<String> _sharedUrlController = StreamController<String>.broadcast();
  Stream<String> get onUrlShared => _sharedUrlController.stream;

  NativeDownloaderService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUrlShared') {
        final url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          _sharedUrlController.add(url);
        }
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
}

