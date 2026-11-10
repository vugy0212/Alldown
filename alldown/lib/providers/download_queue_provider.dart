import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/metadata_fetcher_service.dart';
import '../services/native_downloader_service.dart';
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

  Future<void> cancelAndClean({bool deleteFile = false}) async {
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
  final dynamic _storage;
  final NativeDownloaderService _nativeService;
  final Ref _ref;
  final Map<String, _ActiveDownloadJob> _activeJobs = {};

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

  Future<void> _startRealDownload(DownloadTask task) async {
    await _activeJobs.remove(task.id)?.cancelAndClean();

    final job = _ActiveDownloadJob();
    _activeJobs[task.id] = job;

    _nativeService.startForegroundService(title: task.title);

    try {
      final subFolder = task.isAudio ? 'Music' : 'Videos';
      final configuredDir = _ref.read(settingsProvider).downloadDirectory.trim();
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
          streamInfo = manifest.audioOnly.withHighestBitrate();
          actualResolution = '${(streamInfo.bitrate.kiloBitsPerSecond).toStringAsFixed(0)} kbps';
          actualFormat = streamInfo.container.name.toUpperCase();
          ext = streamInfo.container.name.toLowerCase();
        } else if (manifest.muxed.isNotEmpty) {
          // Select muxed stream matching user's chosen resolution if multiple exist
          final muxedList = manifest.muxed.toList()
            ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
          final targetRes = task.resolution.toLowerCase();
          if (targetRes.contains('480')) {
            final m480 = muxedList.where((s) => s.qualityLabel.contains('480') || s.qualityLabel.contains('360')).toList();
            streamInfo = m480.isNotEmpty ? m480.last : muxedList.first;
          } else if (targetRes.contains('720')) {
            final m720 = muxedList.where((s) => s.qualityLabel.contains('720')).toList();
            streamInfo = m720.isNotEmpty ? m720.last : muxedList.last;
          } else {
            streamInfo = muxedList.last;
          }
          actualResolution = '${task.resolution} (${streamInfo.qualityLabel})';
          actualFormat = 'MP4';
          ext = 'mp4';
        } else if (manifest.videoOnly.isNotEmpty) {
          streamInfo = manifest.videoOnly.withHighestBitrate();
          actualResolution = streamInfo.qualityLabel;
          actualFormat = 'MP4';
          ext = 'mp4';
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
        final req = http.Request('GET', Uri.parse(resolved.streamUrl));
        final resp = await client.send(req);
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
        final req = http.Request('GET', Uri.parse(resolved.streamUrl));
        final resp = await client.send(req);
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
        final req = http.Request('GET', Uri.parse(resolved.streamUrl));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        final resp = await client.send(req);
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
        final req = http.Request('GET', Uri.parse(resolved.streamUrl));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        final resp = await client.send(req);
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        totalBytes = resp.contentLength ?? 0;
        byteStream = resp.stream;
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
        final req = http.Request('GET', Uri.parse(targetDownloadUrl));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
        final resp = await client.send(req);
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

          if (activeCount == 0) {
            _nativeService.stopForegroundService();
          } else {
            _promoteNextQueued();
          }
        },
        onError: (e) async {
          await job.cancelAndClean(deleteFile: true);
          _activeJobs.remove(task.id);
          _updateTask(
            task.id,
            (t) => t.copyWith(
              status: DownloadStatus.paused,
              speed: "0.0 MB/s",
              eta: "Download Error - Tap Resume",
            ),
          );
          if (activeCount == 0) {
            _nativeService.stopForegroundService();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      await job.cancelAndClean(deleteFile: true);
      _activeJobs.remove(task.id);
      _updateTask(
        task.id,
        (t) => t.copyWith(
          status: DownloadStatus.paused,
          speed: "0.0 MB/s",
          eta: "Stream error - Tap Resume",
        ),
      );
      if (activeCount == 0) {
        _nativeService.stopForegroundService();
      }
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
