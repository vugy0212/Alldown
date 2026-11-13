import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import '../providers/download_queue_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/queue_task_card.dart';
import '../widgets/telemetry_waveform.dart';

enum QueueFilterTab {
  active,
  completed,
  paused,
}

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  QueueFilterTab _currentTab = QueueFilterTab.active;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadQueueProvider);
    final queueNotifier = ref.read(downloadQueueProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final l10n = L10n(settings.language);

    final activeCount = tasks.where((t) => t.status == DownloadStatus.active || t.status == DownloadStatus.converting || t.status == DownloadStatus.queued).length;
    final completedCount = tasks.where((t) => t.status == DownloadStatus.completed).length;
    final pausedCount = tasks.where((t) => t.status == DownloadStatus.paused).length;

    List<DownloadTask> displayedTasks;
    switch (_currentTab) {
      case QueueFilterTab.active:
        displayedTasks = tasks.where((t) => t.status == DownloadStatus.active || t.status == DownloadStatus.converting || t.status == DownloadStatus.queued).toList();
        break;
      case QueueFilterTab.completed:
        displayedTasks = tasks.where((t) => t.status == DownloadStatus.completed).toList();
        break;
      case QueueFilterTab.paused:
        displayedTasks = tasks.where((t) => t.status == DownloadStatus.paused).toList();
        break;
    }

    final aggregateSpeed = queueNotifier.aggregateSpeed > 0
        ? '${queueNotifier.aggregateSpeed.toStringAsFixed(1)} MB/s'
        : '0.0 MB/s';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented Filter Tabs: Active (badge), Completed (badge), Paused (badge)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        title: l10n.active,
                        badge: '$activeCount',
                        isSelected: _currentTab == QueueFilterTab.active,
                        onTap: () => setState(() => _currentTab = QueueFilterTab.active),
                      ),
                      _buildTabButton(
                        title: l10n.completed,
                        badge: '$completedCount',
                        isSelected: _currentTab == QueueFilterTab.completed,
                        onTap: () => setState(() => _currentTab = QueueFilterTab.completed),
                      ),
                      _buildTabButton(
                        title: l10n.paused,
                        badge: '$pausedCount',
                        isSelected: _currentTab == QueueFilterTab.paused,
                        onTap: () => setState(() => _currentTab = QueueFilterTab.paused),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Real-Time Bandwidth & Telemetry Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stroke, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: activeCount > 0 ? AppColors.secondary : AppColors.outline,
                                    shape: BoxShape.circle,
                                    boxShadow: activeCount > 0
                                        ? [
                                            BoxShadow(
                                              color: AppColors.secondary.withValues(alpha: 0.8),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    aggregateSpeed,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.south_rounded,
                                  size: 18,
                                  color: AppColors.secondary,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wifi_rounded, size: 13, color: AppColors.secondary),
                                SizedBox(width: 4),
                                Text(
                                  'Ultra-Link',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              settings.language == AppLanguage.hr
                                  ? '$activeCount Aktivno • ${queueNotifier.queuedCount} Na čekanju'
                                  : '$activeCount Active • ${queueNotifier.queuedCount} Queued',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activeCount > 0 ? (settings.language == AppLanguage.hr ? 'Status: Preuzimanje' : 'Engine: Active') : l10n.speedIdle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Live Waveform graph
                      const TelemetryWaveform(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Section Header: "Queue Pipeline"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.queuePipeline,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.highPriority,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        queueNotifier.autoOrderQueue();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              settings.language == AppLanguage.hr
                                  ? 'Red je posložen po prioritetu i statusu'
                                  : 'Queue ordered by priority & status',
                            ),
                          ),
                        );
                      },
                      icon: Text(
                        l10n.autoOrder,
                        style: TextStyle(fontSize: 12, color: AppColors.secondary),
                      ),
                      label: Icon(
                        Icons.swap_vert_rounded,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Task Cards List
                if (displayedTasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: AppColors.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noTasksInCategory,
                          style: TextStyle(color: AppColors.outline),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = displayedTasks[index];
                      return QueueTaskCard(
                        task: task,
                        onPauseResume: () {
                          if (task.status == DownloadStatus.paused) {
                            queueNotifier.resumeTask(task.id);
                          } else {
                            queueNotifier.pauseTask(task.id);
                          }
                        },
                        onCancel: () => queueNotifier.cancelTask(task.id),
                        onBoost: () => queueNotifier.boostPriority(task.id),
                        onStartNow: () => queueNotifier.startTaskNow(task.id),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Bottom Floating Batch Action Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Pause All Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceBright,
                            foregroundColor: AppColors.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => queueNotifier.pauseAll(),
                          icon: const Icon(Icons.pause_circle_rounded, size: 18),
                          label: Text('${l10n.pauseAll} ($activeCount)'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Clear Finished Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceBright,
                          foregroundColor: AppColors.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => queueNotifier.clearFinished(),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                        label: Text(l10n.clean),
                      ),
                      const SizedBox(width: 8),

                      // Concurrency settings trigger
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune_rounded, size: 20, color: AppColors.onPrimaryContainer),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  settings.language == AppLanguage.hr
                                      ? 'Istovremeni zadaci postavljeni na maks. ${settings.maxConcurrentDownloads}'
                                      : 'Concurrency set to max ${settings.maxConcurrentDownloads} tasks',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        l10n.concurrencyLimit(settings.maxConcurrentDownloads),
                        style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

