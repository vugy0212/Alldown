import 'package:flutter/material.dart';
import '../services/external_music_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';

class ExternalFoldersModal extends StatelessWidget {
  final List<ExternalFolder> folders;
  final Future<void> Function() onAddFolder;
  final Future<void> Function(String uri) onRemoveFolder;

  const ExternalFoldersModal({
    super.key,
    required this.folders,
    required this.onAddFolder,
    required this.onRemoveFolder,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ExternalFolder> folders,
    required Future<void> Function() onAddFolder,
    required Future<void> Function(String uri) onRemoveFolder,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExternalFoldersModal(
        folders: folders,
        onAddFolder: onAddFolder,
        onRemoveFolder: onRemoveFolder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: AppColors.primaryAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Glazbene mape (Lokalno)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Uvezi i reproduciraj vanjsku glazbu s uređaja',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.onSurfaceVariant
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            // Content: Empty State or Folder List
            Flexible(
              child: folders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.snippet_folder_outlined,
                            size: 56,
                            color: isDark
                                ? AppColors.onSurfaceVariant.withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Nema uvezenih mapa',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dodajte mapu (npr. Music ili Audiobooks) kako biste slušali svoje lokalne pjesme u AllDown playeru uz puni ekvilajzer i efekte.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.onSurfaceVariant
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: folders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceContainer
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.stroke
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: AppColors.secondary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      folder.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${folder.trackCount} pjesama',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                tooltip: 'Ukloni mapu',
                                onPressed: () async {
                                  HapticService.error();
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Ukloni mapu?'),
                                      content: Text(
                                        'Želite li ukloniti mapu "${folder.name}" iz biblioteke? Datoteke na uređaju neće biti obrisane.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, false),
                                          child: const Text('Odustani'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          child: const Text(
                                            'Ukloni',
                                            style: TextStyle(
                                                color: Colors.redAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await onRemoveFolder(folder.uri);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),

            // Bottom Add Folder Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticService.medium();
                  Navigator.pop(context);
                  await onAddFolder();
                },
                icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                label: const Text(
                  'Dodaj vanjsku mapu s glazbom',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
