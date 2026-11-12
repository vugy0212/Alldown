import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/metadata_fetcher_service.dart';
import '../services/native_downloader_service.dart';
import '../services/remote_rules_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';
import 'media_library_provider.dart';

final nativeDownloaderServiceProvider = Provider<NativeDownloaderService>((ref) {
  return NativeDownloaderService();
});

final downloadQueueProvider = StateNotifierProvider<DownloadQueueNotifier, List<DownloadTask>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final nativeService = ref.watch(nativeDownloaderServiceProvider);
  return DownloadQueueNotifier(storage, nativeService, ref);
});

class _ActiveDownloadJob {
  StreamSubscription<List<int>>? subscription;
  IOSink? fileSink;
  YoutubeExplode? yt;
  http.Client? httpClient;
  String? filePath;
  bool isCancelled = false;

  Future<void> cancelAndClean({bool deleteFile = false}) async {
    isCancelled = true;
    await subscription?.cancel();
    await fileSink?.flush();
    await fileSink?.close();
    yt?.close();
    httpClient?.close();
    if (deleteFile && filePath != null) {
      final f = File(filePath!);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }
}

class DownloadQueueNotifier extends StateNotifier<List<DownloadTask>> {
  final StorageService _storage;
  final NativeDownloaderService _nativeService;
  final Ref _ref;
  final Map<String, _ActiveDownloadJob> _activeJobs = {};
  final Map<String, int> _retryCounts = {};

  DownloadQueueNotifier(this._storage, this._nativeService, this._ref)
      : super(_storage.loadQueue());

  int get activeCount => state.where((t) => t.status == DownloadStatus.active || t.status == DownloadStatus.converting).length;
  int get queuedCount => state.where((t) => t.status == DownloadStatus.queued).length;
  int get completedCount => state.where((t) => t.status == DownloadStatus.completed).length;
  int get pausedCount => state.where((t) => t.status == DownloadStatus.paused).length;

  double get aggregateSpeed {
    double sum = 0.0;
    for (final task in state) {
      if (task.status == DownloadStatus.active || task.status == DownloadStatus.converting) {
        final raw = task.speed.replaceAll(' MB/s', '').replaceAll(' KB/s', '');
        final val = double.tryParse(raw) ?? 0.0;
        if (task.speed.contains('KB/s')) {
          sum += val / 1024.0;
        } else {
          sum += val;
        }
      }
    }
    return sum;
  }

  static String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'media_${DateTime.now().millisecondsSinceEpoch}';
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    if (mb < 1.0) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  void addTask(DownloadTask task) {
    final maxConcurrent = _ref.read(settingsProvider).maxConcurrentDownloads;
    final shouldQueue = activeCount >= maxConcurrent;
    final initialTask = shouldQueue
        ? task.copyWith(status: DownloadStatus.queued, speed: "Queued", eta: "Waiting slot")
        : task;

    state = [initialTask, ...state];
    _storage.saveQueue(state);

    if (!shouldQueue) {
      _startRealDownload(initialTask);
    }
  }

  Future<http.StreamedResponse> _sendConfiguredRequest(
    http.Client client,
    String url,
    AppSettings settings, {
    Map<String, String>? extraHeaders,
  }) {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = settings.resolvedUserAgent;
    if (settings.cookiesActive && settings.cookiesHeader.isNotEmpty) {
      req.headers['Cookie'] = settings.cookiesHeader;
    }
    if (extraHeaders != null) {
      req.headers.addAll(extraHeaders);
    }
    return client
        .send(req)
        .timeout(Duration(seconds: settings.connectionTimeout.clamp(5, 120)));
  }

