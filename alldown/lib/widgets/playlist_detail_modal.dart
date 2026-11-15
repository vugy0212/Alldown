import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_playlist.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';
import 'playlist_editor_modal.dart';
import 'video_player_modal.dart';

class PlaylistDetailModal extends ConsumerWidget {
  final LocalPlaylist playlist;
  final bool isExternalFolder;

  const PlaylistDetailModal({
    super.key,
    required this.playlist,
    required this.isExternalFolder,
  });

  static Future<void> show(
    BuildContext context, {
    required LocalPlaylist playlist,
    required bool isExternalFolder,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaylistDetailModal(
        playlist: playlist,
        isExternalFolder: isExternalFolder,
      ),
    );
  }

  void _playFromIndex(BuildContext context, WidgetRef ref, List<MediaItem> tracks, int index) {
    if (tracks.isEmpty) return;
    HapticService.light();
    ref.read(playerProvider.notifier).playPlaylist(tracks, initialIndex: index);
    VideoPlayerModal.show(context);
  }

  void _shufflePlay(BuildContext context, WidgetRef ref, List<MediaItem> tracks) {
    if (tracks.isEmpty) return;
    HapticService.medium();
    final shuffled = List<MediaItem>.from(tracks)..shuffle();
    ref.read(playerProvider.notifier).playPlaylist(shuffled, initialIndex: 0);
    VideoPlayerModal.show(context);
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, MediaItem track) {
    final titleCtrl = TextEditingController(text: track.title);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Preimenuj pjesmu'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Naziv pjesme',
            hintText: 'Unesite novi naziv',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = titleCtrl.text.trim();
              if (newName.isNotEmpty && newName != track.title) {
                Navigator.pop(dlgCtx);
                final success = await ref
                    .read(mediaLibraryProvider.notifier)
                    .renameTrack(track, newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Pjesma preimenovana u "$newName"'
                            : 'Neuspjelo preimenovanje',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, MediaItem track) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Obriši pjesmu?'),
        content: Text(
          'Želite li trajno obrisati "${track.title}" s vašeg uređaja?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Odustani'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorAccent),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              final deleted = await ref
                  .read(mediaLibraryProvider.notifier)
                  .deleteTrack(track);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      deleted
                          ? 'Pjesma "${track.title}" je obrisana'
                          : 'Neuspjelo brisanje',
                    ),
                  ),
                );
              }
            },
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(mediaLibraryProvider);
    final isDark = ref.watch(settingsProvider).isDarkMode;

    // Resolve current playlist (if updated in state)
    final currentPlaylist = libraryState.allPlaylists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );

    final matchingTracks = currentPlaylist.trackIds
        .map((id) => libraryState.allItems.where((item) => item.id == id).firstOrNull)
        .whereType<MediaItem>()
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.stroke : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                    isExternalFolder
                        ? Icons.folder_rounded
                        : Icons.queue_music_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPlaylist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExternalFolder
                          ? '${matchingTracks.length} pjesama • Vanjska mapa'
                          : '${matchingTracks.length} pjesama • Playlista',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.outline : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.onSurfaceVariant,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Playback Actions Bar
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Sviraj sve',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: matchingTracks.isNotEmpty
                      ? () => _playFromIndex(context, ref, matchingTracks, 0)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                  side: BorderSide(
                    color: isDark ? AppColors.stroke : const Color(0xFFCBD5E1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text(
                  'Nasumično',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: matchingTracks.isNotEmpty
                    ? () => _shufflePlay(context, ref, matchingTracks)
                    : null,
              ),
              if (!isExternalFolder) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  tooltip: 'Uredi',
                  onPressed: () {
                    PlaylistEditorModal.show(
                      context,
                      playlist: currentPlaylist,
                      allAudioTracks: libraryState.allItems
                          .where((e) => e.isAudio)
                          .toList(),
                      externalFolders: libraryState.externalFolders,
                      onSave: (title, trackIds) {
                        ref
                            .read(mediaLibraryProvider.notifier)
                            .updatePlaylist(
                              currentPlaylist.id,
                              title: title,
                              trackIds: trackIds,
                            );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Track List
          Expanded(
            child: matchingTracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_off_rounded,
                          size: 40,
                          color: isDark ? AppColors.outline : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mapa je prazna ili pjesme nisu dostupne',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.outline : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: matchingTracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final track = matchingTracks[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceContainer
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 20,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${track.channel} • ${track.duration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.outline : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 19,
                                color: track.isFavorite ? AppColors.errorAccent : AppColors.outline,
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(28, 28),
                              ),
                              onPressed: () {
                                HapticService.selection();
                                ref.read(mediaLibraryProvider.notifier).toggleFavorite(track.id);
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18),
                              onSelected: (action) {
                                switch (action) {
                                  case 'play':
                                    _playFromIndex(context, ref, matchingTracks, idx);
                                    break;
                                  case 'favorite':
                                    ref.read(mediaLibraryProvider.notifier).toggleFavorite(track.id);
                                    break;
                                  case 'rename':
                                    _showRenameDialog(context, ref, track);
                                    break;
                                  case 'delete':
                                    _showDeleteDialog(context, ref, track);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'play',
                                  child: Row(
                                    children: [
                                      Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.primaryAccent),
                                      SizedBox(width: 8),
                                      Text('Sviraj'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'favorite',
                                  child: Row(
                                    children: [
                                      Icon(
                                        track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        size: 18,
                                        color: track.isFavorite ? AppColors.errorAccent : AppColors.outline,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(track.isFavorite ? 'Ukloni iz favorita' : 'Dodaj u favorite'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 18, color: AppColors.secondary),
                                      const SizedBox(width: 8),
                                      const Text('Preimenuj'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorAccent),
                                      const SizedBox(width: 8),
                                      const Text('Obriši', style: TextStyle(color: AppColors.errorAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _playFromIndex(context, ref, matchingTracks, idx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
