import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../services/native_downloader_service.dart';

class PlayerState {
  final MediaItem? currentItem;
  final bool isPlaying;
  final bool isInitialized;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  const PlayerState({
    this.currentItem,
    this.isPlaying = false,
    this.isInitialized = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  PlayerState copyWith({
    MediaItem? currentItem,
    bool clearItem = false,
    bool? isPlaying,
    bool? isInitialized,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerState(
      currentItem: clearItem ? null : (currentItem ?? this.currentItem),
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  String get positionFormatted {
    final m = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (position.inHours > 0) {
      final h = position.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String get durationFormatted {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final h = duration.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  double get progressFraction {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  VideoPlayerController? _controller;

  PlayerNotifier() : super(const PlayerState());

  VideoPlayerController? get controller => _controller;

  Future<void> playMedia(MediaItem item) async {
    // If same item is already loaded, just toggle play
    if (state.currentItem?.id == item.id && _controller != null && state.isInitialized) {
      await _controller!.play();
      return;
    }

    await _disposeController();

    state = PlayerState(
      currentItem: item,
      isPlaying: false,
      isInitialized: false,
      position: Duration.zero,
      duration: Duration.zero,
    );

    try {
      final file = File(item.localPath);
      if (!file.existsSync()) {
        state = state.copyWith(
          errorMessage: 'File not found on storage: ${item.localPath}',
        );
        return;
      }

      // Animated GIFs are rendered as image sequences in Flutter Image widget, not ExoPlayer
      if (item.format == 'GIF' || item.localPath.toLowerCase().endsWith('.gif')) {
        state = state.copyWith(
          isInitialized: true,
          isPlaying: true,
          duration: const Duration(seconds: 1),
          position: Duration.zero,
          clearError: true,
        );
        return;
      }

      var targetFile = file;
      try {
        final raf = file.openSync(mode: FileMode.read);
        final firstByte = raf.readByteSync();
        raf.closeSync();
        if (firstByte == 0x47) {
          // Unremuxed MPEG-TS file (sync byte 0x47). Auto-remux to clean MP4 for instant ExoPlayer playback!
          final fixedPath = '${file.path.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '')}_clean.mp4';
          final fixedFile = File(fixedPath);
          if (!fixedFile.existsSync() || fixedFile.lengthSync() < 1024) {
            final ok = await NativeDownloaderService().remuxTsToMp4(
              inputPath: file.path,
              outputPath: fixedPath,
            );
            if (ok && fixedFile.existsSync() && fixedFile.lengthSync() > 1024) {
              targetFile = fixedFile;
            }
          } else {
            targetFile = fixedFile;
          }
        }
      } catch (_) {}

      final ctrl = VideoPlayerController.file(targetFile);
      _controller = ctrl;

      await ctrl.initialize();
      ctrl.addListener(_onControllerTick);
      await ctrl.play();

      if (mounted) {
        state = state.copyWith(
          isInitialized: true,
          isPlaying: ctrl.value.isPlaying,
          duration: ctrl.value.duration,
          position: ctrl.value.position,
          clearError: true,
        );
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('ALLDOWN_PLAYBACK_ERROR: $e\n$stack');
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'Playback error: $e',
          isPlaying: false,
        );
      }
    }
  }

  void _onControllerTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted || !ctrl.value.isInitialized) return;
    state = state.copyWith(
      isPlaying: ctrl.value.isPlaying,
      position: ctrl.value.position,
      duration: ctrl.value.duration,
    );
  }

  Future<void> pause() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
    }
  }

  Future<void> togglePlayPause() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
    } else {
      await ctrl.play();
    }
  }

  Future<void> seekTo(double fraction) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final targetMs = (ctrl.value.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).toInt();
    await ctrl.seekTo(Duration(milliseconds: targetMs));
  }

  Future<void> skipForward() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = ctrl.value.position + const Duration(seconds: 10);
    final clamped = next > ctrl.value.duration ? ctrl.value.duration : next;
    await ctrl.seekTo(clamped);
  }

  Future<void> skipBackward() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final prev = ctrl.value.position - const Duration(seconds: 10);
    final clamped = prev < Duration.zero ? Duration.zero : prev;
    await ctrl.seekTo(clamped);
  }

  Future<void> stopAndClose() async {
    await _disposeController();
    if (mounted) {
      state = const PlayerState();
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_onControllerTick);
      await old.pause();
      await old.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
