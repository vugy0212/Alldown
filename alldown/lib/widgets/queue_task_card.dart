import 'package:flutter/material.dart';
import '../models/download_task.dart';
import '../theme/app_colors.dart';

class QueueTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback? onBoost;
  final VoidCallback? onStartNow;

  const QueueTaskCard({
    super.key,
    required this.task,
    required this.onPauseResume,
    required this.onCancel,
    this.onBoost,
    this.onStartNow,
  });

  @override
  Widget build(BuildContext context) {
    final isQueued = task.status == DownloadStatus.queued;
    final isConverting = task.status == DownloadStatus.converting;
    final isPaused = task.status == DownloadStatus.paused;

    return Container(
      decoration: BoxDecoration(
        color: isQueued ? AppColors.surfaceContainerLow : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.priority > 0
              ? AppColors.primaryAccent.withValues(alpha: 0.6)
              : AppColors.stroke,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Thumbnail + Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 96,
                      height: 64,
                      color: AppColors.surfaceContainerHighest,
                      child: Image.network(
                        task.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.surfaceContainerHighest,
                          child: Icon(
                            task.isAudio ? Icons.audiotrack_rounded : Icons.movie_rounded,
                            color: AppColors.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Platform / Audio Badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.isAudio ? Icons.graphic_eq_rounded : Icons.smart_display_rounded,
                            size: 11,
                            color: task.isAudio ? AppColors.tertiary : AppColors.errorAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            task.isAudio ? 'AUDIO' : 'YT',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Duration
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.duration,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Title and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isQueued ? AppColors.onSurfaceVariant : AppColors.onSurface,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isConverting)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Converting (MP3 320k)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.format,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.subtitleInfo,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress & Controls Section
          if (!isQueued) ...[
            const SizedBox(height: 12),
            // Readout line (Percentage, MB, Speed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${(task.progress * 100).toInt()}% • ${task.downloadedBytes} / ${task.totalBytes}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isConverting ? AppColors.tertiary : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: isConverting ? AppColors.tertiary : AppColors.secondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isPaused ? "Paused" : task.speed,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Fluid Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Container(color: AppColors.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: task.progress.clamp(0.01, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isConverting
                              ? AppColors.audioProgressGradient
                              : AppColors.progressGradient,
                          boxShadow: [
                            BoxShadow(
                              color: isConverting
                                  ? AppColors.tertiary.withValues(alpha: 0.6)
                                  : AppColors.secondary.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Action Row: ETA + Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.eta,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status != DownloadStatus.completed && onBoost != null) ...[
                      IconButton(
                        icon: const Icon(Icons.keyboard_double_arrow_up_rounded, size: 18),
                        color: task.priority > 0 ? AppColors.secondary : AppColors.onSurfaceVariant,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: onBoost,
                        tooltip: 'Boost Priority',
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (task.status != DownloadStatus.completed) ...[
                      IconButton(
                        icon: Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 18,
                        ),
                        color: AppColors.onSurface,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: onPauseResume,
                        tooltip: isPaused ? 'Resume' : 'Pause',
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.onSurfaceVariant,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onCancel,
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            // Queued Slot Row
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_protected_setup_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Awaiting active task slot',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onStartNow,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 2),
                              Text(
                                'Start Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        color: AppColors.onSurfaceVariant,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: onCancel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

