import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Advanced Pro Audio features
  final double playbackSpeed;
  final int? aMs;
  final int? bMs;
  final bool isABActive;
  final Duration? sleepTimerRemaining;
  final bool isSleepTimerActive;
  final bool sleepAtEndOfTrack;
  final double volume;

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
    this.playbackSpeed = 1.0,
    this.aMs,
    this.bMs,
    this.isABActive = false,
    this.sleepTimerRemaining,
    this.isSleepTimerActive = false,
    this.sleepAtEndOfTrack = false,
    this.volume = 1.0,
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
    double? playbackSpeed,
    int? aMs,
    int? bMs,
    bool? isABActive,
    bool clearAB = false,
    Duration? sleepTimerRemaining,
    bool? isSleepTimerActive,
    bool? sleepAtEndOfTrack,
    bool clearSleepTimer = false,
    double? volume,
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
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      aMs: clearAB ? null : (aMs ?? this.aMs),
      bMs: clearAB ? null : (bMs ?? this.bMs),
      isABActive: clearAB ? false : (isABActive ?? this.isABActive),
      sleepTimerRemaining: clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      isSleepTimerActive: clearSleepTimer ? false : (isSleepTimerActive ?? this.isSleepTimerActive),
      sleepAtEndOfTrack: clearSleepTimer ? false : (sleepAtEndOfTrack ?? this.sleepAtEndOfTrack),
      volume: volume ?? this.volume,
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
  Timer? _sleepTimer;
  DateTime? _lastNotificationUpdateTime;

  PlayerNotifier() : super(const PlayerState()) {
    _initNativeMediaCallbacks();
  }

  VideoPlayerController? get controller => _controller;

  void _initNativeMediaCallbacks() {
    final native = NativeDownloaderService();
    native.onMediaPlay = () => togglePlayPause();
    native.onMediaPause = () => pause();
    native.onMediaPlayPause = () => togglePlayPause();
    native.onMediaSkipNext = () => playNext();
    native.onMediaSkipPrevious = () => playPrevious();
    native.onMediaSeekTo = (posMs) {
      if (state.duration.inMilliseconds > 0) {
        seekTo(posMs / state.duration.inMilliseconds);
      }
    };
    native.onMediaStop = () => stopAndClose();
  }

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
      _syncNativeNotification(isPlaying: true);
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
      clearAB: true,
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
      if (state.playbackSpeed != 1.0) {
        await ctrl.setPlaybackSpeed(state.playbackSpeed);
      }
      ctrl.addListener(_onControllerTick);

      // Check saved resume position for long tracks (> 10 mins)
      try {
        if (ctrl.value.duration.inMinutes >= 10) {
          final prefs = await SharedPreferences.getInstance();
          final savedPosMs = prefs.getInt('resume_pos_${item.id}') ?? 0;
          if (savedPosMs > 5000 && savedPosMs < ctrl.value.duration.inMilliseconds - 10000) {
            await ctrl.seekTo(Duration(milliseconds: savedPosMs));
          }
        }
      } catch (_) {}

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
      _syncNativeNotification(isPlaying: true);
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

    // A-B Repeat Loop Check
    if (state.isABActive && state.aMs != null && state.bMs != null) {
      if (position.inMilliseconds >= state.bMs!) {
        ctrl.seekTo(Duration(milliseconds: state.aMs!));
        return;
      }
    }

    state = state.copyWith(
      isPlaying: isPlaying,
      position: position,
      duration: duration,
    );

    // Save position periodically for long tracks (> 10 mins)
    if (duration.inMinutes >= 10 && state.currentItem != null) {
      final nowSec = position.inSeconds;
      if (nowSec % 10 == 0) {
        SharedPreferences.getInstance().then((p) {
          p.setInt('resume_pos_${state.currentItem!.id}', position.inMilliseconds);
        });
      }
    }

    // Auto-advance to next song in playlist when playback reaches the end
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 300) &&
        !_isAdvancing) {
      _handleTrackCompleted();
    }

    // Throttle native media notification sync to once every 1.5 seconds during playback
    final now = DateTime.now();
    if (_lastNotificationUpdateTime == null ||
        now.difference(_lastNotificationUpdateTime!).inMilliseconds > 1500) {
      _lastNotificationUpdateTime = now;
      _syncNativeNotification(isPlaying: isPlaying);
    }
  }

  void _syncNativeNotification({required bool isPlaying}) {
    final item = state.currentItem;
    if (item == null) return;
    NativeDownloaderService().updateMediaNotification(
      title: item.title,
      artist: item.channel,
      isPlaying: isPlaying,
      positionMs: state.position.inMilliseconds,
      durationMs: state.duration.inMilliseconds,
      hasNext: state.hasNext,
      hasPrev: state.hasPrevious,
    );
  }

  Future<void> _handleTrackCompleted() async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    if (state.sleepAtEndOfTrack) {
      cancelSleepTimer();
      await pause();
      _isAdvancing = false;
      return;
    }

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

  /// Advanced Playback Speed (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x)
  Future<void> setPlaybackSpeed(double speed) async {
    final validSpeed = speed.clamp(0.25, 3.0);
    state = state.copyWith(playbackSpeed: validSpeed);
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      await ctrl.setPlaybackSpeed(validSpeed);
    }
  }

  /// A-B Repeat Loop controls
  void setPointA() {
    state = state.copyWith(
      aMs: state.position.inMilliseconds,
      isABActive: false,
    );
  }

  void setPointB() {
    if (state.aMs == null) return;
    final currentMs = state.position.inMilliseconds;
    if (currentMs <= state.aMs!) return;
    state = state.copyWith(
      bMs: currentMs,
      isABActive: true,
    );
  }

  void clearAB() {
    state = state.copyWith(clearAB: true);
  }

  /// Sleep Timer with smooth Fade-Out in the last 5 seconds
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    state = state.copyWith(
      sleepTimerRemaining: duration,
      isSleepTimerActive: true,
      sleepAtEndOfTrack: false,
    );

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final rem = state.sleepTimerRemaining;
      if (rem == null || rem.inSeconds <= 0) {
        timer.cancel();
        await pause();
        cancelSleepTimer();
        return;
      }

      final next = rem - const Duration(seconds: 1);
      state = state.copyWith(sleepTimerRemaining: next);

      // Smooth fade out in the last 5 seconds
      if (next.inSeconds <= 5 && _controller != null) {
        final fadeVolume = (next.inSeconds / 5.0).clamp(0.0, 1.0);
        await _controller?.setVolume(fadeVolume);
      }
    });
  }

  void setSleepAtEndOfTrack() {
    cancelSleepTimer();
    state = state.copyWith(
      sleepAtEndOfTrack: true,
      isSleepTimerActive: true,
    );
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _controller?.setVolume(1.0);
    state = state.copyWith(clearSleepTimer: true, volume: 1.0);
  }

  /// Queue Management & Drag-and-drop Reordering
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.playlist.length) return;
    if (newIndex < 0 || newIndex > state.playlist.length) return;

    var actualNewIndex = newIndex;
    if (oldIndex < actualNewIndex) {
      actualNewIndex -= 1;
    }

    final updated = List<MediaItem>.from(state.playlist);
    final movedItem = updated.removeAt(oldIndex);
    updated.insert(actualNewIndex, movedItem);

    int newCurrentIndex = state.currentIndex;
    if (state.currentIndex == oldIndex) {
      newCurrentIndex = actualNewIndex;
    } else if (state.currentIndex > oldIndex && state.currentIndex <= actualNewIndex) {
      newCurrentIndex--;
    } else if (state.currentIndex < oldIndex && state.currentIndex >= actualNewIndex) {
      newCurrentIndex++;
    }

    state = state.copyWith(
      playlist: updated,
      currentIndex: newCurrentIndex,
    );
  }

  void playNextInQueue(MediaItem item) {
    final updated = List<MediaItem>.from(state.playlist);
    final insertPos = (state.currentIndex + 1).clamp(0, updated.length);
    updated.insert(insertPos, item);
    state = state.copyWith(playlist: updated);
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
    _syncNativeNotification(isPlaying: false);
  }

  Future<void> togglePlayPause() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      _syncNativeNotification(isPlaying: false);
    } else {
      await ctrl.play();
      _syncNativeNotification(isPlaying: true);
    }
  }

  Future<void> seekTo(double fraction) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final targetMs = (ctrl.value.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).toInt();
    await ctrl.seekTo(Duration(milliseconds: targetMs));
    _syncNativeNotification(isPlaying: ctrl.value.isPlaying);
  }

  Future<void> skipForward() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = ctrl.value.position + const Duration(seconds: 10);
    final clamped = next > ctrl.value.duration ? ctrl.value.duration : next;
    await ctrl.seekTo(clamped);
    _syncNativeNotification(isPlaying: ctrl.value.isPlaying);
  }

  Future<void> skipBackward() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final prev = ctrl.value.position - const Duration(seconds: 10);
    final clamped = prev < Duration.zero ? Duration.zero : prev;
    await ctrl.seekTo(clamped);
    _syncNativeNotification(isPlaying: ctrl.value.isPlaying);
  }

  Future<void> stopAndClose() async {
    cancelSleepTimer();
    await _disposeController();
    NativeDownloaderService().stopMediaNotification();
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
    cancelSleepTimer();
    _disposeController();
    NativeDownloaderService().stopMediaNotification();
    super.dispose();
  }
}
