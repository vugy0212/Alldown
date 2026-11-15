import 'package:flutter/material.dart';
import '../models/local_playlist.dart';
import '../models/media_item.dart';
import '../services/external_music_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';

class PlaylistEditorModal extends StatefulWidget {
  final LocalPlaylist? playlist;
  final List<MediaItem> allAudioTracks;
  final List<ExternalFolder> externalFolders;
  final void Function(String title, List<String> trackIds) onSave;

  const PlaylistEditorModal({
    super.key,
    this.playlist,
    required this.allAudioTracks,
    required this.externalFolders,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    LocalPlaylist? playlist,
    required List<MediaItem> allAudioTracks,
    required List<ExternalFolder> externalFolders,
    required void Function(String title, List<String> trackIds) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlaylistEditorModal(
        playlist: playlist,
        allAudioTracks: allAudioTracks,
        externalFolders: externalFolders,
        onSave: onSave,
      ),
    );
  }

  @override
  State<PlaylistEditorModal> createState() => _PlaylistEditorModalState();
}

class _PlaylistEditorModalState extends State<PlaylistEditorModal> {
  late final TextEditingController _titleController;
  final TextEditingController _searchController = TextEditingController();

  late final Set<String> _selectedTrackIds;
  String _selectedFolderFilter = 'all'; // 'all', 'downloaded', or folder.uri
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.playlist?.title ?? '',
    );
    _selectedTrackIds = widget.playlist != null
        ? Set<String>.from(widget.playlist!.trackIds)
        : <String>{};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MediaItem> get _filteredTracks {
    return widget.allAudioTracks.where((track) {
      if (!track.isAudio) return false;

      // Folder filter
      if (_selectedFolderFilter == 'downloaded') {
        if (track.localPath.startsWith('content://')) return false;
      } else if (_selectedFolderFilter != 'all') {
        if (!track.localPath.startsWith(_selectedFolderFilter)) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = track.title.toLowerCase().contains(q);
        final matchArtist = track.channel.toLowerCase().contains(q);
        if (!matchTitle && !matchArtist) return false;
      }

      return true;
    }).toList();
  }

  void _toggleSelectAll(List<MediaItem> visibleTracks) {
    HapticService.selection();
    final visibleIds = visibleTracks.map((t) => t.id).toSet();
    final allVisibleSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selectedTrackIds.contains(id));

    setState(() {
      if (allVisibleSelected) {
        _selectedTrackIds.removeAll(visibleIds);
      } else {
        _selectedTrackIds.addAll(visibleIds);
      }
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesite naziv playliste')),
      );
      return;
    }
    HapticService.medium();
    widget.onSave(title, _selectedTrackIds.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.playlist != null;
    final visibleTracks = _filteredTracks;
    final totalAudioCount = widget.allAudioTracks.where((t) => t.isAudio).length;

    final visibleIds = visibleTracks.map((t) => t.id).toSet();
    final allVisibleSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selectedTrackIds.contains(id));

    final downloadedCount = widget.allAudioTracks
        .where((t) => t.isAudio && !t.localPath.startsWith('content://'))
        .length;

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
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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

          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEditing ? 'Uredi playlistu' : 'Nova playlista',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.onSurfaceVariant,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Playlist Name Input
          TextField(
            controller: _titleController,
            autofocus: false,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              labelText: 'Naziv playliste',
              hintText: 'Npr. Omiljeni mix, Trening, Vožnja...',
              filled: true,
              fillColor: isDark ? AppColors.surfaceContainer : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Search Bar for Tracks
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainer : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? AppColors.outline : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Pretraži pjesme ($totalAudioCount ukupno)...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.outline : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Source / Folder Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Sve ($totalAudioCount)',
                  isSelected: _selectedFolderFilter == 'all',
                  onTap: () => setState(() => _selectedFolderFilter = 'all'),
                  isDark: isDark,
                ),
                if (downloadedCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Preuzeto ($downloadedCount)',
                    isSelected: _selectedFolderFilter == 'downloaded',
                    onTap: () => setState(() => _selectedFolderFilter = 'downloaded'),
                    isDark: isDark,
                  ),
                ],
                for (final folder in widget.externalFolders) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: '📁 ${folder.name} (${folder.trackCount})',
                    isSelected: _selectedFolderFilter == folder.uri,
                    onTap: () => setState(() => _selectedFolderFilter = folder.uri),
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selection summary & Select All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Odabrano: ${_selectedTrackIds.length} pjesama',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAccent,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  allVisibleSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: AppColors.primaryAccent,
                ),
                label: Text(
                  allVisibleSelected ? 'Odznači prikazane' : 'Označi sve prikazane',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _toggleSelectAll(visibleTracks),
              ),
            ],
          ),
          const Divider(height: 1),

          // Track List
          Expanded(
            child: visibleTracks.isEmpty
                ? Center(
                    child: Text(
                      'Nema pronađenih pjesama',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.outline : const Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleTracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final track = visibleTracks[idx];
                      final isSelected = _selectedTrackIds.contains(track.id);
                      final isExternal = track.localPath.startsWith('content://');

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: AppColors.primaryAccent,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${isExternal ? "📁 " : ""}${track.channel} • ${track.duration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.outline : const Color(0xFF64748B),
                          ),
                        ),
                        onChanged: (val) {
                          HapticService.selection();
                          setState(() {
                            if (val == true) {
                              _selectedTrackIds.add(track.id);
                            } else {
                              _selectedTrackIds.remove(track.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                isEditing ? 'Spremi promjene' : 'Stvori playlistu (${_selectedTrackIds.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent
              : (isDark ? AppColors.surfaceContainer : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAccent
                : (isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.onSurface : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
