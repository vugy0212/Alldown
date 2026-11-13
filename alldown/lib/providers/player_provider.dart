import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../services/native_downloader_service.dart';

enum AudioRepeatMode {
  off,
  all,
  one,
}

class PlayerState {
  final MediaItem? currentItem;
  final List<MediaItem> playlist;
  final int currentIndex;
  final bool isPlaying;
  final bool isInitialized;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final bool isShuffle;
  final AudioRepeatMode repeatMode;
  final List<int> shuffledIndices;

  const PlayerState({
    this.currentItem,
    this.playlist = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isInitialized = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.isShuffle = false,
    this.repeatMode = AudioRepeatMode.off,
    this.shuffledIndices = const [],
  });

  PlayerState copyWith({
    MediaItem? currentItem,
    bool clearItem = false,
    List<MediaItem>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? isInitialized,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
    bool? isShuffle,
    AudioRepeatMode? repeatMode,
    List<int>? shuffledIndices,
  }) {
    return PlayerState(
      currentItem: clearItem ? null : (currentItem ?? this.currentItem),
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffledIndices: shuffledIndices ?? this.shuffledIndices,
    );
  }

  bool get hasPlaylist => playlist.length > 1;
  int get playlistCount => playlist.length;

  bool get hasNext {
    if (playlist.isEmpty) return false;
    if (repeatMode != AudioRepeatMode.off) return true;
    if (!isShuffle) {
      return currentIndex < playlist.length - 1;
    } else {
      final pos = shuffledIndices.indexOf(currentIndex);
      return pos >= 0 && pos < shuffledIndices.length - 1;
    }
  }

  bool get hasPrevious {
    if (playlist.isEmpty) return false;
    if (repeatMode != AudioRepeatMode.off) return true;
    if (!isShuffle) {
      return currentIndex > 0;
    } else {
      final pos = shuffledIndices.indexOf(currentIndex);
      return pos > 0;
    }
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
  bool _isAdvancing = false;

  PlayerNotifier() : super(const PlayerState());

  VideoPlayerController? get controller => _controller;

  List<int> _generateShuffleIndices(int length, int firstIndex) {
    if (length <= 0) return [];
    final list = List<int>.generate(length, (i) => i)..remove(firstIndex);
    list.shuffle(Random());
    return [firstIndex, ...list];
  }

  Future<void> playMedia(MediaItem item) async {
    await playPlaylist([item], initialIndex: 0);
  }

  Future<void> playPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    if (items.isEmpty) return;
    final validIndex = initialIndex.clamp(0, items.length - 1);
    final shuffleList = state.isShuffle
        ? _generateShuffleIndices(items.length, validIndex)
        : <int>[];

    state = state.copyWith(
      playlist: items,
      currentIndex: validIndex,
      shuffledIndices: shuffleList,
    );

    await _loadAndPlayItem(items[validIndex]);
  }

  Future<void> _loadAndPlayItem(MediaItem item) async {
    // If same item is already loaded, toggle or keep playing
    if (state.currentItem?.id == item.id && _controller != null && state.isInitialized) {
      await _controller!.play();
      return;
    }

    await _disposeController();

    state = state.copyWith(
      currentItem: item,
      isPlaying: false,
      isInitialized: false,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
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

    final isPlaying = ctrl.value.isPlaying;
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;

    state = state.copyWith(
      isPlaying: isPlaying,
      position: position,
      duration: duration,
    );

    // Auto-advance to next song in playlist when playback reaches the end
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 300) &&
        !_isAdvancing) {
      _handleTrackCompleted();
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    if (state.repeatMode == AudioRepeatMode.one) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.seekTo(Duration.zero);
        await ctrl.play();
      }
      _isAdvancing = false;
      return;
    }

    if (state.hasNext) {
      await playNext();
    } else if (state.repeatMode == AudioRepeatMode.all && state.playlist.isNotEmpty) {
      await playTrackAtIndex(0);
    }
    _isAdvancing = false;
  }

  Future<void> playNext() async {
    if (state.playlist.isEmpty) return;

    if (state.repeatMode == AudioRepeatMode.one) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.seekTo(Duration.zero);
        await ctrl.play();
      }
      return;
    }

    int nextIndex = -1;
    if (!state.isShuffle) {
      if (state.currentIndex + 1 < state.playlist.length) {
        nextIndex = state.currentIndex + 1;
      } else if (state.repeatMode == AudioRepeatMode.all) {
        nextIndex = 0;
      }
    } else {
      final curPos = state.shuffledIndices.indexOf(state.currentIndex);
      if (curPos >= 0 && curPos + 1 < state.shuffledIndices.length) {
        nextIndex = state.shuffledIndices[curPos + 1];
      } else if (state.repeatMode == AudioRepeatMode.all && state.shuffledIndices.isNotEmpty) {
        nextIndex = state.shuffledIndices[0];
      }
    }

    if (nextIndex >= 0 && nextIndex < state.playlist.length) {
      state = state.copyWith(currentIndex: nextIndex);
      await _loadAndPlayItem(state.playlist[nextIndex]);
    } else {
      // Reached the end of playlist with repeat off
      await pause();
    }
  }

  Future<void> playPrevious() async {
    if (state.playlist.isEmpty) return;

    // If more than 3 seconds in, seek to beginning first (standard music player UX)
    if (state.position.inSeconds > 3) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.seekTo(Duration.zero);
        return;
      }
    }

    int prevIndex = -1;
    if (!state.isShuffle) {
      if (state.currentIndex - 1 >= 0) {
        prevIndex = state.currentIndex - 1;
      } else if (state.repeatMode == AudioRepeatMode.all) {
        prevIndex = state.playlist.length - 1;
      }
    } else {
      final curPos = state.shuffledIndices.indexOf(state.currentIndex);
      if (curPos > 0) {
        prevIndex = state.shuffledIndices[curPos - 1];
      } else if (state.repeatMode == AudioRepeatMode.all && state.shuffledIndices.isNotEmpty) {
        prevIndex = state.shuffledIndices.last;
      }
    }

    if (prevIndex >= 0 && prevIndex < state.playlist.length) {
      state = state.copyWith(currentIndex: prevIndex);
      await _loadAndPlayItem(state.playlist[prevIndex]);
    } else {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.seekTo(Duration.zero);
      }
    }
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    state = state.copyWith(currentIndex: index);
    await _loadAndPlayItem(state.playlist[index]);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffle;
    List<int> shuffleList = [];
    if (newShuffle && state.playlist.isNotEmpty) {
      shuffleList = _generateShuffleIndices(state.playlist.length, state.currentIndex);
    }
    state = state.copyWith(
      isShuffle: newShuffle,
      shuffledIndices: shuffleList,
    );
  }

  void toggleRepeat() {
    final next = switch (state.repeatMode) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void addToQueue(MediaItem item) {
    final updated = [...state.playlist, item];
    state = state.copyWith(playlist: updated);
  }

  void addMultipleToQueue(List<MediaItem> items) {
    final updated = [...state.playlist, ...items];
    state = state.copyWith(playlist: updated);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.playlist.length) return;
    final updated = List<MediaItem>.from(state.playlist)..removeAt(index);
    if (updated.isEmpty) {
      stopAndClose();
      return;
    }

    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      newIndex = newIndex.clamp(0, updated.length - 1);
      state = state.copyWith(playlist: updated, currentIndex: newIndex);
      _loadAndPlayItem(updated[newIndex]);
      return;
    }
    state = state.copyWith(playlist: updated, currentIndex: newIndex);
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
