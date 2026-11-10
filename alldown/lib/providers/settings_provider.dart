import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
    state = state.copyWith(downloadDirectory: path);
    _storage.saveSettings(state);
  }

  Future<String?> pickDownloadDirectory() async {
    try {
      final selectedDirectory = await FilePickerPlatform.instance.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.trim().isNotEmpty) {
        state = state.copyWith(downloadDirectory: selectedDirectory.trim());
        _storage.saveSettings(state);
        return selectedDirectory.trim();
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
        state = state.copyWith(
          cookiesActive: true,
          cookiesCount: 68,
        );
        _storage.saveSettings(state);
        return true;
      }
    } catch (_) {}
    return false;
  }

  void clearAppCache() {
    // Cache clearing action
  }
}

