import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/media_item.dart';
import '../models/download_task.dart';

class StorageService {
  static const String _keySettings = 'alldown_settings_v2';
  static const String _keyLibrary = 'alldown_library_v2';
  static const String _keyQueue = 'alldown_queue_v2';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  static bool _isValidMediaFile(String path) {
    if (path.isEmpty) return false;
    try {
      final f = File(path);
      if (!f.existsSync()) return false;
      final len = f.lengthSync();
      if (len < 1024) return false;
      // Check first 32 bytes to ensure it is not an HTML error/webpage saved as .mp4
      final raf = f.openSync(mode: FileMode.read);
      final headerBytes = raf.readSync(32);
      raf.closeSync();
      final headerStr = String.fromCharCodes(headerBytes).trimLeft().toLowerCase();
      if (headerStr.startsWith('<!doctype') || headerStr.startsWith('<html') || headerStr.startsWith('<head')) {
        try {
          f.deleteSync();
        } catch (_) {}
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Settings
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  // Library Items (only keep items whose local file exists and is a valid binary media file)
  Future<void> saveLibrary(List<MediaItem> items) async {
    final list = items.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyLibrary, jsonEncode(list));
  }

  List<MediaItem> loadLibrary() {
    final raw = _prefs.getString(_keyLibrary);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final items = decoded
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .where((item) => _isValidMediaFile(item.localPath))
          .toList();
      return items;
    } catch (_) {
      return [];
    }
  }

  // Queue Tasks
  Future<void> saveQueue(List<DownloadTask> tasks) async {
    final list = tasks.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyQueue, jsonEncode(list));
  }

  List<DownloadTask> loadQueue() {
    final raw = _prefs.getString(_keyQueue);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => DownloadTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
