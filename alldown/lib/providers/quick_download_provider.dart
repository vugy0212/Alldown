import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_options.dart';
import '../models/download_task.dart';
import '../services/metadata_fetcher_service.dart';
import 'download_queue_provider.dart';

class DetectedMedia {
  final String title;
  final String channel;
  final String subscribers;
  final String duration;
  final int durationSeconds;
  final String uploadTime;
  final String viewCount;
  final String license;
  final String thumbnailUrl;
  final String platform;
  final String badgeText;

  const DetectedMedia({
    required this.title,
    required this.channel,
    required this.subscribers,
    required this.duration,
    this.durationSeconds = 210,
    required this.uploadTime,
    required this.viewCount,
    required this.license,
    required this.thumbnailUrl,
    required this.platform,
    required this.badgeText,
  });

  String estimateSizeForQuality(VideoQuality quality, bool isAudio, [AudioQuality audioQuality = AudioQuality.kbps320]) {
    final mins = (durationSeconds / 60.0).clamp(0.5, 300.0);
    if (isAudio) {
      double rate = 2.4;
      switch (audioQuality) {
        case AudioQuality.kbps320:
          rate = 2.4;
          break;
        case AudioQuality.kbps256:
          rate = 1.9;
          break;
        case AudioQuality.kbps192:
          rate = 1.4;
          break;
        case AudioQuality.kbps128:
          rate = 1.0;
          break;
      }
      final mb = (mins * rate).clamp(0.8, 500.0);
      return '${mb.toStringAsFixed(1)} MB';
    }
    switch (quality) {
      case VideoQuality.res4k:
        final mb = (mins * 45.0).clamp(15.0, 8000.0);
        return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(0)} MB';
      case VideoQuality.res1080p:
        final mb = (mins * 12.0).clamp(5.0, 2000.0);
        return '${mb.toStringAsFixed(1)} MB';
      case VideoQuality.res720p:
        final mb = (mins * 6.5).clamp(3.0, 1000.0);
        return '${mb.toStringAsFixed(1)} MB';
      case VideoQuality.res480p:
        final mb = (mins * 3.2).clamp(1.5, 500.0);
        return '${mb.toStringAsFixed(1)} MB';
    }
  }
}

class QuickDownloadState {
  final String url;
  final bool isAnalyzing;
  final bool isReady;
  final String analyzeButtonText;
  final DetectedMedia? detectedMedia;
  final DownloadOptions options;
  final bool isDownloadAdded;

  const QuickDownloadState({
    this.url = "",
    this.isAnalyzing = false,
    this.isReady = false,
    this.analyzeButtonText = "Fetch & Analyze Media",
    this.detectedMedia,
    this.options = const DownloadOptions(),
    this.isDownloadAdded = false,
  });

  QuickDownloadState copyWith({
    String? url,
    bool? isAnalyzing,
    bool? isReady,
    String? analyzeButtonText,
    DetectedMedia? detectedMedia,
    bool clearMedia = false,
    DownloadOptions? options,
    bool? isDownloadAdded,
  }) {
    return QuickDownloadState(
      url: url ?? this.url,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isReady: isReady ?? this.isReady,
      analyzeButtonText: analyzeButtonText ?? this.analyzeButtonText,
      detectedMedia: clearMedia ? null : (detectedMedia ?? this.detectedMedia),
      options: options ?? this.options,
      isDownloadAdded: isDownloadAdded ?? this.isDownloadAdded,
    );
  }
}

final quickDownloadProvider = StateNotifierProvider<QuickDownloadNotifier, QuickDownloadState>((ref) {
  return QuickDownloadNotifier(ref);
});

class QuickDownloadNotifier extends StateNotifier<QuickDownloadState> {
  final Ref _ref;

  QuickDownloadNotifier(this._ref) : super(const QuickDownloadState());

  void setUrl(String url) {
    final trimmed = url.trim();
    state = state.copyWith(url: url);
    if (trimmed.isEmpty) {
      state = state.copyWith(clearMedia: true, isReady: false);
      return;
    }
    if (trimmed.startsWith('http') ||
        MetadataFetcherService.extractYouTubeId(trimmed) != null ||
        trimmed.contains('youtu') ||
        trimmed.contains('tiktok') ||
        trimmed.contains('vimeo')) {
      fetchMetadata();
    }
  }

