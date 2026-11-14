import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../l10n/l10n.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'audio_equalizer_modal.dart';
import 'audio_trimmer_modal.dart';
import 'video_editor_modal.dart';

class VideoPlayerModal extends ConsumerWidget {
  const VideoPlayerModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VideoPlayerModal(),
    );
  }

  void _showSavePlaylistDialog(BuildContext context, WidgetRef ref, List<MediaItem> playlist, L10n l10n) {
    final textCtrl = TextEditingController(text: 'Playlist ${DateTime.now().month}/${DateTime.now().day}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l10n.saveAsPlaylist, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.enterPlaylistName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelSelection),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryAccent),
            onPressed: () {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(mediaLibraryProvider.notifier).createPlaylist(
                      name,
                      playlist.map((e) => e.id).toList(),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.playlistCreated)),
                );
              }
            },
            child: Text(l10n.createPlaylist),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, PlayerState playerState, PlayerNotifier notifier, L10n l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bedtime_rounded, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 8),
                  Text(l10n.isHr ? 'Mjerač spavanja (Sleep Timer)' : 'Sleep Timer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.timer_10_rounded),
                title: Text(l10n.isHr ? '15 minuta' : '15 minutes'),
                onTap: () {
                  notifier.setSleepTimer(const Duration(minutes: 15));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(l10n.isHr ? '30 minuta' : '30 minutes'),
                onTap: () {
                  notifier.setSleepTimer(const Duration(minutes: 30));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(l10n.isHr ? '45 minuta' : '45 minutes'),
                onTap: () {
                  notifier.setSleepTimer(const Duration(minutes: 45));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(l10n.isHr ? '60 minuta (1 sat)' : '60 minutes (1 hour)'),
                onTap: () {
                  notifier.setSleepTimer(const Duration(hours: 1));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_off_rounded),
                title: Text(l10n.isHr ? 'Zaustavi na kraju pjesme' : 'End of current track'),
                onTap: () {
                  notifier.setSleepAtEndOfTrack();
                  Navigator.pop(ctx);
                },
              ),
              if (playerState.isSleepTimerActive)
                ListTile(
                  leading: const Icon(Icons.cancel_rounded, color: AppColors.errorAccent),
                  title: Text(l10n.isHr ? 'Isključi mjerač spavanja' : 'Cancel Sleep Timer', style: const TextStyle(color: AppColors.errorAccent)),
                  onTap: () {
                    notifier.cancelSleepTimer();
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedDialog(BuildContext context, PlayerState playerState, PlayerNotifier notifier, L10n l10n) {
    final speeds = [0.5, 0.75, 0.85, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: AppColors.primaryAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(l10n.isHr ? 'Brzina reprodukcije' : 'Playback Speed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: speeds.map((s) {
                  final isSelected = (playerState.playbackSpeed - s).abs() < 0.01;
                  return ChoiceChip(
                    label: Text('${s}x', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryAccent.withValues(alpha: 0.25),
                    onSelected: (val) {
                      if (val) {
                        notifier.setPlaybackSpeed(s);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final controller = notifier.controller;
    final item = playerState.currentItem;
    final settings = ref.watch(settingsProvider);
    final l10n = L10n(settings.language);

    if (item == null) {
      return const SizedBox.shrink();
    }

    final isGif = item.format == 'GIF' || item.localPath.toLowerCase().endsWith('.gif');

    final aspectRatio = (!isGif &&
            controller != null &&
            controller.value.isInitialized &&
            controller.value.aspectRatio > 0)
        ? controller.value.aspectRatio
        : 16 / 9;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.stroke, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGif
                              ? AppColors.secondary.withValues(alpha: 0.2)
                              : AppColors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isGif
                                  ? Icons.gif_rounded
                                  : item.isAudio
                                      ? Icons.headphones_rounded
                                      : Icons.smart_display_rounded,
                              size: isGif ? 18 : 14,
                              color: isGif ? AppColors.secondary : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isGif
                                    ? 'Animated GIF Player'
                                    : item.isAudio
                                        ? (playerState.hasPlaylist
                                            ? '${l10n.playlist} (${playerState.currentIndex + 1}/${playerState.playlistCount})'
                                            : 'Pro Audio Player')
                                        : 'Video Player (${item.resolution})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isGif ? AppColors.secondary : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!item.isAudio && !isGif) ...[
                        Tooltip(
                          message: 'Trim, Crop & GIF Editor',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              notifier.pause();
                              VideoEditorModal.show(context, item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.content_cut_rounded,
                                    size: 19,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        tooltip: 'Minimize',
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.errorAccent,
                        onPressed: () {
                          notifier.stopAndClose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Viewport: Animated GIF vs Video vs Audio with Visualizer Glow
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  color: Colors.black,
                  child: isGif
                      ? Container(
                          constraints: const BoxConstraints(minHeight: 180, maxHeight: 260),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: Image.file(
                            File(item.localPath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, err, _) => Center(
                              child: Text(
                                'Error loading GIF: $err',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        )
                      : playerState.errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.errorAccent, size: 42),
                                  const SizedBox(height: 10),
                                  Text(
                                    playerState.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : !playerState.isInitialized || controller == null
                              ? const SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(color: AppColors.primaryAccent),
                                  ),
                                )
                              : item.isAudio
                                  ? SizedBox(
                                      height: 190,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (item.thumbnailUrl.isNotEmpty)
                                            Image.network(
                                              item.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                            ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withValues(alpha: 0.45),
                                                  Colors.black.withValues(alpha: 0.85),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Ambient Glow Ring
                                                Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primaryAccent.withValues(alpha: playerState.isPlaying ? 0.4 : 0.1),
                                                        blurRadius: 24,
                                                        spreadRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    playerState.isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                                    size: 48,
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  '${item.format} • ${item.resolution}',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.85),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Center(
                                      child: AspectRatio(
                                        aspectRatio: aspectRatio,
                                        child: VideoPlayer(controller),
                                      ),
                                    ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Metadata
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.channel} • ${item.format} • ${item.sizeFormatted}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),

              // Interactive Seekbar & Transport
              if (isGif) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.all_inclusive_rounded, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Infinite GIF Loop Animation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                // Seekbar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.primaryAccent,
                    inactiveTrackColor: AppColors.surfaceContainerHighest,
                    thumbColor: AppColors.secondary,
                  ),
                  child: Slider(
                    value: playerState.progressFraction,
                    onChanged: (val) => notifier.seekTo(val),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        playerState.positionFormatted,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (playerState.isABActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'A-B Loop (${Duration(milliseconds: playerState.aMs!).inSeconds}s - ${Duration(milliseconds: playerState.bMs!).inSeconds}s)',
                            style: TextStyle(fontSize: 10, color: AppColors.tertiary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Text(
                        playerState.durationFormatted,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Transport Controls Row (Audio: Shuffle, Prev, Play/Pause, Next, Repeat)
                if (item.isAudio) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle Button
                      IconButton(
                        tooltip: playerState.isShuffle ? l10n.shuffleEnabled : l10n.shuffleDisabled,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 22,
                          color: playerState.isShuffle
                              ? AppColors.primaryAccent
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        onPressed: notifier.toggleShuffle,
                      ),

                      // Previous Track
                      IconButton(
                        tooltip: 'Previous Track',
                        icon: const Icon(Icons.skip_previous_rounded, size: 30),
                        color: playerState.hasPrevious
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                        onPressed: notifier.playPrevious,
                      ),

                      // Play / Pause Circle
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryAccent.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                          onPressed: notifier.togglePlayPause,
                        ),
                      ),

                      // Next Track
                      IconButton(
                        tooltip: 'Next Track',
                        icon: const Icon(Icons.skip_next_rounded, size: 30),
                        color: playerState.hasNext
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                        onPressed: notifier.playNext,
                      ),

                      // Repeat Button
                      IconButton(
                        tooltip: switch (playerState.repeatMode) {
                          AudioRepeatMode.off => l10n.repeatModeOff,
                          AudioRepeatMode.all => l10n.repeatModeAll,
                          AudioRepeatMode.one => l10n.repeatModeOne,
                        },
                        icon: Icon(
                          playerState.repeatMode == AudioRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          size: 22,
                          color: playerState.repeatMode != AudioRepeatMode.off
                              ? AppColors.primaryAccent
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        onPressed: notifier.toggleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pro Audio Toolbar: Speed, Equalizer, Sleep Timer, A-B Loop, Trimmer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stroke, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Playback Speed
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showSpeedDialog(context, playerState, notifier, l10n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed_rounded, size: 16, color: AppColors.primaryAccent),
                                const SizedBox(width: 4),
                                Text(
                                  '${playerState.playbackSpeed}x',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryAccent),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Equalizer
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => AudioEqualizerModal.show(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.equalizer_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'EQ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sleep Timer
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showSleepTimerDialog(context, playerState, notifier, l10n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  playerState.isSleepTimerActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                                  size: 16,
                                  color: playerState.isSleepTimerActive ? AppColors.tertiary : AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  playerState.isSleepTimerActive
                                      ? (playerState.sleepTimerRemaining != null
                                          ? '${playerState.sleepTimerRemaining!.inMinutes}m'
                                          : 'End')
                                      : 'Sleep',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: playerState.isSleepTimerActive ? AppColors.tertiary : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // A-B Loop Button
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (!playerState.isABActive && playerState.aMs == null) {
                              notifier.setPointA();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Point A set. Tap again to set Point B.'), duration: Duration(seconds: 1)),
                              );
                            } else if (!playerState.isABActive && playerState.aMs != null) {
                              notifier.setPointB();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Point B set. Looping segment!'), duration: Duration(seconds: 1)),
                              );
                            } else {
                              notifier.clearAB();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('A-B Loop cleared.'), duration: Duration(seconds: 1)),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.repeat_on_rounded,
                                  size: 16,
                                  color: playerState.isABActive ? AppColors.tertiary : (playerState.aMs != null ? AppColors.primaryAccent : AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  playerState.isABActive ? 'A-B Loop' : (playerState.aMs != null ? 'Set B' : 'A-B'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: playerState.isABActive ? AppColors.tertiary : (playerState.aMs != null ? AppColors.primaryAccent : AppColors.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Audio Trimmer (Extract segment)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => AudioTrimmerModal.show(context, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.content_cut_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Trim',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Video Transport: Replay 10, Play/Pause, Forward 10
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded, size: 28),
                        color: AppColors.onSurface,
                        onPressed: notifier.skipBackward,
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryAccent.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                          onPressed: notifier.togglePlayPause,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded, size: 28),
                        color: AppColors.onSurface,
                        onPressed: notifier.skipForward,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],

              // Playlist Queue Section with Drag-and-drop Reordering
              if (playerState.playlist.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stroke, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.queue_music_rounded, size: 18, color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Text(
                                '${l10n.upNextQueue} (${playerState.playlist.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showSavePlaylistDialog(context, ref, playerState.playlist, l10n),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_add_outlined, size: 16, color: AppColors.primaryAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.saveAsPlaylist,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Drag and Drop Reorderable Queue List
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: playerState.playlist.length,
                          // ignore: deprecated_member_use
                          onReorder: (oldIdx, newIdx) {
                            notifier.reorderQueue(oldIdx, newIdx);
                          },
                          itemBuilder: (ctx, idx) {
                            final track = playerState.playlist[idx];
                            final isCurrent = idx == playerState.currentIndex;
                            return Container(
                              key: ValueKey('queue_item_${track.id}_$idx'),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.primaryAccent.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: idx,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        size: 20,
                                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 22,
                                    child: isCurrent
                                        ? Icon(Icons.volume_up_rounded, size: 18, color: AppColors.primaryAccent)
                                        : Text(
                                            '${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => notifier.playTrackAtIndex(idx),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                              color: isCurrent ? AppColors.primaryAccent : AppColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            track.channel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10, color: AppColors.secondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => notifier.removeFromQueue(idx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Share / Open Externally Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.stroke),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(item.localPath)],
                        text: item.title,
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(isGif ? 'Share / Send GIF' : 'Share / Open in External Video Player'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
