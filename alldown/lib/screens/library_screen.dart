import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/local_playlist.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../services/haptic_service.dart';
import '../widgets/library_item_card.dart';
import '../widgets/video_player_modal.dart';
import '../widgets/external_folders_modal.dart';
import '../widgets/playlist_editor_modal.dart';
import '../widgets/playlist_detail_modal.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};

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

  Future<void> _onPlayItem(MediaItem item, List<MediaItem> currentList) async {
    if (item.isAudio) {
      final audioList = currentList.where((e) => e.isAudio).toList();
      final idx = audioList.indexWhere((e) => e.id == item.id);
      ref.read(playerProvider.notifier).playPlaylist(
            audioList.isNotEmpty ? audioList : [item],
            initialIndex: idx >= 0 ? idx : 0,
          );
    } else {
      ref.read(playerProvider.notifier).playMedia(item);
    }
    VideoPlayerModal.show(context);
  }

  void _playAllAudio(List<MediaItem> items) {
    final audioList = items.where((e) => e.isAudio).toList();
    if (audioList.isEmpty) return;
    ref.read(playerProvider.notifier).playPlaylist(audioList, initialIndex: 0);
    VideoPlayerModal.show(context);
  }

  void _playSelectedAsPlaylist(List<MediaItem> allItems) {
    final selected = allItems.where((e) => _selectedItemIds.contains(e.id)).toList();
    if (selected.isEmpty) return;
    ref.read(playerProvider.notifier).playPlaylist(selected, initialIndex: 0);
    setState(() {
      _isSelectionMode = false;
      _selectedItemIds.clear();
    });
    VideoPlayerModal.show(context);
  }

  void _playLocalPlaylist(LocalPlaylist pl, List<MediaItem> allItems) {
    final tracks = pl.trackIds
        .map((id) => allItems.where((item) => item.id == id).firstOrNull)
        .whereType<MediaItem>()
        .toList();
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).playPlaylist(tracks, initialIndex: 0);
    VideoPlayerModal.show(context);
  }

  void _toggleSelectItem(String id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _openExternalFoldersModal(BuildContext context) {
    HapticService.selection();
    final state = ref.read(mediaLibraryProvider);
    final notifier = ref.read(mediaLibraryProvider.notifier);
    ExternalFoldersModal.show(
      context,
      folders: state.externalFolders,
      onAddFolder: () => notifier.pickAndAddExternalFolder(),
      onRemoveFolder: (uri) => notifier.removeExternalFolder(uri),
    );
  }

  void _openPlaylistEditor({LocalPlaylist? existingPlaylist}) {
    HapticService.selection();
    final state = ref.read(mediaLibraryProvider);
    final notifier = ref.read(mediaLibraryProvider.notifier);

    PlaylistEditorModal.show(
      context,
      playlist: existingPlaylist,
      allAudioTracks: state.allItems.where((e) => e.isAudio).toList(),
      externalFolders: state.externalFolders,
      onSave: (title, trackIds) {
        if (existingPlaylist != null) {
          notifier.updatePlaylist(existingPlaylist.id, title: title, trackIds: trackIds);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ažurirana playlista "$title"')),
            );
          }
        } else {
          notifier.createPlaylist(title, trackIds);
          setState(() {
            _isSelectionMode = false;
            _selectedItemIds.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stvorena playlista "$title"')),
            );
          }
        }
      },
    );
  }

  void _onDeleteItem(MediaItem item) {
    HapticService.error();
    if (item.localPath.startsWith('content://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pjesma je iz vanjske mape. Koristite izbornik mapa za upravljanje.'),
        ),
      );
      return;
    }
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
    final audioCount = libraryState.allItems.where((e) => e.isAudio).length;
    final playlistsCount = libraryState.allPlaylists.length;
    final isPlaylistsTab = libraryState.selectedCategory == LibraryCategory.playlists;

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

            // Horizontal Filter Chips Row (All, Videos, Audio, Playlists, Favorites)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    title: l10n.categoryAll(libraryState.items.length),
                    icon: Icons.check_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.all,
                    onTap: () {
                      HapticService.selection();
                      libraryNotifier.setCategory(LibraryCategory.all);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryVideos(videoCount),
                    icon: Icons.movie_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.videos,
                    onTap: () {
                      HapticService.selection();
                      libraryNotifier.setCategory(LibraryCategory.videos);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryAudio(audioCount),
                    icon: Icons.headphones_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.audio,
                    onTap: () {
                      HapticService.selection();
                      libraryNotifier.setCategory(LibraryCategory.audio);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryPlaylists(playlistsCount),
                    icon: Icons.queue_music_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.playlists,
                    onTap: () {
                      HapticService.selection();
                      libraryNotifier.setCategory(LibraryCategory.playlists);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    title: l10n.categoryFavorites(libraryState.allItems.where((e) => e.isFavorite).length),
                    icon: Icons.favorite_rounded,
                    isSelected: libraryState.selectedCategory == LibraryCategory.favorites,
                    onTap: () {
                      HapticService.selection();
                      libraryNotifier.setCategory(LibraryCategory.favorites);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Selection Mode Action Bar (When selecting tracks for playlist)
            if (_isSelectionMode)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                      AppColors.secondary.withValues(alpha: isDark ? 0.20 : 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryAccent, width: 1.2),
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.selectedCount(_selectedItemIds.length),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    // Select All / Deselect All
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          final currentAudioIds = items.where((e) => e.isAudio).map((e) => e.id).toSet();
                          if (_selectedItemIds.length == currentAudioIds.length) {
                            _selectedItemIds.clear();
                          } else {
                            _selectedItemIds.addAll(currentAudioIds);
                          }
                        });
                      },
                      child: Text(
                        _selectedItemIds.length == items.where((e) => e.isAudio).length
                            ? l10n.deselectAll
                            : l10n.selectAll,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Play Selected Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.playlist_play_rounded, size: 18),
                      label: Text(l10n.playAsPlaylist, style: const TextStyle(fontSize: 11)),
                      onPressed: _selectedItemIds.isNotEmpty ? () => _playSelectedAsPlaylist(items) : null,
                    ),
                    const SizedBox(width: 4),
                    // Save Selected as Playlist Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text('+ Playlista', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _selectedItemIds.isNotEmpty ? () => _openPlaylistEditor() : null,
                    ),
                    const SizedBox(width: 4),
                    // Cancel Selection
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedItemIds.clear();
                        });
                      },
                    ),
                  ],
                ),
              )
            // Storage Meter & Controls Deck (When not in selection mode)
            else
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
                                        Icons.view_list_rounded,
                                        size: 16,
                                        color: !libraryState.isGridView
                                            ? AppColors.primaryAccent
                                            : (isDark ? AppColors.outline : const Color(0xFF64748B)),
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
                                            ? AppColors.primaryAccent
                                            : (isDark ? AppColors.outline : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Sort Order Button
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

                    // Visual Storage Gauge Bar
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

                    // Quick Audio / Playlist Bar (Play All & Select Tracks)
                    if (audioCount > 0 && !isPlaylistsTab) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                                side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.playlist_play_rounded, size: 18),
                              label: Text(l10n.playAll, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _playAllAudio(items),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryAccent,
                                side: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.checklist_rounded, size: 18),
                              label: Text(l10n.selectTracksAction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Main Content: Playlists Tab View vs Media Items List/Grid
            if (isPlaylistsTab)
              _buildPlaylistsView(context, libraryState, libraryNotifier, isDark, l10n)
            else if (items.isEmpty)
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
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedItemIds.contains(item.id),
                    onToggleSelect: () => _toggleSelectItem(item.id),
                    onPlay: () => _onPlayItem(item, items),
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
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedItemIds.contains(item.id),
                    onToggleSelect: () => _toggleSelectItem(item.id),
                    onPlay: () => _onPlayItem(item, items),
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

  void _playSmartPlaylist(List<MediaItem> tracks, String emptyMsg) {
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMsg)),
      );
      return;
    }
    ref.read(playerProvider.notifier).playPlaylist(tracks, initialIndex: 0);
    VideoPlayerModal.show(context);
  }

  Widget _buildPlaylistsView(
    BuildContext context,
    LibraryState state,
    MediaLibraryNotifier notifier,
    bool isDark,
    L10n l10n,
  ) {
    final audioItems = state.allItems.where((e) => e.isAudio).toList();
    final recentTracks = List<MediaItem>.from(audioItems);
    final favoriteTracks = audioItems.where((e) => e.isFavorite).toList();
    final mostPlayedTracks = List<MediaItem>.from(audioItems)..sort((a, b) => b.duration.compareTo(a.duration));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Smart Playlists Section
        Text(
          l10n.smartPlaylists,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 1. Recently Added
              _buildSmartPlaylistTile(
                title: l10n.smartRecentlyAdded,
                count: recentTracks.length,
                icon: Icons.history_rounded,
                colors: [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
                isDark: isDark,
                onTap: () => _playSmartPlaylist(recentTracks, l10n.noMediaYet),
              ),
              const SizedBox(width: 10),
              // 2. Favorites
              _buildSmartPlaylistTile(
                title: l10n.smartFavorites,
                count: favoriteTracks.length,
                icon: Icons.favorite_rounded,
                colors: [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
                isDark: isDark,
                onTap: () => _playSmartPlaylist(favoriteTracks, l10n.noMediaYet),
              ),
              const SizedBox(width: 10),
              // 3. Most Played
              _buildSmartPlaylistTile(
                title: l10n.smartMostPlayed,
                count: mostPlayedTracks.length,
                icon: Icons.local_fire_department_rounded,
                colors: [const Color(0xFFF59E0B), const Color(0xFFEA580C)],
                isDark: isDark,
                onTap: () => _playSmartPlaylist(mostPlayedTracks, l10n.noMediaYet),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Custom Playlists Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.customPlaylists,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${state.allPlaylists.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Action: + Nova Playlista & Vanjske Mape
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n.newPlaylist, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openPlaylistEditor(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                side: BorderSide(color: isDark ? AppColors.stroke : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.folder_open_rounded, size: 20, color: AppColors.primaryAccent),
              label: const Text('Mape', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _openExternalFoldersModal(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (state.allPlaylists.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerLow : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.queue_music_rounded, size: 48, color: AppColors.secondary),
                const SizedBox(height: 12),
                Text(
                  l10n.noPlaylistsYet,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noPlaylistsSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.outline : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.allPlaylists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final pl = state.allPlaylists[idx];
              final isExternalFolder = pl.id.startsWith('ext_pl_');
              final matchingTracks = pl.trackIds
                  .map((id) => state.allItems.where((e) => e.id == id).firstOrNull)
                  .whereType<MediaItem>()
                  .toList();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticService.selection();
                    PlaylistDetailModal.show(
                      context,
                      playlist: pl,
                      isExternalFolder: isExternalFolder,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainer : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Playlist Icon Box
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: isExternalFolder
                                ? const LinearGradient(
                                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              isExternalFolder ? Icons.folder_rounded : Icons.queue_music_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pl.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isExternalFolder
                                    ? '${pl.trackIds.length} pjesama (Vanjska mapa)'
                                    : '${pl.trackIds.length} pjesama (${matchingTracks.length} dostupno)',
                                style: TextStyle(fontSize: 12, color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),

                        // Play Button
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryAccent, size: 22),
                            onPressed: matchingTracks.isNotEmpty ? () => _playLocalPlaylist(pl, state.allItems) : null,
                          ),
                        ),
                        if (!isExternalFolder) ...[
                          const SizedBox(width: 4),
                          // Edit Playlist Button
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 22),
                            color: AppColors.primaryAccent,
                            tooltip: 'Uredi playlistu',
                            onPressed: () => _openPlaylistEditor(existingPlaylist: pl),
                          ),
                        ],
                        const SizedBox(width: 4),

                        // Delete / Remove
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: AppColors.errorAccent.withValues(alpha: 0.7),
                          onPressed: () async {
                            HapticService.error();
                            if (isExternalFolder) {
                              final folder = state.externalFolders
                                  .where((f) => 'ext_pl_${f.uri.hashCode}' == pl.id)
                                  .firstOrNull;
                              if (folder != null) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    title: const Text('Ukloni vanjsku mapu?'),
                                    content: Text('Želite li ukloniti "${folder.name}" iz AllDowna? Vaše datoteke na memoriji telefona neće biti dirane niti obrisane.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dlgCtx, false),
                                        child: const Text('Odustani'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dlgCtx, true),
                                        style: FilledButton.styleFrom(backgroundColor: AppColors.errorAccent),
                                        child: const Text('Ukloni'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await notifier.removeExternalFolder(folder.uri);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Uklonjena mapa ${folder.name}')),
                                    );
                                  }
                                }
                              }
                              return;
                            }
                            notifier.deletePlaylist(pl.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.playlistDeleted)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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

  Widget _buildSmartPlaylistTile({
    required String title,
    required int count,
    required IconData icon,
    required List<Color> colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainer : Colors.white,
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
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.play_arrow_rounded, color: AppColors.primaryAccent, size: 18),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '$count pjesama',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.outline : const Color(0xFF64748B),
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
