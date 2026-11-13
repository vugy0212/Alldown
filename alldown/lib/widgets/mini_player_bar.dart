import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'video_player_modal.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;

    final item = player.currentItem;
    if (item == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => VideoPlayerModal.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceContainerHigh.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Mini Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: AppColors.surfaceContainerLowest,
                    child: item.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            item.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: AppColors.secondary, size: 20),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: AppColors.secondary, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                      ),
                      Text(
                        player.isPlaying
                            ? 'Playing • ${item.format} (${item.resolution}) • Tap to expand'
                            : 'Paused • Tap to expand',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),

                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded, size: 20),
                      color: AppColors.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: notifier.skipBackward,
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: notifier.togglePlayPause,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: notifier.stopAndClose,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrubber Bar & Timestamps
            Row(
              children: [
                Text(
                  player.positionFormatted,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final localX = details.localPosition.dx;
                        final fraction = (localX / box.size.width).clamp(0.0, 1.0);
                        notifier.seekTo(fraction);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: player.progressFraction,
                          backgroundColor: AppColors.surfaceContainerLowest,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  player.durationFormatted,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