  void clearUrl() {
    state = state.copyWith(url: "", clearMedia: true, isReady: false);
  }

  Future<void> fetchMetadata() async {
    final currentUrl = state.url.trim();
    if (currentUrl.isEmpty) return;

    state = state.copyWith(
      isAnalyzing: true,
      analyzeButtonText: "Analyzing video & streams...",
    );

    try {
      final realInfo = await MetadataFetcherService.fetchMediaInfo(currentUrl);
      if (mounted) {
        state = state.copyWith(
          isAnalyzing: false,
          isReady: true,
          detectedMedia: realInfo,
          analyzeButtonText: "Metadata Loaded!",
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isAnalyzing: false,
          isReady: state.detectedMedia != null,
          analyzeButtonText: "Fetch & Analyze Media",
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      state = state.copyWith(analyzeButtonText: "Fetch & Analyze Media");
    }
  }

  void setFormat(TargetFormat format) {
    state = state.copyWith(options: state.options.copyWith(format: format));
  }

  void setQuality(VideoQuality quality) {
    state = state.copyWith(options: state.options.copyWith(quality: quality));
  }

  void setAudioQuality(AudioQuality quality) {
    state = state.copyWith(options: state.options.copyWith(audioQuality: quality));
  }

  void toggleSubfolder() {
    state = state.copyWith(
      options: state.options.copyWith(createSubfolder: !state.options.createSubfolder),
    );
  }

  void toggleEmbedSubtitles() {
    state = state.copyWith(
      options: state.options.copyWith(embedSubtitles: !state.options.embedSubtitles),
    );
  }

  void toggleSaveMetadata() {
    state = state.copyWith(
      options: state.options.copyWith(saveMetadata: !state.options.saveMetadata),
    );
  }

  bool startDownload() {
    final currentUrl = state.url.trim();
    if (currentUrl.isEmpty) return false;

    final media = state.detectedMedia;
    final isAudio = state.options.format == TargetFormat.audioMp3;

    String resolution = "1080p Full HD";
    if (isAudio) {
      switch (state.options.audioQuality) {
        case AudioQuality.kbps320:
          resolution = "Audio 320 kbps (HQ)";
          break;
        case AudioQuality.kbps256:
          resolution = "Audio 256 kbps";
          break;
        case AudioQuality.kbps192:
          resolution = "Audio 192 kbps";
          break;
        case AudioQuality.kbps128:
          resolution = "Audio 128 kbps";
          break;
      }
    } else {
      switch (state.options.quality) {
        case VideoQuality.res4k:
          resolution = "4K (2160p)";
          break;
        case VideoQuality.res1080p:
          resolution = "1080p Full HD";
          break;
        case VideoQuality.res720p:
          resolution = "720p HD";
          break;
        case VideoQuality.res480p:
          resolution = "480p SD";
          break;
      }
    }

    final estimatedSize = media != null
        ? media.estimateSizeForQuality(state.options.quality, isAudio, state.options.audioQuality)
        : "Auto";

    final ytId = MetadataFetcherService.extractYouTubeId(currentUrl);
    final title = media?.title ?? (ytId != null ? 'YouTube Video ($ytId)' : 'Media Download');
    final thumb = media?.thumbnailUrl ?? (ytId != null ? 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg' : '');
    final duration = media?.duration ?? 'Stream';
    final platform = media?.platform ?? (ytId != null ? 'YouTube' : 'Web');

    final newTask = DownloadTask(
      id: "task_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      url: currentUrl,
      thumbnailUrl: thumb,
      duration: duration,
      format: isAudio ? "M4A / Audio" : "MP4 Video",
      resolution: resolution,
      sizeFormatted: estimatedSize,
      progress: 0.01,
      speed: "Connecting...",
      eta: "Preparing stream...",
      downloadedBytes: "0.0 MB",
      totalBytes: estimatedSize,
      status: DownloadStatus.active,
      isAudio: isAudio,
      platform: platform,
    );

    _ref.read(downloadQueueProvider.notifier).addTask(newTask);

    state = state.copyWith(isDownloadAdded: true);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        state = state.copyWith(isDownloadAdded: false);
      }
    });
    return true;
  }
}
