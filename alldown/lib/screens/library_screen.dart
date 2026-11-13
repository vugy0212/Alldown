import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/player_provider.dart';
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

  String _calculateRealStorageUsed(List<MediaItem> items) {
    if (items.isEmpty) return '0.0 MB used';
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
      return '${(mb / 1024).toStringAsFixed(2)} GB used (${items.length} files)';
    }
    return '${mb.toStringAsFixed(1)} MB used (${items.length} files)';
  }

  String _sortLabel(LibrarySort sort) {
    switch (sort) {
      case LibrarySort.newest:
        return 'Newest';
      case LibrarySort.oldest:
        return 'Oldest';
      case LibrarySort.largest:
        return 'Largest';
      case LibrarySort.title:
        return 'Title A-Z';
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

    final items = libraryState.filteredItems;
    final videoCount = libraryState.items.where((e) => !e.isAudio).length;
    final audioCount = libraryState.items.where((e) => e.isAudio).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Search Input
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.isDark ? AppColors.surfaceContainer : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.stroke, width: 1),
                boxShadow: AppColors.isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: libraryNotifier.setSearchQuery,
                      style: TextStyle(color: AppColors.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search ${libraryState.items.length} downloaded media files...',
                        hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: AppColors.outline,
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
                    title: 'All (${libraryState.items.length})',
                    icon: Icons.check_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.all,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.all),
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: 'Videos ($videoCount)',
                    icon: Icons.movie_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.videos,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.videos),
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: 'Audio ($audioCount)',
                    icon: Icons.headphones_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.audio,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.audio),
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: 'Favorites (${libraryState.items.where((e) => e.isFavorite).length})',
                    icon: Icons.favorite_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.favorites,
                    onTap: () => libraryNotifier.setCategory(LibraryCategory.favorites),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Storage Meter & View Controls Deck
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
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
                            Icon(Icons.storage_rounded, size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Local Storage Used',
                                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                  Text(
                                    _calculateRealStorageUsed(libraryState.items),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
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
                              color: AppColors.surfaceContainerHighest,
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
                                      color: !libraryState.isGridView ? AppColors.surfaceContainer : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.format_list_bulleted_rounded,
                                      size: 16,
                                      color: !libraryState.isGridView ? AppColors.primary : AppColors.outline,
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
                                      color: libraryState.isGridView ? AppColors.surfaceContainer : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.grid_view_rounded,
                                      size: 16,
                                      color: libraryState.isGridView ? AppColors.primary : AppColors.outline,
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
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _sortLabel(libraryState.sort),
                                    style: TextStyle(fontSize: 11, color: AppColors.onSurface),
                                  ),
                                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.outline),
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
                              child: Container(color: AppColors.surfaceContainerHighest),
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
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined, size: 48, color: AppColors.outline.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text(
                      'No downloaded media files yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Videos and audio tracks you download will appear here and can be played directly inside AllDown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.outline),
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
              : (AppColors.isDark ? AppColors.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.stroke,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : (!AppColors.isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
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
              color: isSelected ? AppColors.onPrimaryContainer : AppColors.outline,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
