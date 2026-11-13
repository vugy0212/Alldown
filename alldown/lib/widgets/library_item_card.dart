import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n.dart';
import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
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
                    Navigator.pop(ctx);
                    onToggleFavorite();
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
      onTap: isSelectionMode ? onToggleSelect : onPlay,
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
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        color: AppColors.outline,
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                        ),
                        onPressed: () => _showContextMenu(context, ref),
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
      onTap: isSelectionMode ? onToggleSelect : onPlay,
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