  Future<void> _startRealDownload(DownloadTask task) async {
    await _activeJobs.remove(task.id)?.cancelAndClean();

    final settings = _ref.read(settingsProvider);

    // Enforce Wi-Fi Only setting
    if (settings.wifiOnly) {
      final onWifi = await _nativeService.isWifiConnected();
      if (!onWifi) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.paused,
            speed: "0.0 MB/s",
            eta: "Waiting for Wi-Fi connection",
          ),
        );
        if (activeCount == 0) {
          _nativeService.stopForegroundService();
        }
        return;
      }
    }

    final job = _ActiveDownloadJob();
    _activeJobs[task.id] = job;

    _nativeService.startForegroundService(title: task.title);

    try {
      final subFolder = task.isAudio ? 'Music' : 'Videos';
      final configuredDir = AppSettings.normalizeDirectoryPath(settings.downloadDirectory);
      Directory targetDir;
      bool isCustom = false;

      if (configuredDir.isNotEmpty && !configuredDir.startsWith('/storage/emulated/0/Download/AllDown')) {
        targetDir = Directory('$configuredDir/$subFolder');
        try {
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          isCustom = true;
        } catch (_) {
          final appDocDir = await getApplicationDocumentsDirectory();
          targetDir = Directory('${appDocDir.path}/AllDown/$subFolder');
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
        }
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${appDocDir.path}/AllDown/$subFolder');
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
      }

      final ytId = MetadataFetcherService.extractYouTubeId(task.url);
      final twitterId = MetadataFetcherService.extractTwitterStatusId(task.url);
      final isTikTok = MetadataFetcherService.isTikTokUrl(task.url);
      final isFacebook = MetadataFetcherService.isFacebookUrl(task.url);
      final isStreamable = MetadataFetcherService.isStreamableUrl(task.url);
      final isDirectMedia = MetadataFetcherService.isDirectMediaUrl(task.url);

      Stream<List<int>> byteStream;
      int totalBytes = 0;
      String actualResolution = task.resolution;
      String actualFormat = task.isAudio ? 'M4A' : 'MP4';
      String ext = task.isAudio ? 'm4a' : 'mp4';
      String realDuration = task.duration;
      String realTitle = task.title;
      String realChannel = task.platform;
      String realThumb = task.thumbnailUrl;
      String realPlatform = task.platform;

      if (ytId != null) {
        final yt = YoutubeExplode();
        job.yt = yt;

        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Extracting YouTube stream...",
            eta: "Connecting...",
            progress: 0.02,
          ),
        );

        try {
          final video = await yt.videos.get(ytId);
          realTitle = video.title;
          realChannel = video.author;
          realDuration = MetadataFetcherService.formatDuration(video.duration);
          realThumb = 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg';
          realPlatform = 'YouTube';
        } catch (_) {}

        final manifest = await yt.videos.streamsClient.getManifest(ytId);

        StreamInfo streamInfo;
        if (task.isAudio && manifest.audioOnly.isNotEmpty) {
          final audioList = manifest.audioOnly.toList()
            ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
          final preferWebm = settings.audioCodec == AudioCodec.opus;
          final codecFiltered = audioList.where((s) =>
              preferWebm ? s.container.name.toLowerCase().contains('webm') : !s.container.name.toLowerCase().contains('webm')).toList();
          final candidates = codecFiltered.isNotEmpty ? codecFiltered : audioList;
          if (settings.audioBitrate.startsWith('128')) {
            streamInfo = candidates.first;
          } else if (settings.audioBitrate.startsWith('192') && candidates.length > 1) {
            streamInfo = candidates[candidates.length ~/ 2];
          } else {
            streamInfo = candidates.last;
          }
          actualResolution = '${(streamInfo.bitrate.kiloBitsPerSecond).toStringAsFixed(0)} kbps';
          actualFormat = streamInfo.container.name.toUpperCase();
          ext = streamInfo.container.name.toLowerCase();
        } else if (manifest.muxed.isNotEmpty) {
          // Select muxed stream matching user's chosen resolution & global maxResolution cap
          final muxedList = manifest.muxed.toList()
            ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
          final targetRes = task.resolution.toLowerCase();
          final cap720 = settings.maxResolution == MaxResolution.res720p;
          if (targetRes.contains('480')) {
            final m480 = muxedList.where((s) => s.qualityLabel.contains('480') || s.qualityLabel.contains('360')).toList();
            streamInfo = m480.isNotEmpty ? m480.last : muxedList.first;
          } else if (targetRes.contains('720') || cap720) {
            final m720 = muxedList.where((s) => s.qualityLabel.contains('720') || s.qualityLabel.contains('480')).toList();
            streamInfo = m720.isNotEmpty ? m720.last : muxedList.last;
          } else {
            streamInfo = muxedList.last;
          }
          actualResolution = '${task.resolution} (${streamInfo.qualityLabel})';
          actualFormat = settings.autoRemuxToMp4 ? 'MP4' : settings.videoContainer.toUpperCase();
          ext = actualFormat.toLowerCase();
        } else if (manifest.videoOnly.isNotEmpty) {
          streamInfo = manifest.videoOnly.withHighestBitrate();
          actualResolution = streamInfo.qualityLabel;
          actualFormat = settings.autoRemuxToMp4 ? 'MP4' : settings.videoContainer.toUpperCase();
          ext = actualFormat.toLowerCase();
        } else {
          throw Exception('No downloadable streams found for this YouTube video.');
        }

        totalBytes = streamInfo.size.totalBytes;
        byteStream = yt.videos.streamsClient.get(streamInfo);
      } else if (twitterId != null) {
        // X (Twitter) real MP4 video extractor
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Extracting X video stream...",
            eta: "Resolving MP4...",
            progress: 0.03,
          ),
        );

        final resolved = await MetadataFetcherService.resolveTwitterStream(
          twitterId,
          preferredResolution: task.resolution,
        );
        if (resolved == null) {
          throw Exception('Could not extract MP4 video from this X post.');
        }

        realTitle = resolved.title;
        realChannel = resolved.author;
        realDuration = resolved.duration;
        if (resolved.thumbnailUrl.isNotEmpty) {
          realThumb = resolved.thumbnailUrl;
        }
        actualResolution = resolved.resolutionLabel;
        realPlatform = 'X (Twitter)';

        final client = http.Client();
        job.httpClient = client;
        final resp = await _sendConfiguredRequest(client, resolved.streamUrl, settings);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
      } else if (isTikTok) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Extracting TikTok video...",
            eta: "Resolving MP4...",
            progress: 0.03,
          ),
        );

        final resolved = await MetadataFetcherService.resolveTikTokStream(task.url);
        if (resolved == null) {
          throw Exception('Could not extract TikTok MP4 stream.');
        }

        realTitle = resolved.title;
        realChannel = resolved.author;
        realDuration = resolved.duration;
        if (resolved.thumbnailUrl.isNotEmpty) {
          realThumb = resolved.thumbnailUrl;
        }
        actualResolution = resolved.resolutionLabel;
        realPlatform = 'TikTok';

        final client = http.Client();
        job.httpClient = client;
        final resp = await _sendConfiguredRequest(client, resolved.streamUrl, settings);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
      } else if (isFacebook) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Extracting Facebook video...",
            eta: "Resolving MP4...",
            progress: 0.03,
          ),
        );

        final resolved = await MetadataFetcherService.resolveFacebookStream(
          task.url,
          preferredResolution: task.resolution,
        );
        if (resolved == null) {
          throw Exception('Could not extract direct MP4 from this Facebook video.');
        }

        realTitle = resolved.title;
        realChannel = resolved.author;
        realDuration = resolved.duration;
        if (resolved.thumbnailUrl.isNotEmpty) {
          realThumb = resolved.thumbnailUrl;
        }
        actualResolution = resolved.resolutionLabel;
        realPlatform = 'Facebook';

        final client = http.Client();
        job.httpClient = client;
        final resp = await _sendConfiguredRequest(client, resolved.streamUrl, settings);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
      } else if (isStreamable) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Extracting Streamable video...",
            eta: "Resolving MP4...",
            progress: 0.03,
          ),
        );

        final resolved = await MetadataFetcherService.resolveStreamableStream(task.url);
        if (resolved == null) {
          throw Exception('Could not extract Streamable MP4 stream.');
        }

        realTitle = resolved.title;
        realChannel = resolved.author;
        realDuration = resolved.duration;
        if (resolved.thumbnailUrl.isNotEmpty) {
          realThumb = resolved.thumbnailUrl;
        }
        actualResolution = resolved.resolutionLabel;
        realPlatform = 'Streamable';

        final client = http.Client();
        job.httpClient = client;
        final resp = await _sendConfiguredRequest(client, resolved.streamUrl, settings);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
      } else if (RemoteRulesService.isVimeoUrl(task.url)) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Connecting to Vimeo...",
            eta: "Checking stream permissions...",
            progress: 0.04,
          ),
        );

        final vimeoId = RemoteRulesService.extractVimeoId(task.url);
        if (vimeoId == null) {
          throw Exception('Invalid Vimeo video link.');
        }

        final configRes = await _nativeService.nativeHttpGet(
          url: 'https://player.vimeo.com/video/$vimeoId/config',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
            'Referer': 'https://vimeo.com/',
          },
        );

        if (configRes == null || configRes['statusCode'] != 200) {
          throw Exception('Could not fetch Vimeo configuration.');
        }

        final configJson = jsonDecode(configRes['body'] as String) as Map<String, dynamic>;
        final videoInfo = configJson['video'] as Map<String, dynamic>?;
        if (videoInfo != null) {
          final t = (videoInfo['title'] as String? ?? '').trim();
          if (t.isNotEmpty) realTitle = t;
          final thumbs = videoInfo['thumbs'] as Map<String, dynamic>?;
          if (thumbs != null && thumbs.isNotEmpty) {
            realThumb = thumbs.values.last.toString();
          }
          final dur = videoInfo['duration'];
          if (dur is num) {
            realDuration = MetadataFetcherService.formatDuration(Duration(seconds: dur.toInt()));
          }
        }

        final files = configJson['request']?['files'] as Map<String, dynamic>?;
        final progressive = (files?['progressive'] as List?) ?? [];

        if (progressive.isNotEmpty) {
          final progressiveList = progressive.whereType<Map<String, dynamic>>().toList();
          progressiveList.sort((a, b) => ((b['height'] as num?)?.toInt() ?? 0).compareTo((a['height'] as num?)?.toInt() ?? 0));
          final chosen = progressiveList.first;
          final directMp4Url = chosen['url'] as String;
          actualResolution = '${chosen['height']}p';
          realPlatform = 'Vimeo';

          final client = http.Client();
          job.httpClient = client;
          final resp = await _sendConfiguredRequest(client, directMp4Url, settings);
          if (resp.statusCode >= 400) {
            throw Exception('HTTP ${resp.statusCode}');
          }
          totalBytes = resp.contentLength ?? 0;
          byteStream = resp.stream;
        } else {
          throw Exception('DRM_VIMEO: Ovaj Vimeo video je zaštićen autorskim DRM pravima i autor nije omogućio preuzimanje.');
        }
      } else if (RemoteRulesService.isDailymotionUrl(task.url)) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            speed: "Connecting to Dailymotion...",
            eta: "Resolving metadata...",
            progress: 0.03,
          ),
        );

        final dlr = await RemoteRulesService.resolveViaDlr(task.url);
        if (dlr != null && dlr.success) {
          realTitle = dlr.title;
          realChannel = dlr.author;
          realDuration = dlr.durationFormatted;
          if (dlr.thumbnailUrl.isNotEmpty) {
            realThumb = dlr.thumbnailUrl;
          }
          actualResolution = dlr.bestResolution;
          realPlatform = dlr.platform;
        }

        await _downloadHlsSegments(
          job: job,
          task: task,
          dlr: dlr,
          targetDir: targetDir,
          isCustom: isCustom,
          subFolder: subFolder,
          settings: settings,
          realTitle: realTitle,
          realChannel: realChannel,
          realThumb: realThumb,
          realDuration: realDuration,
          actualResolution: actualResolution,
          realPlatform: realPlatform,
        );
        return;
      } else {
        // Direct media URL or generic webpage containing video/audio
        ResolvedDirectStream? resolvedStream;
        if (!isDirectMedia) {
          _updateTask(
            task.id,
            (t) => t.copyWith(
              speed: "Scanning webpage for media streams...",
              eta: "Resolving...",
              progress: 0.03,
            ),
          );
          resolvedStream = await MetadataFetcherService.resolveGenericWebpageStream(task.url);
        }

        final targetDownloadUrl = resolvedStream != null ? resolvedStream.streamUrl : task.url;
        if (resolvedStream != null) {
          realTitle = resolvedStream.title;
          realChannel = resolvedStream.author;
          if (resolvedStream.thumbnailUrl.isNotEmpty) {
            realThumb = resolvedStream.thumbnailUrl;
          }
          realPlatform = resolvedStream.platform;
          actualResolution = resolvedStream.resolutionLabel;
        }

        final client = http.Client();
        job.httpClient = client;
        final resp = await _sendConfiguredRequest(client, targetDownloadUrl, settings);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
        if (contentType.contains('text/html')) {
          throw Exception('URL points to a webpage with no downloadable media stream.');
        }

        if (contentType.contains('webm')) {
          ext = 'webm';
          actualFormat = 'WEBM';
        } else if (contentType.contains('audio/mpeg') || contentType.contains('audio/mp3')) {
          ext = 'mp3';
          actualFormat = 'MP3';
        } else if (contentType.contains('audio/mp4') || contentType.contains('audio/m4a') || contentType.contains('audio/aac')) {
          ext = 'm4a';
          actualFormat = 'M4A';
        } else if (contentType.contains('video/mp4')) {
          ext = 'mp4';
          actualFormat = 'MP4';
        }

        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
        realChannel = Uri.tryParse(targetDownloadUrl)?.host.replaceFirst('www.', '') ?? realChannel;
      }

      final safeName = _sanitizeFileName(realTitle);
      final savePath = '${targetDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      job.filePath = savePath;
      final file = File(savePath);
      final sink = file.openWrite();
      job.fileSink = sink;

      final totalFormatted = totalBytes > 0 ? _formatBytes(totalBytes) : task.totalBytes;

      _updateTask(
        task.id,
        (t) => t.copyWith(
          title: realTitle,
          thumbnailUrl: realThumb,
          duration: realDuration,
          resolution: actualResolution,
          format: actualFormat,
          platform: realPlatform,
          sizeFormatted: totalFormatted,
          totalBytes: totalFormatted,
          status: DownloadStatus.active,
        ),
      );

      int receivedBytes = 0;
      final stopwatch = Stopwatch()..start();
      int lastUpdateMs = 0;

      job.subscription = byteStream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          final nowMs = stopwatch.elapsedMilliseconds;
          if (nowMs - lastUpdateMs >= 350 || (totalBytes > 0 && receivedBytes >= totalBytes)) {
            lastUpdateMs = nowMs;
            final prog = totalBytes > 0
                ? (receivedBytes / totalBytes).clamp(0.01, 0.99)
                : 0.5;
            final elapsedSec = (nowMs / 1000.0).clamp(0.1, 86400.0);
            final bytesPerSec = receivedBytes / elapsedSec;
            final mbPerSec = bytesPerSec / (1024 * 1024);
            final speedStr = mbPerSec >= 0.1
                ? '${mbPerSec.toStringAsFixed(1)} MB/s'
                : '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';

            String etaStr = 'Downloading...';
            if (totalBytes > 0 && bytesPerSec > 0) {
              final remSec = ((totalBytes - receivedBytes) / bytesPerSec).round().clamp(0, 3599);
              final m = (remSec ~/ 60).toString().padLeft(2, '0');
              final s = (remSec % 60).toString().padLeft(2, '0');
              etaStr = '$m:$s remaining';
            }

            _nativeService.updateNotificationProgress(
              title: realTitle,
              progress: (prog * 100).toInt(),
              speed: speedStr,
              eta: etaStr,
            );

            _updateTask(
              task.id,
              (t) => t.copyWith(
                progress: prog,
                downloadedBytes: _formatBytes(receivedBytes),
                totalBytes: totalFormatted,
                speed: speedStr,
                eta: etaStr,
              ),
            );
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          job.yt?.close();
          job.httpClient?.close();
          _activeJobs.remove(task.id);

          final finalSize = file.existsSync() ? file.lengthSync() : receivedBytes;
          final finalSizeStr = _formatBytes(finalSize);

          String finalPath = savePath;
          if (!isCustom) {
            try {
              final pubDir = Directory('/storage/emulated/0/Download/AllDown/$subFolder');
              if (!pubDir.existsSync()) {
                pubDir.createSync(recursive: true);
              }
              final pubFile = File('${pubDir.path}/$safeName.$ext');
              file.copySync(pubFile.path);
            } catch (_) {}
          }

          _updateTask(
            task.id,
            (t) => t.copyWith(
              progress: 1.0,
              status: DownloadStatus.completed,
              downloadedBytes: finalSizeStr,
              totalBytes: finalSizeStr,
              sizeFormatted: finalSizeStr,
              speed: "0.0 MB/s",
              eta: "Completed",
            ),
          );

          _ref.read(mediaLibraryProvider.notifier).addItem(
            MediaItem(
              id: "lib_${task.id}",
              title: realTitle,
              channel: realChannel,
              duration: realDuration,
              thumbnailUrl: realThumb,
              localPath: finalPath,
              format: actualFormat,
              resolution: actualResolution,
              sizeFormatted: finalSizeStr,
              completedDateFormatted: "Completed Just Now",
              isAudio: task.isAudio,
              platform: realPlatform,
            ),
          );

          _retryCounts.remove(task.id);

          if (settings.notifyOnComplete) {
            _nativeService.showCompletionNotification(title: realTitle);
          }

          if (activeCount == 0) {
            _nativeService.stopForegroundService();
          } else {
            _promoteNextQueued();
          }
        },
        onError: (e) async {
          await job.cancelAndClean(deleteFile: true);
          _activeJobs.remove(task.id);
          await _handleFailureOrRetry(task, settings, "Download Error - Tap Resume");
        },
        cancelOnError: true,
      );
    } catch (e, stack) {
      await job.cancelAndClean(deleteFile: true);
      _activeJobs.remove(task.id);
      final errorMsg = e.toString();
      // ignore: avoid_print
      print('ALLDOWN_TASK_ERROR: $errorMsg\n$stack');
      if (errorMsg.contains('DRM_VIMEO') || errorMsg.contains('DRM_PROTECTED')) {
        _retryCounts.remove(task.id);
        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.paused,
            speed: "0.0 MB/s",
            eta: "DRM zaštićeno (autor ne dopušta preuzimanje)",
          ),
        );
        return;
      }
      final cleanMsg = errorMsg.replaceAll('Exception: ', '').trim();
      await _handleFailureOrRetry(task, settings, cleanMsg.isNotEmpty ? cleanMsg : "Stream error");
    }
  }

  Future<void> _handleFailureOrRetry(
    DownloadTask task,
    AppSettings settings,
    String fallbackMessage,
  ) async {
    final currentRetries = _retryCounts[task.id] ?? 0;
    if (settings.autoRetry && currentRetries < 2) {
      final nextRetry = currentRetries + 1;
      _retryCounts[task.id] = nextRetry;
      _updateTask(
        task.id,
        (t) => t.copyWith(
          status: DownloadStatus.active,
          speed: "Auto-Retrying...",
          eta: "Retry attempt $nextRetry/2...",
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _startRealDownload(task);
      }
      return;
    }

    _retryCounts.remove(task.id);
    _updateTask(
      task.id,
      (t) => t.copyWith(
        status: DownloadStatus.paused,
        speed: "0.0 MB/s",
        eta: fallbackMessage,
      ),
    );
    if (activeCount == 0) {
      _nativeService.stopForegroundService();
    }
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    if (!mounted) return;
    state = state.map((t) => t.id == id ? updater(t) : t).toList();
    _storage.saveQueue(state);
  }

  void _promoteNextQueued() {
    final queuedIndex = state.indexWhere((t) => t.status == DownloadStatus.queued);
    if (queuedIndex != -1) {
      final promoted = state[queuedIndex];
      startTaskNow(promoted.id);
    }
  }

  void pauseTask(String id) {
    final job = _activeJobs[id];
    job?.subscription?.pause();
    _updateTask(
      id,
      (t) => t.copyWith(status: DownloadStatus.paused, speed: "0.0 MB/s", eta: "Paused"),
    );
    if (activeCount == 0) {
      _nativeService.stopForegroundService();
    }
  }

  void resumeTask(String id) {
    final job = _activeJobs[id];
    if (job != null && job.subscription != null) {
      job.subscription!.resume();
      _updateTask(
        id,
        (t) => t.copyWith(status: DownloadStatus.active, eta: "Resuming..."),
      );
    } else {
      final taskIndex = state.indexWhere((t) => t.id == id);
      if (taskIndex != -1) {
        final task = state[taskIndex].copyWith(status: DownloadStatus.active, eta: "Reconnecting...");
        _updateTask(id, (_) => task);
        _startRealDownload(task);
      }
    }
  }

  void cancelTask(String id) async {
    final job = _activeJobs.remove(id);
    await job?.cancelAndClean(deleteFile: true);
    state = state.where((t) => t.id != id).toList();
    _storage.saveQueue(state);
    if (activeCount == 0) {
      _nativeService.stopForegroundService();
    }
  }

  void startTaskNow(String id) {
    final idx = state.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final task = state[idx].copyWith(
        status: DownloadStatus.active,
        speed: "Connecting...",
        eta: "Starting...",
      );
      _updateTask(id, (_) => task);
      _startRealDownload(task);
    }
  }

  void boostPriority(String id) {
    _updateTask(id, (t) => t.copyWith(priority: 1));
    autoOrderQueue();
  }

  void autoOrderQueue() {
    int statusWeight(DownloadStatus s) {
      switch (s) {
        case DownloadStatus.active:
        case DownloadStatus.converting:
          return 0;
        case DownloadStatus.queued:
          return 1;
        case DownloadStatus.paused:
        case DownloadStatus.failed:
          return 2;
        case DownloadStatus.completed:
          return 3;
      }
    }

    final sorted = [...state]..sort((a, b) {
      final wCmp = statusWeight(a.status).compareTo(statusWeight(b.status));
      if (wCmp != 0) return wCmp;
      return b.priority.compareTo(a.priority);
    });
    state = sorted;
    _storage.saveQueue(state);
  }

  Future<void> _downloadHlsSegments({
    required _ActiveDownloadJob job,
    required DownloadTask task,
    required DlrResolvedMedia? dlr,
    required Directory targetDir,
    required bool isCustom,
    required String subFolder,
    required AppSettings settings,
    required String realTitle,
    required String realChannel,
    required String realThumb,
    required String realDuration,
    required String actualResolution,
    required String realPlatform,
  }) async {
    final client = http.Client();
    job.httpClient = client;

    try {
      String masterM3u8Url = dlr?.bestStreamUrl ?? '';

      // Direct metadata fetch from device IP for Dailymotion (fixes IP-bound token 403 E030)
      if (RemoteRulesService.isDailymotionUrl(task.url) || (dlr != null && dlr.platform.toLowerCase().contains('daily'))) {
        final dailyId = RemoteRulesService.extractDailymotionId(task.url);
        if (dailyId != null) {
          _updateTask(
            task.id,
            (t) => t.copyWith(speed: "Dailymotion Token...", eta: "Generating device token..."),
          );
          final metaRes = await _nativeService.nativeHttpGet(
            url: 'https://www.dailymotion.com/player/metadata/video/$dailyId?app=com.dailymotion.neon',
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
              'Accept': 'application/json',
            },
          );
          if (metaRes != null && metaRes['statusCode'] == 200) {
            try {
              final root = jsonDecode(metaRes['body'] as String) as Map<String, dynamic>;
              final autoList = root['qualities']?['auto'] as List?;
              if (autoList != null && autoList.isNotEmpty) {
                final directUrl = autoList[0]['url'] as String?;
                if (directUrl != null && directUrl.isNotEmpty) {
                  masterM3u8Url = directUrl;
                }
              }
              final t = root['title'] as String?;
              if (t != null && t.isNotEmpty) realTitle = t;
              final owner = root['owner'] as Map<String, dynamic>?;
              if (owner != null) {
                realChannel = owner['screenname'] as String? ?? owner['username'] as String? ?? realChannel;
              }
              final posters = root['posters'] as Map<String, dynamic>?;
              if (posters != null && posters.isNotEmpty) {
                realThumb = posters.values.last.toString();
              }
              final dur = root['duration'];
              if (dur is num) {
                realDuration = MetadataFetcherService.formatDuration(Duration(seconds: dur.toInt()));
              }
            } catch (_) {}
          }
        }
      }

      if (masterM3u8Url.isEmpty) {
        throw Exception('No playable HLS stream found.');
      }

      // 1. Fetch master M3U8 (try webViewFetch first to bypass Cloudflare bot check, fallback to nativeHttpGet)
      String masterBody = '';
      Map<String, dynamic>? masterRes;
      try {
        masterRes = await _nativeService.webViewFetch(url: masterM3u8Url);
      } catch (_) {}
      if (masterRes == null || (masterRes['statusCode'] as int? ?? 0) < 200 || (masterRes['statusCode'] as int? ?? 0) >= 300) {
        masterRes = await _nativeService.nativeHttpGet(
          url: masterM3u8Url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
            'Sec-Fetch-Mode': 'cors',
            'Accept': '*/*',
          },
        );
      }

      final masterCode = masterRes?['statusCode'] as int? ?? 0;
      if (masterCode >= 200 && masterCode < 300) {
        masterBody = masterRes!['body'] as String? ?? '';
      } else {
        throw Exception('HLS Master Manifest HTTP $masterCode');
      }

      if (masterBody.contains('METHOD=SAMPLE-AES') || masterBody.contains('skd://drm') || masterM3u8Url.contains('/playlist/drm/')) {
        throw Exception('DRM_PROTECTED: Ovaj video je zaštićen DRM enkripcijom.');
      }

      String mediaPlaylistUrl = masterM3u8Url;
      final masterLines = masterBody.split('\n').map((l) => l.trim()).toList();
      if (masterLines.any((l) => l.startsWith('#EXT-X-STREAM-INF'))) {
        final variants = <Map<String, dynamic>>[];
        for (int i = 0; i < masterLines.length; i++) {
          if (masterLines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < masterLines.length) {
            final inf = masterLines[i];
            final nextLine = masterLines[i + 1];
            if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
              final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(inf);
              final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;
              variants.add({'bw': bw, 'url': nextLine});
            }
          }
        }
        if (variants.isNotEmpty) {
          variants.sort((a, b) => (b['bw'] as int).compareTo(a['bw'] as int));
          mediaPlaylistUrl = Uri.parse(masterM3u8Url).resolve(variants.first['url'] as String).toString();
        }
      }

      // 2. Fetch media segments playlist (try webViewFetch first, fallback to nativeHttpGet)
      String mediaBody = '';
      Map<String, dynamic>? subRes;
      try {
        subRes = await _nativeService.webViewFetch(url: mediaPlaylistUrl);
      } catch (_) {}
      if (subRes == null || (subRes['statusCode'] as int? ?? 0) < 200 || (subRes['statusCode'] as int? ?? 0) >= 300) {
        subRes = await _nativeService.nativeHttpGet(
          url: mediaPlaylistUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
            'Sec-Fetch-Mode': 'cors',
            'Accept': '*/*',
          },
        );
      }

      final subCode = subRes?['statusCode'] as int? ?? 0;
      if (subCode >= 200 && subCode < 300) {
        mediaBody = subRes!['body'] as String? ?? '';
      } else {
        throw Exception('HLS Media Playlist HTTP $subCode');
      }

      if (mediaBody.contains('METHOD=SAMPLE-AES') || mediaBody.contains('skd://drm')) {
        throw Exception('DRM_PROTECTED: Ovaj video je zaštićen DRM enkripcijom.');
      }

      final mediaLines = mediaBody.split('\n').map((l) => l.trim()).toList();
      final segmentUris = <Uri>[];
      final baseUri = Uri.parse(mediaPlaylistUrl);
      for (final line in mediaLines) {
        if (line.isNotEmpty && !line.startsWith('#')) {
          segmentUris.add(baseUri.resolve(line));
        }
      }

      if (segmentUris.isEmpty) {
        throw Exception('No playable video segments found in HLS stream.');
      }

      final safeName = _sanitizeFileName(realTitle);
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final savePath = '${targetDir.path}/${safeName}_$timeStamp.mp4';
      job.filePath = savePath;
      final file = File(savePath);
      if (file.existsSync()) file.deleteSync();

      _updateTask(
        task.id,
        (t) => t.copyWith(
          title: realTitle,
          thumbnailUrl: realThumb,
          duration: realDuration,
          resolution: actualResolution,
          format: 'MP4',
          platform: realPlatform,
          status: DownloadStatus.active,
        ),
      );

      int receivedBytes = 0;
      final stopwatch = Stopwatch()..start();
      final totalSegs = segmentUris.length;

      for (int i = 0; i < totalSegs; i++) {
        if (job.isCancelled) return;
        final segUriStr = segmentUris[i].toString();
        bool segSuccess = false;
        for (int retry = 0; retry < 3; retry++) {
          segSuccess = await _nativeService.nativeDownloadFile(
            url: segUriStr,
            outputPath: savePath,
            append: true,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
              'Sec-Fetch-Mode': 'cors',
            },
          );
          if (segSuccess) break;
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (!segSuccess) {
          throw Exception('Failed to download segment ${i + 1}/$totalSegs');
        }

        final currentSize = file.existsSync() ? file.lengthSync() : (receivedBytes + 250000);
        receivedBytes = currentSize;

        final prog = (i + 1) / totalSegs;
        final elapsedSec = (stopwatch.elapsedMilliseconds / 1000.0).clamp(0.1, 86400.0);
        final bytesPerSec = receivedBytes / elapsedSec;
        final mbPerSec = bytesPerSec / (1024 * 1024);
        final speedStr = mbPerSec >= 0.1
            ? '${mbPerSec.toStringAsFixed(1)} MB/s'
            : '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';

        final estTotalBytes = (receivedBytes / prog).round();
        final estTotalStr = _formatBytes(estTotalBytes);

        _updateTask(
          task.id,
          (t) => t.copyWith(
            progress: prog.clamp(0.01, 0.99),
            downloadedBytes: _formatBytes(receivedBytes),
            totalBytes: estTotalStr,
            sizeFormatted: estTotalStr,
            speed: speedStr,
            eta: '${i + 1}/$totalSegs parts',
          ),
        );

        _nativeService.updateNotificationProgress(
          title: realTitle,
          progress: (prog * 100).toInt(),
          speed: speedStr,
          eta: '${i + 1}/$totalSegs parts',
        );
      }

      client.close();
      _activeJobs.remove(task.id);

      final finalSize = file.existsSync() ? file.lengthSync() : receivedBytes;
      final finalSizeStr = _formatBytes(finalSize);

      String finalPath = savePath;
      if (!isCustom) {
        try {
          final pubDir = Directory('/storage/emulated/0/Download/AllDown/$subFolder');
          if (!pubDir.existsSync()) {
            pubDir.createSync(recursive: true);
          }
          final pubFile = File('${pubDir.path}/$safeName.mp4');
          file.copySync(pubFile.path);
          finalPath = pubFile.path;
        } catch (_) {}
      }

      _updateTask(
        task.id,
        (t) => t.copyWith(
          progress: 1.0,
          status: DownloadStatus.completed,
          downloadedBytes: finalSizeStr,
          totalBytes: finalSizeStr,
          sizeFormatted: finalSizeStr,
          speed: "0.0 MB/s",
          eta: "Completed",
        ),
      );

      _ref.read(mediaLibraryProvider.notifier).addItem(
        MediaItem(
          id: "lib_${task.id}",
          title: realTitle,
          channel: realChannel,
          duration: realDuration,
          thumbnailUrl: realThumb,
          localPath: finalPath,
          format: 'MP4',
          resolution: actualResolution,
          sizeFormatted: finalSizeStr,
          completedDateFormatted: "Completed Just Now",
          isAudio: task.isAudio,
          platform: realPlatform,
        ),
      );

      _retryCounts.remove(task.id);

      if (settings.notifyOnComplete) {
        _nativeService.showCompletionNotification(title: realTitle);
      }

      if (activeCount == 0) {
        _nativeService.stopForegroundService();
      } else {
        _promoteNextQueued();
      }
    } catch (e, stack) {
      await job.cancelAndClean(deleteFile: true);
      _activeJobs.remove(task.id);
      final errorMsg = e.toString();
      // ignore: avoid_print
      print('ALLDOWN_TASK_ERROR: $errorMsg\n$stack');
      if (errorMsg.contains('DRM_VIMEO') || errorMsg.contains('DRM_PROTECTED')) {
        _retryCounts.remove(task.id);
        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.paused,
            speed: "0.0 MB/s",
            eta: "DRM zaštićeno (autor ne dopušta preuzimanje)",
          ),
        );
        return;
      }
      final cleanMsg = errorMsg.replaceAll('Exception: ', '').trim();
      await _handleFailureOrRetry(task, settings, cleanMsg.isNotEmpty ? cleanMsg : "Stream error");
    }
  }

  void pauseAll() {
    for (final entry in _activeJobs.entries) {
      entry.value.subscription?.pause();
    }
    state = state.map((t) {
      if (t.status == DownloadStatus.active || t.status == DownloadStatus.converting) {
        return t.copyWith(status: DownloadStatus.paused, speed: "0.0 MB/s", eta: "Paused");
      }
      return t;
    }).toList();
    _storage.saveQueue(state);
    _nativeService.stopForegroundService();
  }

  void resumeAll() {
    for (final t in state) {
      if (t.status == DownloadStatus.paused) {
        resumeTask(t.id);
      }
    }
  }

  void clearFinished() {
    state = state.where((t) => t.status != DownloadStatus.completed).toList();
    _storage.saveQueue(state);
  }

  @override
  void dispose() {
    for (final job in _activeJobs.values) {
      job.cancelAndClean();
    }
    super.dispose();
  }
}
