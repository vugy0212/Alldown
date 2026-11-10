import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_item.dart';
import '../theme/app_colors.dart';
import 'video_editor_modal.dart';

class LibraryItemCard extends StatelessWidget {
  final MediaItem item;
  final bool isGrid;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const LibraryItemCard({
    super.key,
    required this.item,
    this.isGrid = false,
    required this.onPlay,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  void _showContextMenu(BuildContext context) {
    final isGif = item.format == 'GIF' || item.localPath.toLowerCase().endsWith('.gif');
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;

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
                  title: Text(isGif ? 'Pregledaj GIF animaciju' : 'Play with In-App Player'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPlay();
                  },
                ),
                if (!item.isAudio && !isGif)
                  ListTile(
                    leading: const Icon(Icons.content_cut_rounded, color: AppColors.secondary),
                    title: const Text('Trim, Crop & Make GIF'),
                    subtitle: const Text('Izreži isječak, prilagodi kadar ili izradi GIF'),
                    onTap: () {
                      Navigator.pop(ctx);
                      VideoEditorModal.show(context, item);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: AppColors.outline),
                  title: const Text('Share / Open Externally'),
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
                  leading: const Icon(Icons.folder_open_outlined, color: AppColors.outline),
                  title: const Text('Show File Path'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved at: ${item.localPath}')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded, color: AppColors.outline),
                  title: const Text('Copy Path'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.localPath));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied to clipboard')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: item.isFavorite ? AppColors.errorAccent : AppColors.outline,
                  ),
                  title: Text(item.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onToggleFavorite();
                  },
                ),
                const Divider(color: AppColors.stroke),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorAccent),
                  title: const Text('Delete File', style: TextStyle(color: AppColors.errorAccent)),
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
  Widget build(BuildContext context) {
    if (isGrid) {
      return _buildGridCard(context);
    }
    return _buildListCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        onPressed: () => _showContextMenu(context),
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
                          style: const TextStyle(
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
                          style: const TextStyle(
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
                          style: const TextStyle(
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
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.completedDateFormatted} • Tap to play',
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
      onTap: onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke, width: 1),
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
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.movie_rounded, color: AppColors.outline),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.movie_rounded, color: AppColors.outline),
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
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.sizeFormatted,
                        style: const TextStyle(fontSize: 10, color: AppColors.outline),
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

