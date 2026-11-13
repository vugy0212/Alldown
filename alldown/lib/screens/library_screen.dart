import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/library_item_card.dart';
import '../widgets/video_player_modal.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _calculateRealStorageUsed(List<MediaItem> items, AppLanguage lang) {
    final isHr = lang == AppLanguage.hr;
    if (items.isEmpty) return isHr ? '0.0 MB iskorišteno' : '0.0 MB used';
    int totalBytes = 0;
    for (final item in items) {
      try {
        final f = File(item.localPath);
        if (f.existsSync()) {
          totalBytes += f.lengthSync();
        }
      } catch (_) {}
    }
    final mb = totalBytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = (mb / 1024).toStringAsFixed(2);
      return isHr ? '$gb GB iskorišteno (${items.length} datoteka)' : '$gb GB used (${items.length} files)';
    }
    final mbStr = mb.toStringAsFixed(1);
    return isHr ? '$mbStr MB iskorišteno (${items.length} datoteka)' : '$mbStr MB used (${items.length} files)';
  }

  String _sortLabel(LibrarySort sort, AppLanguage lang) {
    final isHr = lang == AppLanguage.hr;
    switch (sort) {
      case LibrarySort.newest:
        return isHr ? 'Najnovije' : 'Newest';
      case LibrarySort.oldest:
        return isHr ? 'Najstarije' : 'Oldest';
      case LibrarySort.largest:
        return isHr ? 'Najveće' : 'Largest';
      case LibrarySort.title:
        return isHr ? 'Naziv A-Z' : 'Title A-Z';
    }
  }

  void _cycleSort(MediaLibraryNotifier notifier, LibrarySort current) {
    final values = LibrarySort.values;
    final next = values[(values.indexOf(current) + 1) % values.length];
    notifier.setSort(next);
  }

  Future<void> _onPlayItem(MediaItem item) async {
    await ref.read(playerProvider.notifier).playMedia(item);
    if (mounted) {
      VideoPlayerModal.show(context);
    }
  }

  void _onDeleteItem(MediaItem item) {
    try {
      final f = File(item.localPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
    ref.read(mediaLibraryProvider.notifier).removeItem(item.id);
    if (ref.read(playerProvider).currentItem?.id == item.id) {
      ref.read(playerProvider.notifier).stopAndClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(mediaLibraryProvider);
    final libraryNotifier = ref.read(mediaLibraryProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final l10n = L10n(settings.language);

    final items = libraryState.filteredItems;
    final videoCount = libraryState.items.where((e) => !e.isAudio).length;
    final audioCount = libraryState.items.where((e) => e.isAudio).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF3F4F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Search Input
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainer : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.outline : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: libraryNotifier.setSearchQuery,
                      style: TextStyle(
                        color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.searchDownloaded(libraryState.items.length),
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.outline : const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: isDark ? AppColors.outline : const Color(0xFF64748B),
                      onPressed: () {
                        _searchController.clear();
                        libraryNotifier.setSearchQuery('');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Horizontal Filter Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    title: l10n.categoryAll(libraryState.items.length),
                    icon: Icons.check_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.all,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.all),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryVideos(videoCount),
                    icon: Icons.movie_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.videos,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.videos),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryAudio(audioCount),
                    icon: Icons.headphones_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.audio,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.audio),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryFavorites(libraryState.items.where((e) => e.isFavorite).length),
                    icon: Icons.favorite_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.favorites,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.favorites),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Storage Meter & View Controls Deck
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerLow : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                            Icon(Icons.storage_rounded, size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.localStorageUsed,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.onSurfaceVariant : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    _calculateRealStorageUsed(libraryState.items, settings.language),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // View Toggle (List / Grid)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceContainerHighest : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (libraryState.isGridView) libraryNotifier.toggleViewMode();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: !libraryState.isGridView
                                          ? (isDark ? AppColors.surfaceContainer : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: !libraryState.isGridView && !isDark
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.format_list_bulleted_rounded,
                                      size: 16,
                                      color: !libraryState.isGridView
                                          ? AppColors.primary
                                          : (isDark ? AppColors.outline : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (!libraryState.isGridView) libraryNotifier.toggleViewMode();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: libraryState.isGridView
                                          ? (isDark ? AppColors.surfaceContainer : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: libraryState.isGridView && !isDark
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.grid_view_rounded,
                                      size: 16,
                                      color: libraryState.isGridView
                                          ? AppColors.primary
                                          : (isDark ? AppColors.outline : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Interactive Sort Trigger
                          InkWell(
                            onTap: () => _cycleSort(libraryNotifier, libraryState.sort),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainer : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _sortLabel(libraryState.sort, settings.language),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.onSurface : const Color(0xFF334155),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 16,
                                    color: isDark ? AppColors.outline : const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Visual Storage Gauge Bar (Proportional to actual video vs audio count)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (videoCount > 0)
                            Expanded(
                              flex: videoCount * 10,
                              child: Container(color: AppColors.primaryAccent),
                            ),
                          if (videoCount > 0 && audioCount > 0) const SizedBox(width: 2),
                          if (audioCount > 0)
                            Expanded(
                              flex: audioCount * 10,
                              child: Container(color: AppColors.secondary),
                            ),
                          if (libraryState.items.isEmpty)
                            Expanded(
                              child: Container(
                                color: isDark ? AppColors.surfaceContainerHighest : const Color(0xFFE2E8F0),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Media Items List / Grid
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerLow : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 48,
                      color: isDark
                          ? AppColors.outline.withValues(alpha: 0.6)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noMediaYet,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.noMediaYetSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.outline : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else if (libraryState.isGridView)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.88,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return LibraryItemCard(
                    item: item,
                    isGrid: true,
                    onPlay: () => _onPlayItem(item),
                    onDelete: () => _onDeleteItem(item),
                    onToggleFavorite: () => libraryNotifier.toggleFavorite(item.id),
                  );
                },
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return LibraryItemCard(
                    item: item,
                    isGrid: false,
                    onPlay: () => _onPlayItem(item),
                    onDelete: () => _onDeleteItem(item),
                    onToggleFavorite: () => libraryNotifier.toggleFavorite(item.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : (isDark ? AppColors.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : (!isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppColors.onPrimaryContainer
                  : (isDark ? AppColors.outline : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.onPrimaryContainer
                    : (isDark ? AppColors.onSurfaceVariant : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
