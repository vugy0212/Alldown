import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n.dart';
import '../models/media_item.dart';
import '../providers/player_provider.dart';
import '../providers/media_library_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../services/haptic_service.dart';
import 'audio_trimmer_modal.dart';
import 'video_editor_modal.dart';

class LibraryItemCard extends ConsumerWidget {
  final MediaItem item;
  final bool isGrid;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const LibraryItemCard({
    super.key,
    required this.item,
    this.isGrid = false,
    required this.onPlay,
    required this.onDelete,
    required this.onToggleFavorite,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final isGif = item.format == 'GIF' || item.localPath.toLowerCase().endsWith('.gif');
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;
    final l10n = L10n(ref.read(settingsProvider).language);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 12 + bottomNavPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    isGif ? Icons.gif_rounded : Icons.play_circle_outline_rounded,
                    color: isGif ? AppColors.secondary : AppColors.primary,
                    size: isGif ? 26 : 22,
                  ),
                  title: Text(isGif
                      ? (l10n.isHr ? 'Pregledaj GIF animaciju' : 'View GIF Animation')
                      : (l10n.isHr ? 'Pokreni u playeru' : 'Play with In-App Player')),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPlay();
                  },
                ),
                if (item.isAudio) ...[
                  ListTile(
                    leading: const Icon(Icons.playlist_play_rounded, color: AppColors.primaryAccent),
                    title: Text(l10n.isHr ? 'Sviraj sljedeće' : 'Play Next in Queue'),
                    subtitle: Text(l10n.isHr ? 'Umetni odmah iza trenutne pjesme' : 'Insert directly after current playing track'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(playerProvider.notifier).playNextInQueue(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.isHr ? 'Pjesma dodana kao sljedeća u redu' : 'Track inserted next in queue')),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.queue_music_rounded, color: AppColors.secondary),
                    title: Text(l10n.isHr ? 'Dodaj na kraj reda' : 'Add to Queue End'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(playerProvider.notifier).addToQueue(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.isHr ? 'Pjesma dodana na kraj reda' : 'Track added to queue')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryAccent),
                    title: Text(l10n.isHr ? 'Dodaj u playlistu' : 'Add to Playlist'),
                    subtitle: Text(l10n.isHr ? 'Uvrsti u postojeću ili novu playlistu' : 'Add to custom playlist'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddToPlaylistSheet(context, ref, item, l10n);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.content_cut_rounded, color: AppColors.tertiary),
                    title: Text(l10n.isHr ? 'Izreži zvuk (Audio Trimmer)' : 'Trim Audio Segment'),
                    subtitle: Text(l10n.isHr ? 'Stvori kraći audio isječak ili melodiju' : 'Create audio clip or ringtone'),
                    onTap: () {
                      Navigator.pop(ctx);
                      AudioTrimmerModal.show(context, item);
                    },
                  ),
                ],
                if (!item.isAudio && !isGif) ...[
                  ListTile(
                    leading: Icon(Icons.content_cut_rounded, color: AppColors.secondary),
                    title: Text(l10n.isHr ? 'Uredi video i kadar' : 'Edit Video & Framing'),
                    subtitle: Text(l10n.isHr
                        ? 'Obreži, izreži, zumiraj i napravi GIF'
                        : 'Trim, crop, CapCut pinch-zoom & GIF'),
                    onTap: () {
                      Navigator.pop(ctx);
                      VideoEditorModal.show(context, item);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.music_note_rounded, color: AppColors.primary),
                    title: Text(l10n.isHr ? 'Izdvoji i obreži zvuk' : 'Extract & Trim Audio'),
                    subtitle: Text(l10n.isHr
                        ? 'Pretvori video isječak u M4A zvuk'
                        : 'Convert video segment to M4A audio'),
                    onTap: () {
                      Navigator.pop(ctx);
                      VideoEditorModal.show(context, item);
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(Icons.share_outlined, color: AppColors.outline),
                  title: Text(l10n.isHr ? 'Podijeli / Otvori izvana' : 'Share / Open Externally'),
                  onTap: () {
                    Navigator.pop(ctx);
                    SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(item.localPath)],
                        text: item.title,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.folder_open_outlined, color: AppColors.outline),
                  title: Text(l10n.isHr ? 'Prikaži putanju datoteke' : 'Show File Path'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.isHr ? "Spremljeno u:" : "Saved at:"} ${item.localPath}')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.content_copy_rounded, color: AppColors.outline),
                  title: Text(l10n.isHr ? 'Kopiraj putanju' : 'Copy Path'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.localPath));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.isHr ? 'Putanja kopirana u međuspremnik' : 'Path copied to clipboard',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: item.isFavorite ? AppColors.errorAccent : AppColors.outline,
                  ),
                  title: Text(item.isFavorite
                      ? (l10n.isHr ? 'Ukloni iz favorita' : 'Remove from Favorites')
                      : (l10n.isHr ? 'Dodaj u favorite' : 'Add to Favorites')),
                  onTap: () {
                    HapticService.light();
                    Navigator.pop(ctx);
                    onToggleFavorite();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: AppColors.secondary),
                  title: Text(l10n.isHr ? 'Preimenuj' : 'Rename'),
                  onTap: () {
                    HapticService.light();
                    Navigator.pop(ctx);
                    _showRenameDialog(context, ref, item, l10n);
                  },
                ),
                Divider(color: AppColors.stroke),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorAccent),
                  title: Text(
                    l10n.isHr ? 'Obriši datoteku' : 'Delete File',
                    style: const TextStyle(color: AppColors.errorAccent),
                  ),
                  onTap: () {
                    HapticService.error();
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, MediaItem track, L10n l10n) {
    final titleCtrl = TextEditingController(text: track.title);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l10n.isHr ? 'Preimenuj stavku' : 'Rename Item'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.isHr ? 'Naziv' : 'Title',
            hintText: l10n.isHr ? 'Unesite novi naziv' : 'Enter new title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(l10n.isHr ? 'Odustani' : 'Cancel'),
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
                            ? (l10n.isHr ? 'Preimenovano u "$newName"' : 'Renamed to "$newName"')
                            : (l10n.isHr ? 'Neuspjelo preimenovanje' : 'Failed to rename'),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.isHr ? 'Spremi' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref, MediaItem track, L10n l10n) {
    final libraryState = ref.read(mediaLibraryProvider);
    final notifier = ref.read(mediaLibraryProvider.notifier);
    final isDark = ref.read(settingsProvider).isDarkMode;
    final playlists = libraryState.localPlaylists;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceContainerHigh : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  l10n.isHr ? 'Dodaj u playlistu' : 'Add to Playlist',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    l10n.newPlaylist,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final titleCtrl = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: Text(l10n.newPlaylist),
                        content: TextField(
                          controller: titleCtrl,
                          autofocus: true,
                          decoration: InputDecoration(hintText: l10n.enterPlaylistName),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            child: const Text('Odustani'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final name = titleCtrl.text.trim();
                              if (name.isNotEmpty) {
                                notifier.createPlaylist(name, [track.id]);
                                Navigator.pop(dlgCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Pjesma dodana u novu playlistu "$name"')),
                                );
                              }
                            },
                            child: const Text('Stvori'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        l10n.noPlaylistsYet,
                        style: TextStyle(color: isDark ? AppColors.outline : const Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (_, idx) {
                        final pl = playlists[idx];
                        final contains = pl.trackIds.contains(track.id);
                        return ListTile(
                          leading: const Icon(Icons.queue_music_rounded, color: AppColors.primaryAccent),
                          title: Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${pl.trackIds.length} pjesama'),
                          trailing: contains
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryAccent, size: 20)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            if (contains) {
                              notifier.removeTrackFromPlaylist(pl.id, track.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pjesma uklonjena iz "${pl.title}"')),
                              );
                            } else {
                              notifier.addTracksToPlaylist(pl.id, [track.id]);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pjesma dodana u "${pl.title}"')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n(ref.watch(settingsProvider).language);
    if (isGrid) {
      return _buildGridCard(context);
    }
    return _buildListCard(context, ref, l10n);
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, L10n l10n) {
    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          HapticService.selection();
          onToggleSelect?.call();
        } else {
          HapticService.light();
          onPlay();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.12)
              : (AppColors.isDark ? AppColors.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : AppColors.stroke,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: AppColors.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 18),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppColors.primaryAccent : AppColors.outline,
                  size: 24,
                ),
              ),
            // Thumbnail with play overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: item.isVertical ? 56 : 100,
                    height: item.isVertical ? 80 : 66,
                    color: AppColors.surfaceContainerHigh,
                    child: item.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            item.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(
                                item.isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
                                color: AppColors.outline,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              item.isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
                              color: AppColors.outline,
                            ),
                          ),
                  ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Duration badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.duration,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Content info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                                height: 1.25,
                              ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 19,
                              color: item.isFavorite ? AppColors.errorAccent : AppColors.outline,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(28, 28),
                            ),
                            onPressed: () {
                              HapticService.selection();
                              onToggleFavorite();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            color: AppColors.outline,
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(28, 28),
                            ),
                            onPressed: () {
                              HapticService.light();
                              _showContextMenu(context, ref);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Format badges row
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.resolution,
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
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.format,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.sizeFormatted,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (item.platform == "YouTube")
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_display_rounded, size: 10, color: AppColors.errorAccent),
                              SizedBox(width: 2),
                              Text(
                                'YouTube',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Date completed
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.completedDateFormatted.replaceAll('Completed Just Now', l10n.completedJustNow)} • ${l10n.tapToPlay}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: AppColors.outline,
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
      ),
    );
  }

  Widget _buildGridCard(BuildContext context) {
    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          HapticService.selection();
          onToggleSelect?.call();
        } else {
          HapticService.light();
          onPlay();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.12)
              : (AppColors.isDark ? AppColors.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAccent
                : (AppColors.isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: AppColors.isDark
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top thumbnail
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.surfaceContainerHigh,
                      child: item.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              item.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(Icons.movie_rounded, color: AppColors.outline),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.movie_rounded, color: AppColors.outline),
                            ),
                    ),
                  ),
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? AppColors.primaryAccent : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        HapticService.selection();
                        onToggleFavorite();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: item.isFavorite ? AppColors.errorAccent : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.duration,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          item.resolution,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.sizeFormatted,
                        style: TextStyle(fontSize: 10, color: AppColors.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

