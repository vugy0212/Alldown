import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main()');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.loadSettings());

  void updateDirectory(String path) {
    final normalized = AppSettings.normalizeDirectoryPath(path);
    state = state.copyWith(downloadDirectory: normalized);
    _storage.saveSettings(state);
  }

  Future<String?> pickDownloadDirectory() async {
    try {
      final selectedDirectory = await FilePickerPlatform.instance.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.trim().isNotEmpty) {
        final normalized = AppSettings.normalizeDirectoryPath(selectedDirectory);
        state = state.copyWith(downloadDirectory: normalized);
        _storage.saveSettings(state);
        return normalized;
      }
    } catch (_) {}
    return null;
  }

  void resetDownloadDirectory() {
    state = state.copyWith(downloadDirectory: "/storage/emulated/0/Download/AllDown");
    _storage.saveSettings(state);
  }

  void setConcurrentDownloads(int count) {
    state = state.copyWith(maxConcurrentDownloads: count);
    _storage.saveSettings(state);
  }

  void toggleWifiOnly() {
    state = state.copyWith(wifiOnly: !state.wifiOnly);
    _storage.saveSettings(state);
  }

  void toggleAutoRetry() {
    state = state.copyWith(autoRetry: !state.autoRetry);
    _storage.saveSettings(state);
  }

  void toggleAutoRemux() {
    state = state.copyWith(autoRemuxToMp4: !state.autoRemuxToMp4);
    _storage.saveSettings(state);
  }

  void setAudioCodec(AudioCodec codec) {
    state = state.copyWith(audioCodec: codec);
    _storage.saveSettings(state);
  }

  void setMaxResolution(MaxResolution res) {
    state = state.copyWith(maxResolution: res);
    _storage.saveSettings(state);
  }

  void toggleSponsorBlock() {
    state = state.copyWith(sponsorBlockEnabled: !state.sponsorBlockEnabled);
    _storage.saveSettings(state);
  }

  Future<bool> importCookiesFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result.isNotEmpty) {
        final filePath = result.first.path;
        if (filePath != null && filePath.isNotEmpty) {
          final file = File(filePath);
          if (file.existsSync()) {
            final lines = await file.readAsLines();
            final pairs = <String>[];
            for (final rawLine in lines) {
              var line = rawLine.trim();
              if (line.isEmpty) continue;
              if (line.startsWith('#HttpOnly_')) {
                line = line.substring('#HttpOnly_'.length);
              } else if (line.startsWith('#')) {
                continue;
              }
              final parts = line.split('\t');
              if (parts.length >= 7) {
                final name = parts[5].trim();
                final value = parts[6].trim();
                if (name.isNotEmpty) {
                  pairs.add('$name=$value');
                }
              } else if (line.contains('=') && !line.contains(' ')) {
                pairs.add(line);
              }
            }
            if (pairs.isNotEmpty) {
              state = state.copyWith(
                cookiesActive: true,
                cookiesCount: pairs.length,
                cookiesHeader: pairs.join('; '),
              );
              _storage.saveSettings(state);
              return true;
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }

  void clearCookies() {
    state = state.copyWith(
      cookiesActive: false,
      cookiesCount: 0,
      cookiesHeader: "",
    );
    _storage.saveSettings(state);
  }

  void setAudioBitrate(String bitrate) {
    state = state.copyWith(audioBitrate: bitrate);
    _storage.saveSettings(state);
  }

  void setVideoContainer(String container) {
    state = state.copyWith(videoContainer: container);
    _storage.saveSettings(state);
  }

  void setUserAgent(String ua) {
    state = state.copyWith(userAgent: ua);
    _storage.saveSettings(state);
  }

  void setConnectionTimeout(int timeout) {
    state = state.copyWith(connectionTimeout: timeout);
    _storage.saveSettings(state);
  }

  void toggleNotifyOnComplete() {
    state = state.copyWith(notifyOnComplete: !state.notifyOnComplete);
    _storage.saveSettings(state);
  }

  void toggleTheme() {
    final next = !state.isDarkMode;
    state = state.copyWith(isDarkMode: next);
    _storage.saveSettings(state);
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
    _storage.saveSettings(state);
  }

  void resetAllSettings() {
    state = const AppSettings();
    _storage.saveSettings(state);
  }

  Future<void> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

