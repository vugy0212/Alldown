import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../providers/quick_download_provider.dart';
import 'remote_rules_service.dart';

class ResolvedDirectStream {
  final String streamUrl;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;
  final String resolutionLabel;
  final String platform;
  final bool isHls;

  const ResolvedDirectStream({
    required this.streamUrl,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.resolutionLabel,
    required this.platform,
    this.isHls = false,
  });
}

class MetadataFetcherService {
  static final RegExp _ytRegex = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+?&v=|shorts\/|live\/))([\w-]{11})',
    caseSensitive: false,
  );

  static final RegExp _twitterRegex = RegExp(
    r'(?:x\.com|twitter\.com)\/(?:[^\/]+\/status|i\/web\/status|i\/status|status)\/(\d+)',
    caseSensitive: false,
  );

  /// Extracts YouTube Video ID from any URL or shared text
  static String? extractYouTubeId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final match = _ytRegex.firstMatch(trimmed);
    if (match != null && match.group(1) != null) {
      return match.group(1);
    }

    try {
      final uri = Uri.parse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
      final host = uri.host.toLowerCase();

      if (host.contains('youtube.com')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.length == 11) return v;

        final segments = uri.pathSegments;
        final keyIndex = segments.indexWhere(
          (s) => s == 'shorts' || s == 'live' || s == 'embed' || s == 'v',
        );
        if (keyIndex != -1 && segments.length > keyIndex + 1) {
          final id = segments[keyIndex + 1];
          if (id.length == 11) return id;
        }
      } else if (host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) {
          final id = uri.pathSegments.first;
          if (id.length == 11) return id;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Extracts X / Twitter Status ID if present
  static String? extractTwitterStatusId(String input) {
    final match = _twitterRegex.firstMatch(input.trim());
    return match?.group(1);
  }

  static bool isTikTokUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('tiktok.com/');
  }

  static bool isFacebookUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com');
  }

  static bool isInstagramUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('instagram.com/reel/') ||
        lower.contains('instagram.com/reels/') ||
        lower.contains('instagram.com/p/') ||
        lower.contains('instagram.com/tv/') ||
        lower.contains('instagr.am/');
  }

  static String? extractInstagramShortcode(String input) {
    final match = RegExp(
      r'instagram\.com\/(?:[^\/]+\/)?(?:p|reel|reels|tv)\/([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(input);
    return match?.group(1);
  }

  static bool isRedditUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('reddit.com') || lower.contains('redd.it');
  }

  /// Resolves Reddit direct stream via Cloudflare Edge DLR or direct client fallback
  static Future<ResolvedDirectStream?> resolveRedditStream(
    String url, {
    String preferredResolution = '720p',
  }) async {
    // 1. First try Cloudflare Edge DLR resolver
    try {
      final dlr = await RemoteRulesService.resolveViaDlr(url);
      if (dlr != null && dlr.success && dlr.bestStreamUrl.isNotEmpty) {
        return ResolvedDirectStream(
          streamUrl: dlr.bestStreamUrl,
          title: dlr.title,
          author: dlr.author,
          duration: dlr.durationFormatted,
          thumbnailUrl: dlr.thumbnailUrl,
          resolutionLabel: dlr.bestResolution,
          platform: 'Reddit',
          isHls: dlr.isHls,
        );
      }
    } catch (_) {}

    // 2. Client-side fallback via RapidSave / oEmbed
    try {
      final rsUri = Uri.parse('https://rapidsave.com/info?url=${Uri.encodeComponent(url.trim())}');
      final response = await http.get(
        rsUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final html = response.body;

        String title = 'Reddit Video';
        final captionMatch = RegExp(r'class=["\x27]caption["\x27][^>]*>([^<]+)<', caseSensitive: false).firstMatch(html);
        final titleTagMatch = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
        if (captionMatch != null && captionMatch.group(1)!.trim().isNotEmpty) {
          title = captionMatch.group(1)!.trim();
        } else if (titleTagMatch != null) {
          final t = titleTagMatch.group(1)!.trim().replaceAll(RegExp(r'\s*-\s*RapidSave.*$', caseSensitive: false), '').trim();
          if (!t.toLowerCase().contains('download reddit video')) {
            title = t;
          }
        }

        String author = 'Reddit User';
        final authorMatch = RegExp(r'<td>Author:<\/td>\s*<td>([^<]+)<\/td>', caseSensitive: false).firstMatch(html);
        final subMatch = RegExp(r'<td>Subreddit:<\/td>\s*<td>([^<]+)<\/td>', caseSensitive: false).firstMatch(html);
        if (authorMatch != null && authorMatch.group(1)!.trim().isNotEmpty) {
          author = 'u/${authorMatch.group(1)!.trim()}';
        } else if (subMatch != null && subMatch.group(1)!.trim().isNotEmpty) {
          author = 'r/${subMatch.group(1)!.trim()}';
        }

        String? bestStreamUrl;
        final dlButtonMatch = RegExp(r'<a[^>]+class=["\x27][^"\x27]*downloadbutton[^"\x27]*["\x27][^>]+href=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
        if (dlButtonMatch != null) {
          final rawHref = dlButtonMatch.group(1)!.trim();
          if (rawHref.startsWith('/sd.php')) {
            try {
              final sdRes = await http.get(
                Uri.parse('https://rapidsave.com$rawHref'),
                headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
              ).timeout(const Duration(seconds: 5));
              if (sdRes.statusCode == 200) {
                final sdLinks = RegExp(r'href=["\x27](https?:\/\/sd\.rapidsave\.com\/download[^"\x27]+)["\x27]', caseSensitive: false)
                    .allMatches(sdRes.body)
                    .map((m) => m.group(1)!)
                    .toList();
                if (sdLinks.isNotEmpty) {
                  final q1080 = sdLinks.where((u) => u.contains('1080')).toList();
                  final q720 = sdLinks.where((u) => u.contains('720')).toList();
                  bestStreamUrl = q1080.isNotEmpty ? q1080.first : (q720.isNotEmpty ? q720.first : sdLinks.first);
                }
              }
            } catch (_) {}
          } else if (rawHref.startsWith('http')) {
            bestStreamUrl = rawHref;
          }
        }

        final vMatch = RegExp(r'https?:\/\/v\.redd\.it\/([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(html) ??
                       RegExp(r'https?:\/\/v\.redd\.it\/([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(url);
        final vId = vMatch?.group(1);
        final hlsUrl = vId != null ? 'https://v.redd.it/$vId/HLSPlaylist.m3u8' : null;

        final finalStream = bestStreamUrl ?? hlsUrl;
        if (finalStream != null && finalStream.isNotEmpty) {
          final isHls = bestStreamUrl == null && hlsUrl != null;
          return ResolvedDirectStream(
            streamUrl: finalStream,
            title: title,
            author: author,
            duration: 'Reddit HD',
            thumbnailUrl: '',
            resolutionLabel: 'HD MP4',
            platform: 'Reddit',
            isHls: isHls,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  static String formatDuration(Duration? d) {
    if (d == null || d.inSeconds <= 0) return '00:30';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String formatViews(int? count, {String suffix = 'views'}) {
    if (count == null || count <= 0) return 'Stream Ready';
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B $suffix';
    }
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M $suffix';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K $suffix';
    }
    return '$count $suffix';
  }

  /// Resolves direct MP4 stream and metadata from X (Twitter) using FxTwitter API
  static Future<ResolvedDirectStream?> resolveTwitterStream(
    String statusId, {
    String preferredResolution = '1080p',
  }) async {
    try {
      final uri = Uri.parse('https://api.fxtwitter.com/status/$statusId');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final tweet = root['tweet'] as Map<String, dynamic>?;
      if (tweet == null) return null;

      final rawTitle = (tweet['text'] as String? ?? '').trim();
      final authorObj = tweet['author'] as Map<String, dynamic>?;
      final authorName = authorObj?['name'] as String? ?? 'X User';
      final screenName = authorObj?['screen_name'] as String? ?? 'x';
      final title = rawTitle.isNotEmpty ? rawTitle : 'X Video by @$screenName';

      final media = tweet['media'] as Map<String, dynamic>?;
      final videos = (media?['videos'] as List?) ?? (media?['all'] as List?) ?? [];
      if (videos.isEmpty) return null;

      final videoObj = videos.first as Map<String, dynamic>;
      final thumb = videoObj['thumbnail_url'] as String? ?? '';
      final durNum = (videoObj['duration'] as num?)?.toDouble() ?? 30.0;
      final durationStr = formatDuration(Duration(seconds: durNum.round().clamp(1, 86400)));

      // Collect MP4 variants with bitrates
      final variantsRaw = (videoObj['variants'] as List?) ?? (videoObj['formats'] as List?) ?? [];
      final mp4Variants = <Map<String, dynamic>>[];

      for (final v in variantsRaw) {
        if (v is Map<String, dynamic>) {
          final vUrl = v['url'] as String? ?? '';
          final contentType = v['content_type'] as String? ?? v['container'] as String? ?? '';
          if (vUrl.contains('.mp4') || contentType.contains('mp4')) {
            mp4Variants.add(v);
          }
        }
      }

      // Sort by bitrate ascending
      mp4Variants.sort((a, b) {
        final ba = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bb = (b['bitrate'] as num?)?.toInt() ?? 0;
        return ba.compareTo(bb);
      });

      String chosenUrl = videoObj['url'] as String? ?? '';
      String chosenLabel = 'HD MP4';

      if (mp4Variants.isNotEmpty) {
        final pref = preferredResolution.toLowerCase();
        if (pref.contains('480')) {
          // Find variant with 480 in URL or pick lower-middle bitrate
          final match480 = mp4Variants.where((v) => (v['url'] as String).contains('480')).toList();
          final picked = match480.isNotEmpty
              ? match480.first
              : mp4Variants[(mp4Variants.length ~/ 2).clamp(0, mp4Variants.length - 1)];
          chosenUrl = picked['url'] as String;
          chosenLabel = '480p SD';
        } else if (pref.contains('720')) {
          final match720 = mp4Variants.where((v) => (v['url'] as String).contains('720')).toList();
          final picked = match720.isNotEmpty
              ? match720.first
              : mp4Variants[(mp4Variants.length - 1).clamp(0, mp4Variants.length - 1)];
          chosenUrl = picked['url'] as String;
          chosenLabel = '720p HD';
        } else {
          // 1080p or 4K -> highest bitrate MP4
          final picked = mp4Variants.last;
          chosenUrl = picked['url'] as String;
          chosenLabel = pref.contains('4k') || pref.contains('2160') ? 'Max HD' : '1080p FHD';
        }
      }

      if (chosenUrl.isEmpty) return null;

      return ResolvedDirectStream(
        streamUrl: chosenUrl,
        title: title,
        author: '$authorName (@$screenName)',
        duration: durationStr,
        thumbnailUrl: thumb,
        resolutionLabel: chosenLabel,
        platform: 'X (Twitter)',
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves direct MP4 stream from TikTok via TikWM public API
  static Future<ResolvedDirectStream?> resolveTikTokStream(String url) async {
    try {
      final apiUri = Uri.parse('https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}');
      final response = await http.get(apiUri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final playUrl = data['play'] as String? ?? data['wmplay'] as String? ?? '';
      if (playUrl.isEmpty) return null;

      final title = (data['title'] as String? ?? '').trim();
      final authorObj = data['author'] as Map<String, dynamic>?;
      final author = authorObj?['nickname'] as String? ?? 'TikTok Creator';
      final cover = data['cover'] as String? ?? '';
      final durSec = (data['duration'] as num?)?.toInt() ?? 30;

      return ResolvedDirectStream(
        streamUrl: playUrl,
        title: title.isNotEmpty ? title : 'TikTok Video by $author',
        author: author,
        duration: formatDuration(Duration(seconds: durSec)),
        thumbnailUrl: cover,
        resolutionLabel: 'HD MP4',
        platform: 'TikTok',
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves direct MP4 stream and metadata from Facebook (Reels, Watch, Videos)
  static Future<ResolvedDirectStream?> resolveFacebookStream(
    String rawUrl, {
    String preferredResolution = '1080p',
  }) async {
    try {
      var targetUrl = rawUrl.trim();
      if (!targetUrl.startsWith('http')) {
        targetUrl = 'https://$targetUrl';
      }

      // Convert reel URL to watch URL if needed
      final reelMatch = RegExp(r'facebook\.com\/reel\/(\d+)', caseSensitive: false).firstMatch(targetUrl);
      if (reelMatch != null) {
        targetUrl = 'https://www.facebook.com/watch/?v=${reelMatch.group(1)}';
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(targetUrl));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
      });
      request.followRedirects = true;
      request.maxRedirects = 6;

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));
      final responseBody = await streamedResponse.stream.bytesToString();
      client.close();

      if (responseBody.isEmpty) return null;

      String cleanStreamUrl(String u) {
        var res = u.replaceAll(r'\/', '/');
        res = res.replaceAll(r'\u0026', '&');
        res = res.replaceAll(r'\u0025', '%');
        res = res.replaceAll('&amp;', '&');
        return res.trim();
      }

      // 1. Search for HD MP4
      String? hdUrl;
      final hdPatterns = [
        RegExp(r'"browser_native_hd_url":\s*"([^"]+)"'),
        RegExp(r'"playable_url_quality_hd":\s*"([^"]+)"'),
        RegExp(r'"hd_src":\s*"([^"]+)"'),
        RegExp(r'"hd_src_no_ratelimit":\s*"([^"]+)"'),
      ];
      for (final p in hdPatterns) {
        final m = p.firstMatch(responseBody);
        if (m != null && m.group(1) != null) {
          hdUrl = cleanStreamUrl(m.group(1)!);
          break;
        }
      }

      // 2. Search for SD MP4
      String? sdUrl;
      final sdPatterns = [
        RegExp(r'"browser_native_sd_url":\s*"([^"]+)"'),
        RegExp(r'"playable_url":\s*"([^"]+)"'),
        RegExp(r'"sd_src":\s*"([^"]+)"'),
        RegExp(r'"sd_src_no_ratelimit":\s*"([^"]+)"'),
      ];
      for (final p in sdPatterns) {
        final m = p.firstMatch(responseBody);
        if (m != null && m.group(1) != null) {
          sdUrl = cleanStreamUrl(m.group(1)!);
          break;
        }
      }

      // 3. Fallback: search for any direct fbcdn .mp4 URL
      if (hdUrl == null && sdUrl == null) {
        final fallbackRegex = RegExp(r'(https?:[^\s"<>]+\.mp4[^\s"<>]*)');
        final allMatches = fallbackRegex.allMatches(responseBody);
        for (final match in allMatches) {
          final cand = cleanStreamUrl(match.group(1) ?? '');
          if (cand.contains('fbcdn.net')) {
            sdUrl = cand;
            break;
          }
        }
      }

      if (hdUrl == null && sdUrl == null) {
        return null;
      }

      // Title
      String title = 'Facebook Video';
      final ogTitleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"', caseSensitive: false).firstMatch(responseBody);
      if (ogTitleMatch != null && ogTitleMatch.group(1) != null) {
        title = ogTitleMatch.group(1)!.trim();
      } else {
        final titleTagMatch = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(responseBody);
        if (titleTagMatch != null && titleTagMatch.group(1) != null) {
          title = titleTagMatch.group(1)!.trim();
        }
      }
      title = title.replaceAll(RegExp(r'\s*\|\s*Facebook$', caseSensitive: false), '').trim();
      title = title
          .replaceAll('&#xb7;', '·')
          .replaceAll('&middot;', '·')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll('&#039;', "'")
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
      if (title.isEmpty) title = 'Facebook Video';

      // Thumbnail
      String thumb = '';
      final ogImgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"', caseSensitive: false).firstMatch(responseBody);
      if (ogImgMatch != null && ogImgMatch.group(1) != null) {
        thumb = cleanStreamUrl(ogImgMatch.group(1)!);
      }

      // Preferred resolution selection
      final pref = preferredResolution.toLowerCase();
      String chosenUrl;
      String chosenLabel;
      if (pref.contains('480')) {
        chosenUrl = sdUrl ?? hdUrl!;
        chosenLabel = '480p SD';
      } else {
        chosenUrl = hdUrl ?? sdUrl!;
        chosenLabel = hdUrl != null ? 'HD 1080p' : 'SD 480p';
      }

      return ResolvedDirectStream(
        streamUrl: chosenUrl,
        title: title,
        author: 'Facebook Video',
        duration: '02:00',
        thumbnailUrl: thumb,
        resolutionLabel: chosenLabel,
        platform: 'Facebook',
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves direct progressive MP4 stream for Instagram Reels, Posts, and Videos
  static Future<ResolvedDirectStream?> resolveInstagramStream(
    String rawUrl, {
    String preferredResolution = '1080p',
    String? cookiesHeader,
  }) async {
    try {
      final shortcode = extractInstagramShortcode(rawUrl);
      if (shortcode == null) return null;

      final targetUrl = 'https://www.instagram.com/reel/$shortcode/';
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(targetUrl));
      request.headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
      });
      if (cookiesHeader != null && cookiesHeader.trim().isNotEmpty) {
        request.headers['Cookie'] = cookiesHeader.trim();
      }
      request.followRedirects = true;
      request.maxRedirects = 5;

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));
      final responseBody = await streamedResponse.stream.bytesToString();
      client.close();

      if (responseBody.isEmpty) return null;

      String cleanUrl(String u) {
        var res = u.replaceAll(r'\/', '/');
        res = res.replaceAll(r'\u0026', '&');
        res = res.replaceAll(r'\u0025', '%');
        res = res.replaceAll('&amp;', '&');
        return res.trim();
      }

      // Method 1: Scan <script type="application/json" data-sjs> tags
      final sjsRegex = RegExp(r'<script\b[^>]+\bdata-sjs>(\{.+?\})<\/script>', dotAll: true);
      final sjsMatches = sjsRegex.allMatches(responseBody);

      String? streamUrl;
      String? title;
      String? author;
      String? thumbUrl;
      String? duration;
      String resolutionLabel = 'HD MP4';

      for (final match in sjsMatches) {
        final jsonText = match.group(1);
        if (jsonText == null ||
            (!jsonText.contains('video_versions') && !jsonText.contains('xig_polaris_media'))) {
          continue;
        }

        try {
          final data = jsonDecode(jsonText);
          void scan(dynamic obj) {
            if (obj is Map) {
              if (obj.containsKey('video_versions') && obj['video_versions'] is List) {
                final list = (obj['video_versions'] as List).whereType<Map>().toList();
                if (list.isNotEmpty) {
                  // Sort by resolution (width * height) descending
                  list.sort((a, b) {
                    final areaA = ((a['width'] as num?)?.toInt() ?? 0) *
                        ((a['height'] as num?)?.toInt() ?? 0);
                    final areaB = ((b['width'] as num?)?.toInt() ?? 0) *
                        ((b['height'] as num?)?.toInt() ?? 0);
                    return areaB.compareTo(areaA);
                  });
                  final best = list.first;
                  final rawU = best['url']?.toString();
                  if (rawU != null && rawU.isNotEmpty) {
                    streamUrl = cleanUrl(rawU);
                    final h = best['height'];
                    if (h != null) {
                      resolutionLabel = '${h}p HD';
                    }
                  }
                }
              }

              if (obj.containsKey('caption') && obj['caption'] is Map) {
                final capMap = obj['caption'] as Map;
                final txt = capMap['text']?.toString().trim();
                if (txt != null && txt.isNotEmpty) {
                  title = txt.split('\n').first.trim();
                  if (title!.length > 80) {
                    title = '${title!.substring(0, 80)}...';
                  }
                }
              }

              if (obj.containsKey('user') && obj['user'] is Map) {
                final userMap = obj['user'] as Map;
                final uname = userMap['username']?.toString();
                if (uname != null && uname.isNotEmpty) {
                  author = '@$uname';
                }
              }

              if (obj.containsKey('image_versions2') && obj['image_versions2'] is Map) {
                final imgMap = obj['image_versions2'] as Map;
                final candidates = imgMap['candidates'];
                if (candidates is List && candidates.isNotEmpty) {
                  final firstCand = candidates.first;
                  if (firstCand is Map && firstCand['url'] != null) {
                    thumbUrl = cleanUrl(firstCand['url'].toString());
                  }
                }
              }

              if (obj.containsKey('video_duration') && obj['video_duration'] is num) {
                final sec = (obj['video_duration'] as num).toInt();
                final m = sec ~/ 60;
                final sRem = sec % 60;
                duration = '${m.toString().padLeft(2, '0')}:${sRem.toString().padLeft(2, '0')}';
              }

              for (final val in obj.values) {
                scan(val);
              }
            } else if (obj is List) {
              for (final elem in obj) {
                scan(elem);
              }
            }
          }

          scan(data);
          if (streamUrl != null) break;
        } catch (_) {}
      }

      // Method 2: Fallback regex on HTML for video_versions or fbcdn .mp4
      if (streamUrl == null) {
        final videoVersionRegex = RegExp(r'"video_versions":\s*\[\s*\{[^}]*?"url":\s*"([^"]+)"');
        final match = videoVersionRegex.firstMatch(responseBody);
        if (match != null && match.group(1) != null) {
          streamUrl = cleanUrl(match.group(1)!);
        }
      }

      if (streamUrl == null) {
        final fbcdnRegex = RegExp(r'''https?:\\?\/\\?\/[^\s"'<>]*(?:fbcdn\.net|cdninstagram\.com)[^\s"'<>]+\.mp4[^\s"'<>]*''');
        final match = fbcdnRegex.firstMatch(responseBody);
        if (match != null) {
          streamUrl = cleanUrl(match.group(0)!);
        }
      }

      if (streamUrl == null) return null;

      // Extract title / author fallbacks
      String finalTitle = title ?? '';
      if (finalTitle.isEmpty) {
        final ogTitle = RegExp(r'<meta\s+property=["\x27]og:title["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(responseBody)?.group(1);
        final titleTag = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(responseBody)?.group(1);
        var t = (ogTitle ?? titleTag ?? 'Instagram Video ($shortcode)').trim();
        t = t.replaceAll(RegExp(r'\s*•\s*Instagram.*$', caseSensitive: false), '').trim();
        finalTitle = t.isNotEmpty ? t : 'Instagram Video ($shortcode)';
      }

      String finalThumb = thumbUrl ?? '';
      if (finalThumb.isEmpty) {
        final ogImg = RegExp(r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(responseBody)?.group(1);
        if (ogImg != null) finalThumb = cleanUrl(ogImg);
      }

      return ResolvedDirectStream(
        streamUrl: streamUrl!,
        title: finalTitle,
        author: author ?? 'Instagram Creator',
        duration: duration ?? '00:30',
        thumbnailUrl: finalThumb,
        resolutionLabel: resolutionLabel,
        platform: 'Instagram',
      );
    } catch (_) {
      return null;
    }
  }

  static bool isStreamableUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('streamable.com/');
  }

  static bool isDirectMediaUrl(String input) {
    try {
      final uri = Uri.parse(input.startsWith('http') ? input : 'https://$input');
      final path = uri.path.toLowerCase();
      return path.endsWith('.mp4') ||
          path.endsWith('.webm') ||
          path.endsWith('.mkv') ||
          path.endsWith('.mov') ||
          path.endsWith('.m4a') ||
          path.endsWith('.mp3') ||
          path.endsWith('.wav') ||
          path.endsWith('.flac') ||
          path.endsWith('.ogg') ||
          path.endsWith('.aac');
    } catch (_) {
      return false;
    }
  }

  /// Resolves direct MP4 stream from Streamable API
  static Future<ResolvedDirectStream?> resolveStreamableStream(String url) async {
    try {
      final match = RegExp(r'streamable\.com\/([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(url);
      if (match == null) return null;
      final code = match.group(1)!;

      final apiUri = Uri.parse('https://api.streamable.com/videos/$code');
      final response = await http.get(apiUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as Map<String, dynamic>?) ?? {};

      final mp4Obj = files['mp4'] as Map<String, dynamic>? ??
          files['original'] as Map<String, dynamic>? ??
          files['mp4-mobile'] as Map<String, dynamic>?;
      if (mp4Obj == null) return null;

      var streamUrl = mp4Obj['url'] as String? ?? '';
      if (streamUrl.startsWith('//')) {
        streamUrl = 'https:$streamUrl';
      }
      if (streamUrl.isEmpty) return null;

      final rawTitle = (data['title'] as String? ?? '').trim();
      final title = rawTitle.isNotEmpty ? rawTitle : 'Streamable Video ($code)';
      var thumb = data['thumbnail_url'] as String? ?? '';
      if (thumb.startsWith('//')) {
        thumb = 'https:$thumb';
      }

      final durSec = ((mp4Obj['duration'] as num?)?.toDouble() ?? 30.0).round().clamp(1, 86400);
      final height = mp4Obj['height'] ?? 720;

      return ResolvedDirectStream(
        streamUrl: streamUrl,
        title: title,
        author: 'Streamable',
        duration: formatDuration(Duration(seconds: durSec)),
        thumbnailUrl: thumb,
        resolutionLabel: '${height}p HD',
        platform: 'Streamable',
      );
    } catch (_) {
      return null;
    }
  }

  /// Universal stream extractor: scans HTML for OpenGraph og:video, HTML5 video sources, or direct CDN links
  static Future<ResolvedDirectStream?> resolveGenericWebpageStream(String url) async {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final client = http.Client();
      final req = http.Request('GET', uri);
      req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      req.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,video/*,audio/*,*/*;q=0.8';
      req.followRedirects = true;
      req.maxRedirects = 5;

      final streamed = await client.send(req).timeout(const Duration(seconds: 8));
      final contentType = (streamed.headers['content-type'] ?? '').toLowerCase();

      // If URL directly returned media bytes
      if (contentType.contains('video/') || contentType.contains('audio/') || contentType.contains('application/octet-stream')) {
        client.close();
        final domain = uri.host.replaceFirst('www.', '');
        final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media';
        final cleanTitle = Uri.decodeComponent(lastSeg.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''));
        final isAudio = contentType.contains('audio');
        return ResolvedDirectStream(
          streamUrl: url,
          title: cleanTitle.isNotEmpty ? cleanTitle : 'Direct Media Stream',
          author: domain,
          duration: 'Stream',
          thumbnailUrl: '',
          resolutionLabel: isAudio ? 'Audio Stream' : 'HD Media',
          platform: domain,
        );
      }

      final body = await streamed.stream.bytesToString();
      client.close();
      if (body.isEmpty) return null;

      final patterns = [
        RegExp(r'<meta\s+property=["\x27]og:video(?::secure_url|:url)?["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
        RegExp(r'<meta\s+name=["\x27]twitter:player:stream["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
        RegExp(r'<meta\s+itemprop=["\x27]contentUrl["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
        RegExp(r'<source\s+[^>]*src=["\x27]([^"\x27]+\.(?:mp4|webm|m4a|mp3)[^"\x27]*)["\x27]', caseSensitive: false),
        RegExp(r'<video\s+[^>]*src=["\x27]([^"\x27]+\.(?:mp4|webm|m4a|mp3)[^"\x27]*)["\x27]', caseSensitive: false),
        RegExp(r'''["'](https?:\/\/[^\s"'<>]+\.(?:mp4|webm|m4a|mp3)[^\s"'<>]*)["']''', caseSensitive: false),
      ];

      String? foundStream;
      for (final p in patterns) {
        final m = p.firstMatch(body);
        if (m != null && m.group(1) != null) {
          var cand = m.group(1)!.trim();
          cand = cand.replaceAll(r'\/', '/');
          cand = cand.replaceAll(r'\u0026', '&');
          cand = cand.replaceAll('&amp;', '&');
          if (cand.startsWith('//')) cand = 'https:$cand';
          if (cand.startsWith('http')) {
            foundStream = cand;
            break;
          }
        }
      }

      if (foundStream != null) {
        final ogTitle = RegExp(r'<meta\s+property=["\x27]og:title["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(body)?.group(1);
        final titleTag = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(body)?.group(1);
        var title = (ogTitle ?? titleTag ?? uri.host).trim();
        title = title.replaceAll(RegExp(r'\s*\|\s*.*$'), '').trim();

        final thumb = RegExp(r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(body)?.group(1) ?? '';

        return ResolvedDirectStream(
          streamUrl: foundStream,
          title: title.isNotEmpty ? title : 'Web Video',
          author: uri.host.replaceFirst('www.', ''),
          duration: 'Stream',
          thumbnailUrl: thumb,
          resolutionLabel: 'Web HD',
          platform: uri.host.replaceFirst('www.', ''),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetches real metadata for any media URL
  static Future<DetectedMedia> fetchMediaInfo(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty URL');
    }

    // 1. Check X / Twitter Status URL
    final twitterId = extractTwitterStatusId(trimmed);
    if (twitterId != null) {
      try {
        final uri = Uri.parse('https://api.fxtwitter.com/status/$twitterId');
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final root = jsonDecode(response.body) as Map<String, dynamic>;
          final tweet = root['tweet'] as Map<String, dynamic>?;
          if (tweet != null) {
            final rawText = (tweet['text'] as String? ?? '').trim();
            final authorObj = tweet['author'] as Map<String, dynamic>?;
            final authorName = authorObj?['name'] as String? ?? 'X Creator';
            final screenName = authorObj?['screen_name'] as String? ?? 'x';
            final followers = (authorObj?['followers'] as num?)?.toInt();
            final views = (tweet['views'] as num?)?.toInt();

            final media = tweet['media'] as Map<String, dynamic>?;
            final videos = (media?['videos'] as List?) ?? (media?['all'] as List?) ?? [];
            String thumb = authorObj?['avatar_url'] as String? ?? '';
            int durSec = 35;

            if (videos.isNotEmpty) {
              final v = videos.first as Map<String, dynamic>;
              thumb = v['thumbnail_url'] as String? ?? thumb;
              durSec = ((v['duration'] as num?)?.toDouble() ?? 35.0).round().clamp(1, 86400);
            }

            return DetectedMedia(
              title: rawText.isNotEmpty ? rawText : 'X Video by @$screenName',
              channel: '$authorName (@$screenName)',
              subscribers: formatViews(followers, suffix: 'followers'),
              duration: formatDuration(Duration(seconds: durSec)),
              durationSeconds: durSec,
              uploadTime: 'X / Twitter Post',
              viewCount: formatViews(views),
              license: 'Direct MP4 Stream',
              thumbnailUrl: thumb,
              platform: 'X (Twitter)',
              badgeText: 'HD MP4',
            );
          }
        }
      } catch (_) {}
    }

    // 2. Check YouTube URL
    final ytId = extractYouTubeId(trimmed);
    if (ytId != null) {
      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(ytId).timeout(const Duration(seconds: 7));
        final durSec = video.duration?.inSeconds ?? 210;
        final uploadStr = video.uploadDate != null
            ? '${video.uploadDate!.year}-${video.uploadDate!.month.toString().padLeft(2, '0')}-${video.uploadDate!.day.toString().padLeft(2, '0')}'
            : 'YouTube HD';

        return DetectedMedia(
          title: video.title,
          channel: video.author,
          subscribers: 'YouTube Creator',
          duration: formatDuration(video.duration),
          durationSeconds: durSec > 0 ? durSec : 210,
          uploadTime: uploadStr,
          viewCount: formatViews(video.engagement.viewCount),
          license: 'Audio + Video Ready',
          thumbnailUrl: 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg',
          platform: 'YouTube',
          badgeText: 'MP4 / Audio',
        );
      } catch (_) {
        try {
          final oembedUri = Uri.parse(
            'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$ytId&format=json',
          );
          final response = await http.get(oembedUri).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'YouTube Video';
            final author = data['author_name'] as String? ?? 'YouTube Creator';

            return DetectedMedia(
              title: title,
              channel: author,
              subscribers: 'YouTube Channel',
              duration: '03:30',
              durationSeconds: 210,
              uploadTime: 'YouTube Stream',
              viewCount: 'Direct Stream',
              license: 'Audio + Video Ready',
              thumbnailUrl: 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg',
              platform: 'YouTube',
              badgeText: 'HD Stream',
            );
          }
        } catch (_) {}

        return DetectedMedia(
          title: 'YouTube Video ($ytId)',
          channel: 'YouTube',
          subscribers: 'Stream Detected',
          duration: '03:30',
          durationSeconds: 210,
          uploadTime: 'Ready to Download',
          viewCount: 'Direct Stream',
          license: 'Audio + Video',
          thumbnailUrl: 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg',
          platform: 'YouTube',
          badgeText: 'HD Stream',
        );
      } finally {
        yt.close();
      }
    }

    // 3. Check TikTok URL
    if (isTikTokUrl(trimmed)) {
      final tk = await resolveTikTokStream(trimmed);
      if (tk != null) {
        return DetectedMedia(
          title: tk.title,
          channel: tk.author,
          subscribers: 'TikTok Creator',
          duration: tk.duration,
          durationSeconds: 45,
          uploadTime: 'TikTok Stream',
          viewCount: 'No Watermark MP4',
          license: 'Direct Stream',
          thumbnailUrl: tk.thumbnailUrl,
          platform: 'TikTok',
          badgeText: 'HD MP4',
        );
      }
    }

    // 4. Check Facebook URL
    if (isFacebookUrl(trimmed)) {
      final fb = await resolveFacebookStream(trimmed);
      if (fb != null) {
        return DetectedMedia(
          title: fb.title,
          channel: fb.author,
          subscribers: 'Facebook Creator',
          duration: fb.duration,
          durationSeconds: 120,
          uploadTime: 'Facebook Video',
          viewCount: 'Direct Stream',
          license: 'Direct MP4 Stream',
          thumbnailUrl: fb.thumbnailUrl,
          platform: 'Facebook',
          badgeText: fb.resolutionLabel,
        );
      }
    }

    // 5. Check Instagram URL
    if (isInstagramUrl(trimmed)) {
      final ig = await resolveInstagramStream(trimmed);
      if (ig != null) {
        return DetectedMedia(
          title: ig.title,
          channel: ig.author,
          subscribers: 'Instagram Creator',
          duration: ig.duration,
          durationSeconds: 30,
          uploadTime: 'Instagram Reel',
          viewCount: 'Direct Stream',
          license: 'Direct MP4 Stream',
          thumbnailUrl: ig.thumbnailUrl,
          platform: 'Instagram',
          badgeText: ig.resolutionLabel,
        );
      } else {
        final shortcode = extractInstagramShortcode(trimmed) ?? 'Reel';
        return DetectedMedia(
          title: 'Instagram Post ($shortcode)',
          channel: 'Instagram',
          subscribers: 'Instagram Creator',
          duration: '00:30',
          durationSeconds: 30,
          uploadTime: 'Instagram Post',
          viewCount: 'Direct Stream',
          license: 'Direct MP4 Stream',
          thumbnailUrl: '',
          platform: 'Instagram',
          badgeText: 'HD MP4',
        );
      }
    }

    // 5. Check Streamable URL
    if (isStreamableUrl(trimmed)) {
      final st = await resolveStreamableStream(trimmed);
      if (st != null) {
        return DetectedMedia(
          title: st.title,
          channel: st.author,
          subscribers: 'Streamable Video',
          duration: st.duration,
          durationSeconds: 30,
          uploadTime: 'Streamable HD',
          viewCount: 'Direct MP4',
          license: 'Direct Stream',
          thumbnailUrl: st.thumbnailUrl,
          platform: 'Streamable',
          badgeText: st.resolutionLabel,
        );
      }
    }

    // 6. Check Direct Media File URL (.mp4, .webm, .m4a, .mp3, etc.)
    if (isDirectMediaUrl(trimmed)) {
      final domain = _extractCleanDomain(trimmed);
      final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
      final lastSeg = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media';
      final cleanTitle = Uri.decodeComponent(lastSeg.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''));
      final ext = lastSeg.contains('.') ? lastSeg.split('.').last.toUpperCase() : 'MP4';
      final isAudio = ['MP3', 'M4A', 'WAV', 'FLAC', 'AAC', 'OGG'].contains(ext);

      return DetectedMedia(
        title: cleanTitle.isNotEmpty ? cleanTitle : 'Direct $ext Stream',
        channel: domain,
        subscribers: 'Direct Media File',
        duration: 'Stream',
        durationSeconds: 180,
        uploadTime: '$ext Format',
        viewCount: 'Fast Direct Download',
        license: 'Direct Stream',
        thumbnailUrl: '',
        platform: domain,
        badgeText: isAudio ? 'Audio $ext' : 'HD $ext',
      );
    }

    // 6.5 Dynamic Link Resolver (Reddit, Vimeo, Dailymotion via Cloudflare Edge)
    if (isRedditUrl(trimmed) || RemoteRulesService.isVimeoUrl(trimmed) || RemoteRulesService.isDailymotionUrl(trimmed)) {
      try {
        final dlr = await RemoteRulesService.resolveViaDlr(trimmed);
        if (dlr != null && dlr.success) {
          return DetectedMedia(
            title: dlr.title,
            channel: dlr.author,
            subscribers: '${dlr.platform} Post',
            duration: dlr.durationFormatted,
            durationSeconds: dlr.durationSeconds > 0 ? dlr.durationSeconds : 60,
            uploadTime: dlr.platform,
            viewCount: 'Sound Included',
            license: 'Public Video',
            thumbnailUrl: dlr.thumbnailUrl,
            platform: dlr.platform,
            badgeText: dlr.bestResolution,
          );
        }
      } catch (_) {}
    }

    // 7. Generic Webpage Video Parser (og:video, HTML5 <video>)
    final webStream = await resolveGenericWebpageStream(trimmed);
    if (webStream != null) {
      return DetectedMedia(
        title: webStream.title,
        channel: webStream.author,
        subscribers: 'Web Media Extractor',
        duration: webStream.duration,
        durationSeconds: 180,
        uploadTime: 'Web Media',
        viewCount: 'Stream Ready',
        license: 'Web Stream',
        thumbnailUrl: webStream.thumbnailUrl,
        platform: webStream.platform,
        badgeText: webStream.resolutionLabel,
      );
    }

    // 8. Generic NoEmbed for Vimeo, SoundCloud, Reddit, etc.
    try {
      final noembedUri = Uri.parse('https://noembed.com/embed?url=${Uri.encodeComponent(trimmed)}');
      final response = await http.get(noembedUri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == null) {
          final title = data['title'] as String? ?? _extractCleanDomain(trimmed);
          final author = data['author_name'] as String? ?? data['provider_name'] as String? ?? 'Web Stream';
          final thumb = data['thumbnail_url'] as String? ?? '';
          final provider = data['provider_name'] as String? ?? 'Web Stream';

          return DetectedMedia(
            title: title,
            channel: author,
            subscribers: provider,
            duration: 'Stream',
            durationSeconds: 180,
            uploadTime: 'Direct Link',
            viewCount: 'Stream Ready',
            license: 'Web Source',
            thumbnailUrl: thumb,
            platform: provider,
            badgeText: 'HD Stream',
          );
        }
      }
    } catch (_) {}

    // 5. Fallback for direct media streams
    final domain = _extractCleanDomain(trimmed);
    return DetectedMedia(
      title: 'Media Stream ($domain)',
      channel: domain,
      subscribers: 'Direct URL',
      duration: 'Stream',
      durationSeconds: 180,
      uploadTime: 'Direct Link',
      viewCount: 'HTTP Stream',
      license: 'Direct Download',
      thumbnailUrl: '',
      platform: domain,
      badgeText: 'Direct',
    );
  }

  static String _extractCleanDomain(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return 'Web Media';
    }
  }
}
