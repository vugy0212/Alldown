import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final controller = notifier.controller;
    final item = playerState.currentItem;

    if (item == null) {
      return const SizedBox.shrink();
    }

    final aspectRatio = (controller != null &&
            controller.value.isInitialized &&
            controller.value.aspectRatio > 0)
        ? controller.value.aspectRatio
        : 16 / 9;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.stroke, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isAudio ? Icons.headphones_rounded : Icons.smart_display_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.isAudio ? 'Audio Player' : 'Video Player (${item.resolution})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Minimize to Mini Player',
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        tooltip: 'Stop & Close',
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

              // Video / Audio Viewport
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  color: Colors.black,
                  child: playerState.errorMessage != null
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
                                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : !playerState.isInitialized || controller == null
                          ? const SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.primaryAccent),
                              ),
                            )
                          : item.isAudio
                              ? SizedBox(
                                  height: 180,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (item.thumbnailUrl.isNotEmpty)
                                        Image.network(
                                          item.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                        ),
                                      Container(color: Colors.black.withValues(alpha: 0.55)),
                                      const Center(
                                        child: Icon(
                                          Icons.graphic_eq_rounded,
                                          size: 64,
                                          color: AppColors.secondary,
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
                style: const TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),

              // Interactive Seekbar
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      playerState.durationFormatted,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Transport Controls Row
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
              const SizedBox(height: 14),

              // Share / Open Externally Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.stroke),
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
                  label: const Text('Share / Open in External Video Player'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

