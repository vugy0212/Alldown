import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DlrStreamItem {
  final String url;
  final String quality;
  final String format; // MP4 or HLS
  final String? resolution;

  const DlrStreamItem({
    required this.url,
    required this.quality,
    required this.format,
    this.resolution,
  });

  factory DlrStreamItem.fromJson(Map<String, dynamic> json) {
    return DlrStreamItem(
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String? ?? 'Auto',
      format: (json['format'] as String? ?? 'MP4').toUpperCase(),
      resolution: json['resolution'] as String?,
    );
  }
}

class DlrResolvedMedia {
  final bool success;
  final String platform;
  final String title;
  final String author;
  final int durationSeconds;
  final String durationFormatted;
  final String thumbnailUrl;
  final String bestStreamUrl;
  final String bestResolution;
  final List<DlrStreamItem> streams;
  final Map<String, String> headers;

  const DlrResolvedMedia({
    required this.success,
    required this.platform,
    required this.title,
    required this.author,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.thumbnailUrl,
    required this.bestStreamUrl,
    required this.bestResolution,
    required this.streams,
    required this.headers,
  });

  bool get isHls =>
      bestStreamUrl.contains('.m3u8') ||
      streams.any((s) => s.format == 'HLS' || s.url.contains('.m3u8'));

  factory DlrResolvedMedia.fromJson(Map<String, dynamic> json) {
    final streamList = (json['streams'] as List<dynamic>? ?? [])
        .map((e) => DlrStreamItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawHeaders = json['headers'] as Map<String, dynamic>? ?? {};
    final headers = rawHeaders.map((k, v) => MapEntry(k, v.toString()));

    return DlrResolvedMedia(
      success: json['success'] as bool? ?? false,
      platform: json['platform'] as String? ?? 'Web Media',
      title: json['title'] as String? ?? 'Media Stream',
      author: json['author'] as String? ?? 'Web Source',
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      durationFormatted: json['durationFormatted'] as String? ?? 'Stream',
      thumbnailUrl: json['thumbnail'] as String? ?? '',
      bestStreamUrl: json['bestStreamUrl'] as String? ?? '',
      bestResolution: json['bestResolution'] as String? ?? 'HD',
      streams: streamList,
      headers: headers,
    );
  }
}

class RemoteRulesService {
  static const String endpoint = 'https://alldown-dlr.vugy0212.workers.dev';
  static const String _prefsKeyRules = 'alldown_cached_remote_rules';
  static const String _prefsKeyRulesTimestamp = 'alldown_cached_remote_rules_ts';

  static Map<String, dynamic>? _cachedRules;

  /// Fetch and cache extraction rules from Cloudflare Worker
  static Future<Map<String, dynamic>?> syncRules({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force && _cachedRules != null) return _cachedRules;

      final cachedStr = prefs.getString(_prefsKeyRules);
      if (cachedStr != null && !force) {
        final lastSync = prefs.getInt(_prefsKeyRulesTimestamp) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Cache rules locally for 1 hour before re-checking
        if (now - lastSync < 3600000) {
          _cachedRules = jsonDecode(cachedStr) as Map<String, dynamic>;
          return _cachedRules;
        }
      }

      final res = await http.get(Uri.parse('$endpoint/api/rules')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedRules = data;
        await prefs.setString(_prefsKeyRules, res.body);
        await prefs.setInt(_prefsKeyRulesTimestamp, DateTime.now().millisecondsSinceEpoch);
        return data;
      }
    } catch (_) {}

    // Fallback to locally stored cache if network is down
    if (_cachedRules == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedStr = prefs.getString(_prefsKeyRules);
        if (cachedStr != null) {
          _cachedRules = jsonDecode(cachedStr) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    return _cachedRules;
  }

  /// Resolves direct stream via Cloudflare Worker DLR resolver
  static Future<DlrResolvedMedia?> resolveViaDlr(String url) async {
    try {
      final uri = Uri.parse('$endpoint/api/resolve');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url.trim()}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return DlrResolvedMedia.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Checks if URL belongs to Vimeo
  static bool isVimeoUrl(String url) {
    return RegExp(r'vimeo\.com\/(?:channels\/(?:\w+\/)?|groups\/[^\/]*\/videos\/|album\/(?:\d+\/)?video\/|video\/|)(\d+)', caseSensitive: false).hasMatch(url) ||
           url.contains('player.vimeo.com/video/');
  }

  /// Checks if URL belongs to Dailymotion
  static bool isDailymotionUrl(String url) {
    return RegExp(r'(dailymotion\.com\/(video|embed\/video)|dai\.ly)\/([a-zA-Z0-9]+)', caseSensitive: false).hasMatch(url);
  }
}

